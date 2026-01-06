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
                
                print("✅ 成功下载 \(year) 年节假日配置")
                
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
                print("⚠️ 获取 \(year) 年数据失败 (可能是还没发布): \(error.localizedDescription)")
            }
        }
        
        // 更新内存和本地存储
        await MainActor.run {
            self.holidays = tempHolidays
            self.makeUpWorkdays = tempMakeups
            UserDefaults.standard.set(Array(tempHolidays), forKey: kHolidaysKey)
            UserDefaults.standard.set(Array(tempMakeups), forKey: kMakeupsKey)
        }
    }
}
