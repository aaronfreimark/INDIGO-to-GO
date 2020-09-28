//
//  IndigoExposure.swift
//  INDIGO To Go
//
//  Created by Aaron Freimark on 9/22/20.
//

import Foundation
import SwiftUI


struct IndigoSequence: Hashable {
    var count: Float = 0
    var seconds: Float = 0
    var filter: String = ""
    var color: Color = .gray
    var totalTime: Float { seconds * count }
    var circleSize: CGFloat = 6


    init(count: Float, seconds: Float, filter: String) {
        self.count = count
        self.seconds = seconds
        self.filter = filter
        self.color = sequencerColor(filter)
    }
    
    func sequencerColor(_ filter: String) -> Color {
        
        switch filter.uppercased() {
        case "R", "RED": return .red;
        case "G", "GREEN": return .green;
        case "B", "BLUE": return .blue;

        case "HA", "H A", "H-A": return .pink;
        case "OIII", "O-III", "O III": return .yellow;
        case "SII", "S-II", "S II": return .purple;
            
        default: return .gray;
        }
        
    }
    
    func progressView(imagerTotalTime: Float, enclosingWidth: CGFloat) -> some View {
        let proportion: CGFloat = CGFloat(self.totalTime) / CGFloat(imagerTotalTime)
        let widthPx =  proportion * CGFloat(enclosingWidth)
        
        let eachCircleWidthPx = widthPx / CGFloat(self.count)
        
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(self.filter)
                    .font(.caption)
                    .foregroundColor(self.color)

                HStack(spacing: 0) {
                    ForEach(0..<Int(self.count)) { _ in
                        Circle()
                            .fill(self.color)
                            .frame(width: circleSize, height: circleSize)
                            .padding(0.0)
                    }.frame(width: eachCircleWidthPx, height: nil, alignment: .leading)
                }
            }
        }.frame(width: widthPx)

    }
    
}
