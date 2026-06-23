const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions/v2");

initializeApp();

// Fires whenever a new message is written under
// conversations/{cid}/messages/{mid}. Looks up the recipient's FCM tokens
// and sends an APNs push. Prunes tokens FCM reports as dead.
exports.onMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const msg = event.data?.data();
    if (!msg) {
      logger.warn("onMessageCreated fired with no data", { params: event.params });
      return;
    }
    const { conversationId } = event.params;

    const convSnap = await getFirestore()
      .collection("conversations").doc(conversationId).get();
    const conv = convSnap.data();
    if (!conv || !Array.isArray(conv.participants)) {
      logger.warn("conversation has no participants", { conversationId });
      return;
    }

    const recipientUid = conv.participants.find((u) => u !== msg.senderUid);
    if (!recipientUid) {
      logger.info("no distinct recipient — skipping", { conversationId, senderUid: msg.senderUid });
      return;
    }

    const senderName =
      (conv.participantNames && conv.participantNames[msg.senderUid]) || "Someone";

    const tokensSnap = await getFirestore()
      .collection("users").doc(recipientUid).collection("fcmTokens").get();
    const tokenDocs = tokensSnap.docs;
    const tokens = tokenDocs.map((d) => d.data().token).filter(Boolean);
    if (tokens.length === 0) {
      logger.info("recipient has no fcmTokens — skipping", { recipientUid });
      return;
    }

    const body = String(msg.text || "").slice(0, 140);
    const resp = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: senderName, body },
      data: { conversationId, type: "message" },
      apns: { payload: { aps: { sound: "default" } } },
    });

    logger.info("FCM result", {
      recipientUid,
      sent: resp.successCount,
      failed: resp.failureCount,
    });

    // Prune dead tokens.
    const deadDocIds = [];
    resp.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error && r.error.code;
        logger.warn("FCM send failed", {
          code,
          message: r.error && r.error.message,
          tokenPrefix: tokens[i] ? tokens[i].slice(0, 16) : null,
        });
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          deadDocIds.push(tokenDocs[i].id);
        }
      }
    });
    if (deadDocIds.length > 0) {
      await Promise.all(
        deadDocIds.map((id) =>
          getFirestore()
            .collection("users").doc(recipientUid)
            .collection("fcmTokens").doc(id)
            .delete()
        )
      );
      logger.info("pruned dead tokens", { recipientUid, count: deadDocIds.length });
    }
  }
);
