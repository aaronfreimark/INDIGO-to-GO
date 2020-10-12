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
        
        let imagerTotalTime = CGFloat(client.properties.imagerTotalTime)
        
        Group {
            StatusRow(description: client.properties.imagerSequenceText, subtext: "\(client.properties.imagerImagesTaken) / \(client.properties.imagerImagesTotal)", status: client.properties.imagerSequenceStatus)
            
            ZStack {
                VStack {
                    
                    // Exposure Dots
                    
                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            ForEach(client.properties.sequences, id: \.self) { sequence in
                                sequence.progressView(imagerTotalTime: imagerTotalTime, enclosingWidth: metrics.size.width)
                            }
                        }
                        .frame(height: 5.0)
                    }

                    // Progress Bar

                    ProgressView(value: Float(client.properties.imagerElapsedTime), total: Float(client.properties.imagerTotalTime))
                        .frame(height: 15.0)
            
                }
                .padding()
                
                
                // Meridian & HA Limit
                
                
                if client.properties.isMountConnected && client.properties.mountIsTracking {
                    
                    let proportionHa = CGFloat(client.properties.mountSecondsUntilHALimit) / imagerTotalTime
                    let proportionMeridian = CGFloat(client.properties.mountSecondsUntilMeridian) / imagerTotalTime
                    
                    
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

                
                
                // Sunrise

                if client.location.hasLocation {
                    
                    let adjustedSunrise: Float = client.location.timeUntilSunriseSeconds()  + client.properties.elapsedTimeIfSequencing()
                    let adjustedAstonomicalSunrise: Float = client.location.timeUntilAstronomicalSunriseSeconds() + client.properties.elapsedTimeIfSequencing()
                    let preSunrise: Float = adjustedSunrise - adjustedAstonomicalSunrise
                    
                    let proportionAstronomicalSunrise: CGFloat = CGFloat(adjustedAstonomicalSunrise) / imagerTotalTime
                    let proportionPreSunrise: CGFloat = CGFloat(preSunrise) / imagerTotalTime
                    
                    
                    
                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            let spacerWidth: CGFloat? = CGFloat(metrics.size.width) * proportionAstronomicalSunrise
                            
                            Spacer()
                                .frame(width: spacerWidth)
                            Rectangle()
                                .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 1.0, green: 1.0, blue: 0.0, opacity: 0.0), Color(red: 1.0, green: 1.0, blue: 0.0, opacity: 0.5)]), startPoint: .leading, endPoint: .trailing))
                                .frame(width: CGFloat(metrics.size.width) * proportionPreSunrise)
                            Rectangle()
                                .fill(Color(red: 1.0, green: 1.0, blue: 0.0, opacity: 0.5))
                        }
                    }
                    .padding(.horizontal)
                                        
                } else {
                    EmptyView()
                }


            }
            .mask(RoundedRectangle(cornerRadius: 9.0, style: .continuous).padding(.horizontal))
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


