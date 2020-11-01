//
//  ServerHeaderView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/28/20.
//

import SwiftUI

struct ServerHeaderView: View {

    @EnvironmentObject var client: IndigoClientViewModel
    @State var isExpanded = false

    var body: some View {
        VStack {
            Button(action: { self.isExpanded = !self.isExpanded }) {
                Label("\(client.connectedServers().count == 1 ? "Server" : "Servers"):  \(client.connectedServers().count > 0 ? client.connectedServers().joined(separator: ", ") : "None")", systemImage: "bonjour")
            }
            .font(.system(size: 16))
            .padding(5)
            .sheet(isPresented: $isExpanded, content: {
                SettingsView()
                    .environmentObject(client)
            })
            
        }
    }
}

struct ServerHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: MockIndigoClientForPreview(), isPreview: true)
        ServerHeaderView()
            .environmentObject(client)
            .previewLayout(PreviewLayout.sizeThatFits)
    }
}
