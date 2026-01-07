//
//  AudioPlayerManager.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import Foundation
import AVFoundation

@Observable
class AudioPlayerManager {
    // 单例
    static let shared = AudioPlayerManager()
    
    var playingSoundName: String? = nil // 当前正在播放的铃声名
    private var audioPlayer: AVAudioPlayer?
    
    // 播放或暂停
    func togglePreview(soundName: String) {
        // 1. 如果点击的是当前正在播放的，则停止
        if playingSoundName == soundName {
            stop()
            return
        }
        
        // 2. 播放新的
        play(soundName: soundName)
    }
    
    func play(soundName: String) {
        // 先停止旧的
        stop()
        
        // 尝试查找文件 (m4a)
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "m4a") else {
            Log.d("找不到音频文件: \(soundName)")
            return
        }
        
        do {
            // 设置音频会话，确保静音模式下也能播放(可选)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            playingSoundName = soundName
            Log.d("正在试听: \(soundName)")
        } catch {
            Log.d("播放失败: \(error)")
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        playingSoundName = nil
    }
}
