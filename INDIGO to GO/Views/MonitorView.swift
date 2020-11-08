//
//  ContentView.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/9/20.
//

import SwiftUI

struct MonitorView: View {
    
    /// The interesting stuff is in this object!
    @EnvironmentObject var client: IndigoClientViewModel
        
    @State var isShowingSpinner = true
    
    /// Keep track of whether a sheet is showing or not.
    @State private var isAlertShowing: Bool = false
    @State private var isTimesShowing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ServerHeaderView()
                .environmentObject(client)

            List {
                if !client.isAnythingConnected {
                    HStack {
                        Spacer()
                        ProgressView()
                            .font(.largeTitle)
                            .padding(30)
                        Text("No INDIGO agents are connected. Please tap above to identify agents on your local network.")
                    }
                    .font(.footnote)
                }
                
                // =================================================================== SEQUENCE
                
                if client.isImagerConnected || client.isMountConnected {
                    Section {
                        if client.isImagerConnected  {
                            ImagerProgressView()
                                .environmentObject(client)
                                .onTapGesture(perform: {
                                    withAnimation {
                                        self.isTimesShowing.toggle()
                                    }
                                })

                            if self.isTimesShowing {
                                ForEach(client.timeStatusRows) { sr in
                                    StatusRowView(sr: sr)
                                }
                            }

                        }
                    }
                    
                    
                    Section {
                        StatusRowView(sr: client.srSequenceStatus)
                        StatusRowView(sr: client.srCoolingStatus)
                        StatusRowView(sr: client.srMountStatus)
                    }
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
                
                
                /// Park & Warm Button
                if client.agentSelection != .remote {
                    Section {
                        if client.isMountConnected || client.isImagerConnected {
                            ParkAndWarmButton
                        }
                    }
                }
                
            }
            .listStyle(GroupedListStyle())
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private var ParkAndWarmButton: some View {
        Button(action: { self.isAlertShowing = true }) {
            Label("Emergency Stop", systemImage: "octagon.fill")
                .foregroundColor(.red)
        }
        .disabled(!client.isParkButtonEnabled)
        .alert(isPresented: $isAlertShowing, content: {
            Alert(
                title: Text("Emergency Stop"),
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
    
    
}




struct MonitorView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: IndigoSimulatorClient())
        MonitorView()
            .environmentObject(client)
            .background(Color(.systemBackground))
            .environment(\.colorScheme, .dark)
    }
}

