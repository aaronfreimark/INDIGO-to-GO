//
//  SettingsView.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/16/20.
//

import SwiftUI
import Combine

struct SettingsView: View {

    var client: IndigoClient
    var userSettings = UserSettings()

    @State var imager: String
    @State var guider: String
    @State var mount: String

    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>

    init(client: IndigoClient) {
        _imager = State(initialValue: userSettings.imager)
        _guider = State(initialValue: userSettings.guider)
        _mount = State(initialValue: userSettings.mount)
        self.client = client
        
    }
    
    var body: some View {
        NavigationView {
            Form {

                Section(header: Text("Imager: \(imager)")) {
                    Picker(selection: $imager, label: Text("Imager Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                            $0.name != "AstroTelescope" && $0.name != "AstroGuider"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Mount: \(imager)")) {
                    Picker(selection: $mount, label: Text("Mount Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                                    $0.name != "AstroGuider" && $0.name != "AstroImager"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Guider: \(imager)")) {
                    Picker(selection: $guider, label: Text("Guider Agent")) {
                        ForEach(client.bonjourBrowser.discovered.filter {
                                    $0.name != "AstroTelescope" && $0.name != "AstroImager"
                        }, id: \.name) { endpoint in
                            Text(endpoint.name)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }

                HStack() {
                    Spacer()
                    Button(action: saveServers) { Text("Save") }
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
            //.listStyle(GroupedListStyle())
            .navigationBarTitle("Servers")
            .onAppear(perform: {
                print("client.bonjourBrowser.discovered: \(client.bonjourBrowser.discovered)")
                if !client.bonjourBrowser.names().contains(self.imager) { self.imager = "None" }
                if !client.bonjourBrowser.names().contains(self.guider) { self.guider = "None" }
                if !client.bonjourBrowser.names().contains(self.mount) { self.mount = "None" }
            })
        }
    }
    
    func saveServers() {
        userSettings.imager = imager
        userSettings.guider = guider
        userSettings.mount = mount
        self.client.reinit(servers: [imager, guider, mount])
        
        self.presentationMode.wrappedValue.dismiss()
    }
}



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClient(isPreview: true)
        SettingsView(client: client)
    }
}

class UserSettings: ObservableObject {
/*
 @Published var servers: [String] {
        didSet { UserDefaults.standard.set(servers, forKey: "servers") }
    }
*/
    
    @Published var imager: String {
        didSet { UserDefaults.standard.set(imager, forKey: "imager") }
    }
    @Published var guider: String {
        didSet { UserDefaults.standard.set(guider, forKey: "guider") }
    }
    @Published var mount: String {
        didSet { UserDefaults.standard.set(mount, forKey: "mount") }
    }

    init() {
        // self.servers = UserDefaults.standard.object(forKey: "servers") as? [String] ?? ["indigosky"]
        self.imager = UserDefaults.standard.object(forKey: "imager") as? String ?? "None"
        self.guider = UserDefaults.standard.object(forKey: "guider") as? String ?? "None"
        self.mount = UserDefaults.standard.object(forKey: "mount") as? String ?? "None"
    }
}
