// Agentboard/Core/OutputBuffer.swift
import Foundation

/// Buffers rapid terminal output and flushes at a controlled rate.
/// Inspired by Happy's activityUpdateAccumulator.
@Observable
class OutputBuffer {
    private var buffer: String = ""
    private var flushTimer: Timer?
    private let flushInterval: TimeInterval
    private let onFlush: (String) -> Void

    /// Whether output is currently being buffered (flow is active)
    private(set) var isBuffering = false

    init(fps: Double = 60, onFlush: @escaping (String) -> Void) {
        self.flushInterval = 1.0 / fps
        self.onFlush = onFlush
    }

    /// Append data to the buffer. Starts the flush timer if not running.
    func append(_ data: String) {
        buffer += data
        isBuffering = true
        startTimerIfNeeded()
    }

    /// Force an immediate flush (e.g. on user input for responsiveness).
    func flushNow() {
        guard !buffer.isEmpty else { return }
        let data = buffer
        buffer = ""
        isBuffering = false
        onFlush(data)
    }

    /// Stop buffering and flush remaining content.
    func stop() {
        flushTimer?.invalidate()
        flushTimer = nil
        flushNow()
    }

    private func startTimerIfNeeded() {
        guard flushTimer == nil else { return }
        flushTimer = Timer.scheduledTimer(
            withTimeInterval: flushInterval,
            repeats: true
        ) { [weak self] _ in
            self?.timerFired()
        }
    }

    private func timerFired() {
        if buffer.isEmpty {
            flushTimer?.invalidate()
            flushTimer = nil
            isBuffering = false
        } else {
            flushNow()
        }
    }

    deinit {
        flushTimer?.invalidate()
    }
}
