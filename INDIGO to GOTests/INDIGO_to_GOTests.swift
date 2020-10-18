//
//  INDIGO_to_GOTests.swift
//  INDIGO to GOTests
//
//  Created by Aaron Freimark on 10/17/20.
//

import XCTest
import SwiftyJSON
@testable import INDIGO_to_GO

class INDIGO_to_GOTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSequenceParser() throws {

        let path = Bundle.main.path(forResource: "INDIGO_Property_Tests", ofType: "json")!
        let jsonString = try? String(contentsOfFile: path, encoding: String.Encoding.utf8)
        let json = JSON(parseJSON: jsonString!)

        for (index,testJson):(String, JSON) in json {
            print("Test #\(index)")
            
            var client = IndigoClient()
            
            for (_, propJson):(String, JSON) in testJson["properties"] {
                client.setValue(key: propJson["key"].string!, toValue: propJson["value"].string!, toState: propJson["State"].string!)
            }

            client.updateUI()
            
            XCTAssertEqual(client.srSequenceStatus?.value , "\(testJson["currentImage"]) / \(testJson["totalImages"])")
            XCTAssertEqual(client.imagerTotalTime, testJson["totalTime"].float)
            XCTAssertEqual(client.imagerElapsedTime , testJson["elapsedTime"].float)
        }



    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
