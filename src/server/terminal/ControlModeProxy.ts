// src/server/terminal/ControlModeProxy.ts

import { TerminalProxyBase } from './TerminalProxyBase'
import { TerminalProxyError, TerminalState } from './types'
import { ControlModeParser } from './ControlModeParser'
import type { ControlModeEvent } from './ControlModeTypes'

/**
 * Terminal proxy using tmux control mode (-CC).
 * Provides structured output instead of raw escape sequences.
 */
class ControlModeProxy extends TerminalProxyBase {
  private process: ReturnType<typeof Bun.spawn> | null = null
  private parser = new ControlModeParser()
  private decoder = new TextDecoder()
  private paused = new Set<string>()
  private currentPane = '%0'
  private cols = 80
  private rows = 24

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

    if (this.process) {
      try {
        this.process.kill()
      } catch {
        // Ignore
      }
      this.process = null
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

    let proc: ReturnType<typeof Bun.spawn>
    try {
      proc = this.spawn(['tmux', '-CC', 'attach', '-t', this.options.sessionName], {
        env: { ...process.env, TERM: 'xterm-256color' },
        stdout: 'pipe',
        stdin: 'pipe',
      })
    } catch (error) {
      this.state = TerminalState.DEAD
      throw new TerminalProxyError(
        'ERR_TMUX_ATTACH_FAILED',
        error instanceof Error ? error.message : 'Failed to attach tmux control mode client',
        true
      )
    }

    this.process = proc

    proc.exited.then(() => {
      this.process = null
      this.state = TerminalState.DEAD
      this.logEvent('terminal_proxy_dead', { sessionName: this.options.sessionName, mode: this.getMode() })
      this.options.onExit?.()
    })

    const stdout = proc.stdout
    if (stdout && typeof stdout !== 'number') {
      this.readLoop(stdout.getReader())
    }

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

  private async readLoop(reader: ReadableStreamDefaultReader<Uint8Array>): Promise<void> {
    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        const text = this.decoder.decode(value, { stream: true })
        const events = this.parser.feed(text)
        for (const event of events) {
          this.handleEvent(event)
        }
      }
    } catch (error) {
      this.logEvent('terminal_read_error', {
        sessionName: this.options.sessionName,
        error: error instanceof Error ? error.message : 'Read loop failed',
        mode: this.getMode(),
      })
    }

    const tail = this.decoder.decode()
    if (tail) {
      const events = this.parser.feed(tail)
      for (const event of events) {
        this.handleEvent(event)
      }
    }
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
    const stdin = this.process?.stdin
    if (stdin && typeof stdin !== 'number') {
      // FileSink has a direct write() method
      stdin.write(cmd + '\n')
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
