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
        f.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"

        let lat = 41.42444
        let lon = -73.95917

        let location = CLLocation(latitude: lat, longitude: lon)
        let loc = Location()
        loc.location = location
        loc.hasLocation = true

        let day1ASR = f.date(from: "2020-10-17 05:37:00 EDT")!
        let day1SR = f.date(from: "2020-10-17 07:09:00 EDT")!
        let day1SS = f.date(from: "2020-10-17 18:12:00 EDT")!
        let day1ASS = f.date(from: "2020-10-17 19:42:00 EDT")!
        let day1Dawn = DateInterval(start: day1ASR, end: day1SR)
        let day1Day = DateInterval(start: day1SR, end: day1SS)
        let day1Twilight = DateInterval(start: day1SS, end: day1ASS)

        let day2ASR = f.date(from: "2020-10-18 05:39:00 EDT")!
        let day2SR = f.date(from: "2020-10-18 07:11:00 EDT")!
        let day2SS = f.date(from: "2020-10-18 18:08:00 EDT")!
        let day2ASS = f.date(from: "2020-10-18 19:41:00 EDT")!
        let day2Dawn = DateInterval(start: day2ASR, end: day2SR)
        let day2Day = DateInterval(start: day2SR, end: day2SS)
        let day2Twilight = DateInterval(start: day2SS, end: day2ASS)

        let tests: [DaylightTestStruct] = [
            // 0 -- test evening day 1 to morning, day 2
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 22:31:00 EDT")!, end: f.date(from: "2020-10-18 08:31:00 EDT")!),
                start: Daylight(dawn: day2Dawn, day: day2Day, twilight: nil),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            ),
            // 1 -- test mid-day day 1 to almost midnight, day 1
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 12:00:00 EDT")!, end: f.date(from: "2020-10-17 23:31:00 EDT")!),
                start: Daylight(dawn: nil, day: day1Day, twilight: day1Twilight),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            ),
            // 2 -- test mid-day day 1 to twilight, day 1
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 12:00:00 EDT")!, end: f.date(from: "2020-10-17 18:31:00 EDT")!),
                start: Daylight(dawn: nil, day: day1Day, twilight: day1Twilight),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            ),
            // 3 -- test night day 1 to dawn, day 2
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 21:31:00 EDT")!, end: f.date(from: "2020-10-18 06:31:00 EDT")!),
                start: Daylight(dawn: day2Dawn, day: nil, twilight: nil),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            ),
            // 4 -- test post-midnight day 2 to dawn, day 2
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-18 00:31:00 EDT")!, end: f.date(from: "2020-10-18 06:31:00 EDT")!),
                start: Daylight(dawn: day2Dawn, day: nil, twilight: nil),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            ),
            // 5 -- test post-midnight day 2 to morning, day 2
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-18 01:31:00 EDT")!, end: f.date(from: "2020-10-18 08:31:00 EDT")!),
                start: Daylight(dawn: day2Dawn, day: day2Day, twilight: nil),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            ),
            // 6 -- test twilight day 1 to post-midnight, day 2
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 17:00:00 EDT")!, end: f.date(from: "2020-10-18 12:31:00 EDT")!),
                start: Daylight(dawn: nil, day: day1Day, twilight: day1Twilight),
                end: Daylight(dawn: day2Dawn, day: day2Day, twilight: nil)
            ),
            // 7 -- Longer than 24 hours
            DaylightTestStruct(
                seq: DateInterval(start: f.date(from: "2020-10-17 17:00:00 EDT")!, end: f.date(from: "2020-10-20 12:31:00 EDT")!),
                start: Daylight(dawn: nil, day: nil, twilight: nil),
                end: Daylight(dawn: nil, day: nil, twilight: nil)
            )


        ]
        

        for (index ,test) in tests.enumerated() {
            print("Test #\(index)...")

            let daylight = loc.calculateDaylight(interval: test.seq)

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

            if test.start.dusk == nil {
                XCTAssertNil(daylight.start.dusk)
            } else {
                if let tested = daylight.start.dusk, let expected = test.start.dusk {
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

            if test.end.dusk == nil {
                XCTAssertNil(daylight.end.dusk)
            } else {
                if let tested = daylight.end.dusk, let expected = test.end.dusk {
                    XCTAssertEqual(tested.start.timeIntervalSince1970, expected.start.timeIntervalSince1970, accuracy: testAccuracy)
                    XCTAssertEqual(tested.end.timeIntervalSince1970, expected.end.timeIntervalSince1970, accuracy: testAccuracy)
                } else {
                    XCTFail("daylight.start.twilight is unexpectedly nil")
                }
            }
            
        }
        
        /// Test nextSunrise & nextSunset: 2020-10-17 02:31:00
        XCTAssertEqual(loc.nextSunrise(from: f.date(from: "2020-10-17 02:31:00 EDT")!)!.timeIntervalSince1970, day1SR.timeIntervalSince1970, accuracy: testAccuracy)
        XCTAssertEqual(loc.nextSunset(from: f.date(from: "2020-10-17 02:31:00 EDT")!)!.timeIntervalSince1970, day1SS.timeIntervalSince1970, accuracy: testAccuracy)

        /// Test nextSunrise & nextSunset: 2020-10-17 12:00:00
        XCTAssertEqual(loc.nextSunrise(from: f.date(from: "2020-10-17 12:00:00 EDT")!)!.timeIntervalSince1970, day2SR.timeIntervalSince1970, accuracy: testAccuracy)
        XCTAssertEqual(loc.nextSunset(from: f.date(from: "2020-10-17 12:00:00 EDT")!)!.timeIntervalSince1970, day1SS.timeIntervalSince1970, accuracy: testAccuracy)

        /// Test nextSunrise & nextSunset: 2020-10-17 22:31:00
        XCTAssertEqual(loc.nextSunrise(from: f.date(from: "2020-10-17 22:31:00 EDT")!)!.timeIntervalSince1970, day2SR.timeIntervalSince1970, accuracy: testAccuracy)
        XCTAssertEqual(loc.nextSunset(from: f.date(from: "2020-10-17 22:31:00 EDT")!)!.timeIntervalSince1970, day2SS.timeIntervalSince1970, accuracy: testAccuracy)
        
        /// Test nextSunrise & nextSunset: 2020-10-18 02:31:00
        XCTAssertEqual(loc.nextSunrise(from: f.date(from: "2020-10-18 02:31:00 EDT")!)!.timeIntervalSince1970, day2SR.timeIntervalSince1970, accuracy: testAccuracy)
        XCTAssertEqual(loc.nextSunset(from: f.date(from: "2020-10-18 02:31:00 EDT")!)!.timeIntervalSince1970, day2SS.timeIntervalSince1970, accuracy: testAccuracy)



    }
}
