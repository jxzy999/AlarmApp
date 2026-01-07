//
//  AlarmAppApp.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import SwiftUI
import SwiftData

@main
struct AlarmAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AlarmModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            AlarmListView()
                .task {
                    // 1. 获取节假日数据
                    await HolidayService.shared.fetchHolidayData()
                    
                    // 2. [新增] 启动时检查所有闹钟健康度
                    await checkAllAlarms()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    
    @MainActor
    func checkAllAlarms() async {
        let context = sharedModelContainer.mainContext
        do {
            // 查询所有已启用的闹钟
            let descriptor = FetchDescriptor<AlarmModel>(
                predicate: #Predicate { $0.isEnabled == true }
            )
            let enabledAlarms = try context.fetch(descriptor)
            
            // 遍历检查每一个
            for alarm in enabledAlarms {
                await AlarmService.shared.checkAndReplenish(alarmID: alarm.id)
            }
            
        } catch {
            print("启动检查失败: \(error)")
        }
    }
}
