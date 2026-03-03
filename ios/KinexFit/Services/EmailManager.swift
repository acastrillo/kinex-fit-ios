import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "Email")

/// Manages email functionality (weekly summaries, reports)
@MainActor
final class EmailManager {
    static let shared = EmailManager()

    private let apiClient: APIClient

    init(apiClient: APIClient = AppState.shared?.environment.apiClient ?? .preview) {
        self.apiClient = apiClient
    }

    // MARK: - Weekly Summary

    struct WeeklySummary: Codable {
        let period: String  // "2026-02-26 to 2026-03-04"
        let workouts: Int
        let volume: Int  // total reps
        let duration: Int  // minutes
        let topExercise: String
        let newPRs: Int
        let bodyMetricsChange: BodyMetricsChange
        let consistencyScore: Double  // 0-100

        struct BodyMetricsChange: Codable {
            let weight: Double?
            let unit: String
            let change: String  // "↓ 1.5 lbs"
        }
    }

    /// Fetch weekly summary from backend
    func fetchWeeklySummary() async throws -> WeeklySummary {
        let request = APIRequest(
            method: .get,
            path: "/api/user/summary/weekly",
            query: ["format": "json"]
        )

        let response: WeeklySummary = try await apiClient.send(request)
        logger.info("Fetched weekly summary")
        return response
    }

    /// Generate HTML email template
    func generateWeeklySummaryHTML(_ summary: WeeklySummary) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 12px; text-align: center; }
                .header h1 { margin: 0; font-size: 28px; }
                .header p { margin: 10px 0 0 0; opacity: 0.9; }
                .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }
                .stat-card { background: #f5f5f5; padding: 15px; border-radius: 8px; }
                .stat-value { font-size: 24px; font-weight: bold; color: #667eea; }
                .stat-label { font-size: 12px; color: #666; margin-top: 5px; }
                .highlight { background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107; }
                .footer { text-align: center; color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; }
                .cta { background: #667eea; color: white; padding: 12px 30px; border-radius: 6px; text-decoration: none; display: inline-block; margin: 20px 0; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Your Weekly Workout Summary</h1>
                    <p>\(summary.period)</p>
                </div>

                <div class="stats">
                    <div class="stat-card">
                        <div class="stat-value">\(summary.workouts)</div>
                        <div class="stat-label">Workouts Completed</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">\(summary.duration)</div>
                        <div class="stat-label">Minutes Trained</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">\(summary.volume)</div>
                        <div class="stat-label">Total Reps</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">\(Int(summary.consistencyScore))</div>
                        <div class="stat-label">Consistency %</div>
                    </div>
                </div>

                <div class="highlight">
                    <strong>🏆 Top Exercise This Week</strong><br>
                    \(summary.topExercise)
                </div>

                <div class="highlight">
                    <strong>💪 Personal Records</strong><br>
                    \(summary.newPRs) new personal records achieved!
                </div>

                \(generateBodyMetricsHTML(summary.bodyMetricsChange))

                <center>
                    <a href="https://kinexfit.com/app" class="cta">View Full Report</a>
                </center>

                <div class="footer">
                    <p>Keep crushing your fitness goals! 🚀</p>
                    <p><a href="https://kinexfit.com/preferences/emails" style="color: #667eea; text-decoration: none;">Manage email preferences</a></p>
                </div>
            </div>
        </body>
        </html>
        """
    }

    private func generateBodyMetricsHTML(_ change: WeeklySummary.BodyMetricsChange) -> String {
        guard let weight = change.weight else { return "" }

        let changeSymbol = weight < 0 ? "📉" : "📈"
        return """
        <div class="highlight">
            <strong>\(changeSymbol) Body Metrics</strong><br>
            Weight: \(change.change)
        </div>
        """
    }

    /// Send weekly summary email
    func sendWeeklySummaryEmail(to email: String) async throws {
        let summary = try await fetchWeeklySummary()
        let html = generateWeeklySummaryHTML(summary)

        struct EmailRequest: Encodable {
            let to: String
            let subject: String
            let htmlBody: String
            let type: String

            enum CodingKeys: String, CodingKey {
                case to
                case subject
                case htmlBody = "html_body"
                case type
            }
        }

        let request = try APIRequest.json(
            path: "/api/notifications/email",
            method: .post,
            body: EmailRequest(
                to: email,
                subject: "Your Weekly Workout Summary 🏋️",
                htmlBody: html,
                type: "weekly_summary"
            )
        )

        _ = try await apiClient.send(request)
        logger.info("Weekly summary email sent to \(email)")
    }
}
