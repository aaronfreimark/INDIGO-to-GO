//
//  Daylight.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/17/20.
//

import Foundation

struct Daylight: Equatable {
    var dawn: DateInterval?
    var day: DateInterval?
    var dusk: DateInterval?
    
    init() { }
    
    init(dawn: DateInterval?, day: DateInterval?, twilight: DateInterval?) {
        self.dawn = dawn
        self.day = day
        self.dusk = twilight
    }

    init(asr: Date?, sr: Date?, ss: Date?, ass: Date?) {
        if let asr = asr, let sr = sr {
//            print("ASR: \(asr)")
//            print("SR: \(sr)")
            self.dawn = DateInterval(start: asr, end: sr)
        }
        if let sr = sr, let ss = ss {
//            print("SS: \(ss)")
            self.day = DateInterval(start: sr, end: ss)
        }
        if let ss = ss, let ass = ass {
//            print("ASS: \(ass)")
            self.dusk = DateInterval(start: ss, end: ass)
        }
    }
    
    func isNil() -> Bool {
        return self.dawn == nil && self.day == nil && self.dusk == nil
    }
    
    mutating func nullifyIfOutside(_ testInterval: DateInterval) {
        if let dawn = self.dawn { if dawn.intersects(testInterval) == false { self.dawn = nil } }
        if let day = self.day { if day.intersects(testInterval) == false { self.day = nil } }
        if let twilight = self.dusk { if twilight.intersects(testInterval) == false { self.dusk = nil } }
    }
}
