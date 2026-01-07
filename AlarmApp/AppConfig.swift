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
    
    
    @Parameter(title: "AlarmModel ID")
    var alarmModelID: String?
    
    init() {}
    init(alarmID: String, alarmModelID: String) {
        self.alarmID = alarmID
        self.alarmModelID = alarmModelID
    }
    
    func perform() async throws -> some IntentResult {
        
        Log.d("StopIntent: \(alarmID) - \(String(describing: alarmModelID))")
        
        // 1. 检查是否需要补货
        if let alarmModelID = alarmModelID,
           let parentUUID = UUID(uuidString: alarmModelID) {
            // 异步触发检查，不阻塞 Intent 返回
            await AlarmService.shared.checkAndReplenish(alarmID: parentUUID)
        }
        
        // 2. 停止当前响铃的闹钟
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
        AlarmButton(text: "开始", textColor: .black, systemImageName: "play.fill")
    }
}
