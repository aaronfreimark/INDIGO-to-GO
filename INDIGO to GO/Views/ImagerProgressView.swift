//
//  ProgressView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/11/20.
//

import SwiftUI

struct ImagerProgressView: View {

    @EnvironmentObject var client: IndigoClient

    let meridianColor = Color.orange
    let haColor = Color.orange.opacity(0.3)
    let sunColor: Color = Color.yellow.opacity(0.3)

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
                                let spacerWidth: CGFloat? = metrics.size.width * proportionHa

                                Spacer()
                                    .frame(width: spacerWidth)
                                Rectangle()
                                    .fill(self.haColor)
                                    .frame(width: metrics.size.width * (proportionMeridian - proportionHa))
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }

                    GeometryReader { metrics in
                        HStack(alignment: .center, spacing: 0) {
                            let spacerWidth: CGFloat? = metrics.size.width * proportionMeridian

                            Spacer()
                                .frame(width: spacerWidth)
                            Rectangle()
                                .fill(self.meridianColor)
                                .frame(width: 2)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Sunrise & Sunset
                
                if client.hasDaylight {
                    let daylight = client.daylight!
                    let offsetTime = client.elapsedTimeIfSequencing()

                    if daylight.start.hasDawn {
                        let dawn = daylight.start.dawn!
                        DaylightView(span: dawn, time: imagerTotalTime, type: .dawn, offsetTime: offsetTime)
                    }

                    if daylight.start.hasDay {
                        let day = daylight.start.day!
                        DaylightView(span: day, time: imagerTotalTime, type: .day, offsetTime: offsetTime)
                    }

                    if daylight.start.hasTwilight {
                        let twilight = daylight.start.twilight!
                        DaylightView(span: twilight, time: imagerTotalTime, type: .twilight, offsetTime: offsetTime)
                    }

                    if daylight.end.hasDawn {
                        let dawn = daylight.end.dawn!
                        DaylightView(span: dawn, time: imagerTotalTime, type: .dawn, offsetTime: offsetTime)
                    }

                    if daylight.end.hasDay {
                        let day = daylight.end.day!
                        DaylightView(span: day, time: imagerTotalTime, type: .day, offsetTime: offsetTime)
                    }

                    if daylight.end.hasTwilight {
                        let twilight = daylight.end.twilight!
                        DaylightView(span: twilight, time: imagerTotalTime, type: .twilight, offsetTime: offsetTime)
                    }

                }


            }
        }
        .mask(RoundedRectangle(cornerRadius: 9.0, style: .continuous).padding(.horizontal))
        
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


