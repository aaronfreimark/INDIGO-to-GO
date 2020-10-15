//
//  ProgressView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/11/20.
//

import SwiftUI

struct ImagerProgressView: View {

    @EnvironmentObject var client: IndigoClient

    let sunColor = Color.yellow.opacity(0.3)
    let meridianColor = Color.orange
    let haColor = Color.orange.opacity(0.3)
    
    var body: some View {
        
        let imagerTotalTime = CGFloat(client.imagerTotalTime)
        
        Group {
            StatusRowView(sr: client.srSequenceStatus)
            
            ZStack {
                VStack {
                    
                    // Exposure Dots
                    
                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            ForEach(client.sequences, id: \.self) { sequence in
                                sequence.progressView(imagerTotalTime: imagerTotalTime, enclosingWidth: metrics.size.width)
                            }
                        }
                        .frame(height: 5.0)
                    }

                    // Progress Bar

                    ProgressView(value: Float(client.imagerElapsedTime), total: Float(client.imagerTotalTime))
                        .frame(height: 15.0)
            
                }
                .padding()
                
                
                // Meridian & HA Limit
                
                
                if client.isMountConnected && client.isMountTracking {
                    
                    let proportionHa = CGFloat(client.mountSecondsUntilHALimit) / imagerTotalTime
                    let proportionMeridian = CGFloat(client.mountSecondsUntilMeridian) / imagerTotalTime
                    
                    
                    if client.isMountHALimitEnabled {
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

                if client.hasLocation && client.imagerFinish != nil {
                    
                    let preSunrise: Float = client.secondsUntilSunrise - client.secondsUntilAstronomicalSunrise
                    
                    let proportionAstronomicalSunrise: CGFloat = CGFloat(client.secondsUntilAstronomicalSunrise) / imagerTotalTime
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

                if client.hasLocation && client.imagerStart != nil {
                    
                    let postSunset: Float = client.secondsUntilAstronomicalSunset - client.secondsUntilSunset
                    
                    let proportionSunset: CGFloat = CGFloat(client.secondsUntilSunset) / imagerTotalTime
                    let proportionPostSunset: CGFloat = CGFloat(postSunset) / imagerTotalTime
                    
                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            
                            if client.secondsUntilSunset > 0 {
                                Rectangle()
                                    .fill(self.sunColor)
                                    .frame(width: CGFloat(metrics.size.width) * proportionSunset)
                                Rectangle()
                                    .fill(Color.yellow)
                                    .frame(width: 1)
                            }

                            if client.secondsUntilAstronomicalSunset > 0 {

                                /// sunsetOffset will be negative
                                let sunsetOffset: CGFloat = client.secondsUntilSunset < 0 ? CGFloat(metrics.size.width) * proportionSunset : 0

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
                ImagerProgressView()
                    .environmentObject(client)
            }
        }
        .listStyle(GroupedListStyle())
    }
}


