//
//  ContentView.swift
//  BabyPass
//
//  Created by Jasmine Wang on 4/15/26.
//

//import SwiftUI
//import FirebaseFirestore
//
//struct ContentView: View {
//    @State private var status = "Tap the button to test"
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("BabyPass")
//                .font(.largeTitle)
//                .fontWeight(.bold)
//            Text(status)
//                .foregroundColor(.gray)
//            Button("Test Firestore") {
//                let db = Firestore.firestore()
//                db.collection("test").addDocument(data: [
//                    "message": "Hello from BabyPass",
//                    "timestamp": Date()
//                ]) { error in
//                    if let error = error {
//                        status = "Error: \(error.localizedDescription)"
//                    } else {
//                        status = "Firestore write succeeded!"
//                    }
//                }
//            }
//            .buttonStyle(.borderedProminent)
//            .tint(.pink)
//        }
//    }
//}
import SwiftUI

//struct ContentView: View {
//    @EnvironmentObject var authService: AuthService
//
//    var body: some View {
//        Group {
//            if authService.isSignedIn {
//                MainTabView()
//            } else {
//                SignInView()
//            }
//        }
//        .animation(.easeInOut, value: authService.isSignedIn)
//    }
//}
struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(DataService())
}
