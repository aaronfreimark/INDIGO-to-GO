//
//  LocationFeatures.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 10/17/20.
//

import XCTest
import Foundation
import CoreLocation
@testable import INDIGO_to_GO

class LocationFeaturesTests: XCTestCase {

    private let testAccuracy: TimeInterval = 60 * 2

    
//    override func setUpWithError() throws {
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//
//    override func tearDownWithError() throws {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }

    struct DaylightTestStruct {
        var seq: DateInterval
        var start: Daylight
        var end: Daylight
    }
    
    func testDaylightObject() throws {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let lat = 41.42444
        let lon = -73.95917

        let location = CLLocation(latitude: lat, longitude: lon)
        let loc = LocationFeatures()
        loc.location = location
        loc.hasLocation = true

        let day1ASR = f.date(from: "2020-10-17 05:37:00")!
        let day1SR = f.date(from: "2020-10-17 07:09:00")!
        let day1SS = f.date(from: "2020-10-17 18:12:00")!
        let day1ASS = f.date(from: "2020-10-17 19:42:00")!
        let day1Dawn = DateInterval(start: day1ASR, end: day1SR)
        let day1Day = DateInterval(start: day1SR, end: day1SS)
        let day1Twilight = DateInterval(start: day1SS, end: day1ASS)

        let day2ASR = f.date(from: "2020-10-18 05:39:00")!
        let day2SR = f.date(from: "2020-10-18 07:11:00")!
        let day2SS = f.date(from: "2020-10-18 18:08:00")!
        let day2ASS = f.date(from: "2020-10-18 19:41:00")!
        let day2Dawn = DateInterval(start: day2ASR, end: day2SR)
        let day2Day = DateInterval(start: day2SR, end: day2SS)
        let day2Twilight = DateInterval(start: day2SS, end: day2ASS)

        let tests: [DaylightTestStruct] = [
            // 0
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 22:31:00")!, end: f.date(from: "2020-10-18 08:31:00")!),
                start: Daylight(dawn: nil, day: nil, twilight: nil),
                end: Daylight(dawn: day2Dawn, day: day2Day, twilight: nil)
            ),
            // 1
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 12:00:00")!, end: f.date(from: "2020-10-17 23:31:00")!),
                start: Daylight(dawn: nil, day: day1Day, twilight: day1Twilight),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            ),
            // 2
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-18 00:31:00")!, end: f.date(from: "2020-10-18 08:31:00")!),
                start: Daylight(dawn: day2Dawn, day: day2Day, twilight: nil),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            ),
            // 3
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 17:00:00")!, end: f.date(from: "2020-10-18 12:31:00")!),
                start: Daylight(dawn: nil, day: day1Day, twilight: day1Twilight),
                end: Daylight(dawn: day2Dawn, day: day2Day, twilight: nil)
            ),
            // 4 -- Longer than 24 hours
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 17:00:00")!, end: f.date(from: "2020-10-20 12:31:00")!),
                start: Daylight(dawn: nil, day: nil, twilight: nil),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            )


        ]
        

        for (index ,test) in tests.enumerated() {
            print("Test #\(index)...")

            let daylight = loc.calculateDaylight(sequenceInterval: test.seq)

            if test.start.dawn == nil {
                XCTAssertNil(daylight.start.dawn)
            } else {
                if let tested = daylight.start.dawn, let expected = test.start.dawn {
                    XCTAssertEqual(tested.start.timeIntervalSince1970, expected.start.timeIntervalSince1970, accuracy: testAccuracy)
                    XCTAssertEqual(tested.end.timeIntervalSince1970, expected.end.timeIntervalSince1970, accuracy: testAccuracy)
                } else {
                    XCTFail("daylight.start.dawn is unexpectedly nil")
                }
            }

            if test.start.day == nil {
                XCTAssertNil(daylight.start.day)
            } else {
                if let tested = daylight.start.day, let expected = test.start.day {
                    XCTAssertEqual(tested.start.timeIntervalSince1970, expected.start.timeIntervalSince1970, accuracy: testAccuracy)
                    XCTAssertEqual(tested.end.timeIntervalSince1970, expected.end.timeIntervalSince1970, accuracy: testAccuracy)
                } else {
                    XCTFail("daylight.start.day is unexpectedly nil")
                }
            }

            if test.start.twilight == nil {
                XCTAssertNil(daylight.start.twilight)
            } else {
                if let tested = daylight.start.twilight, let expected = test.start.twilight {
                    XCTAssertEqual(tested.start.timeIntervalSince1970, expected.start.timeIntervalSince1970, accuracy: testAccuracy)
                    XCTAssertEqual(tested.end.timeIntervalSince1970, expected.end.timeIntervalSince1970, accuracy: testAccuracy)
                } else {
                    XCTFail("daylight.start.twilight is unexpectedly nil")
                }
            }

            if test.end.dawn == nil {
                XCTAssertNil(daylight.end.dawn)
            } else {
                if let tested = daylight.end.dawn, let expected = test.end.dawn {
                    XCTAssertEqual(tested.start.timeIntervalSince1970, expected.start.timeIntervalSince1970, accuracy: testAccuracy)
                    XCTAssertEqual(tested.end.timeIntervalSince1970, expected.end.timeIntervalSince1970, accuracy: testAccuracy)
                } else {
                    XCTFail("daylight.start.dawn is unexpectedly nil")
                }
            }

            if test.end.day == nil {
                XCTAssertNil(daylight.end.day)
            } else {
                if let tested = daylight.end.day, let expected = test.end.day {
                    XCTAssertEqual(tested.start.timeIntervalSince1970, expected.start.timeIntervalSince1970, accuracy: testAccuracy)
                    XCTAssertEqual(tested.end.timeIntervalSince1970, expected.end.timeIntervalSince1970, accuracy: testAccuracy)
                } else {
                    XCTFail("daylight.start.day is unexpectedly nil")
                }
            }

            if test.end.twilight == nil {
                XCTAssertNil(daylight.end.twilight)
            } else {
                if let tested = daylight.end.twilight, let expected = test.end.twilight {
                    XCTAssertEqual(tested.start.timeIntervalSince1970, expected.start.timeIntervalSince1970, accuracy: testAccuracy)
                    XCTAssertEqual(tested.end.timeIntervalSince1970, expected.end.timeIntervalSince1970, accuracy: testAccuracy)
                } else {
                    XCTFail("daylight.start.twilight is unexpectedly nil")
                }
            }


        }
    }
}
