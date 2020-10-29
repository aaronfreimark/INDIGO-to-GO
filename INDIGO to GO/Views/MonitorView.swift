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
    @State private var isSettingsSheetShowing: Bool = false
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
                        Text("No INDIGO agents are connected. Please tap Settings to identify agents on your local network.")
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
                
                //            if client.isImagerConnected {
                //                ImagerPreviewView().environmentObject(client)
                //            }
                
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
                
                
                Section {
                    
                    
                    /// Park & Warm Button
                    if client.isMountConnected || client.isImagerConnected {
                        ParkAndWarmButton
                    }
                    
                    /// Servers Button
                    //                Button(action: serversButton) {
                    //                    Text("Servers")
                    //                }
                    //                .sheet(isPresented: $isSettingsSheetShowing, content: { SettingsView().environmentObject(client) })
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
    
    private func serversButton() {
        self.isSettingsSheetShowing = true
    }
    
    
}




struct MonitorView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: MockIndigoClientForPreview(), isPreview: true)
        MonitorView()
            .environmentObject(client)
            .background(Color(.systemBackground))
            .environment(\.colorScheme, .dark)
    }
}

