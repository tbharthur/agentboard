// src/server/terminal/ControlModeTypes.ts

/**
 * Events emitted by ControlModeParser when parsing tmux control mode output.
 * These are internal server-side types, not sent over WebSocket directly.
 */
type ControlModeEvent =
  | { type: 'output'; paneId: string; data: string; latencyMs?: number }
  | { type: 'command-start'; cmdNum: number; timestamp: number; flags: number }
  | { type: 'command-end'; cmdNum: number; success: boolean }
  | { type: 'command-output'; cmdNum: number; line: string }
  | { type: 'window-add'; windowId: string }
  | { type: 'window-close'; windowId: string }
  | { type: 'window-renamed'; windowId: string; name: string }
  | { type: 'session-changed'; sessionId: string; name: string }
  | { type: 'pause'; paneId: string }
  | { type: 'continue'; paneId: string }
  | { type: 'exit'; reason?: string }

export type { ControlModeEvent }
