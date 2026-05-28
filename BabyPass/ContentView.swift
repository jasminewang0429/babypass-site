//
//  ContentView.swift
//  BabyPass
//
//  Created by Jasmine Wang on 4/15/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(DataService())
}
