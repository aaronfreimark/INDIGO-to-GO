//
//  ProgressView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/11/20.
//

import SwiftUI

struct ImagerProgressView: View {

    @ObservedObject var client: IndigoClient

    init(client: IndigoClient) {
        self.client = client
    }
    
    var body: some View {
        
        Group {
            StatusRow(description: client.properties.imagerSequenceText, subtext: "\(client.properties.imagerImagesTaken) / \(client.properties.imagerImagesTotal)", status: client.properties.imagerSequenceStatus)
            
            ZStack {
                VStack {
                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            ForEach(client.properties.sequences, id: \.self) { sequence in
                                sequence.progressView(imagerTotalTime: client.properties.imagerTotalTime, enclosingWidth: metrics.size.width)
                            }
                        }
                        .frame(height: 5.0)
                    }
                    ProgressView(value: Float(client.properties.imagerElapsedTime), total: Float(client.properties.imagerTotalTime))
                        .frame(height: 15.0)
                }
                .padding()
                
                if client.properties.isMountConnected && client.properties.mountIsTracking {
                    
                    let proportionHa = CGFloat(client.properties.mountSecondsUntilHALimit) / CGFloat(client.properties.imagerTotalTime)
                    let proportionMeridian = CGFloat(client.properties.mountSecondsUntilMeridian) / CGFloat(client.properties.imagerTotalTime)
                    
                    
                    if client.properties.isMountHALimitEnabled {
                        GeometryReader { metrics in
                            HStack(alignment: .center, spacing: 0) {
                                let spacerWidth: CGFloat? = CGFloat(metrics.size.width) * proportionHa
                                
                                Spacer()
                                    .frame(width: spacerWidth)
                                Rectangle()
                                    .fill(Color.orange)
                                    .opacity(0.3)
                                    .frame(width: CGFloat(metrics.size.width) * (proportionMeridian - proportionHa))
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            let spacerWidth: CGFloat? = CGFloat(metrics.size.width) * proportionMeridian
                            
                            Spacer()
                                .frame(width: spacerWidth)
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: 2)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                } else {
                    EmptyView()
                }
            }
        }
        
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            Section {
                let client = IndigoClient(isPreview: true)
                ImagerProgressView(client: client)
            }
        }
        .listStyle(GroupedListStyle())
    }
}
