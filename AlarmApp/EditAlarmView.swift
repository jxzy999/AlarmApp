//
//  EditAlarmView.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import SwiftUI
import SwiftData


struct EditAlarmView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    var existingAlarm: AlarmModel?
    
    // --- 状态 ---
    @State private var time: Date = Date()
    @State private var label: String = "闹钟"
    @State private var soundName: String = "Bell Tower"
    
    // 重复模式状态
    @State private var repeatMode: AlarmRepeatMode = .once
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedMonthDays: Set<Int> = []
    @State private var selectedYearDate: Date = Date()
    
    // 小睡状态
    @State private var isSnoozeEnabled: Bool = true
    @State private var snoozeDuration: Int = 5
    
    // 常量
    let weekDaysOrdered = [2, 3, 4, 5, 6, 7, 1]
    let weekDaySymbols = ["一", "二", "三", "四", "五", "六", "日"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                List {
                    // 1. 时间选择 (修复居中问题)
                    Section {
                        HStack {
                            Spacer()
                            DatePicker("时间", selection: $time, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(width: 320) // 给定一个合理的宽度使其看起来居中
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    // 2. 重复模式板块
                    Section {
                        Picker("重复频率", selection: $repeatMode) {
                            ForEach(AlarmRepeatMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        
                        // 动态内容区
                        repeatContent
                    } header: {
                        Text("重复设置")
                    }
                    
                    // 3. 详细设置
                    Section {
                        HStack {
                            Text("标签")
                            Spacer()
                            TextField("闹钟", text: $label).multilineTextAlignment(.trailing)
                        }
                        
                        // --- 修改开始 ---
                        NavigationLink {
                            RingtoneSelectView(selectedSound: $soundName)
                        } label: {
                            HStack {
                                Text("铃声")
                                Spacer()
                                Text(soundName)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Toggle("稍后提醒", isOn: $isSnoozeEnabled)
                        
                        if isSnoozeEnabled {
                            HStack {
                                Text("间隔时长")
                                Spacer()
                                Picker("", selection: $snoozeDuration) {
                                    ForEach(1...10, id: \.self) { min in
                                        Text("\(min) 分钟").tag(min)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 100)
                                .frame(width: 150)
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingAlarm == nil ? "添加闹钟" : "编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { saveAlarm() } }
            }
            // 修复回显：使用 task 确保视图加载前数据已准备好
            .task {
                loadData()
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    var repeatContent: some View {
        switch repeatMode {
        case .once:
            EmptyView()
            
        case .weekly:
            // 修复点选问题：添加 .buttonStyle(.borderless)
            HStack(spacing: 0) {
                ForEach(Array(weekDaysOrdered.enumerated()), id: \.offset) { index, dayRawValue in
                    let isSelected = selectedWeekdays.contains(dayRawValue)
                    Button {
                        if isSelected { selectedWeekdays.remove(dayRawValue) }
                        else { selectedWeekdays.insert(dayRawValue) }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color(uiColor: .tertiarySystemFill))
                            Text(weekDaySymbols[index])
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 44)
                    .buttonStyle(.borderless) // <--- 关键修复：防止 List 点击冲突
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            
        case .monthly:
            // 修复点选问题：添加 .buttonStyle(.borderless)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(1...31, id: \.self) { day in
                    let isSelected = selectedMonthDays.contains(day)
                    Button {
                        if isSelected { selectedMonthDays.remove(day) }
                        else { selectedMonthDays.insert(day) }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color.clear)
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: isSelected ? 0 : 1))
                            Text("\(day)")
                                .font(.system(size: 12))
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .frame(height: 30)
                    }
                    .buttonStyle(.borderless) // <--- 关键修复
                }
            }
            .padding(.vertical, 8)
            
        case .yearly:
            DatePicker("选择日期", selection: $selectedYearDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
            
        case .holiday:
            Text("智能跳过法定节假日，包含调休补班")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Logic
    
    func loadData() {
        if let alarm = existingAlarm {
            // 确保所有字段都从 existingAlarm 同步到 State
            time = alarm.time
            label = alarm.label
            repeatMode = alarm.repeatMode
            
            // 集合类型转换
            selectedWeekdays = Set(alarm.repeatDays)
            selectedMonthDays = Set(alarm.repeatMonthDays)
            
            selectedYearDate = alarm.repeatYearDate
            isSnoozeEnabled = alarm.isSnoozeEnabled
            snoozeDuration = alarm.snoozeDuration
        } else {
            // 如果是新增，初始化一些默认值
            time = Date()
            // 将秒数归零，防止初始时间带有秒数
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: time)
            time = calendar.date(from: components) ?? Date()
        }
    }
    
    func saveAlarm() {
        let alarmToSave = existingAlarm ?? AlarmModel(time: time)
        
        // 保存时截断秒数，确保时间是整分
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let cleanTime = calendar.date(from: comps) ?? time
        
        alarmToSave.time = cleanTime
        alarmToSave.label = label
        alarmToSave.repeatMode = repeatMode
        alarmToSave.repeatDays = Array(selectedWeekdays)
        alarmToSave.repeatMonthDays = Array(selectedMonthDays)
        alarmToSave.repeatYearDate = selectedYearDate
        alarmToSave.isSnoozeEnabled = isSnoozeEnabled
        alarmToSave.snoozeDuration = snoozeDuration
        alarmToSave.isEnabled = true
        
        if existingAlarm == nil {
            modelContext.insert(alarmToSave)
        }
        
        // 强制保存 Context，确保 Service 读取到最新数据（虽然 Service 直接用对象，但是个好习惯）
        try? modelContext.save()
        
        AlarmService.shared.syncAlarmToSystem(alarmToSave)
        dismiss()
    }
}
