//
//  ImagerPreviewView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/12/20.
//

import SwiftUI
import URLImage

struct ImagerPreviewView: View {

    @ObservedObject var client: IndigoClient
    @State private var isPreviewShowing: Bool = false

    init(client: IndigoClient) {
        self.client = client
    }
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isPreviewShowing,
            content:
                {
                    URLImage(client.imagerLatestImageURL, delay: 0.5, placeholder: { _ in
                        Text("Loading...")
                    }, content: {
                        $0.image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    })
                }, label:
                    {
                        HStack
                        {
                            Text("Preview")
                                .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { isPreviewShowing = !isPreviewShowing }
                    })
            .onAppear {
                URLImageService.shared.setDefaultExpiryTime(0.0)
            }
    }
}

struct ImagerPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            Section {
                let client = IndigoClient(isPreview: true)
                ImagerPreviewView(client: client)
            }
        }
        .listStyle(GroupedListStyle())
    }
}
