//
//  StatusRow.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/14/20.
//

import Foundation

struct StatusRow {
    var isSet: Bool = true
    var text: String
    var value: String = ""
    var status: Status = .blank
    
    enum Status {
        case ok, warn, alert, unknown, blank
        case custom(String)
    }

}
