//
//  Item.swift
//  AlarmApp
//
//  Created by true on 2026/1/6.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
