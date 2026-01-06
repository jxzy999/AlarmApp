//
//  WorkdayCalculator.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import Foundation

struct WorkdayCalculator {
    // 判断指定日期是否需要响铃（中国法定工作日逻辑）
    static func isChineseWorkday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1=Sun, 7=Sat
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        // --- 配置区域 (实际开发请从网络获取并缓存) ---
        
        // 1. 法定节假日 (放假不响)
        let holidays = [
            "2026-01-01", // 元旦
            "2026-02-16", "2026-02-17" // 模拟春节
        ]
        
        // 2. 调休补班 (周末要响)
        let makeUpWorkdays = [
            "2026-02-08" // 假设这天周日上班
        ]
        
        // ----------------------------------------
        
        if holidays.contains(dateString) { return false } // 节假日：不响
        if makeUpWorkdays.contains(dateString) { return true } // 补班：响
        
        // 普通逻辑：周一到周五响，周末不响
        if weekday == 1 || weekday == 7 { return false }
        
        return true
    }
}
