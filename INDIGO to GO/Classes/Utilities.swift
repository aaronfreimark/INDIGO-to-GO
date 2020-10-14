//
//  Utilities.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/14/20.
//

import Foundation

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}


extension Date {
    func timeString() -> String {
        let timeFormat = DateFormatter()
        timeFormat.dateStyle = .none
        timeFormat.timeStyle = .short

        return timeFormat.string(from: self)
    }
}

