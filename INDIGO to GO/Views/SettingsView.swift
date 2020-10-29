//
//  SettingsView.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/16/20.
//

import SwiftUI
import Combine

struct SettingsView: View {

    @EnvironmentObject var client: IndigoClientViewModel

    @State var imager: String = "None"
    @State var guider: String = "None"
    @State var mount: String = "None"

    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Label("Servers", systemImage: "bonjour")
                    .font(.largeTitle)
                Spacer()
            }
            .padding()

            Text("Please select your INDIGO server or agents. Agents are discovered on your local network using Bonjour.")
                .font(.footnote)
                .padding()

            Form {

                Section(header: Text("Imager: \(imager)")) {
                    Picker(selection: $imager, label: Text("Imager Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                            $0.name != "AstroTelescope" && $0.name != "AstroGuider"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }
                }

                Section(header: Text("Mount: \(mount)")) {
                    Picker(selection: $mount, label: Text("Mount Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                                    $0.name != "AstroGuider" && $0.name != "AstroImager"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }
                }

                Section(header: Text("Guider: \(guider)")) {
                    Picker(selection: $guider, label: Text("Guider Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                                    $0.name != "AstroTelescope" && $0.name != "AstroImager"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.top, 30)

            Button(action: self.saveServers) { Text("Save") }
                .frame(width: 200.0)
                .foregroundColor(Color.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(9)
                .padding()
            
            Button(action: self.simulatedServer) { Text("Use a simulated server")}
                .padding()

        }
        .background(Color(.secondarySystemBackground))
        .onAppear(perform: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if !client.bonjourBrowser.names().contains(client.client.defaultImager) { self.imager = "None" } else {self.imager = client.client.defaultImager }
                if !client.bonjourBrowser.names().contains(client.client.defaultGuider) { self.guider = "None" } else {self.guider = client.client.defaultGuider }
                if !client.bonjourBrowser.names().contains(client.client.defaultMount) { self.mount = "None" } else {self.mount = client.client.defaultMount }
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                client.bonjourBrowser.seek()
            }
        }
        
    }
    
    func saveServers() {
        self.client.client.defaultImager = imager
        self.client.client.defaultGuider = guider
        self.client.client.defaultMount = mount
        self.client.reinitSavedServers()
        
        self.presentationMode.wrappedValue.dismiss()
    }

    func simulatedServer() {
        self.client.reinitSimulatedServer()
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

