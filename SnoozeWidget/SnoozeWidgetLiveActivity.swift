//
//  SnoozeWidgetLiveActivity.swift
//  SnoozeWidget
//
//  Created by true on 2026/1/6.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import AlarmKit


struct SnoozeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
            ActivityConfiguration(for: SnoozeWidgetAttributes.self) { context in
                // --- 锁屏界面 UI ---
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "zzzz")
                                .foregroundStyle(.orange)
                            Text("稍后提醒: \(context.attributes.label)")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        
                        // 倒计时核心组件
                        Text(timerInterval: Date()...context.state.fireDate, countsDown: true)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // 取消按钮
                    Button(intent: CancelSnoozeIntent(alarmID: context.attributes.alarmID)) {
                        Text("取消")
                            .font(.callout.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray.opacity(0.5))
                    .clipShape(Capsule())
                }
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.orange)
                
            } dynamicIsland: { context in
                // --- 灵动岛 UI (可选) ---
                DynamicIsland {
                    // 展开区域
                    DynamicIslandExpandedRegion(.leading) {
                        Label("稍后", systemImage: "zzzz").font(.caption).foregroundStyle(.orange)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Text(timerInterval: Date()...context.state.fireDate, countsDown: true)
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                         // 岛内也放一个取消按钮
                         Button(intent: CancelSnoozeIntent(alarmID: context.attributes.alarmID)) {
                             Text("取消小睡").frame(maxWidth: .infinity)
                         }
                         .buttonStyle(.bordered)
                         .tint(.white)
                    }
                } compactLeading: {
                    Image(systemName: "zzzz").foregroundStyle(.orange)
                } compactTrailing: {
                    Text(timerInterval: Date()...context.state.fireDate, countsDown: true)
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                        .font(.caption)
                } minimal: {
                    Image(systemName: "zzzz").foregroundStyle(.orange)
                }
            }
        }
}

