/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Alamofire
import Shared
import JSONSchema
import Deferred

enum Endpoint {
    case Staging
    case Production

    var url: NSURL {
        switch self {
        case .Staging:
            return NSURL(string: "https://onyx_tiles.stage.mozaws.net/v3/links/ping-centre")!
        case .Production:
            return NSURL(string: "https://tiles.services.mozilla.com/v3/links/ping-centre")!
        }
    }
}

public struct PingCentre {
    public static func clientForTopic(topic: PingCentreTopic, clientID: NSUUID = NSUUID()) -> PingCentreClient {
        switch AppConstants.BuildChannel {
        case .Developer:
            fallthrough
        case .Nightly:
            fallthrough
        case .Aurora:
            fallthrough
        case .Beta:
            return DefaultPingCentreImpl(topic: topic, endpoint: .Staging, clientID: clientID)
        case .Release:
            return DefaultPingCentreImpl(topic: topic, endpoint: .Production, clientID: clientID)
        }
    }
}

enum PingCentreError: MaybeErrorType {
    case ValidationError(errors)
    case NetworkError(error)
}

// MARK: Ping Centre Client
public protocol PingCentreClient {
    func sendPing(data: [String: AnyObject], validate: Bool) -> Success
}

// Neat trick to have default parameters for protocol methods while still being able to lean on the compiler
// for adherence to the protocol.
extension PingCentreClient {
    func sendPing(data: [String: AnyObject], validate: Bool = true) -> Success {
        sendPing(data, validate: validate)
    }
}

class DefaultPingCentreImpl: PingCentreClient {
    private let topic: PingCentreTopic
    private let clientID: NSUUID
    private let endpoint: Endpoint
    private let manager: Alamofire.Manager

    private let validationQueue: NSOperationQueue

    init(topic: PingCentreTopic, endpoint: Endpoint, clientID: NSUUID = NSUUID(),
         validationQueue: NSOperationQueue = NSOperationQueue(), manager: Alamofire.Manager = Alamofire.Manager()) {
        self.topic = topic
        self.clientID = clientID
        self.endpoint = endpoint
        self.validationQueue = validationQueue
        self.manager = manager
    }

    func sendPing(data: [String: AnyObject], validate: Bool = true) -> Success {
        var payload = data
        payload["topic"] = topic.name
        payload["client_id"] = clientID.UUIDString

        return (validate ? validatePayload(payload, schema: topic.schema) : succeed()) >>> {
            return sendPayload(payload)
        }
    }

    private func sendPayload(payload: [String: AnyObject]) -> Success {
        let deferred = Success()
        self.manager.request(.POST, endpoint.url, parameters: payload, encoding: .JSON)
                    .validate(statusCode: 200..<300)
                    .response { _, _, _, error in
            if let e = error {
                NSLog("Failed to send ping to ping centre -- topic: \(self.topic.name), error: \(e)")
                return
            }
            deferred.fill(())
        }
        return deferred
    }

    private func validatePayload(payload: [String: AnyObject], schema: Schema) -> Success {
        let errors = schema.validate(payload).errors ?? []
        guard errors.isEmpty else {
            validationErrors = errors
            return deferMaybe(PingCentreError.ValidationError(errors))
        }
    }
}
