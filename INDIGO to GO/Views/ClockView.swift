//
//  ClockView.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/24/20.
//

import SwiftUI
import Foundation

struct ClockView: View {
    let date: Date
    let hourSize: CGFloat = 0.24
    var hourOffset: CGFloat { 0.5 - hourSize }
    let minuteSize: CGFloat = 0.37
    var minuteOffset: CGFloat { 0.5 - minuteSize }

    init(_ date: Date) {
        self.date = date
    }
    
    func hourAngle() -> Angle {
        let hours = Double(Calendar.current.component(.hour, from: self.date))
        return Angle(degrees: 360.0 * hours / 12.0)
    }
    
    func minuteAngle() -> Angle {
        let minutes = Double(Calendar.current.component(.minute, from: self.date))
        return Angle(degrees: 360.0 * minutes / 60.0)
    }

    var body: some View {
        GeometryReader { metrics in
            let lineWidth: CGFloat = metrics.size.width / 15
            ZStack {
                Circle()
                    .stroke(Color.gray, lineWidth: lineWidth)
                
                // Hour Hand
                RoundedRectangle(cornerRadius: lineWidth/2)
                    .size(width: lineWidth, height: metrics.size.width * hourSize)
                    .offset(x: metrics.size.width / 2 - lineWidth / 2, y: metrics.size.width * hourOffset)
                    .rotation(self.hourAngle())
                    .foregroundColor(.gray)

                // Minute Hand
                RoundedRectangle(cornerRadius: lineWidth/2)
                    .size(width:lineWidth, height: metrics.size.width * minuteSize)
                    .offset(x: metrics.size.width / 2 - lineWidth / 2, y: metrics.size.width * minuteOffset)
                    .rotation(self.minuteAngle())
                    .foregroundColor(.gray)
            }
            .frame(width: metrics.size.width, height: metrics.size.width, alignment: .center)
        }
    }
}

struct ClockView_Previews: PreviewProvider {
    
    static var previews: some View {
        let date1 = Date(timeIntervalSinceReferenceDate: 0)
        ClockView(date1)
            .previewDisplayName("\(Calendar.current.component(.hour, from: date1)):\(Calendar.current.component(.minute, from: date1))")
            .previewLayout(PreviewLayout.fixed(width: 100.0, height: 100.0))
            .padding()
        
        let date2 = date1.addingTimeInterval(3*60*60)
        ClockView(Date(timeIntervalSinceReferenceDate: 3*60*60))
            .previewDisplayName("\(Calendar.current.component(.hour, from: date2)):\(Calendar.current.component(.minute, from: date2))")
            .previewLayout(PreviewLayout.fixed(width: 100.0, height: 100.0))
            .padding()

        let date3 = date2.addingTimeInterval(10*60*60 + 15*60)
        ClockView(date3)
            .previewDisplayName("\(Calendar.current.component(.hour, from: date3)):\(Calendar.current.component(.minute, from: date3))")
            .previewLayout(PreviewLayout.fixed(width: 100.0, height: 100.0))
            .padding()
        
        let date4 = date3.addingTimeInterval(30*60)
        ClockView(date4)
            .previewDisplayName("\(Calendar.current.component(.hour, from: date4)):\(Calendar.current.component(.minute, from: date4))")
            .previewLayout(PreviewLayout.fixed(width: 100.0, height: 100.0))
            .padding()
    }
}
