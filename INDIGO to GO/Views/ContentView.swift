//
//  ContentView.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/9/20.
//

import SwiftUI
import URLImage
import Combine

struct ContentView: View {
    // The interesting stuff is in this object!
    @ObservedObject var client = IndigoClient()
        
    // Set up a timer for periodic refresh
    @State var currentDate = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Keep track of whether a sheet is showing or not. This works much better as two booleans vs an enum
    @State private var isWebViewSheetShowing: Bool = false
    @State private var isSettingsSheetShowing: Bool = false
    @State private var isAlertShowing: Bool = false

    // URL of preview image; Probably doesn't need to be its own variable like this. I think we're trying to make sure it doesn't reload every 1 second.
    @State var imgURL: String?
    
    var body: some View {
        
        List {
            if !client.properties.isAnythingConnected {
                Section {
                    Text("No INDIGO agents are connected. Please tap the Server button to find some on your local network.")
                        .padding(30)
                }
            }

            // =================================================================== SEQUENCE
            
            if client.properties.isImagerConnected || client.properties.isMountConnected {
                Section(header: Text("Sequence")) {
                    if client.properties.isImagerConnected {
                        StatusRow(description: client.properties.imagerSequenceText, subtext: "\(client.properties.imagerImagesTaken) / \(client.properties.imagerImagesTotal)", status: client.properties.imagerSequenceStatus)

            // =================================================================== PROGRESS

                        ZStack {
                            VStack {
                                GeometryReader { metrics in
                                    HStack(alignment: .center, spacing: 0) {
                                        ForEach(client.properties.sequences, id: \.self) { sequence in
                                            sequence.progressView(imagerTotalTime: client.properties.imagerTotalTime, enclosingWidth: metrics.size.width)
                                        }
                                    }
                                    .frame(height: 5.0)
                                }
                                ProgressView(value: Float(client.properties.imagerElapsedTime), total: Float(client.properties.imagerTotalTime))
                                    .frame(height: 15.0)
                            }
                            .padding()
                            
                            if client.properties.isMountConnected && client.properties.mountIsTracking {
                                
                                let proportionHa = CGFloat(client.properties.mountSecondsUntilHALimit) / CGFloat(client.properties.imagerTotalTime)
                                let proportionMeridian = CGFloat(client.properties.mountSecondsUntilMeridian) / CGFloat(client.properties.imagerTotalTime)
                                
                                
                                if client.properties.isMountHALimitEnabled {
                                    GeometryReader { metrics in
                                        HStack(alignment: .center, spacing: 0) {
                                            let spacerWidth: CGFloat? = CGFloat(metrics.size.width) * proportionHa
                                            
                                            Spacer()
                                                .frame(width: spacerWidth)
                                            Rectangle()
                                                .fill(Color.orange)
                                                .opacity(0.3)
                                                .frame(width: CGFloat(metrics.size.width) * (proportionMeridian - proportionHa))
                                            Spacer()
                                        }
                                    }
                                    .padding(.horizontal)
                                }

                                GeometryReader { metrics in
                                    HStack(alignment: .center, spacing: 0) {
                                        let spacerWidth: CGFloat? = CGFloat(metrics.size.width) * proportionMeridian
                                        
                                        Spacer()
                                            .frame(width: spacerWidth)
                                        Rectangle()
                                            .fill(Color.orange)
                                            .frame(width: 2)
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal)

                            } else {
                                EmptyView()
                            }
                        }
                    }

                    // =================================================================== COMPLETION

                    if client.properties.isImagerConnected {
                        StatusRow(description: "Estimated Completion", subtext: client.properties.imagerExpectedFinish, status: "clock")
                    }
                    if client.properties.isMountHALimitEnabled {
                        StatusRow(description: "HA Limit", subtext: client.properties.mountHALimit, status: "exclamationmark.arrow.circlepath")
                    }
                    if client.properties.isMountConnected  {
                        StatusRow(description: "Meridian Transit", subtext: client.properties.mountMeridian, status: "ellipsis.circle")
                    }
                }
            }
            
            if client.properties.isImagerConnected {
                DisclosureGroup(isExpanded: $isWebViewSheetShowing, content:
                {
                    URLImage(client.properties.imagerLatestImageURL, delay: 0.5, placeholder: { _ in
                        Text("Loading...")
                    }, content: {
                        $0.image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    })
                }, label:
                    {
                        HStack
                        {
                            Text("Preview")
                                .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { isWebViewSheetShowing = !isWebViewSheetShowing }
                    })
            }
            
            // =================================================================== GUIDER
            
            if client.properties.isGuiderConnected {
                Section(header: Text("Guider")) {
                    StatusRow(description: client.properties.guiderTrackingText, subtext: "\(client.properties.guiderDriftMax)", status: client.properties.guiderTrackingStatus)
                    StatusRow(description: "RA Error (RSME)", subtext: "\(client.properties.guiderRSMERA)", status: client.properties.guiderRSMERAStatus)
                    StatusRow(description: "DEC Error (RSME)", subtext: "\(client.properties.guiderRSMEDec)", status: client.properties.guiderRSMEDecStatus)
                }
            } else {
                EmptyView()
            }
            
            // =================================================================== HARDWARE
            
            if client.properties.isMountConnected || client.properties.isImagerConnected {
                Section(header: Text("Hardware")) {
                    if client.properties.isImagerConnected {
                        StatusRow(description: client.properties.imagerCoolingText, subtext: "\(client.properties.imagerCameraTemperature) °C", status: client.properties.imagerCoolingStatus)
                    }
                    if client.properties.isMountConnected {
                        StatusRow(description: client.properties.mountTrackingText, status: client.properties.mountTrackingStatus)
                    }
                }
            }
            
            Section(footer:
                        VStack(alignment: .leading) {
                            ForEach(self.client.connectedServers(), id: \.self ) { name in
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text(name)
                                }
                            }
                        }) {
                //Button(action: { client.printProperties() } ) { Text("Properties") }

                if client.properties.isMountConnected || client.properties.isImagerConnected {
                    Button(action: { self.isAlertShowing = true }) {
                        Text(client.properties.ParkandWarmButtonTitle)
                    }
                    .disabled(!client.properties.isPartAndWarmButtonEnabled)
                    .alert(isPresented: $isAlertShowing, content: {
                        Alert(
                            title: Text(client.properties.ParkandWarmButtonTitle),
                            message: Text(client.properties.ParkandWarmButtonDescription),
                            primaryButton: .destructive(Text(client.properties.ParkandWarmButtonOK), action: {
                                isAlertShowing = false
                                client.emergencyStopAll()
                            }),
                            secondaryButton: .cancel(Text("Cancel"), action: {
                                isAlertShowing = false
                            })
                        )
                    })
                }
                Button(action: serversButton) {
                    Text("Servers")
                }
                .sheet(isPresented: $isSettingsSheetShowing, content: { SettingsView(client: self.client) })
            }
            
        }
        .listStyle(GroupedListStyle())
        .onReceive(timer) { input in
            if !isSettingsSheetShowing && !isWebViewSheetShowing {
                client.updateUI()
            }
        }
        .onAppear(perform: {
            
            URLImageService.shared.setDefaultExpiryTime(0.0)

            // Start up Bonjour, let stuff populate
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                client.bonjourBrowser.seek()
            })

            // Show the settings sheet if after 2 seconds there are no connected servers...
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.client.connectedServers().count == 0 {
                    // Start up Bonjour, let stuff populate
                    self.isSettingsSheetShowing = true
                }
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            
            // Start up Bonjour, let stuff populate
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                client.bonjourBrowser.seek()
            })
            
            // after 1 second search for whatever is in serverSettings.servers to try to reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                client.reinitSavedServers()
            }
        }

    }
    
    private func serversButton() {
        self.isSettingsSheetShowing = true
    }
    
    
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        ContentView(client: client)
    }
}

enum SheetList: String {
    case WebView, Settings
}
