//
//  INDIGO_to_GOTests.swift
//  INDIGO to GOTests
//
//  Created by Aaron Freimark on 10/17/20.
//

import XCTest
import SwiftyJSON
import Firebase
@testable import INDIGO_to_GO

class INDIGO_to_GOTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Load in sample sequences from a JSON file, and make sure we parse the image sequences correctly
    func testSequenceParser() throws {
        let path = Bundle.main.path(forResource: "INDIGO_Property_Tests", ofType: "json")!
        let jsonString = try? String(contentsOfFile: path, encoding: String.Encoding.utf8)
        let json = JSON(parseJSON: jsonString!)

        for (index,testJson):(String, JSON) in json {
            print("Test #\(index)")
            
            let client = LocalIndigoClient()
            
            for (_, propJson):(String, JSON) in testJson["properties"] {
                client.setValue(key: propJson["key"].string!, toValue: propJson["value"].string!, toState: propJson["State"].string!)
            }
            XCTAssertEqual(client.getKeys().count, Int(testJson["properties"].count))

            let clientVM = IndigoClientViewModel(client: client)
            clientVM.update()
            
            XCTAssertEqual(clientVM.client?.getKeys().count, Int(testJson["properties"].count))
            XCTAssertEqual(clientVM.srSequenceStatus?.value , "\(testJson["currentImage"]) / \(testJson["totalImages"])")
            XCTAssertEqual(clientVM.imagerTotalTime, testJson["totalTime"].float)
            XCTAssertEqual(clientVM.imagerElapsedTime , testJson["elapsedTime"].float)
        }
    }
    
    func testProperties() throws {
        let client = LocalIndigoClient()
        
        let keycountBefore = client.getKeys().count
        XCTAssertEqual(keycountBefore, 0)
        
        let count = 10000
        for _ in 1...10000 {
            client.setValue(key: UUID().uuidString, toValue: UUID().uuidString, toState: "Ok")
        }
        let keycountDuring = client.getKeys().count
        XCTAssertEqual(keycountDuring, count)
        
        client.removeAll()
        let keycountAfter = client.getKeys().count
        XCTAssertEqual(keycountAfter, 0)
    }

}
