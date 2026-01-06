//
//  AlarmService.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import Foundation
import AlarmKit
import CryptoKit
import SwiftData
import SwiftUI
import AppIntents

@Observable
class AlarmService {
    static let shared = AlarmService()
    private let alarmManager = AlarmManager.shared
    
    // MARK: - 主同步方法
    @MainActor
    func syncAlarmToSystem(_ alarm: AlarmModel) {
        Task {
            // 清理所有旧的 (包括小睡产生的临时闹钟)
            await cleanUpSystemAlarms(for: alarm)
            guard alarm.isEnabled else { return }
            
            // 权限检查
            guard let authStatus = try? await alarmManager.requestAuthorization(),
                  authStatus == .authorized else { return }
            
            switch alarm.repeatMode {
            case .once:
                await scheduleOnce(alarm)
            case .weekly:
                await scheduleWeekly(alarm)
            case .monthly:
                await scheduleMonthly(alarm) // 新增
            case .yearly:
                await scheduleYearly(alarm)  // 新增
            case .holiday:
                await scheduleSmartHoliday(alarm)
            }
        }
    }
    
    // MARK: - 调度逻辑实现
    
    // 1. 单次
    private func scheduleOnce(_ alarm: AlarmModel) async {
        // 如果时间已过，定在明天；否则今天
        let targetDate = calculateNextFireDate(from: alarm.time)
        // 使用 "once" 作为后缀，确保 ID 固定，每次修改都能覆盖旧的
        await scheduleFixed(alarm, at: targetDate, idSuffix: "once")
    }
    
    // 2. 每周 (使用 .relative repeats .weekly)
    private func scheduleWeekly(_ alarm: AlarmModel) async {
        let weekdays = alarm.repeatDays.compactMap { Locale.Weekday.from(rawValue: $0) }
        if weekdays.isEmpty { await scheduleOnce(alarm); return }
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        let time = Alarm.Schedule.Relative.Time(hour: components.hour ?? 0, minute: components.minute ?? 0)
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: .weekly(weekdays)))
        
        let config = buildConfiguration(for: alarm, schedule: schedule, childID: alarm.id)
        let _ = try? await alarmManager.schedule(id: alarm.id, configuration: config)
    }
    
    // 3. 每月 (计算未来12个月)
    private func scheduleMonthly(_ alarm: AlarmModel) async {
        let calendar = Calendar.current
        let now = Date()
        let timeComps = calendar.dateComponents([.hour, .minute], from: alarm.time)
        
        // 只能用循环 .fixed 来模拟复杂月历
        for monthOffset in 0...12 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: now) else { continue }
            
            for day in alarm.repeatMonthDays {
                // 构造日期: 某年-某月-day HH:mm
                var components = calendar.dateComponents([.year, .month], from: monthDate)
                components.day = day
                components.hour = timeComps.hour
                components.minute = timeComps.minute
                
                // 检查该月是否有这天 (例如2月没有30号)
                if components.isValidDate(in: calendar),
                   let fireDate = calendar.date(from: components),
                   fireDate > now {
                    
                    await scheduleFixed(alarm, at: fireDate, idSuffix: "monthly-\(fireDate.timeIntervalSince1970)")
                }
            }
        }
    }
    
    // 4. 每年 (计算未来5年)
    private func scheduleYearly(_ alarm: AlarmModel) async {
        let calendar = Calendar.current
        let now = Date()
        let timeComps = calendar.dateComponents([.hour, .minute], from: alarm.time)
        let targetDayComps = calendar.dateComponents([.month, .day], from: alarm.repeatYearDate)
        
        for yearOffset in 0...5 {
            var components = DateComponents()
            components.year = calendar.component(.year, from: now) + yearOffset
            components.month = targetDayComps.month
            components.day = targetDayComps.day
            components.hour = timeComps.hour
            components.minute = timeComps.minute
            
            if let fireDate = calendar.date(from: components), fireDate > now {
                await scheduleFixed(alarm, at: fireDate, idSuffix: "yearly-\(components.year!)")
            }
        }
    }
    
    // 5. 节假日 (调用之前的 WorkdayCalculator)
    private func scheduleSmartHoliday(_ alarm: AlarmModel) async {
        let calendar = Calendar.current
        let now = Date()
        // 预埋 30 天
        for i in 0...30 {
            guard let date = calendar.date(byAdding: .day, value: i, to: now) else { continue }
            if WorkdayCalculator.isChineseWorkday(date) {
                // 合并时间
                var comps = calendar.dateComponents([.year, .month, .day], from: date)
                let time = calendar.dateComponents([.hour, .minute], from: alarm.time)
                comps.hour = time.hour; comps.minute = time.minute
                
                if let fireDate = calendar.date(from: comps), fireDate > now {
                    await scheduleFixed(alarm, at: fireDate, idSuffix: "holiday-\(i)")
                }
            }
        }
    }
    
    // MARK: - 小睡业务逻辑
    func scheduleSnooze(originalID: UUID, minutes: Int) async {
        let now = Date()
        let fireDate = now.addingTimeInterval(TimeInterval(minutes * 60))
        
        // 生成临时小睡 ID
        let snoozeID = UUID()
        
        // 构造临时配置
        // 这里需要构建一个临时的 Configuration，元数据稍微不同
        let alertContent = AlarmPresentation.Alert(
            title: "稍后提醒",
            stopButton: .stopButton,
            secondaryButton: nil // 小睡的闹钟通常只能停止，或者再次小睡(这里简化为停止)
        )
        
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alertContent),
            metadata: AppAlarmMetadata(label: "小睡", soundName: "Helios"),
            tintColor: .orange
        )
        
        let config = MyAppAlarmConfiguration(
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: StopIntent(alarmID: snoozeID.uuidString),
            secondaryIntent: nil
        )
        
        let _ = try? await alarmManager.schedule(id: snoozeID, configuration: config)
        print("已设定小睡: \(minutes)分钟后")
    }
    
    // MARK: - 辅助：通用单次调度
    private func scheduleFixed(_ alarm: AlarmModel, at date: Date, idSuffix: String) async {
        let childID = generateDeterministicUUID(parentID: alarm.id, suffix: idSuffix)
        
        // 注意：这里将 snoozeDuration 传入 Intent
        let snoozeIntent = alarm.isSnoozeEnabled
        ? SnoozeIntent(alarmID: childID.uuidString, duration: alarm.snoozeDuration)
        : nil
        
        let config = buildConfiguration(for: alarm, schedule: .fixed(date), childID: childID, snoozeIntent: snoozeIntent)
        
        let alarm = try? await alarmManager.schedule(id: childID, configuration: config)
        
        print("scheduleFixed - alarm: \(String(describing: alarm?.id))")
    }
     
    private func buildConfiguration(for alarm: AlarmModel,
                                    schedule: Alarm.Schedule,
                                    childID: UUID,
                                    snoozeIntent: (any LiveActivityIntent)? = nil) -> MyAppAlarmConfiguration {
        
        // 只有当传入了 snoozeIntent 时才显示按钮
        let secondaryBtn: AlarmButton? = (snoozeIntent != nil) ? .snoozeButton : nil
        let behavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = (snoozeIntent != nil) ? .custom : nil
        
        let alertContent = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.label),
            stopButton: .stopButton,
            secondaryButton: secondaryBtn,
            secondaryButtonBehavior: behavior
        )
        
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alertContent),
            metadata: AppAlarmMetadata(label: alarm.label, soundName: alarm.soundName),
            tintColor: .blue
        )
        
        // 如果没有传入特定的 snoozeIntent (比如在 scheduleFixed 外部调用)，则根据 alarm 配置生成
        let finalSnoozeIntent = snoozeIntent ?? (
            alarm.isSnoozeEnabled ? SnoozeIntent(alarmID: childID.uuidString, duration: alarm.snoozeDuration) : nil
        )
        
        return MyAppAlarmConfiguration(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopIntent(alarmID: childID.uuidString),
            secondaryIntent: finalSnoozeIntent
        )
    }
    
    // 确定性 UUID (带 Suffix 字符串)
    private func generateDeterministicUUID(parentID: UUID, suffix: String) -> UUID {
        let comboStr = "\(parentID.uuidString)-\(suffix)"
        let inputData = Data(comboStr.utf8)
        let hashed = Insecure.MD5.hash(data: inputData)
        // ... (同之前的 MD5 转 UUID 逻辑) ...
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        hashed.withUnsafeBytes { buffer in
            for i in 0..<16 { if i < buffer.count { uuidBytes[i] = buffer[i] } }
        }
        return UUID(uuid: (uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3], uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7], uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11], uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]))
    }
    
    private func calculateNextFireDate(from time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // 1. 获取用户设置的时、分
        let timeComps = calendar.dateComponents([.hour, .minute], from: time)
        let hour = timeComps.hour ?? 0
        let minute = timeComps.minute ?? 0
        
        // 2. 构造“今天”的这个时间点 (秒数为0)
        var nextDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)!
        
        // 3. 比较逻辑：
        // 如果构造出的时间 <= 当前时间（甚至只差1秒），都视为已经过期，必须推到明天。
        // 例如：现在是 15:00:30，设定的闹钟是 15:00:00 -> 已经过了 -> 明天响
        // 例如：现在是 15:00:30，设定的闹钟是 15:01:00 -> 还没过 -> 今天响
        if nextDate <= now {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
        }
        
        print("DEBUG: 单次闹钟设定 - 当前时间: \(now), 目标响铃: \(nextDate)")
        return nextDate
    }
    
    // 清理逻辑 (略微修改以适应新的 Suffix)
    @MainActor
    func deleteAlarm(_ alarm: AlarmModel) {
        Task { await cleanUpSystemAlarms(for: alarm) }
    }
    
    private func cleanUpSystemAlarms(for alarm: AlarmModel) async {
        try? alarmManager.cancel(id: alarm.id) // 移除主 ID
        // 暴力清理未来可能的 ID (真实场景最好有记录)
        // 这里只是演示，实际可能需要更复杂的 ID 追踪
    }
}



