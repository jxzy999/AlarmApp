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
import ActivityKit

@Observable
class AlarmService {
    static let shared = AlarmService()
    private let alarmManager = AlarmManager.shared
    
    // MARK: - 主同步方法
    
    // 供 View 调用
    @MainActor
    func syncAlarmToSystem(_ alarm: AlarmModel) {
        Task {
            await reScheduleAlarm(alarm)
        }
    }
    
    @MainActor
    func reScheduleAlarm(_ alarm: AlarmModel) async {
        Log.d("🔄 开始执行重新调度逻辑: \(alarm.label)")
        
        // 1. 清理旧的
        await cleanUpSystemAlarms(for: alarm)
        
        guard alarm.isEnabled else {
            Log.d("⏹️ 闹钟未启用，跳过调度")
            return
        }
        
        // 2. 权限检查
        guard let authStatus = try? await alarmManager.requestAuthorization(),
              authStatus == .authorized else { return }
        
        // 3. 执行调度
        switch alarm.repeatMode {
        case .once:
            await scheduleOnce(alarm)
        case .weekly:
            await scheduleWeekly(alarm)
        case .monthly:
            await scheduleMonthly(alarm)
        case .yearly:
            await scheduleYearly(alarm)
        case .holiday:
            await scheduleSmartHoliday(alarm)
        }
        
        Log.d("✅ 重新调度逻辑执行完毕: \(alarm.label)")
    }
    
    // MARK: - 调度逻辑实现
    
    // 1. 单次
    private func scheduleOnce(_ alarm: AlarmModel) async {
        // 如果时间已过，定在明天；否则今天
        let targetDate = calculateNextFireDate(from: alarm.time)
        
        await scheduleFixed(alarm, at: targetDate)
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
                    
                    await scheduleFixed(alarm, at: fireDate)
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
                await scheduleFixed(alarm, at: fireDate)
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
                    await scheduleFixed(alarm, at: fireDate)
                }
            }
        }
    }
    
    // MARK: - 辅助：通用单次调度
    private func scheduleFixed(_ alarm: AlarmModel, at date: Date) async {
        // 生成全新随机 ID，避免 Code 0 冲突
        let childID = UUID()
        
        let schedule = Alarm.Schedule.fixed(date)
        
        // 这里的 childID 传给 buildConfiguration
        let config = buildConfiguration(for: alarm, schedule: schedule, childID: childID)
        
        do {
            let systemAlarm = try await alarmManager.schedule(id: childID, configuration: config)
            Log.d("✅ 成功调度 - ID: \(systemAlarm.id) ， date: \(date)")
            
            // --- 关键：追加 ID 到列表，而不是覆盖 ---
            appendSystemID(childID, for: alarm.id)
            
        } catch {
            Log.d("❌ 调度失败: \(error)")
        }
        
        alarm.debugLog()
    }
    
    private func buildConfiguration(for alarm: AlarmModel,
                                    schedule: Alarm.Schedule,
                                    childID: UUID) -> MyAppAlarmConfiguration {
        
        let secondaryBtn: AlarmButton? = alarm.isSnoozeEnabled ? .snoozeButton : nil
        let behavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = alarm.isSnoozeEnabled ? .countdown : nil
        
        let alertContent = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.label),
            stopButton: .stopButton,
            secondaryButton: secondaryBtn,
            secondaryButtonBehavior: behavior
        )
        
        var presentation = AlarmPresentation(alert: alertContent)
        
        if alarm.isSnoozeEnabled {
            let countdownContent = AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: alarm.label),
                                                               pauseButton: .stopButton)
            
//            let pausedContent = AlarmPresentation.Paused(title: "暂停", resumeButton: .resumeButton)
//            presentation = AlarmPresentation(alert: alertContent, countdown: countdownContent, paused: pausedContent)
            
            presentation = AlarmPresentation(alert: alertContent, countdown: countdownContent)
        }
        
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: AppAlarmMetadata(label: alarm.label, icon: iconForMode(alarm.repeatMode), alarmModelID: alarm.id.uuidString),
            tintColor: .blue
        )
        
        // 处理铃声格式
        let soundName = alarm.soundName
        let soundFileName = soundName.hasSuffix(".m4a") ? soundName : "\(soundName).m4a"
        let alertSound = AlertConfiguration.AlertSound.named(soundFileName)
        
        let timeInterval = TimeInterval(alarm.snoozeDuration * 60)
        let countdownDuration = alarm.isSnoozeEnabled ? Alarm.CountdownDuration.init(preAlert: nil, postAlert: timeInterval) : nil
        let finalSnoozeIntent = alarm.isSnoozeEnabled ? RepeatIntent(alarmID: childID.uuidString) : nil
        
        return MyAppAlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopIntent(alarmID: childID.uuidString, alarmModelID: alarm.id.uuidString),
            secondaryIntent: finalSnoozeIntent,
            sound: alertSound
        )
    }
    
    // 辅助：根据模式返回图标
    private func iconForMode(_ mode: AlarmRepeatMode) -> String {
        switch mode {
        case .once: return "alarm"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .yearly: return "birthday.cake"
        case .holiday: return "suitcase.fill" // 节假日用公文包表示工作/休假
        }
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
        
        Log.d("DEBUG: 单次闹钟设定 - 当前时间: \(now), 目标响铃: \(nextDate)")
        return nextDate
    }
    
    // MARK: - 处理用户点击“停止”后的业务逻辑：
    /// 1. 如果是单次闹钟 -> 关闭开关
    /// 2. 如果是重复闹钟 -> 检查是否需要补货
    @MainActor
    func handleStopAction(alarmModelID: UUID) async {
        do {
            // 1. 创建临时的 ModelContainer 来获取最新的数据状态
            // (这是为了在 Intent 可能的后台进程中安全读写)
            let schema = Schema([AlarmModel.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            
            // 2. 查找对应的 AlarmModel
            let descriptor = FetchDescriptor<AlarmModel>(predicate: #Predicate { $0.id == alarmModelID })
            
            if let alarm = try context.fetch(descriptor).first {
                
                Log.d("🛑 处理停止动作: \(alarm.label) (模式: \(alarm.repeatMode.rawValue))")
                
                if alarm.repeatMode == .once {
                    // --- Case A: 单次闹钟 ---
                    // 任务完成，关闭开关
                    alarm.isEnabled = false
                    
                    // 保存更改到数据库
                    try context.save()
                    Log.d("✅ 单次闹钟已自动关闭: \(alarm.label)")
                    
                } else {
                    // --- Case B: 重复/节假日闹钟 ---
                    await self.checkAndReplenish(alarmID: alarmModelID)
                }
            }
        } catch {
            Log.d("❌ 处理停止动作失败: \(error)")
        }
    }
    
    
    // MARK: - 检查并补货 (Check & Replenish)
    
    /// 检查特定闹钟的剩余预埋量，如果不足则补充
    /// 此方法是单纯的逻辑判断，不涉及 UI，可被 Intent 或 App 调用
    func checkAndReplenish(alarmID: UUID) async {
        Log.d("checkAndReplenish")
        
        // 1. 获取本地记录的“该闹钟产生的所有系统ID”
        let storedIDStrings = getSystemIDs(for: alarmID)
        
        Log.d("checkAndReplenish \(storedIDStrings)")
        // 如果本地都没记录了，说明要么是新建的，要么被清空了，直接视为0
        guard !storedIDStrings.isEmpty else { return }
        
        do {
            // 2. 获取系统当前真正存活的所有闹钟
            let activeSystemAlarms = try alarmManager.alarms
            
            // 转为 Set 提高查找性能
            let activeSystemIDs = Set(activeSystemAlarms.map { $0.id.uuidString })
            
            // 3. 计算交集：本地记录的 ID 中，还有多少个在系统中活着？
            let aliveCount = storedIDStrings.filter { activeSystemIDs.contains($0) }.count
            
            Log.d("🔍 闹钟 [UUID: \(alarmID)] 剩余存活数量: \(aliveCount)")
            
            // 4. 清理旧数据 (可选优化)：把已经死掉的 ID 从 UserDefaults 移除，防止列表无限膨胀
            let validIDs = storedIDStrings.filter { activeSystemIDs.contains($0) }
            if validIDs.count != storedIDStrings.count {
                UserDefaults.standard.set(validIDs, forKey: getStoreKey(for: alarmID))
            }
            
            // 5. 阈值判断：如果小于 5 个，且不是单次闹钟，则触发重新调度
            // 注意：这里我们需要访问 AlarmModel 来判断 repeatMode。
            // 由于 checkAndReplenish 可能在后台 Intent 调用，我们需要手动查库。
            if aliveCount < 5 {
                await replenishByRescheduling(alarmID: alarmID)
            }
            
        } catch {
            Log.d("❌ 获取系统闹钟列表失败: \(error)")
        }
    }
    
    // 内部私有方法：查库并重新调度
    @MainActor
    private func replenishByRescheduling(alarmID: UUID) async {
        // 创建临时的 ModelContainer 来查询数据 (确保线程安全)
        do {
            let schema = Schema([AlarmModel.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<AlarmModel>(predicate: #Predicate { $0.id == alarmID })
            
            if let alarm = try context.fetch(descriptor).first {
                // 只有非单次闹钟才需要补货
                if alarm.repeatMode != .once && alarm.repeatMode != .weekly {
                    Log.d("⚠️ 触发补货机制: \(alarm.label)")
                    
                    await self.reScheduleAlarm(alarm)
                                        
                    Log.d("🏁 补货任务彻底完成")
                }
            }
        } catch {
            Log.d("❌ 补货查询数据库失败: \(error)")
        }
    }
    
    
    // MARK: - ID 管理 (解决冲突的关键)
    
    private func getStoreKey(for alarmID: UUID) -> String {
        return "sys_ids_\(alarmID.uuidString)"
    }
    
    // 获取该闹钟关联的所有系统 ID 列表
    private func getSystemIDs(for alarmID: UUID) -> [String] {
        return UserDefaults.standard.stringArray(forKey: getStoreKey(for: alarmID)) ?? []
    }
    
    // 添加一个新的系统 ID 到列表
    private func appendSystemID(_ systemID: UUID, for alarmID: UUID) {
        var ids = getSystemIDs(for: alarmID)
        ids.append(systemID.uuidString)
        UserDefaults.standard.set(ids, forKey: getStoreKey(for: alarmID))
    }
    
    // 清空该闹钟的所有记录
    private func clearSystemIDs(for alarmID: UUID) {
        UserDefaults.standard.removeObject(forKey: getStoreKey(for: alarmID))
    }
    
    // MARK: - 清理逻辑
    @MainActor
    func deleteAlarm(_ alarm: AlarmModel) {
        Task { await cleanUpSystemAlarms(for: alarm) }
    }
    
    private func cleanUpSystemAlarms(for alarm: AlarmModel) async {
        // 1. 获取记录的所有系统 ID
        let ids = getSystemIDs(for: alarm.id)
        
        // 2. 遍历并取消系统通知
        for idStr in ids {
            if let uuid = UUID(uuidString: idStr) {
                do {
                    try alarmManager.cancel(id: uuid)
                    Log.d("🗑️ 已清理 ID: \(uuid)")
                } catch {
                    Log.d("🗑️ 清理 ID: \(uuid) error: \(error)")
                }
            }
        }
        
        // 3. 清空本地记录
        clearSystemIDs(for: alarm.id)
    }
}



