import Foundation

enum AppConstants {
    static let maxActivities = 30
    static let maxNameLength = 30
    static let maxCategoryLength = 20

    /// How many days back the Add Time Entry sheet allows
    static let addTimeEntryLookbackDays = 7
    /// Rolling window (days) shown in the Edit Time Entry sheet
    static let editTimeEntryWindowDays = 7
    /// Max rows shown in the Edit Time Entry entry list
    static let editTimeEntryMaxRows = 5
    /// Rolling window (days) used for activity-detail consistency / goal metrics
    static let activityStatsWindowDays = 30
}
