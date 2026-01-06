//
//  AppAlarmMetadata.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import AlarmKit


// 用于在锁屏、灵动岛显示闹钟的自定义信息
struct AppAlarmMetadata: AlarmMetadata, Codable {
    var label: String
    var icon: String
    init(label: String = "闹钟", icon: String = "alarm") {
        self.label = label
        self.icon = icon
    }
}
