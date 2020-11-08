//
//  SettingsView.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/16/20.
//

import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit

struct SettingsView: View {

    @EnvironmentObject var client: IndigoClientViewModel

    @State var imager: String = "None"
    @State var guider: String = "None"
    @State var mount: String = "None"
    @State var agents = AgentSelection.local
    @State var isPublishedToRemote = false

    enum AgentSelection: String {
        case local, remote, simulator
    }
    
    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack(spacing: 0) {
            Label("Connections", systemImage: "bonjour")
                .font(.title)
                .padding()
            
            Picker(selection: $agents, label: Text("Agent Setup")) {
                Text("Local").tag(AgentSelection.local)
                
                #if !targetEnvironment(macCatalyst)
                Text("Remote").tag(AgentSelection.remote)
                #endif
                
                Text("Simulator").tag(AgentSelection.simulator)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Form {

                if self.agents == .local {
                    Text("Imager: \(imager)").font(.footnote).baselineOffset(-20)
                    Picker(selection: $imager, label: Text("Imager Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                            $0.name != "AstroTelescope" && $0.name != "AstroGuider"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }
                    
                    Text("Mount: \(mount)").font(.footnote).baselineOffset(-20)
                    Picker(selection: $mount, label: Text("Mount Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                            $0.name != "AstroGuider" && $0.name != "AstroImager"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }
                    
                    Text("Guider: \(guider)").font(.footnote).baselineOffset(-20)
                    Picker(selection: $guider, label: Text("Guider Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                            $0.name != "AstroTelescope" && $0.name != "AstroImager"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }

                    #if targetEnvironment(macCatalyst)
                    Text("")
                    Toggle(isOn: $isPublishedToRemote) {
                        Text("Publish to remote clients")
                    }
                    if self.isPublishedToRemote {
                        HStack {
                            Spacer()
                            SignInWithAppleButtonView()
                                .environmentObject(client)
                            Spacer()
                        }
                        .padding(.vertical)
                        

                        Text("Use INDIGO to GO for iOS to remotely monitor your system. An anonymous identitifer, INDIGO data, and nothing else will be published.")
                            .font(.caption)
                            .padding(.vertical)
                    }
                    #endif
                    
                } else if self.agents == .remote {
                    Text("Run INDIGO to GO for Mac on your local network, and you may monitor your equipment from anywhere.")
                        .font(.caption)
                        .padding(.vertical)

                    HStack {
                        Spacer()
                        SignInWithAppleButtonView()
                            .environmentObject(client)
                        Spacer()
                    }

                } else {
                    
                    Text("The simulator allows you to demo INDIGO to GO without real astrophotography equipment.")
                        .font(.caption)
                        .padding(.vertical)

                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Button(action: self.saveServers) { Text("Save") }
                .frame(width: 280, height: 50)
                .foregroundColor(Color.white)
                .background(Color.blue)
                .cornerRadius(9)
                .padding()
            
        }
        .onAppear(perform: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.agents = client.agentSelection
                self.isPublishedToRemote = client.isPublishedToRemote && client.isFirebaseSignedIn
                
                self.imager = UserDefaults.standard.object(forKey: "imager") as? String ?? "None"
                self.guider = UserDefaults.standard.object(forKey: "guider") as? String ?? "None"
                self.mount = UserDefaults.standard.object(forKey: "mount") as? String ?? "None"

            }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                client.bonjourBrowser.seek()
            }
        }
        
    }
    
    func saveServers() {
        UserDefaults.standard.set(self.agents.rawValue, forKey: "agentSelection")
        UserDefaults.standard.set(isPublishedToRemote, forKey: "isPublishedToRemote")
        UserDefaults.standard.set(imager, forKey: "imager")
        UserDefaults.standard.set(guider, forKey: "guider")
        UserDefaults.standard.set(mount, forKey: "mount")

        switch self.agents {
        case .local:
            self.client.isPublishedToRemote = self.isPublishedToRemote
            if !self.isPublishedToRemote {
                SignInWithAppleButtonView().firebaseSignOut()
            }
            break

        case .remote, .simulator:
            break
        }

        self.client.reinit()

        self.presentationMode.wrappedValue.dismiss()
    }
   
}



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: IndigoSimulatorClient())
        SettingsView()
            .environmentObject(client)
//            .background(Color(.systemBackground))
//            .environment(\.colorScheme, .dark)
    }
}

