//
//  MainTabView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/21/20.
//

import SwiftUI

struct MainTabView: View {
    @State var currentTab: Int = 1
    @EnvironmentObject var client: IndigoClient

    var body: some View {
        TabView(selection: $currentTab) {
            ContentView()
                .tabItem { Label("Monitor", systemImage: "list.bullet.below.rectangle") }
                .tag(1)
            ImagerPreviewView()
                .tabItem { Label("Preview", systemImage: "camera.metering.matrix") }
                .tag(2)
            Text("Sequence")
                .tabItem { Label("Sequence", systemImage: "list.bullet.rectangle") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
        .environmentObject(client)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        MainTabView()
            .environmentObject(client)
    }
}
