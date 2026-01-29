// Agentboard/Core/FlowController.swift
import Foundation

/// Manages tmux control mode flow control.
/// Sends pause/resume commands to the server to prevent overwhelming the client.
class FlowController {
    private let sendMessage: (String, String, String) -> Void // sessionId, paneId, action
    private var isPaused = false
    private var pendingBytes: Int = 0
    private let pauseThreshold: Int = 64 * 1024  // 64KB
    private let resumeThreshold: Int = 16 * 1024  // 16KB

    init(sendMessage: @escaping (String, String, String) -> Void) {
        self.sendMessage = sendMessage
    }

    /// Track incoming data volume. Pause if we're getting too far behind.
    func trackIncoming(sessionId: String, paneId: String, byteCount: Int) {
        pendingBytes += byteCount
        if !isPaused && pendingBytes > pauseThreshold {
            isPaused = true
            sendMessage(sessionId, paneId, "pause")
        }
    }

    /// Mark data as consumed (rendered). Resume if we've caught up.
    func trackConsumed(sessionId: String, paneId: String, byteCount: Int) {
        pendingBytes = max(0, pendingBytes - byteCount)
        if isPaused && pendingBytes < resumeThreshold {
            isPaused = false
            sendMessage(sessionId, paneId, "resume")
        }
    }

    func reset() {
        isPaused = false
        pendingBytes = 0
    }
}
