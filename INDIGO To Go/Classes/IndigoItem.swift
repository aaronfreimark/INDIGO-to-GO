//
//  IndigoItem.swift
//  INDIGO Status
//
//  Created by Aaron Freimark on 9/15/20.
//

import Foundation

struct IndigoItem: Hashable, Equatable {
    var value = ""
    var state: StateValue?
    var target: String?

    init(theValue: String, theState: String, theTarget: String?) {
        self.value = theValue
        self.target = theTarget
        self.state = StateValue(rawValue: theState)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(target)
        hasher.combine(value)
        hasher.combine(state)
    }

}

enum StateValue: String {
    case Ok, Busy, Alert, Idle
}
