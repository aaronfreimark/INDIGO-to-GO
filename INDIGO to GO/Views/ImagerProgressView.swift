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

                    if daylight.start.hasDawn {
                        let dawn = daylight.start.dawn!
                        DaylightView(span: dawn, time: imagerTotalTime, type: .dawn)
                    }

                    if daylight.start.hasDay {
                        let day = daylight.start.day!
                        DaylightView(span: day, time: imagerTotalTime, type: .day)
                    }

                    if daylight.start.hasTwilight {
                        let twilight = daylight.start.twilight!
                        DaylightView(span: twilight, time: imagerTotalTime, type: .twilight)
                    }

                    if daylight.end.hasDawn {
                        let dawn = daylight.end.dawn!
                        DaylightView(span: dawn, time: imagerTotalTime, type: .dawn)
                    }

                    if daylight.end.hasDay {
                        let day = daylight.end.day!
                        DaylightView(span: day, time: imagerTotalTime, type: .day)
                    }

                    if daylight.end.hasTwilight {
                        let twilight = daylight.end.twilight!
                        DaylightView(span: twilight, time: imagerTotalTime, type: .twilight)
                    }

                }


            }
        }
        .mask(RoundedRectangle(cornerRadius: 9.0, style: .continuous).padding(.horizontal))
        
    }
    
}


struct DaylightView: View {
    var span: DateInterval
    var time: CGFloat
    enum DayParts { case dawn, day, twilight }
    var type: DayParts

    var width: CGFloat = 0
    var offset: CGFloat = 0
    let sunColor = Color.yellow.opacity(0.3)
        
    private var filledRectangle: some View {
        switch type {
        case .dawn:
            return AnyView(Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: [self.sunColor.opacity(0.0), self.sunColor]), startPoint: .leading, endPoint: .trailing)))
        case .day:
            return AnyView(
                Rectangle()
                .fill(sunColor))
        case .twilight:
            return AnyView(Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: [self.sunColor, self.sunColor.opacity(0.0)]), startPoint: .leading, endPoint: .trailing)))
        }
    }

    private var coloredLine: some View {
        switch type {
        case .dawn:
            return AnyView(EmptyView())
        case .day:
            return AnyView(Rectangle().fill(Color.yellow))
        case .twilight:
            return AnyView(Rectangle().fill(Color.yellow))
        }
    }

    var body: some View {
        let width = CGFloat(span.duration) / time
        let offset = CGFloat(span.start.timeIntervalSinceNow) / time
        
        
        GeometryReader { metrics in
            HStack(alignment: .center, spacing: 0) {
                coloredLine
                    .frame(width: 1)
                filledRectangle
                    .frame(width: metrics.size.width * width)
                Spacer()
            }
            .offset(x: metrics.size.width * offset)
        }
        .padding(.horizontal)
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


