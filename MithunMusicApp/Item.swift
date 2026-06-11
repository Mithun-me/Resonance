//
//  Item.swift
//  MithunMusicApp
//
//  Created by Mithun Samy on 11/06/26.
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
