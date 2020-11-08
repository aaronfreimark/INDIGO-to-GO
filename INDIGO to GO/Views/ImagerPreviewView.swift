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
    @State private var camera: String = "Imager" // or Guider
    
    var body: some View {
        
            VStack {
                ServerHeaderView()
                    .environmentObject(client)

                Picker(selection: $camera, label: Text("Camera")) {
                    if client.isImagerConnected { Text("Imager").tag("Imager") }
                    if client.isGuiderConnected { Text("Guider").tag("Guider") }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                Spacer().frame(maxWidth: .infinity)

                self.image()
                
                Spacer().frame(maxWidth: .infinity)
                

            }
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))
    }
    
    
    func image() -> AnyView {
        if client.agentSelection == .remote {
            return AnyView(Text("Preview is not yet supported for remote connections."))
        }
        
        if self.camera == "Imager", let url = client.imagerLatestImageURL {
            return AnyView(URLImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            })
        } else if self.camera == "Guider", let url = client.guiderLatestImageURL {
            return AnyView(URLImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            })
        } else {
            return AnyView(Image(systemName: "photo")
                .font(.largeTitle)
                .imageScale(.large)
            )
        }
    }
    
}

struct ImagerPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let client = IndigoClientViewModel(client: IndigoSimulatorClient())
        ImagerPreviewView()
            .environmentObject(client)
    }
}
