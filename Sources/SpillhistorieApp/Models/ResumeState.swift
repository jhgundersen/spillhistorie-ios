import Foundation

struct ResumeState: Codable {
    let audioURL: URL
    let title: String
    let series: String
    let durationSeconds: Double
    let positionSeconds: Double

    // Mirror TUI thresholds: only resume if pos > 10s and not near end
    var isResumable: Bool {
        positionSeconds > 10 && (durationSeconds <= 0 || positionSeconds < durationSeconds - 30)
    }
}
