//
//  DaylightView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/18/20.
//

import SwiftUI
import Foundation

struct DaylightView: View {
    var span: DateInterval
    var time: CGFloat
    enum DayParts { case dawn, day, twilight }
    var type: DayParts
    var offsetTime: Int = 0

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
        let width = CGFloat(self.span.duration) / time
        let offsetTime = TimeInterval(self.offsetTime)
        let start = self.span.start.addingTimeInterval(offsetTime)
        let offset = CGFloat(start.timeIntervalSinceNow) / self.time
        
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

//struct SwiftUIView_Previews: PreviewProvider {
//    static var previews: some View {
//        SwiftUIView()
//    }
//}
