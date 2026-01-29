// src/server/terminal/ControlModeParser.ts

import type { ControlModeEvent } from './ControlModeTypes'

/**
 * Line-based state machine that parses tmux control mode (-CC) output.
 * Reference: https://github.com/tmux/tmux/wiki/Control-Mode
 */
class ControlModeParser {
  private buffer = ''
  private activeCommand: { cmdNum: number; timestamp: number; lines: string[] } | null = null

  /**
   * Feed raw data from tmux. Returns parsed events.
   * Buffers partial lines until newline is received.
   *
   * When reading from a PTY, lines arrive with \r\n endings and may have
   * a DCS prefix (\x1bP1000p) on the first chunk. Both are stripped.
   */
  feed(chunk: string): ControlModeEvent[] {
    this.buffer += chunk

    // Strip DCS prefix from initial control mode handshake
    if (this.buffer.startsWith('\x1bP1000p')) {
      this.buffer = this.buffer.slice(7)
    }

    const events: ControlModeEvent[] = []

    let newlineIdx: number
    while ((newlineIdx = this.buffer.indexOf('\n')) !== -1) {
      let line = this.buffer.slice(0, newlineIdx)
      this.buffer = this.buffer.slice(newlineIdx + 1)
      // Strip trailing \r (PTY adds \r\n line endings)
      if (line.endsWith('\r')) {
        line = line.slice(0, -1)
      }
      const lineEvents = this.parseLine(line)
      events.push(...lineEvents)
    }
    return events
  }

  private parseLine(line: string): ControlModeEvent[] {
    // If inside a command response, check for %end/%error first
    if (this.activeCommand) {
      // %end <timestamp> <cmdnum> <flags>
      const endMatch = line.match(/^%end (\d+) (\d+) (\d+)$/)
      if (endMatch) {
        this.activeCommand = null
        return [{ type: 'command-end', cmdNum: parseInt(endMatch[2], 10), success: true }]
      }

      // %error <timestamp> <cmdnum> <flags>
      const errorMatch = line.match(/^%error (\d+) (\d+) (\d+)$/)
      if (errorMatch) {
        this.activeCommand = null
        return [{ type: 'command-end', cmdNum: parseInt(errorMatch[2], 10), success: false }]
      }

      // Notifications (% prefix) can arrive between %begin and %end —
      // fall through to parse them normally instead of swallowing them
      if (!line.startsWith('%')) {
        // Accumulate non-notification command output
        return [{ type: 'command-output', cmdNum: this.activeCommand.cmdNum, line }]
      }
    }

    // %output %<pane> <data>
    const outputMatch = line.match(/^%output %(\d+) (.*)$/)
    if (outputMatch) {
      return [{ type: 'output', paneId: outputMatch[1], data: this.decodeOctalEscapes(outputMatch[2]) }]
    }

    // %extended-output %<pane> <ms> : <data>
    const extOutputMatch = line.match(/^%extended-output %(\d+) (\d+) : (.*)$/)
    if (extOutputMatch) {
      return [{
        type: 'output',
        paneId: extOutputMatch[1],
        latencyMs: parseInt(extOutputMatch[2], 10),
        data: this.decodeOctalEscapes(extOutputMatch[3])
      }]
    }

    // %begin <timestamp> <cmdnum> <flags>
    const beginMatch = line.match(/^%begin (\d+) (\d+) (\d+)$/)
    if (beginMatch) {
      this.activeCommand = {
        cmdNum: parseInt(beginMatch[2], 10),
        timestamp: parseInt(beginMatch[1], 10),
        lines: []
      }
      return [{
        type: 'command-start',
        cmdNum: this.activeCommand.cmdNum,
        timestamp: this.activeCommand.timestamp,
        flags: parseInt(beginMatch[3], 10)
      }]
    }

    // %end <timestamp> <cmdnum> <flags> (outside command context)
    const endMatch = line.match(/^%end (\d+) (\d+) (\d+)$/)
    if (endMatch) {
      return [{ type: 'command-end', cmdNum: parseInt(endMatch[2], 10), success: true }]
    }

    // %error <timestamp> <cmdnum> <flags> (outside command context)
    const errorMatch = line.match(/^%error (\d+) (\d+) (\d+)$/)
    if (errorMatch) {
      return [{ type: 'command-end', cmdNum: parseInt(errorMatch[2], 10), success: false }]
    }

    // %window-add @<window>
    const windowAddMatch = line.match(/^%window-add @(\d+)$/)
    if (windowAddMatch) {
      return [{ type: 'window-add', windowId: windowAddMatch[1] }]
    }

    // %window-close @<window>
    const windowCloseMatch = line.match(/^%window-close @(\d+)$/)
    if (windowCloseMatch) {
      return [{ type: 'window-close', windowId: windowCloseMatch[1] }]
    }

    // %window-renamed @<window> <name>
    const windowRenamedMatch = line.match(/^%window-renamed @(\d+) (.*)$/)
    if (windowRenamedMatch) {
      return [{ type: 'window-renamed', windowId: windowRenamedMatch[1], name: windowRenamedMatch[2] }]
    }

    // %session-changed $<session> <name>
    const sessionChangedMatch = line.match(/^%session-changed \$(\d+) (.*)$/)
    if (sessionChangedMatch) {
      return [{ type: 'session-changed', sessionId: sessionChangedMatch[1], name: sessionChangedMatch[2] }]
    }

    // %pause %<pane>
    const pauseMatch = line.match(/^%pause %(\d+)$/)
    if (pauseMatch) {
      return [{ type: 'pause', paneId: pauseMatch[1] }]
    }

    // %continue %<pane>
    const continueMatch = line.match(/^%continue %(\d+)$/)
    if (continueMatch) {
      return [{ type: 'continue', paneId: continueMatch[1] }]
    }

    // %exit [reason]
    if (line.startsWith('%exit')) {
      const reason = line.slice(5).trim() || undefined
      return [{ type: 'exit', reason }]
    }

    // Unknown message, ignore
    return []
  }

  /**
   * Decode tmux octal escapes: \NNN -> character
   * Characters < ASCII 32 and \ are encoded as \NNN (3-digit octal)
   */
  private decodeOctalEscapes(data: string): string {
    return data.replace(/\\([0-7]{3})/g, (_, octal) =>
      String.fromCharCode(parseInt(octal, 8))
    )
  }
}

export { ControlModeParser }
