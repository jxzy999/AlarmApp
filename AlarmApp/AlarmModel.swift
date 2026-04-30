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


extension AlarmModel {
    func debugLog() {
        Log.alarm("---------------------------------------")
        Log.alarm("⏰ [AlarmModel Debug Info]")
        Log.alarm("🆔 ID: \(id)")
        Log.alarm("🏷️ Label: \(label)")
        Log.alarm("🕒 Time: \(timeString) (Raw: \(time))")
        Log.alarm("🔘 Enabled: \(isEnabled)")
        
        Log.alarm("🎵 Sound: \(soundName)")
        Log.alarm("🔁 Repeat Mode: \(repeatMode.rawValue)")
        
        switch repeatMode {
        case .weekly:
            Log.alarm("   └ Days: \(repeatDays) (1=Sun, 7=Sat)")
        case .monthly:
            Log.alarm("   └ Days: \(repeatMonthDays)")
        case .yearly:
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            Log.alarm("   └ Date: \(formatter.string(from: repeatYearDate))")
        default:
            break
        }
        
        Log.alarm("💤 Snooze: \(isSnoozeEnabled ? "Enabled" : "Disabled")")
        if isSnoozeEnabled {
            Log.alarm("   └ Duration: \(snoozeDuration) min")
        }
        Log.alarm("---------------------------------------")
    }
}

// MARK: - 下一次响铃时间（用于列表展示）
extension AlarmModel {
    /// 计算下一次响铃时间（基于当前时间）。
    /// - Parameters:
    ///   - now: 当前时间（默认 Date()，便于测试时注入）。
    ///   - calendar: 日历对象（默认 Calendar.current，便于测试时注入）。
    /// - Returns: 下一次响铃的绝对时间；若无法计算（例如“每月”未选择日期），返回 nil。
    func nextFireDate(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let timeComps = calendar.dateComponents([.hour, .minute], from: time)
        let hour = timeComps.hour ?? 0
        let minute = timeComps.minute ?? 0
        
        switch repeatMode {
        case .once:
            return nextDateForOnce(hour: hour, minute: minute, now: now, calendar: calendar)
            
        case .weekly:
            // 与调度逻辑保持一致：若未选择星期，则退化为单次闹钟（今天/明天）。
            guard !repeatDays.isEmpty else {
                return nextDateForOnce(hour: hour, minute: minute, now: now, calendar: calendar)
            }
            return nextDateForWeekly(hour: hour, minute: minute, now: now, calendar: calendar)
            
        case .monthly:
            // 需要用户选择“每月哪几天”，否则无法得出下一次
            guard !repeatMonthDays.isEmpty else { return nil }
            return nextDateForMonthly(hour: hour, minute: minute, now: now, calendar: calendar)
            
        case .yearly:
            return nextDateForYearly(hour: hour, minute: minute, now: now, calendar: calendar)
            
        case .holiday:
            return nextDateForHoliday(hour: hour, minute: minute, now: now, calendar: calendar)
        }
    }
    
    /// 生成列表里展示的“下一次响铃时间”文案：
    /// - 3天内：今天/明天/后天 + 时间
    /// - 更久：日期 + 时间
    /// - Returns: “下次响铃：...” 文案；若闹钟关闭/无法计算，会返回对应提示。
    func nextFireDisplayText(from now: Date = Date(), calendar: Calendar = .current) -> String {
        guard isEnabled else { return "下次响铃：已关闭" }
        guard let nextDate = nextFireDate(from: now, calendar: calendar) else { return "下次响铃：未设置" }
        return "下次响铃：\(formatNextFireDate(nextDate, now: now, calendar: calendar))"
    }
    
    // MARK: - Private Helpers
    
    /// 单次闹钟：若今天该时间已过，则取明天同一时间；否则取今天。
    private func nextDateForOnce(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date? {
        guard var nextDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return nil }
        if nextDate <= now {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        return nextDate
    }
    
    /// 每周闹钟：从今天起向后扫描 7 天，找最早且大于当前时间的日期。
    private func nextDateForWeekly(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date? {
        let repeatSet = Set(repeatDays)
        let todayStart = calendar.startOfDay(for: now)
        
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }
            let weekday = calendar.component(.weekday, from: day) // 1=Sun ... 7=Sat
            guard repeatSet.contains(weekday) else { continue }
            
            if let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
               candidate > now {
                return candidate
            }
        }
        
        return nil
    }
    
    /// 每月闹钟：向后计算未来 13 个月内的候选日期，取最早且大于当前时间的一个。
    private func nextDateForMonthly(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date? {
        let sortedDays = repeatMonthDays.sorted()
        
        var best: Date?
        for monthOffset in 0...13 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: now) else { continue }
            let ym = calendar.dateComponents([.year, .month], from: monthDate)
            
            for day in sortedDays {
                var comps = DateComponents()
                comps.year = ym.year
                comps.month = ym.month
                comps.day = day
                comps.hour = hour
                comps.minute = minute
                comps.second = 0
                
                guard comps.isValidDate(in: calendar),
                      let candidate = calendar.date(from: comps),
                      candidate > now else { continue }
                
                if best == nil || candidate < best! {
                    best = candidate
                }
            }
        }
        
        return best
    }
    
    /// 每年闹钟：使用保存的“月日”，向后计算未来 6 年内的候选日期，取最早且大于当前时间的一个。
    private func nextDateForYearly(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date? {
        let md = calendar.dateComponents([.month, .day], from: repeatYearDate)
        guard let month = md.month, let day = md.day else { return nil }
        
        let currentYear = calendar.component(.year, from: now)
        for yearOffset in 0...6 {
            var comps = DateComponents()
            comps.year = currentYear + yearOffset
            comps.month = month
            comps.day = day
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            
            guard comps.isValidDate(in: calendar),
                  let candidate = calendar.date(from: comps),
                  candidate > now else { continue }
            
            return candidate
        }
        
        return nil
    }
    
    /// 法定工作日闹钟：从今天起向后扫描一段时间，找到下一个工作日并合并时间。
    private func nextDateForHoliday(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date? {
        let todayStart = calendar.startOfDay(for: now)
        
        // 与调度逻辑（预埋 30 天）保持一致，并略微放宽到 60 天，避免边界场景列表显示为空。
        for dayOffset in 0...60 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }
            guard WorkdayCalculator.isChineseWorkday(day) else { continue }
            
            if let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
               candidate > now {
                return candidate
            }
        }
        
        return nil
    }
    
    /// 按“3天内用 今天/明天/后天，否则用日期+时间”的规则格式化。
    private func formatNextFireDate(_ nextDate: Date, now: Date, calendar: Calendar) -> String {
        let startNow = calendar.startOfDay(for: now)
        let startNext = calendar.startOfDay(for: nextDate)
        let dayDiff = calendar.dateComponents([.day], from: startNow, to: startNext).day ?? 0
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeText = timeFormatter.string(from: nextDate)
        
        if dayDiff == 0 { return "今天 \(timeText)" }
        if dayDiff == 1 { return "明天 \(timeText)" }
        if dayDiff == 2 { return "后天 \(timeText)" }
        
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy年M月d日 HH:mm"
        return dateTimeFormatter.string(from: nextDate)
    }
}
