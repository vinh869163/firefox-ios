/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

@testable import Client
import XCTest
import JSONSchema
import Alamofire

private let mockTopic = PingCentreTopic(name: "ios-mock", schema: Schema([
    "type": "object",
    "properties": [
        "title": ["type": "string"]
    ],
    "required": [
        "title"
    ]
]))

private class MockingURLProtocol: NSURLProtocol {
    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        return request.URL?.scheme == "https" && request.HTTPMethod == "POST"
    }

    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }

    override func startLoading() {

        let response = NSHTTPURLResponse(URL: request.URL!,
                                         statusCode: 200,
                                         HTTPVersion: "HTTP/1.1",
                                         headerFields: ["Content-Type": "application/json"])

        self.client?.URLProtocol(self, didReceiveResponse: response!, cacheStoragePolicy: .NotAllowed)
        self.client?.URLProtocolDidFinishLoading(self)
    }
}

class PingCentreTests: XCTestCase {
    var manager: Alamofire.Manager!
    var client: PingCentreClient!

    override func setUp() {
        super.setUp()
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.protocolClasses!.insert(MockingURLProtocol.self, atIndex: 0)

        self.manager = Manager(configuration: configuration)
        self.client = DefaultPingCentreImpl(topic: mockTopic, endpoint: .Staging, manager: self.manager)
    }

    func testSendPing() {

        self.client.sendPing(<#T##data: [String : AnyObject]##[String : AnyObject]#>, validate: true)
    }
}
