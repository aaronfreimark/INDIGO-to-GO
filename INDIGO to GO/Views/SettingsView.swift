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
    @State var endpointsSelected: [String]
    
    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>

    init(client: IndigoClient) {
        _endpointsSelected = State(initialValue: Array(client.connections.keys))
        self.client = client
        
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Agents")) {
                    /*
                     Picker(selection: $userSettings.servers[0], label: Text("Imager Agent")) {
                     ForEach(client.bonjourBrowser.discovered, id: \.name) { endpoint in
                     Text(endpoint.name)
                     }
                     }.pickerStyle(SegmentedPickerStyle())
                     */
                    ForEach(client.bonjourBrowser.discovered, id: \.name) { endpoint in
                        HStack {
                            Button(action: {
                                if endpointsSelected.contains(endpoint.name) {
                                    endpointsSelected = endpointsSelected.filter { $0 != endpoint.name }
                                } else {
                                    endpointsSelected.append(endpoint.name)
                                }
                            }) {
                                HStack{
                                    if endpointsSelected.contains(endpoint.name) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                            .animation(.easeIn)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.primary)
                                            .animation(.easeOut)
                                    }
                                    Text(endpoint.name)
                                }
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Settings")
            .navigationBarItems(trailing: Button("Save", action: {

                var servers: [String] = []
                for endpoint in client.bonjourBrowser.discovered {
                    if endpointsSelected.contains(endpoint.name) { servers.append(endpoint.name) }
                }
                userSettings.servers = servers
                print("userSettings.servers: \(servers)")
                self.client.reinit(servers: userSettings.servers)
                
                self.presentationMode.wrappedValue.dismiss()
            }))
            .onAppear(perform: {
                print("client.bonjourBrowser.discovered: \(client.bonjourBrowser.discovered)")
            })
        }
    }
}



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}

class UserSettings: ObservableObject {
    @Published var servers: [String] {
        didSet { UserDefaults.standard.set(servers, forKey: "servers") }
    }

    init() {
        self.servers = UserDefaults.standard.object(forKey: "servers") as? [String] ?? ["indigosky"]
    }
}
