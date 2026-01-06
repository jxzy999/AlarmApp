//
//  AlarmModel.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import SwiftData
import Foundation

// 重复模式枚举
enum AlarmRepeatMode: String, Codable, CaseIterable, Identifiable {
    case once = "单次"
    case weekly = "每周"
    case monthly = "每月"
    case yearly = "每年"
    case holiday = "法定工作日"
    
    var id: String { rawValue }
}

@Model
final class AlarmModel {
    @Attribute(.unique) var id: UUID
    var time: Date
    var label: String
    var isEnabled: Bool
    var soundName: String
    
    // --- 新增/修改的属性 ---
    var repeatMode: AlarmRepeatMode // 重复模式
    
    var repeatDays: [Int]   // 每周: 1-7 (Sun-Sat)
    var repeatMonthDays: [Int] // 每月: 1-31
    var repeatYearDate: Date // 每年: 只存月日
    
    var isSnoozeEnabled: Bool
    var snoozeDuration: Int // 小睡时长 (1-10分钟)
    
    init(time: Date, label: String = "闹钟", isEnabled: Bool = true) {
        self.id = UUID()
        self.time = time
        self.label = label
        self.isEnabled = isEnabled
        self.soundName = "Bell Tower"
        
        // 默认值初始化
        self.repeatMode = .once
        self.repeatDays = []
        self.repeatMonthDays = []
        self.repeatYearDate = Date()
        self.isSnoozeEnabled = true
        self.snoozeDuration = 5 // 默认5分钟
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    // UI 描述
    var repeatDescription: String {
        switch repeatMode {
        case .once: return "单次"
        case .weekly:
            if repeatDays.count == 7 { return "每天" }
            if repeatDays.isEmpty { return "未设置" }
            return "每周 \(repeatDays.count) 天"
        case .monthly:
            if repeatMonthDays.isEmpty { return "每月" }
            return "每月 \(repeatMonthDays.count) 天"
        case .yearly:
            let formatter = DateFormatter()
            formatter.dateFormat = "MM月dd日"
            return "每年 \(formatter.string(from: repeatYearDate))"
        case .holiday:
            return "法定工作日"
        }
    }
}


// MARK: - 扩展 Locale.Weekday 修复类型转换报错
extension Locale.Weekday {
    // 辅助方法：将 Int (1=Sun, ... 7=Sat) 转换为 Sample Code 需要的 Locale.Weekday
    static func from(rawValue: Int) -> Locale.Weekday {
        // Locale.Weekday 在新 API 中通常没有直接的 Int init，我们需要手动映射
        // 这里的顺序依据：Standard Gregorian: 1=Sun, 2=Mon...
        switch rawValue {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .sunday // Fallback
        }
    }
}
