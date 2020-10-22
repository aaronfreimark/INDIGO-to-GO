//
//  MainTabView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/21/20.
//

import SwiftUI

struct MainTabView: View {
    @State var currentTab: Int
    
    var body: some View {
        TabView(selection: $currentTab) {
            Text("Tab Content 1").tabItem { Label("Monitor", systemImage: <#T##String#>) }.tag(1)
            Text("Tab Content 2").tabItem { Label("Preview", systemImage: <#T##String#>) }.tag(2)
            Text("Tab Content 2").tabItem { Label("Settings", systemImage: <#T##String#>) }.tag(3)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView(currentTab: 1)
    }
}
