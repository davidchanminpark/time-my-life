//
//  ScheduledDay.swift
//  TimeMyLifeApp
//
//  Represents a scheduled day for an activity
//  Created as a separate model to avoid SwiftData reflection metadata issues
//  when using predicates with array.contains() operations

import Foundation
import SwiftData

/// Represents a scheduled weekday for an activity
@Model
public final class ScheduledDay {
    /// Weekday integer (1=Sunday, 2=Monday, ..., 7=Saturday)
    public var weekday: Int
    
    /// Reference to the parent activity (SwiftData relationship)
    public var activity: Activity?
    
    public init(weekday: Int, activity: Activity? = nil) {
        self.weekday = weekday
        self.activity = activity
    }
}

