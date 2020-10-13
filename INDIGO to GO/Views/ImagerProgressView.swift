//
//  ProgressView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/11/20.
//

import SwiftUI

struct ImagerProgressView: View {

    @ObservedObject var client: IndigoClient

    let sunColor = Color.yellow.opacity(0.3)
    let meridianColor = Color.orange
    let haColor = Color.orange.opacity(0.3)

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
                                    .fill(self.haColor)
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
                                .fill(self.meridianColor)
                                .frame(width: 2)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                } else {
                    EmptyView()
                }

                
                
                // Sunrise

                if client.location.hasLocation && client.properties.imagerFinish != nil {
                    
                    let adjustedSunrise: Float = client.location.secondsUntilSunrise + client.properties.elapsedTimeIfSequencing()
                    let adjustedAstonomicalSunrise: Float = client.location.secondsUntilAstronomicalSunrise + client.properties.elapsedTimeIfSequencing()
                    let preSunrise: Float = adjustedSunrise - adjustedAstonomicalSunrise
                    
                    let proportionAstronomicalSunrise: CGFloat = CGFloat(adjustedAstonomicalSunrise) / imagerTotalTime
                    let proportionPreSunrise: CGFloat = CGFloat(preSunrise) / imagerTotalTime
                    
                    
                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            
                            Spacer()
                                .frame(width: CGFloat(metrics.size.width) * proportionAstronomicalSunrise)
                            Rectangle()
                                .fill(LinearGradient(gradient: Gradient(colors: [self.sunColor.opacity(0.0), self.sunColor]), startPoint: .leading, endPoint: .trailing))
                                .frame(width: CGFloat(metrics.size.width) * proportionPreSunrise)
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: 1)
                            Rectangle()
                                .fill(self.sunColor)
                        }
                    }
                    .padding(.horizontal)
                                        
                } else {
                    EmptyView()
                }

                
                // Sunset

                if client.location.hasLocation && client.properties.imagerStart != nil {
                    
                    let adjustedSunset: Float = client.location.secondsUntilSunset  + client.properties.elapsedTimeIfSequencing()
                    let adjustedAstonomicalSunset: Float = client.location.secondsUntilAstronomicalSunset + client.properties.elapsedTimeIfSequencing()
                    let postSunset: Float = adjustedAstonomicalSunset - adjustedSunset
                    
                    let proportionSunset: CGFloat = CGFloat(adjustedSunset) / imagerTotalTime
                    let proportionPostSunset: CGFloat = CGFloat(postSunset) / imagerTotalTime
                    
                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            
                            if adjustedSunset > 0 {
                                Rectangle()
                                    .fill(self.sunColor)
                                    .frame(width: CGFloat(metrics.size.width) * proportionSunset)
                                Rectangle()
                                    .fill(Color.yellow)
                                    .frame(width: 1)
                            }

                            if adjustedAstonomicalSunset > 0 {

                                /// sunsetOffset will be negative
                                let sunsetOffset: CGFloat = adjustedSunset < 0 ? CGFloat(metrics.size.width) * proportionSunset : 0

                                Rectangle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [self.sunColor, self.sunColor.opacity(0.0)]), startPoint: .leading, endPoint: .trailing))
                                    .frame(width: CGFloat(metrics.size.width) * proportionPostSunset - sunsetOffset)
                                    .offset(x: sunsetOffset)
                                Spacer()
                            }
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


