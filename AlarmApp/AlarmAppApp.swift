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
                    // 启动时异步更新节假日数据
                    // 这不会阻塞 UI，下载完成后下次计算会自动生效
                    await HolidayService.shared.fetchHolidayData()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
