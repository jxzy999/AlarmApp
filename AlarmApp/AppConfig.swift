//
//  AppConfig.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import Foundation
import AlarmKit
import AppIntents
import SwiftUI

// MARK: - Metadata (传递给系统的数据)
typealias MyAppAlarmConfiguration = AlarmManager.AlarmConfiguration<AppAlarmMetadata>


// MARK: - App Intents (交互意图)
// 当闹钟响起时，用户点击按钮触发的动作

struct StopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "停止"
    
    @Parameter(title: "Alarm ID")
    var alarmID: String
    
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    
    func perform() throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            // 调用 Manager 停止
            try AlarmManager.shared.stop(id: uuid)
        }
        return .result()
    }
}


struct RepeatIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmManager.shared.countdown(id: uuid)
        }
        return .result()
    }
    
    static var title: LocalizedStringResource = "稍后提醒"
    static var description = IntentDescription("稍后再重复一次")
    
    @Parameter(title: "Alarm ID")
    var alarmID: String
    
    init(alarmID: String) {
        self.alarmID = alarmID
    }
    
    init() {
        self.alarmID = ""
    }
}


// 扩展按钮样式
extension AlarmButton {
    static var snoozeButton: Self {
        AlarmButton(text: "稍后", textColor: .primary, systemImageName: "moon.zzz.fill")
    }
    
    static var stopButton: Self {
        AlarmButton(text: "停止", textColor: .black, systemImageName: "pause.fill")
    }
    
    static var resumeButton: Self {
        AlarmButton(text: "Start", textColor: .black, systemImageName: "play.fill")
    }
}
