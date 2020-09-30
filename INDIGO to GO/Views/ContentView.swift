//
//  ContentView.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/9/20.
//

import SwiftUI
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
                        
                        ZStack {
                            VStack {
                                GeometryReader { metrics in
                                    HStack(alignment: .center, spacing: 0) {
                                        ForEach(client.properties.sequences, id: \.self) { sequence in
                                            sequence.progressView(imagerTotalTime: client.properties.imagerTotalTime, enclosingWidth: metrics.size.width)
                                        }
                                    }
                                    .frame(height: 2.0)
                                }
                                ProgressView(value: Float(client.properties.imagerImageTime), total: Float(client.properties.imagerTotalTime))
                            }.padding()
                            
                            if client.properties.isMountConnected && client.properties.mountIsTracking {
                                
                                let proportionHa = CGFloat(client.properties.mountSecondsUntilHALimit) / CGFloat(client.properties.imagerTotalTime)
                                let proportionMeridian = CGFloat(client.properties.mountSecondsUntilMeridian) / CGFloat(client.properties.imagerTotalTime)
                                
                                
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
                                GeometryReader { metrics in
                                    HStack(alignment: .center, spacing: 0) {
                                        let spacerWidth: CGFloat? = CGFloat(metrics.size.width) * proportionMeridian
                                        
                                        Spacer()
                                            .frame(width: spacerWidth)
                                        Rectangle()
                                            .fill(Color.orange)
                                            .frame(width: 1)
                                        Spacer()
                                    }
                                }
                            } else {
                                EmptyView()
                            }
                        }
                    }
                    
                    if client.properties.isImagerConnected {
                        StatusRow(description: "Estimated Completion", subtext: client.properties.imagerExpectedFinish, status: "clock")
                    }
                    if client.properties.isMountConnected  {
                        StatusRow(description: "HA Limit", subtext: client.properties.mountHALimit, status: "exclamationmark.arrow.circlepath")
                        StatusRow(description: "Meridian Transit", subtext: client.properties.mountMeridian, status: "ellipsis.circle")
                    }
                }
            }
            
            if client.properties.isImagerConnected {
                if let url = client.properties.imagerLatestImageURL {
                    Section(header: Text("Latest Image")){
                        Button(action: {
                            self.imgURL = url
                            self.isWebViewSheetShowing = true
                        } ) {
                            Text(client.properties.imagerImageLatest)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .truncationMode(.head)
                        }
                        .sheet(isPresented: $isWebViewSheetShowing, content: { WebViewView(url: self.imgURL) })
                    }
                }
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
                    if client.properties.isMountConnected {
                        StatusRow(description: client.properties.mountTrackingText, status: client.properties.mountTrackingStatus)
                    }
                    if client.properties.isImagerConnected {
                        StatusRow(description: client.properties.imagerCoolingText, subtext: "\(client.properties.imagerCameraTemperature) °C", status: client.properties.imagerCoolingStatus)
                    }
                    Button(action: { self.isAlertShowing = true }) {
                        Text("Emergency Stop").foregroundColor(.red)
                    }
                    .alert(isPresented: $isAlertShowing, content: {
                        Alert(
                            title: Text("Emergency Stop"),
                            message: Text("Immediately park the mount and disable cooling, if possible."),
                            primaryButton: .destructive(Text("Emergency Stop"), action: {
                                isAlertShowing = false
                                client.emergencyStopAll()
                            }),
                            secondaryButton: .cancel(Text("Cancel"), action: {
                                isAlertShowing = false
                            })
                        )
                    })
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
                Button(action: { self.isSettingsSheetShowing = true }) {
                    Text("Servers")
                }
                .sheet(isPresented: $isSettingsSheetShowing, content: { SettingsView(client: self.client) })
            }
            
        }
        .listStyle(GroupedListStyle())
        .onAppear(perform: {
            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                
                
                // Show the settings sheet if after 2 seconds there are no connected servers...
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if self.client.connectedServers().count == 0 {
                        self.isSettingsSheetShowing = true
                    }
                }
                
                
            })
        })
        .onReceive(timer) { input in
            if !isSettingsSheetShowing && !isWebViewSheetShowing { client.updateUI() }
        }
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
