//
//  Item.swift
//  TokenTestiOS
//
//  Created by Josh Lister on 10/04/2025.
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
