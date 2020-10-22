//
//  ImagerPreviewView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/12/20.
//

import SwiftUI
import URLImage

struct ImagerPreviewView: View {

    @EnvironmentObject var client: IndigoClient
    @State private var isPreviewShowing: Bool = false
    
    var body: some View {
        
        List {
            Section {
                Picker(selection: /*@START_MENU_TOKEN@*/.constant(1)/*@END_MENU_TOKEN@*/, label: /*@START_MENU_TOKEN@*/Text("Picker")/*@END_MENU_TOKEN@*/) {
                    Text("Imager").tag(1)
                    Text("Guider").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            Section {
                
                if let url = client.imagerLatestImageURL {
                    URLImage(url, delay: 0.5, placeholder: { _ in
                        Text("Loading...")
                    }, content: {
                        $0.image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    })
                } else {
                    Image(systemName: "square.split.diagonal.2x2")
                }
            }
        }
        .listStyle(GroupedListStyle())
    }
}

struct ImagerPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            Section {
                let client = IndigoClient(isPreview: true)
                ImagerPreviewView()
                    .environmentObject(client)
            }
        }
        .listStyle(GroupedListStyle())
    }
}
