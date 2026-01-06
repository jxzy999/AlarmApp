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

// MARK: - 1. Metadata (传递给系统的数据)
// 用于在锁屏、灵动岛显示闹钟的自定义信息
struct AppAlarmMetadata: AlarmMetadata, Codable {
    var label: String
    var soundName: String
    init(label: String = "闹钟", soundName: String = "Bell Tower") {
        self.label = label
        self.soundName = soundName
    }
}

typealias MyAppAlarmConfiguration = AlarmManager.AlarmConfiguration<AppAlarmMetadata>


// MARK: - 2. App Intents (交互意图)
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


struct SnoozeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "稍后提醒"
    
    @Parameter(title: "Alarm ID")
    var alarmID: String
    
    @Parameter(title: "Duration")
    var duration: Int
    
    // --- 新增参数：携带铃声和标签 ---
    @Parameter(title: "Sound Name")
    var soundName: String
    
    @Parameter(title: "Label")
    var label: String
    
    init() {}
    
    // 初始化时传入这些信息
    init(alarmID: String, duration: Int, soundName: String, label: String) {
        self.alarmID = alarmID
        self.duration = duration
        self.soundName = soundName
        self.label = label
    }
    
    func perform() throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmManager.shared.stop(id: uuid)
            
            // 将携带的铃声和标签传给 Service
            Task {
                await AlarmService.shared.scheduleSnooze(
                    originalID: uuid,
                    minutes: duration,
                    soundName: soundName, // 传入铃声
                    label: label          // 传入标签
                )
            }
        }
        return .result()
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
}
