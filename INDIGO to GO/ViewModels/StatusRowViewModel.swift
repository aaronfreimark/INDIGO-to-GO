//
//  StatusRow.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/14/20.
//

import Foundation

protocol StatusRow {
    var isSet: Bool { get }
    var text: String { get }
    var value: String { get }
    var status: StatusRowStatus { get }
    var date: Date? { get }
}

enum StatusRowStatus {
    case ok, warn, alert, unknown, blank, clock, start, end
    case custom(String)
}

struct StatusRowText: StatusRow, Identifiable {
    var isSet: Bool = true
    var text: String
    var value: String = ""
    var status: StatusRowStatus = .blank
    var date: Date?
    let id = UUID()

}


struct StatusRowTime: StatusRow, Comparable, Identifiable {
    var isSet: Bool = true
    var text: String
    var value: String {
        if let d = self.date { return d.timeString() }
        else { return self.textIfNil; }
    }
    var status: StatusRowStatus = .blank
    let id = UUID()

    var date: Date?
    var textIfNil: String = "-"

    // The Comparible protocol allows us to order these structs chronolically
    
    static func < (lhs: StatusRowTime, rhs: StatusRowTime) -> Bool {
        let l = lhs.date ?? Date.distantFuture
        let r = rhs.date ?? Date.distantFuture
        return l < r
    }
    
    static func == (lhs: StatusRowTime, rhs: StatusRowTime) -> Bool {
        return lhs.date == rhs.date
    }

}
