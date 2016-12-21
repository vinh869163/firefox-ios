/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import Account

// MARK: Stats/Telemetry structures
public struct SyncUploadStats {
    var sent: Int = 0
    var sentFailed: Int = 0
}

public struct SyncDownloadStats {
    var applied: Int = 0
    var succeeded: Int = 0
    var failed: Int = 0
    var newFailed: Int = 0
    var reconciled: Int = 0
}

// TODO: Implement various bookmark validation issues we can run into
public struct ValidationStats {}

public struct SyncEngineStats {
    public let name: String
    public var uploadStats: SyncUploadStats?
    public var downloadStats: SyncDownloadStats?
    public var took: UInt64 = 0
    public var status: SyncStatus = .Completed
    public var failureReason: AnyObject?
    public var validationStats: ValidationStats?

    public init(name: String) {
        self.name = name
    }
}

public class SyncStatsReport {
    private var when: Timestamp
    private var took: UInt64 = 0
    private var uid: String
    private var deviceID: String?
    private var didLogin: Bool
    private var why: String
    private var engines = [String: SyncEngineStats]()

    public init(when: Timestamp, account: FirefoxAccount, didLogin: Bool = false, why: String) {
        self.when = when
        self.uid = account.uid
        self.didLogin = didLogin
        self.why = why
        self.deviceID = account.deviceRegistration?.id
    }

    public func addStats(stats: SyncEngineStats, forEngine engine: String) {
        engines[engine] = stats
    }

    public func finishReport() {
        took = when - NSDate.now()
    }
}

// Delegate object that is passed along to each synchronizer to pull out upload/downloading stats
public class SyncEngineStatsObserver: SyncStatsDelegate {
    var engineStats: SyncEngineStats?
    var startSyncTime: Timestamp?

    public init() {}

    public func syncEngineWillBeginReport(engine: String) {
        engineStats = SyncEngineStats(name: engine)
        startSyncTime = NSDate.now()
    }
    
    public func syncEngine(engine: String, didGenerateUploadStats stats: SyncUploadStats) {
        engineStats?.uploadStats = stats
    }

    public func syncEngine(engine: String, didGenerateApplyStats stats: SyncDownloadStats) {
        engineStats?.downloadStats = stats
    }

    public func syncEngineDidEndReport(engine: String, status: SyncStatus) -> SyncEngineStats? {
        defer { engineStats = nil }

        engineStats?.status = status

        guard let startTime = startSyncTime else {
            return engineStats
        }
        
        let took = NSDate.now() - startTime
        engineStats?.took = took

        return engineStats
    }
}
