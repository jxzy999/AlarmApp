//
//  RingtoneSelectView.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import SwiftUI

struct RingtoneSelectView: View {
    @Binding var selectedSound: String // 双向绑定，回传给编辑页
    @State private var audioManager = AudioPlayerManager() // 页面独享播放器状态
    
    // 这里列出你必须要添加到 Xcode 项目中的文件名（不带后缀）
    let systemSounds = [
        "Alarm",
        "Apex",
        "Ascending",
        "Bark",
        "Beacon",
        "Bell Tower", // 默认
        "Blues",
        "Breaking-EncoreInfinitum",
        "Chimes",
    ]
    
    var body: some View {
        List {
            ForEach(systemSounds, id: \.self) { sound in
                HStack {
                    // 1. 播放/暂停按钮区域
                    Button {
                        audioManager.togglePreview(soundName: sound)
                    } label: {
                        Image(systemName: audioManager.playingSoundName == sound ? "pause.circle.fill" : "play.circle")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless) // 防止点击整行
                    
                    // 2. 铃声名字 + 点击选中逻辑
                    Button {
                        // 选中该铃声
                        selectedSound = sound
                        // 选中时同时也试听一下
                        audioManager.play(soundName: sound)
                    } label: {
                        HStack {
                            Text(sound)
                                .foregroundStyle(.primary)
                            Spacer()
                            // 选中标记
                            if selectedSound == sound {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    // 让整行除了播放按钮外，都是选中区域
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("选择铃声")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // 离开页面时停止播放
            audioManager.stop()
        }
    }
}
