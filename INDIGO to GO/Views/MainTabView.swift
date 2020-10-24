//
//  MainTabView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/21/20.
//

import SwiftUI

struct MainTabView: View {
    @State var currentTab: Int = 1
    @EnvironmentObject var client: IndigoClientViewModel
    
    /// Set up a timer for periodic refresh
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()


    var body: some View {
        TabView(selection: $currentTab) {
            MonitorView()
                .tabItem { Label("Monitor", systemImage: "list.bullet.below.rectangle") }
                .tag(1)
            ImagerPreviewView()
                .tabItem { Label("Preview", systemImage: "camera.metering.matrix") }
                .tag(2)
//            Text("Sequence")
//                .tabItem { Label("Sequence", systemImage: "list.bullet.rectangle") }
//                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
        .environmentObject(client)
        .onReceive(timer) { input in
            client.update()
        }
        .onAppear(perform: {
            /// Start up Bonjour, let stuff populate
//            self.showSpinner()
            DispatchQueue.main.async() {
                client.client.bonjourBrowser.seek()
            }
            
            /// after 1 second search for whatever is in serverSettings.servers to try to reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if client.connectedServers().count == 0 {
                    client.reinitSavedServers()
                }
            }

            /// after 2 seconds search again
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if client.connectedServers().count == 0 {
                    client.reinitSavedServers()
                }
            }

        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            
            /// Start up Bonjour, let stuff populate
//            self.showSpinner()
            DispatchQueue.main.async() {
                client.client.bonjourBrowser.seek()
            }
            
            /// after 1 second search for whatever is in serverSettings.servers to try to reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if client.connectedServers().count == 0 {
                    client.reinitSavedServers()
                }
            }
            /// after 2 seconds search again
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if client.connectedServers().count == 0 {
                    client.reinitSavedServers()
                }
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: MockIndigoClientForPreview(), isPreview: true)
        MainTabView()
            .environmentObject(client)
    }
}
