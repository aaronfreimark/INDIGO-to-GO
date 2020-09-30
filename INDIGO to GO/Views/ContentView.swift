//
//  ContentView.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/9/20.
//

import SwiftUI
import Combine

struct ContentView: View {
    var userSettings = UserSettings()
    @ObservedObject var client = IndigoClient()
        
    @State var currentDate = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var isWebViewSheetShowing: Bool = false
    @State private var isSettingsSheetShowing: Bool = false

    @State var imgURL: String?
    
    var body: some View {
        
        
        List {
            if !client.properties.imagerConnected && !client.properties.mountConnected && !client.properties.guiderConnected {
                Section {
                    Text("No INDIGO agents are connected. Please tap the Server button to find some on your local network.")
                        .padding(30)
                }
            }

            // =================================================================== SEQUENCE
            
            if client.properties.imagerConnected || client.properties.mountConnected {
                Section(header: Text("Sequence")) {
                    if client.properties.imagerConnected {
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
                            
                            if client.properties.mountConnected && client.properties.mountIsTracking {
                                
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
                    
                    if client.properties.imagerConnected {
                        StatusRow(description: "Estimated Completion", subtext: client.properties.imagerExpectedFinish, status: "clock")
                    }
                    if client.properties.mountConnected  {
                        StatusRow(description: "HA Limit", subtext: client.properties.mountHALimit, status: "exclamationmark.arrow.circlepath")
                        StatusRow(description: "Meridian Transit", subtext: client.properties.mountMeridian, status: "ellipsis.circle")
                    }
                }
            }
            
            if client.properties.imagerConnected {
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
            
            if client.properties.guiderConnected {
                Section(header: Text("Guider")) {
                    StatusRow(description: client.properties.guiderTrackingText, subtext: "\(client.properties.guiderDriftMax)", status: client.properties.guiderTrackingStatus)
                    StatusRow(description: "RA Error (RSME)", subtext: "\(client.properties.guiderRSMERA)", status: client.properties.guiderRSMERAStatus)
                    StatusRow(description: "DEC Error (RSME)", subtext: "\(client.properties.guiderRSMEDec)", status: client.properties.guiderRSMEDecStatus)
                }
            } else {
                EmptyView()
            }
            
            // =================================================================== HARDWARE
            
            if client.properties.mountConnected || client.properties.imagerConnected {
                Section(header: Text("Hardware")) {
                    if client.properties.mountConnected {
                        StatusRow(description: client.properties.mountTrackingText, status: client.properties.mountTrackingStatus)
                    }
                    if client.properties.imagerConnected {
                        StatusRow(description: client.properties.imagerCoolingText, subtext: "\(client.properties.imagerCameraTemperature) °C", status: client.properties.imagerCoolingStatus)
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



struct StatusRow: View {
    var description: String
    var subtext: String?
    var status: String?
    let width:CGFloat = 20
    
    private var iconView: some View {
        switch status {
        case "ok":
            return AnyView(Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green).frame(width: width, alignment: .leading))
        case "warn":
            return AnyView(Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow).frame(width: width, alignment: .leading))
        case "alert":
            return AnyView(Image(systemName: "stop.fill")
                .foregroundColor(.red).frame(width: width, alignment: .leading))
        case "unknown":
            return AnyView(Image(systemName:"questionmark.circle")
                .foregroundColor(.gray).frame(width: width, alignment: .leading))
        case "", nil:
            return AnyView(EmptyView().frame(width: width))
        default: return
            AnyView(Image(systemName:status!)
            .foregroundColor(.gray).frame(width: width, height: nil, alignment: .leading))
        }
    }
    
    private var subtextView: some View {
        if subtext != nil {
            return Text(subtext!).font(.callout).foregroundColor(.gray)
        }
        return Text("")
    }
    
    var body: some View {
        HStack {
            iconView
            Text(description)
            Spacer()
            subtextView
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

enum SheetList: String {
    case WebView, Settings
}
