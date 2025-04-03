//
//  ContentView.swift
//  CruiseAIios
//
//  Created by Ojas Kandhare on 4/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        HomePage(appState: appState)
    }
}

#Preview {
    ContentView()
}
