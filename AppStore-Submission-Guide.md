# BabyPass — App Store Submission Guide

## Part 1: App Store Listing Content

### App Name
BabyPass

### Subtitle (30 characters max)
Buy & Sell Baby Items Nearby

### Category
Primary: Shopping
Secondary: Lifestyle

### Price
Free

### Age Rating
4+ (no objectionable content)

### Keywords (100 characters max)
baby,kids,secondhand,resale,marketplace,stroller,car seat,toys,parents,local,buy,sell,used,clothing

### Description

BabyPass is the easiest way for parents to buy and sell secondhand baby and kids' items in their neighborhood.

Kids grow fast — and so does the pile of outgrown clothes, toys, and gear. BabyPass connects local parents so great baby items get a second life instead of collecting dust.

**How it works:**

**Selling is simple.** Snap a few photos, set your price, choose a pickup location, and your listing goes live instantly. Nearby parents can browse and message you to arrange a pickup.

**Buying is easy.** Browse listings by category — strollers, car seats, clothing, toys, furniture, and more. See items on a map to find what's close to you. Message sellers directly in the app to ask questions and set up a time to meet.

**Why parents love BabyPass:**
- Post items in under a minute
- Browse by category and condition
- See listings on an interactive map
- Message sellers directly in the app
- No shipping hassle — local pickup only
- Completely free, no fees

Whether you're a new parent looking for affordable gear or clearing out the nursery, BabyPass makes it simple. Join the community of parents helping each other save money and reduce waste.

### Promotional Text (170 characters max)
The neighborhood marketplace for parents. Buy and sell baby gear, clothes, toys, and more — locally and for free.

### What's New (for version 1.0)
Welcome to BabyPass! Browse and sell baby items near you, message sellers directly, and find great deals on the map.

---

## Part 2: Hosting Your Privacy Policy & Support Page

Apple requires a **Privacy Policy URL** and **Support URL** before you can submit. You have two HTML files ready — here's how to host them for free using GitHub Pages:

1. Go to github.com and sign in (or create a free account)
2. Create a new repository — name it something like `babypass-site`, set it to **Public**
3. Upload `privacy-policy.html` and `support.html` from your BabyPass folder
4. Go to the repo's **Settings → Pages**
5. Under "Source," select **Deploy from a branch**, pick `main`, and click Save
6. After a minute or two, your pages will be live at:
   - `https://YOUR-USERNAME.github.io/babypass-site/privacy-policy.html`
   - `https://YOUR-USERNAME.github.io/babypass-site/support.html`
7. Use these URLs in App Store Connect

---

## Part 3: Screenshots

You need screenshots for at least these device sizes:
- **6.7" display** (iPhone 15 Pro Max / 16 Pro Max) — required
- **6.5" display** (iPhone 11 Pro Max) — optional but recommended
- **iPad Pro 12.9"** — required only if you support iPad

**How to take screenshots in the Simulator:**

1. In Xcode, select an iPhone 15 Pro Max simulator
2. Run the app (⌘R)
3. Navigate to each screen and press ⌘S to save a screenshot
4. Screenshots save to your Desktop

**Recommended screenshots (in order):**

1. **Browse screen** — show a few listings with the search bar visible
2. **Map screen** — show listings pinned on the map
3. **Listing detail** — show a specific item with photos, price, and description
4. **Sell screen** — show the posting form filled out
5. **Messages screen** — show a conversation with a seller

Tip: Post a few test listings first so the Browse and Map screens look populated.

---

## Part 4: Step-by-Step Submission Checklist

### Prerequisites
- [ ] Apple Developer Program membership ($99/year) — enroll at developer.apple.com
- [ ] Privacy Policy and Support pages hosted and accessible (see Part 2)
- [ ] Screenshots taken for required device sizes (see Part 3)
- [ ] App icon showing correctly in the build

### In Xcode — Archive & Upload
- [ ] Set the device to "Any iOS Device" (not a simulator) in the toolbar
- [ ] Go to Product → Archive
- [ ] When the archive completes, the Organizer window opens
- [ ] Click "Distribute App"
- [ ] Choose "App Store Connect" → "Upload"
- [ ] Follow the prompts (keep default options) and click Upload
- [ ] Wait for the upload to finish and processing email from Apple (usually 5–15 minutes)

### In App Store Connect (appstoreconnect.apple.com)
- [ ] Sign in with your Apple Developer account
- [ ] Click the "+" or "New App" button
- [ ] Fill in:
  - Platform: iOS
  - Name: BabyPass
  - Primary Language: English (U.S.)
  - Bundle ID: com.jasmine.BabyPass
  - SKU: babypass-v1 (any unique string)
- [ ] On the app page, fill in the "App Information" tab:
  - Subtitle: Buy & Sell Baby Items Nearby
  - Category: Shopping (primary), Lifestyle (secondary)
  - Content Rights: does not contain third-party content
  - Age Rating: complete the questionnaire (answer No to all — should result in 4+)
  - Privacy Policy URL: paste your hosted URL
- [ ] On the "App Privacy" tab:
  - Click "Get Started"
  - Select: Yes, the app collects data
  - Data types collected: Contact Info (email, name), User Content (photos, messages), Location (coarse location for listings)
  - For each: used for App Functionality, not linked to identity for tracking
- [ ] On the "Pricing and Availability" tab:
  - Price: Free
  - Availability: select the countries you want
- [ ] On the version page (e.g., "1.0 Prepare for Submission"):
  - Upload screenshots for each required device size
  - Promotional Text: paste from Part 1
  - Description: paste from Part 1
  - Keywords: paste from Part 1
  - Support URL: paste your hosted support page URL
  - Marketing URL: optional (can leave blank)
  - Build: select the build you uploaded from Xcode
  - App Review Information: add your contact info and any notes for the reviewer
  - Version Release: "Automatically release this version"
- [ ] Click "Add for Review"
- [ ] Click "Submit to App Review"

### After Submission
- Apple typically reviews within 24–48 hours
- You'll get an email when the app is approved (or if changes are needed)
- If rejected, read the notes carefully — common reasons include missing privacy descriptions or screenshots not matching the app
- Once approved, BabyPass will be live on the App Store!
