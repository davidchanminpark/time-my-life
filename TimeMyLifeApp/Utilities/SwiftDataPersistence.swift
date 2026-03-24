//
//  SwiftDataPersistence.swift
//  TimeMyLifeApp
//

import SwiftData

/// Central place for SwiftData store configuration.
/// `loadIssueModelContainer` usually means the on-disk store was created with an older, incompatible schema.
/// **Bump `persistentStoreName`** when you change models (e.g. new `@Model`, relationships) so the app uses a new store file instead of failing to migrate.
public enum SwiftDataAppConfiguration {
    /// Versioned store name — change (e.g. v3 → v4) after schema-breaking model changes.
    public static let persistentStoreName = "TimeMyLifeApp_v3"

    public static func makeModelContainer(schema: Schema) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            persistentStoreName,
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
