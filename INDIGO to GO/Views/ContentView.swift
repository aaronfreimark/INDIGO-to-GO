//
//  ContentView.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/9/20.
//

import SwiftUI

struct ContentView: View {
    /// The interesting stuff is in this object!
    @EnvironmentObject var client: IndigoClient
        
    /// Set up a timer for periodic refresh
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State var isShowingSpinner = true
    
    /// Keep track of whether a sheet is showing or not.
    @State private var isSettingsSheetShowing: Bool = false
    @State private var isAlertShowing: Bool = false
    
    var body: some View {
        
        List {
            if !client.isAnythingConnected {
                if self.isShowingSpinner {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    Section {
                        Text("No INDIGO agents are connected. Please tap the Server button to find some on your local network.")
                            .padding(30)
                    }
                }
            }

            // =================================================================== SEQUENCE

            if client.isImagerConnected || client.isMountConnected {
                Section(header: Text("Sequence")) {
                    if client.isImagerConnected  { ImagerProgressView().environmentObject(client) }

                    StatusRowView(sr: client.srEstimatedCompletion)
                    StatusRowView(sr: client.srHALimit)
                    StatusRowView(sr: client.srMeridianTransit)
                    StatusRowView(sr: client.srSunrise)
                }
            }

            if client.isImagerConnected {
                ImagerPreviewView().environmentObject(client)
            }

            // =================================================================== GUIDER

            if client.isGuiderConnected {
                Section(header: Text("Guider")) {
                    StatusRowView(sr: client.srGuidingStatus)
                    StatusRowView(sr: client.srRAError)
                    StatusRowView(sr: client.srDecError)
                }
            } else {
                EmptyView()
            }

            // =================================================================== HARDWARE

            if client.isMountConnected || client.isImagerConnected {
                Section(header: Text("Hardware")) {
                    StatusRowView(sr: client.srCoolingStatus)
                    StatusRowView(sr: client.srMountStatus)
                }
            }
            
            Section(footer:
                        VStack(alignment: .leading) {
                            ForEach(client.connectedServers(), id: \.self ) { name in
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text(name)
                                }
                            }
                        }) {

//                Button(action: { client.printProperties() } ) { Text("Properties") }

                /// Park & Warm Button
                if client.isMountConnected || client.isImagerConnected {
                    ParkAndWarmButton
                }

                /// Servers Button
                Button(action: serversButton) {
                    Text("Servers")
                }
                .sheet(isPresented: $isSettingsSheetShowing, content: { SettingsView().environmentObject(client) })
            }
            
        }
        .listStyle(GroupedListStyle())
        .onReceive(timer) { input in
            if !isSettingsSheetShowing {
                client.updateUI()
            }
        }
        .onAppear(perform: {
            /// Start up Bonjour, let stuff populate
            self.showSpinner()
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                client.bonjourBrowser.seek()
            })
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            
            /// Start up Bonjour, let stuff populate
            self.showSpinner()
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                client.bonjourBrowser.seek()
            })
            
            /// after 1 second search for whatever is in serverSettings.servers to try to reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                client.reinitSavedServers()
            }
        }

    }
    
    private var ParkAndWarmButton: some View {
        Button(action: { self.isAlertShowing = true }) {
            Text(client.parkButtonTitle)
        }
        .disabled(!client.isParkButtonEnabled)
        .alert(isPresented: $isAlertShowing, content: {
            Alert(
                title: Text(client.parkButtonTitle),
                message: Text(client.parkButtonDescription),
                primaryButton: .destructive(Text(client.parkButtonOK), action: {
                    isAlertShowing = false
                    client.emergencyStopAll()
                }),
                secondaryButton: .cancel(Text("Cancel"), action: {
                    isAlertShowing = false
                })
            )
        })
    }

    func showSpinner() {
        let duration = 5.0
        
        self.isShowingSpinner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.isShowingSpinner = false
        }
    }
    
    private func serversButton() {
        self.isSettingsSheetShowing = true
    }
    
    
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        ContentView()
            .environmentObject(client)
    }
}

