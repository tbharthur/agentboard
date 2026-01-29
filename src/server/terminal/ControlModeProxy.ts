// src/server/terminal/ControlModeProxy.ts

import { readSync, writeSync, closeSync } from 'fs'
import { TerminalProxyBase } from './TerminalProxyBase'
import { TerminalProxyError, TerminalState } from './types'
import { ControlModeParser } from './ControlModeParser'
import type { ControlModeEvent } from './ControlModeTypes'

// macOS fcntl constants
const F_GETFL = 3
const F_SETFL = 4
const O_NONBLOCK = 0x0004

// Lazy-loaded FFI — deferred to first PTY creation to avoid blocking server startup.
// Bun's dlopen at module top-level can stall the HTTP event loop.
let _ffi: {
  symbols: { openpty: CallableFunction; fcntl: CallableFunction; poll: CallableFunction }
  ptr: CallableFunction
} | null = null

function loadFfi() {
  if (!_ffi) {
    const { dlopen, FFIType, ptr } = require('bun:ffi')
    const lib = dlopen('libSystem.B.dylib', {
      openpty: {
        args: [FFIType.ptr, FFIType.ptr, FFIType.ptr, FFIType.ptr, FFIType.ptr],
        returns: FFIType.i32,
      },
      fcntl: {
        args: [FFIType.i32, FFIType.i32, FFIType.i32],
        returns: FFIType.i32,
      },
      poll: {
        args: [FFIType.ptr, FFIType.u32, FFIType.i32],
        returns: FFIType.i32,
      },
    })
    _ffi = { symbols: lib.symbols, ptr }
  }
  return _ffi
}

const POLLIN = 0x0001

/** Non-blocking check if fd has data ready to read. */
function fdHasData(fd: number): boolean {
  const { symbols, ptr } = loadFfi()
  // struct pollfd { int fd; short events; short revents; } = 8 bytes
  const pollfd = new ArrayBuffer(8)
  const view = new DataView(pollfd)
  view.setInt32(0, fd, true)       // fd
  view.setInt16(4, POLLIN, true)   // events = POLLIN
  view.setInt16(6, 0, true)        // revents = 0
  const ready = symbols.poll(ptr(new Uint8Array(pollfd)), 1, 0) as number
  return ready > 0
}

/** Create a PTY pair with non-blocking master. Returns { masterFd, slaveFd }. */
function createPty(): { masterFd: number; slaveFd: number } {
  const { symbols, ptr } = loadFfi()

  const masterBuf = new Int32Array(1)
  const slaveBuf = new Int32Array(1)
  const result = symbols.openpty(ptr(masterBuf), ptr(slaveBuf), null, null, null)
  if (result !== 0) {
    throw new Error(`openpty failed with code ${result}`)
  }
  const masterFd = masterBuf[0]
  const slaveFd = slaveBuf[0]

  // Set master fd to non-blocking so readSync returns EAGAIN instead of blocking
  const flags = symbols.fcntl(masterFd, F_GETFL, 0) as number
  if (flags >= 0) {
    symbols.fcntl(masterFd, F_SETFL, flags | O_NONBLOCK)
  }

  return { masterFd, slaveFd }
}

/**
 * Terminal proxy using tmux control mode (-CC).
 * Provides structured output instead of raw escape sequences.
 *
 * tmux -CC requires a real PTY for stdin (tcgetattr check). We create a PTY
 * pair via openpty(), give the slave end to tmux as both stdin and stdout,
 * then read/write control mode protocol through the master fd.
 */
class ControlModeProxy extends TerminalProxyBase {
  private process: ReturnType<typeof Bun.spawn> | null = null
  private parser = new ControlModeParser()
  private paused = new Set<string>()
  private currentPane = '%0'
  private cols = 80
  private rows = 24
  private masterFd: number | null = null
  private reading = false

  getMode(): 'control-mode' {
    return 'control-mode'
  }

  getClientTty(): string | null {
    return null
  }

  write(data: string): void {
    this.sendCommand(`send-keys -t ${this.currentPane} -l -- ${this.escapeForTmux(data)}`)
  }

  resize(cols: number, rows: number): void {
    this.cols = cols
    this.rows = rows
    this.sendCommand(`resize-pane -t ${this.currentPane} -x ${cols} -y ${rows}`)
  }

  async dispose(): Promise<void> {
    this.state = TerminalState.DEAD
    this.reading = false

    if (this.process) {
      try {
        this.process.kill()
      } catch {
        // Ignore
      }
      this.process = null
    }

    if (this.masterFd !== null) {
      try {
        closeSync(this.masterFd)
      } catch {
        // Ignore
      }
      this.masterFd = null
    }

    try {
      this.runTmux(['kill-session', '-t', this.options.sessionName])
      this.logEvent('terminal_session_cleanup', { sessionName: this.options.sessionName })
    } catch {
      // Ignore
    }

    this.currentWindow = null
    this.readyAt = null
    this.startPromise = null
  }

  protected async doStart(): Promise<void> {
    if (this.process) return

    const startedAt = this.now()
    this.state = TerminalState.ATTACHING

    this.logEvent('terminal_proxy_start', {
      sessionName: this.options.sessionName,
      baseSession: this.options.baseSession,
      mode: this.getMode(),
    })

    try {
      this.runTmux(['new-session', '-d', '-t', this.options.baseSession, '-s', this.options.sessionName])
    } catch (error) {
      this.state = TerminalState.DEAD
      throw new TerminalProxyError(
        'ERR_SESSION_CREATE_FAILED',
        error instanceof Error ? error.message : 'Failed to create grouped session',
        true
      )
    }

    // Create PTY pair — tmux -CC requires a real TTY for stdin
    let masterFd: number
    let slaveFd: number
    try {
      const pty = createPty()
      masterFd = pty.masterFd
      slaveFd = pty.slaveFd
    } catch (error) {
      this.state = TerminalState.DEAD
      throw new TerminalProxyError(
        'ERR_TMUX_ATTACH_FAILED',
        error instanceof Error ? error.message : 'Failed to create PTY pair',
        true
      )
    }

    let proc: ReturnType<typeof Bun.spawn>
    try {
      proc = this.spawn(['tmux', '-CC', 'attach', '-t', this.options.sessionName], {
        env: { ...process.env, TERM: 'xterm-256color' },
        stdin: slaveFd,
        stdout: slaveFd,
        stderr: 'pipe',
      })
    } catch (error) {
      closeSync(masterFd)
      closeSync(slaveFd)
      this.state = TerminalState.DEAD
      throw new TerminalProxyError(
        'ERR_TMUX_ATTACH_FAILED',
        error instanceof Error ? error.message : 'Failed to attach tmux control mode client',
        true
      )
    }

    // Close slave fd in parent — tmux owns it via spawn
    try { closeSync(slaveFd) } catch { /* ignore */ }

    this.process = proc
    this.masterFd = masterFd

    proc.exited.then(() => {
      this.process = null
      this.reading = false
      this.state = TerminalState.DEAD
      this.logEvent('terminal_proxy_dead', { sessionName: this.options.sessionName, mode: this.getMode() })
      this.options.onExit?.()
    })

    // Read control mode output from the PTY master fd
    this.readLoop()

    this.readyAt = this.now()
    this.state = TerminalState.READY
    this.logEvent('terminal_proxy_ready', {
      sessionName: this.options.sessionName,
      durationMs: this.readyAt - startedAt,
      mode: this.getMode(),
    })
  }

  protected async doSwitch(target: string, onReady?: () => void): Promise<boolean> {
    if (this.state === TerminalState.DEAD || !this.process) {
      throw new TerminalProxyError('ERR_NOT_READY', 'Terminal client not ready', true)
    }

    this.state = TerminalState.SWITCHING
    this.outputSuppressed = true
    const startedAt = this.now()

    this.logEvent('terminal_switch_attempt', {
      sessionName: this.options.sessionName,
      tmuxWindow: target,
      mode: this.getMode(),
    })

    try {
      this.sendCommand(`select-window -t ${target}`)
      if (onReady) {
        try { onReady() } catch { /* ignore */ }
      }
      this.outputSuppressed = false
      this.setCurrentWindow(target)

      this.logEvent('terminal_switch_success', {
        sessionName: this.options.sessionName,
        tmuxWindow: target,
        durationMs: this.now() - startedAt,
        mode: this.getMode(),
      })
      this.state = TerminalState.READY
      return true
    } catch (error) {
      this.outputSuppressed = false
      this.state = TerminalState.READY
      this.logEvent('terminal_switch_failure', {
        sessionName: this.options.sessionName,
        tmuxWindow: target,
        error: error instanceof Error ? error.message : 'tmux switch failed',
        mode: this.getMode(),
      })
      throw new TerminalProxyError(
        'ERR_TMUX_SWITCH_FAILED',
        error instanceof Error ? error.message : 'Unable to switch tmux window',
        true
      )
    }
  }

  private readLoop(): void {
    this.reading = true
    const buf = Buffer.alloc(16384)
    const decoder = new TextDecoder()
    let idleCount = 0
    const tick = () => {
      if (!this.reading || this.masterFd === null) return

      let gotData = false
      // Use poll() to check for data before readSync. Bun's readSync blocks even
      // on O_NONBLOCK fds, so we must verify data is available first.
      if (fdHasData(this.masterFd)) {
        try {
          const n = readSync(this.masterFd, buf, 0, buf.length, null)
          if (n > 0) {
            gotData = true
            idleCount = 0
            const text = decoder.decode(buf.subarray(0, n), { stream: true })
            const events = this.parser.feed(text)
            for (const event of events) {
              this.handleEvent(event)
            }
          }
        } catch (error: unknown) {
          const code = (error as NodeJS.ErrnoException).code
          if (code !== 'EAGAIN' && code !== 'EWOULDBLOCK') {
            this.reading = false
            this.logEvent('terminal_read_error', {
              sessionName: this.options.sessionName,
              error: error instanceof Error ? error.message : 'Read loop failed',
              mode: this.getMode(),
            })
            return
          }
        }
      } else {
        idleCount++
      }

      if (this.reading) {
        // Adaptive polling: fast when data is flowing, backs off when idle
        const delay = gotData ? 1 : Math.min(1 + idleCount, 50)
        setTimeout(tick, delay)
      }
    }

    setTimeout(tick, 0)
  }

  private handleEvent(event: ControlModeEvent): void {
    if (event.type === 'pause') {
      this.paused.add(event.paneId)
    } else if (event.type === 'continue') {
      this.paused.delete(event.paneId)
    }

    if (!this.outputSuppressed || event.type !== 'output') {
      this.options.onEvent?.(event)
    }
  }

  private sendCommand(cmd: string): void {
    if (this.masterFd !== null) {
      try {
        const encoded = new TextEncoder().encode(cmd + '\n')
        writeSync(this.masterFd, encoded)
      } catch {
        // Write failed — process may have died
      }
    }
  }

  private escapeForTmux(data: string): string {
    return data.replace(/\\/g, '\\\\').replace(/'/g, "\\'")
  }

  pausePane(_paneId: string): void {
    this.sendCommand('refresh-client -f pause-after=1')
  }

  resumePane(paneId: string): void {
    this.sendCommand(`refresh-client -A '${paneId}:continue'`)
  }
}

export { ControlModeProxy }
