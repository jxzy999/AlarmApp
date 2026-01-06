//
//  Log.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import Foundation
import OSLog

/// 简易日志工具，用于替换 print
enum Log {
    // MARK: - 配置区域
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.AlarmApp"
    
    // 定义分类
    static let general = Logger(subsystem: subsystem, category: "General")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let database = Logger(subsystem: subsystem, category: "Database")
    static let alarm = Logger(subsystem: subsystem, category: "AlarmLogic")
    
    // MARK: - 通用打印方法
    
    /// 🛠 调试 (Debug)
    static func d(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let msgStr = String(describing: message)
        // 注意这里：所有变量都加了 privacy: .public
        general.debug("🛠 [DEBUG] \(fileName, privacy: .public):\(line) - \(function, privacy: .public) -> \(msgStr, privacy: .public)")
    }
    
    /// ℹ️ 信息 (Info)
    static func i(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let msgStr = String(describing: message)
        general.info("ℹ️ [INFO] \(fileName, privacy: .public):\(line) - \(function, privacy: .public) -> \(msgStr, privacy: .public)")
    }
    
    /// ⚠️ 警告 (Warning)
    static func w(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let msgStr = String(describing: message)
        general.warning("⚠️ [WARN] \(fileName, privacy: .public):\(line) - \(function, privacy: .public) -> \(msgStr, privacy: .public)")
    }
    
    /// 🔴 错误 (Error)
    static func e(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let msgStr = String(describing: message)
        general.error("🔴 [ERROR] \(fileName, privacy: .public):\(line) - \(function, privacy: .public) -> \(msgStr, privacy: .public)")
    }
    
    // MARK: - 特定模块快捷方法
    
    static func alarm(_ message: String) {
        // 这里也要加 privacy: .public
        alarm.notice("⏰ \(message, privacy: .public)")
    }
    
    static func db(_ message: String) {
        database.notice("💾 \(message, privacy: .public)")
    }
}
