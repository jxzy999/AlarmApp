//
//  WorkdayCalculator.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import Foundation

struct WorkdayCalculator {
    // 判断指定日期是否需要响铃
    static func isChineseWorkday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1=Sun, 7=Sat
        
        // 格式化为 yyyy-MM-dd 以便查表
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // 强制使用公历，防止用户日历设置影响
        formatter.calendar = Calendar(identifier: .gregorian)
        let dateString = formatter.string(from: date)
        
        // 获取单例服务
        let service = HolidayService.shared
        
        // 1. 优先级最高：调休补班 (虽然是周末，但要上班) -> 响铃
        if service.makeUpWorkdays.contains(dateString) {
            return true
        }
        
        // 2. 优先级次之：法定节假日 (虽然是周一到周五，但放假) -> 不响
        if service.holidays.contains(dateString) {
            return false
        }
        
        // 3. 兜底逻辑：普通周一到周五响，周末不响
        if weekday == 1 || weekday == 7 {
            return false
        }
        
        return true
    }
}
