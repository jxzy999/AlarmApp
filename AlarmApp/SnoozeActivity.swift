//
//  SnoozeActivity.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import AlarmKit

struct SnoozeWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 动态数据：目标响铃时间
        var fireDate: Date
    }

    // Fixed non-changing properties about your activity go here!
    var label: String
    var soundName: String
    var alarmID: String
}

// 定义“取消小睡”的 Intent
struct CancelSnoozeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "取消小睡"
    
    @Parameter(title: "Alarm ID")
    var alarmID: String
    
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    
    func perform() throws -> some IntentResult {
        // 1. 停止系统闹钟
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmManager.shared.stop(id: uuid)
        }
        
        // 2. 结束当前的实时活动
        for activity in Activity<SnoozeWidgetAttributes>.activities {
            // 简单的逻辑：结束所有 Snooze 活动，或者你可以根据 ID 匹配
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        return .result()
    }
}
