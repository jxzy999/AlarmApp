//
//  ContentView.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import SwiftUI
import SwiftData


struct AlarmListView: View {
    @Environment(\.modelContext) var modelContext
    // 按时间排序
    @Query(sort: \AlarmModel.time) var alarms: [AlarmModel]
    
    @State private var showAddSheet = false
    @State private var selectedAlarm: AlarmModel?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if alarms.isEmpty {
                    ContentUnavailableView("无闹钟", systemImage: "alarm", description: Text("点击右上角 + 添加"))
                } else {
                    List {
                        ForEach(alarms) { alarm in
                            AlarmListCell(alarm: alarm)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        deleteAlarm(alarm)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .onTapGesture {
                                    selectedAlarm = alarm
                                }
                        }
                    }
                    .scrollContentBackground(.hidden) // 适配现代 iOS 风格
                }
            }
            .navigationTitle("闹钟")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $showAddSheet) {
                EditAlarmView()
            }
            .sheet(item: $selectedAlarm) { alarm in
                EditAlarmView(existingAlarm: alarm)
            }
        }
    }
    
    func deleteAlarm(_ alarm: AlarmModel) {
        // 调用 Service 清理系统闹钟
        AlarmService.shared.deleteAlarm(alarm)
        // 从数据库移除
        modelContext.delete(alarm)
        try? modelContext.save()
    }
}

// 抽离 Cell 组件，处理布局和图标
struct AlarmListCell: View {
    @Bindable var alarm: AlarmModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom) {
                    Text(alarm.timeString)
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                    
                    if !alarm.label.isEmpty && alarm.label != "闹钟" {
                        Text(alarm.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                }
                
                HStack(spacing: 4) {
                    // 根据重复模式显示小图标
                    Image(systemName: iconForMode(alarm.repeatMode))
                        .font(.caption2)
                    
                    Text(alarm.repeatDescription)
                        .font(.caption)
                }
                .foregroundStyle(alarm.isEnabled ? .secondary : .tertiary)
            }
            
            Spacer()
            
            Toggle("", isOn: $alarm.isEnabled)
                .labelsHidden()
                .onChange(of: alarm.isEnabled) {
                    // 开关切换时同步系统
                    AlarmService.shared.syncAlarmToSystem(alarm)
                }
        }
        .padding(.vertical, 8)
    }
    
    // 辅助：根据模式返回图标
    func iconForMode(_ mode: AlarmRepeatMode) -> String {
        switch mode {
        case .once: return "alarm"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .yearly: return "birthday.cake"
        case .holiday: return "suitcase.fill" // 节假日用公文包表示工作/休假
        }
    }
}



#Preview {
    AlarmListView()
        .modelContainer(for: AlarmModel.self, inMemory: true)
}
