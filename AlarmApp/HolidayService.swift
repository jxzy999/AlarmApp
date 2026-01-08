//
//  HolidayService.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import Foundation

// 1. 对应 holiday-cn 的 JSON 结构
struct HolidayDay: Codable {
    let name: String
    let date: String // 格式 "yyyy-MM-dd"
    let isOffDay: Bool  // true = 放假, false = 调休上班
}

struct HolidayYearConfig: Codable {
    let year: Int
    let days: [HolidayDay]
}

// 2. 假日服务管理类
@Observable
class HolidayService {
    static let shared = HolidayService()
    
    // 缓存 key
    private let kHolidaysKey = "cached_holidays_set"
    private let kMakeupsKey = "cached_makeups_set"
    
    // 内存缓存 (加速读取)
    var holidays: Set<String> = []
    var makeUpWorkdays: Set<String> = []
    
    init() {
        loadFromCache()
    }
    
    // 从本地加载缓存
    private func loadFromCache() {
        let defaults = UserDefaults.standard
        if let hList = defaults.stringArray(forKey: kHolidaysKey) {
            holidays = Set(hList)
        }
        if let mList = defaults.stringArray(forKey: kMakeupsKey) {
            makeUpWorkdays = Set(mList)
        }
    }
    
    // 核心：从网络更新数据
    // 我们通常下载当年和下一年的数据
    func fetchHolidayData() async {
        let currentYear = Calendar.current.component(.year, from: Date())
        let years = [currentYear - 1, currentYear, currentYear + 1] // 下载去年、今年和明年
        
        var tempHolidays = self.holidays
        var tempMakeups = self.makeUpWorkdays
        
        for year in years {
            
            //let urlString = "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json"
            let urlString = "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json"
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let config = try JSONDecoder().decode(HolidayYearConfig.self, from: data)
                
                Log.d("✅ 成功下载 \(year) 年节假日配置")
                
                // 解析数据
                for day in config.days {
                    if day.isOffDay {
                        tempHolidays.insert(day.date)
                        // 如果某天变成了放假，确保它不在补班列表里
                        tempMakeups.remove(day.date)
                    } else {
                        tempMakeups.insert(day.date)
                        // 如果某天变成了补班，确保它不在放假列表里
                        tempHolidays.remove(day.date)
                    }
                }
            } catch {
                Log.d("⚠️ 获取 \(year) 年数据失败 (可能是还没发布): \(error.localizedDescription)")
            }
        }
        
        // 在进入 MainActor 之前，创建不可变的副本 (Freeze the state)
        // 防止并发环境下 var 变量被修改的风险
        let finalHolidays = tempHolidays
        let finalMakeups = tempMakeups
        
        // 更新内存和本地存储
        await MainActor.run {
            self.holidays = finalHolidays
            self.makeUpWorkdays = finalMakeups
            UserDefaults.standard.set(Array(finalHolidays), forKey: kHolidaysKey)
            UserDefaults.standard.set(Array(finalMakeups), forKey: kMakeupsKey)
        }
    }
    
    
    /// 检查指定年份是否有数据缓存
    /// 注意：访问 holidays 属性会建立 SwiftUI 的依赖追踪，当数据更新时 View 会刷新
    func hasData(for year: Int) -> Bool {
        let yearPrefix = "\(year)-"
        // 只要假期列表或补班列表中包含该年份前缀的数据，就视为有数据
        // 使用 lazy 避免遍历整个集合，找到一个即停止
        let hasHoliday = holidays.contains { $0.hasPrefix(yearPrefix) }
        if hasHoliday { return true }
        
        let hasMakeup = makeUpWorkdays.contains { $0.hasPrefix(yearPrefix) }
        return hasMakeup
    }
}
