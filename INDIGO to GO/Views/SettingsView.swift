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
                Text("Remote").tag(AgentSelection.remote)
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
                self.agents = AgentSelection(rawValue: client.agentSelection) ?? .local
                self.isPublishedToRemote = client.isPublishedToRemote && client.isFirebaseSignedIn
                if !client.bonjourBrowser.names().contains(client.defaultImager) { self.imager = "None" } else {self.imager = client.defaultImager }
                if !client.bonjourBrowser.names().contains(client.defaultGuider) { self.guider = "None" } else {self.guider = client.defaultGuider }
                if !client.bonjourBrowser.names().contains(client.defaultMount) { self.mount = "None" } else {self.mount = client.defaultMount }
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                client.bonjourBrowser.seek()
            }
        }
        
    }
    
    func saveServers() {
        self.client.agentSelection = self.agents.rawValue

        switch self.agents {
        case .local:
            self.client.isPublishedToRemote = self.isPublishedToRemote
            if !self.isPublishedToRemote {
                SignInWithAppleButtonView().firebaseSignOut()
            }

            self.client.defaultImager = imager
            self.client.defaultGuider = guider
            self.client.defaultMount = mount
            self.client.reinitSavedServers()
            
            break
        case .remote:
            self.client.reinitRemoteServer()
            break
            
        case .simulator:
            self.client.reinitSimulatedServer()
            break
        }

        self.presentationMode.wrappedValue.dismiss()
    }
   
}



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: MockIndigoClientForPreview(), isPreview: true)
        SettingsView()
            .environmentObject(client)
//            .background(Color(.systemBackground))
//            .environment(\.colorScheme, .dark)
    }
}

