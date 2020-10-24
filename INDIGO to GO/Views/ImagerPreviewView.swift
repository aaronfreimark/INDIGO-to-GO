//
//  ImagerPreviewView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/12/20.
//

import SwiftUI
import URLImage

struct ImagerPreviewView: View {

    @EnvironmentObject var client: IndigoClientViewModel
    @State private var camera: String = "Imager" // Guider
        
    var body: some View {
        
            VStack {
                Picker(selection: $camera, label: Text("Camera")) {
                    Text("Imager").tag("Imager")
                    Text("Guider").tag("Guider")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                Spacer().frame(maxWidth: .infinity)

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
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .imageScale(.large)
                }
                
                Spacer().frame(maxWidth: .infinity)
                

            }
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))
    }
}

struct ImagerPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: MockIndigoClientForPreview(), isPreview: true)
        ImagerPreviewView()
            .environmentObject(client)
    }
}
