//
//  StatusRow.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 9/30/20.
//

import Foundation
import SwiftUI

struct StatusRowView: View {
    var sr: StatusRow?

    var body: some View {
        if let sr = self.sr, sr.isSet {
            HStack {
                Label(
                    title: { Text(sr.text) },
                    icon: { iconView }
                )
                Spacer()
                Text(sr.value)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var iconView: some View {
        if let sr = self.sr {
            switch sr.status {
            
            case .ok:
                return AnyView(Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green))
                
            case .warn:
                return AnyView(Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow))
                
            case .alert:
                return AnyView(Image(systemName: "stop.fill")
                                .foregroundColor(.red))
                
            case .unknown:
                return AnyView(Image(systemName:"questionmark.circle")
                                .foregroundColor(.gray))
                
            case .start:
                return AnyView(Image(systemName:"square.and.arrow.up")
                                .rotationEffect(Angle(degrees: 90.0))
                                .foregroundColor(.gray))
                
            case .end:
                return AnyView(Image(systemName:"square.and.arrow.down")
                                .rotationEffect(Angle(degrees: -90.0))
                                .foregroundColor(.gray))
                
            case .blank:
                return AnyView(EmptyView())
                
            case .clock:
                if let date = sr.date {
                    return AnyView(
                        ClockView(date)
                            .frame(width: 16, height: 16)
                    )
                   
                } else {
                    return AnyView(EmptyView())
                }

            case let .pie(pct):
                // progress = pct
                return AnyView(
                    ProgressView(value: pct)
                        .progressViewStyle(PiePercentageProgressViewStyle())
                        .foregroundColor(.green)
                        .frame(width: 16, height: 16)
                )
                
            case let .custom(systemImage):
                return AnyView(Image(systemName: systemImage)
                                .foregroundColor(.gray))
            }
        } else {
            return AnyView(EmptyView())
        }
    }
    
}


public struct PiePercentageProgressViewStyle : ProgressViewStyle {
    public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View {
        GeometryReader { geometry in
            let width: CGFloat = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: width/2, y: width/2)

            ZStack {
                Path { path in
                    path.addArc(center: center, radius: width/2, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 360), clockwise: false)
                }
                .stroke(lineWidth: 2.0)
                
                if let fraction = configuration.fractionCompleted {
                    Path { path in
                        let center = CGPoint(x: width/2, y: width/2)
                        
                        path.move(to: center)
                        path.addArc(center: center, radius: width/2, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: (360 * fraction) - 90), clockwise: false)
                        path.addLine(to: center)
                    }
                    .fill()
                }
            }
        }
    }
}



struct StatusRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sr = StatusRowText(text: "Description", value: "Value", status: .ok)
        StatusRowView(sr: sr)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()

        let sr2 = StatusRowText(text: "Description", value: "Alert", status: .alert)
        StatusRowView(sr: sr2)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
            .background(Color(.systemBackground))
            .environment(\.colorScheme, .dark)

        let sr3 = StatusRowTime(text: "Description", status: .custom("star.fill"), date: Date())
        StatusRowView(sr: sr3)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()

        let sr4 = StatusRowTime(text: "Clock", status: .clock, date: Date())
        StatusRowView(sr: sr4)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()

        let sr5 = StatusRowTime(text: "Start", status: .start, date: Date())
        StatusRowView(sr: sr5)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()

        let sr6 = StatusRowTime(text: "End", status: .end, date: Date())
        StatusRowView(sr: sr6)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()

        let sr7 = StatusRowText(text: "Pie Chart", value: "0.3", status: .pie(0.3))
        StatusRowView(sr: sr7)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()

    }
}
