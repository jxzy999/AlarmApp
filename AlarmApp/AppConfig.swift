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
    init(label: String = "闹钟", soundName: String = "Helios") {
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
    
    // 1. 接收 Alarm ID
    @Parameter(title: "Alarm ID")
    var alarmID: String
    
    // 2. 接收用户设置的时长 (分钟)
    @Parameter(title: "Duration")
    var duration: Int
    
    init() {}
    init(alarmID: String, duration: Int) {
        self.alarmID = alarmID
        self.duration = duration
    }
    
    func perform() throws -> some IntentResult {
        // 先停止当前的
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmManager.shared.stop(id: uuid)
            
            // 业务功能：设定一个新的单次闹钟 (N分钟后)
            Task {
                await AlarmService.shared.scheduleSnooze(originalID: uuid, minutes: duration)
            }
        }
        return .result()
    }
}

// 扩展按钮样式
extension AlarmButton {
    static var stopButton: Self {
        // 样式可根据需求修改，这里设为红色停止样式
        AlarmButton(text: "停止", textColor: .white, systemImageName: "stop.circle.fill")
    }
    
    static var snoozeButton: Self {
        AlarmButton(text: "稍后", textColor: .primary, systemImageName: "moon.zzz.fill")
    }
}
