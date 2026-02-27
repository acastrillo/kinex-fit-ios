import Foundation
import GRDB

struct DatabaseMigratorFactory {
    func migrate(_ dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("create-v1") { db in
            try db.create(table: "users") { table in
                table.column("id", .text).primaryKey()
                table.column("email", .text)
                table.column("firstName", .text)
                table.column("lastName", .text)
                table.column("tier", .text)
                table.column("subscriptionStatus", .text)
                table.column("scanQuotaUsed", .integer).notNull().defaults(to: 0)
                table.column("aiQuotaUsed", .integer).notNull().defaults(to: 0)
                table.column("onboardingCompleted", .boolean).notNull().defaults(to: false)
                table.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "workouts") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("content", .text)
                table.column("source", .text)
                table.column("durationMinutes", .integer)
                table.column("exerciseCount", .integer)
                table.column("difficulty", .text)
                table.column("imageURL", .text)
                table.column("createdAt", .datetime).notNull()
                table.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "body_metrics") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("date", .datetime).notNull()
                table.column("weight", .double)
                table.column("notes", .text)
                table.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "sync_queue") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("entity", .text).notNull()
                table.column("operation", .text).notNull()
                table.column("payload", .text)
                table.column("createdAt", .datetime).notNull()
                table.column("retryCount", .integer).notNull().defaults(to: 0)
                table.column("lastError", .text)
                table.column("nextAttemptAt", .datetime)
            }

            try db.create(table: "settings") { table in
                table.column("key", .text).primaryKey()
                table.column("value", .text)
            }
        }

        migrator.registerMigration("add-subscriptionExpiresAt") { db in
            try db.alter(table: "users") { table in
                table.add(column: "subscriptionExpiresAt", .datetime)
            }
        }

        migrator.registerMigration("add-workout-card-metadata") { db in
            let existingColumns = Set(try db.columns(in: "workouts").map(\.name))
            let missingColumns = [
                "durationMinutes",
                "exerciseCount",
                "difficulty",
                "imageURL"
            ].filter { !existingColumns.contains($0) }

            guard !missingColumns.isEmpty else { return }

            try db.alter(table: "workouts") { table in
                if missingColumns.contains("durationMinutes") {
                    table.add(column: "durationMinutes", .integer)
                }
                if missingColumns.contains("exerciseCount") {
                    table.add(column: "exerciseCount", .integer)
                }
                if missingColumns.contains("difficulty") {
                    table.add(column: "difficulty", .text)
                }
                if missingColumns.contains("imageURL") {
                    table.add(column: "imageURL", .text)
                }
            }
        }

        migrator.registerMigration("add-workout-source-metadata") { db in
            try db.alter(table: "workouts") { table in
                table.add(column: "sourceURL", .text)
                table.add(column: "sourceAuthor", .text)
            }
        }

        migrator.registerMigration("add-workout-enhancement-source-text") { db in
            try db.alter(table: "workouts") { table in
                table.add(column: "enhancementSourceText", .text)
            }
        }

        migrator.registerMigration("add-quota-limit-columns") { db in
            try db.alter(table: "users") { table in
                table.add(column: "scanQuotaLimit", .integer)
                table.add(column: "aiQuotaLimit", .integer)
            }
        }

        try migrator.migrate(dbQueue)
    }
}
