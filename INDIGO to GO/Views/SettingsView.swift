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
        NavigationView {
            Form {

                Section(header: Text("Imager: \(imager)")) {
                    Picker(selection: $imager, label: Text("Imager Agent")) {
                        ForEach(client.client.bonjourBrowser.discovered.filter {
                            $0.name != "AstroTelescope" && $0.name != "AstroGuider"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }
                }

                Section(header: Text("Mount: \(mount)")) {
                    Picker(selection: $mount, label: Text("Mount Agent")) {
                        ForEach(client.client.bonjourBrowser.discovered.filter {
                                    $0.name != "AstroGuider" && $0.name != "AstroImager"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }
                }

                Section(header: Text("Guider: \(guider)")) {
                    Picker(selection: $guider, label: Text("Guider Agent")) {
                        ForEach(client.client.bonjourBrowser.discovered.filter {
                                    $0.name != "AstroTelescope" && $0.name != "AstroImager"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }
                }

                HStack() {
                    Spacer()
                    Button(action: self.saveServers) { Text("Save") }
                        .frame(width: 200.0)
                        .foregroundColor(Color.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(9)
                    Spacer()
                }
                .padding(.vertical, 30.0)

                VStack {
                    Text("Please select your INDIGO server or agents. Agents are discovered on your local network using Bonjour.")
                        .font(.callout)

//                    Link("http://indigo-astronomy.org", destination: URL(string: "http://indigo-astronomy.org")!)
//                        .font(.callout)
//                    Link("http://www.cloudmakers.eu", destination: URL(string: "http://www.cloudmakers.eu")!)
//                        .font(.callout)
                }
                .padding(.vertical, 30.0)

            }
            .pickerStyle(SegmentedPickerStyle())
            .navigationBarTitle("Servers")
            .onAppear(perform: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if !client.client.bonjourBrowser.names().contains(client.client.defaultImager) { self.imager = "None" } else {self.imager = client.client.defaultImager }
                    if !client.client.bonjourBrowser.names().contains(client.client.defaultGuider) { self.guider = "None" } else {self.guider = client.client.defaultGuider }
                    if !client.client.bonjourBrowser.names().contains(client.client.defaultMount) { self.mount = "None" } else {self.mount = client.client.defaultMount }
                }
            })
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                client.client.bonjourBrowser.seek()
            }
        }

    }
    
    func saveServers() {
        self.client.client.defaultImager = imager
        self.client.client.defaultGuider = guider
        self.client.client.defaultMount = mount
        self.client.client.reinitSavedServers()
        
        self.presentationMode.wrappedValue.dismiss()
    }
}



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: MockIndigoClientForPreview(), isPreview: true)
        SettingsView()
            .environmentObject(client)
    }
}

