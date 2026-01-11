import path from 'node:path'
import fs from 'node:fs'
import { config } from './config'
import { generateSessionName } from './nameGenerator'
import type { AgentType, Session, SessionStatus } from '../shared/types'

// How many seconds of inactivity before considering a session "waiting"
const IDLE_THRESHOLD_SECONDS = 2

interface WindowInfo {
  id: string
  name: string
  path: string
  activity: number
  command: string
}

export class SessionManager {
  private sessionName: string

  constructor(sessionName = config.tmuxSession) {
    this.sessionName = sessionName
  }

  ensureSession(): void {
    try {
      runTmux(['has-session', '-t', this.sessionName])
    } catch {
      runTmux(['new-session', '-d', '-s', this.sessionName])
    }
  }

  listWindows(): Session[] {
    this.ensureSession()

    const managed = this.listWindowsForSession(this.sessionName, 'managed')
    const externals = this.listExternalWindows()

    return [...managed, ...externals]
  }

  createWindow(projectPath: string, name?: string, command?: string): Session {
    this.ensureSession()

    const resolvedPath = resolveProjectPath(projectPath)
    if (!resolvedPath) {
      throw new Error('Project path is required')
    }

    if (!fs.existsSync(resolvedPath)) {
      throw new Error(`Project path does not exist: ${resolvedPath}`)
    }

    const existingNames = new Set(
      this.listWindowsForSession(this.sessionName, 'managed').map(
        (session) => session.name
      )
    )

    let baseName = name?.trim()
    if (baseName) {
      baseName = baseName.replace(/\s+/g, '-')
    } else {
      // Generate random name, retry if collision
      do {
        baseName = generateSessionName()
      } while (existingNames.has(baseName))
    }

    const finalCommand = command?.trim() || 'claude'
    const finalName = this.findAvailableName(baseName, existingNames)
    const nextIndex = this.findNextAvailableWindowIndex()

    runTmux([
      'new-window',
      '-t',
      `${this.sessionName}:${nextIndex}`,
      '-n',
      finalName,
      '-c',
      resolvedPath,
      finalCommand,
    ])

    const sessions = this.listWindowsForSession(this.sessionName, 'managed')
    const created = sessions.find((session) => session.name === finalName)

    if (!created) {
      throw new Error('Failed to create tmux window')
    }

    return created
  }

  killWindow(tmuxWindow: string): void {
    runTmux(['kill-window', '-t', tmuxWindow])
  }

  renameWindow(tmuxWindow: string, newName: string): void {
    const trimmed = newName.trim()
    if (!trimmed) {
      throw new Error('Name cannot be empty')
    }

    // Validate: alphanumeric, hyphens, underscores only
    if (!/^[\w-]+$/.test(trimmed)) {
      throw new Error(
        'Name can only contain letters, numbers, hyphens, and underscores'
      )
    }

    const sessionName = this.resolveSessionName(tmuxWindow)
    const targetWindowId = this.extractWindowId(tmuxWindow)
    const existingNames = new Set(
      this.listWindowsForSession(sessionName, 'managed')
        .filter((s) => this.extractWindowId(s.tmuxWindow) !== targetWindowId)
        .map((s) => s.name)
    )

    if (existingNames.has(trimmed)) {
      throw new Error(`A session named "${trimmed}" already exists`)
    }

    runTmux(['rename-window', '-t', tmuxWindow, trimmed])
  }

  private listExternalWindows(): Session[] {
    if (config.discoverPrefixes.length === 0) {
      return []
    }

    const sessions = this.listSessions().filter((sessionName) =>
      config.discoverPrefixes.some((prefix) => sessionName.startsWith(prefix))
    )

    return sessions.flatMap((sessionName) =>
      this.listWindowsForSession(sessionName, 'external')
    )
  }

  private listSessions(): string[] {
    try {
      const output = runTmux(['list-sessions', '-F', '#{session_name}'])
      return output
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
    } catch {
      return []
    }
  }

  private listWindowsForSession(
    sessionName: string,
    source: Session['source']
  ): Session[] {
    const output = runTmux([
      'list-windows',
      '-t',
      sessionName,
      '-F',
      '#{window_id}\t#{window_name}\t#{pane_current_path}\t#{window_activity}\t#{pane_start_command}',
    ])

    return output
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => parseWindow(line))
      .map((window) => ({
        id: `${sessionName}:${window.id}`,
        name: window.name,
        tmuxWindow: `${sessionName}:${window.id}`,
        projectPath: window.path,
        status: inferStatus(window.activity),
        lastActivity: new Date(
          window.activity ? window.activity * 1000 : Date.now()
        ).toISOString(),
        agentType: inferAgentType(window.command),
        source,
        command: window.command || undefined,
      }))
  }

  private findAvailableName(base: string, existing: Set<string>): string {
    if (!existing.has(base)) {
      return base
    }

    let suffix = 2
    while (existing.has(`${base}-${suffix}`)) {
      suffix += 1
    }

    return `${base}-${suffix}`
  }

  private findNextAvailableWindowIndex(): number {
    const baseIndex = this.getTmuxBaseIndex()
    const usedIndices = this.getWindowIndices()

    if (usedIndices.length === 0) {
      return baseIndex
    }

    // Find the first gap, or use max + 1
    const maxIndex = Math.max(...usedIndices)
    for (let i = baseIndex; i <= maxIndex; i++) {
      if (!usedIndices.includes(i)) {
        return i
      }
    }

    return maxIndex + 1
  }

  private getTmuxBaseIndex(): number {
    try {
      const output = runTmux(['show-options', '-gv', 'base-index'])
      return Number.parseInt(output.trim(), 10) || 0
    } catch {
      return 0
    }
  }

  private getWindowIndices(): number[] {
    try {
      const output = runTmux([
        'list-windows',
        '-t',
        this.sessionName,
        '-F',
        '#{window_index}',
      ])
      return output
        .split('\n')
        .map((line) => Number.parseInt(line.trim(), 10))
        .filter((n) => !Number.isNaN(n))
    } catch {
      return []
    }
  }

  private resolveSessionName(tmuxWindow: string): string {
    const colonIndex = tmuxWindow.indexOf(':')
    if (colonIndex > 0) {
      return tmuxWindow.slice(0, colonIndex)
    }

    const resolved = runTmux([
      'display-message',
      '-p',
      '-t',
      tmuxWindow,
      '#{session_name}',
    ]).trim()

    if (!resolved) {
      throw new Error('Unable to resolve session for window')
    }

    return resolved
  }

  private extractWindowId(tmuxWindow: string): string {
    const parts = tmuxWindow.split(':')
    const windowTarget = parts[parts.length - 1] || tmuxWindow
    const paneSplit = windowTarget.split('.')
    return paneSplit[0] || windowTarget
  }
}

function parseWindow(line: string): WindowInfo {
  const [id, name, panePath, activityRaw, command] = line.split('\t')
  const activity = Number.parseInt(activityRaw || '0', 10)

  return {
    id: id || '',
    name: name || 'unknown',
    path: panePath || '',
    activity: Number.isNaN(activity) ? 0 : activity,
    command: command || '',
  }
}

function runTmux(args: string[]): string {
  const result = Bun.spawnSync(['tmux', ...args], {
    stdout: 'pipe',
    stderr: 'pipe',
  })

  if (result.exitCode !== 0) {
    const error = result.stderr.toString() || 'tmux command failed'
    throw new Error(error)
  }

  return result.stdout.toString()
}

const homeDir = process.env.HOME || process.env.USERPROFILE || ''

function resolveProjectPath(value: string): string {
  const trimmed = value.trim()
  if (!trimmed) {
    return ''
  }

  if (
    homeDir &&
    (trimmed === '~' || trimmed.startsWith('~/') || trimmed.startsWith('~\\'))
  ) {
    const remainder = trimmed === '~' ? '' : trimmed.slice(2)
    return path.resolve(path.join(homeDir, remainder))
  }

  return path.resolve(trimmed)
}

function inferStatus(activityTimestamp: number): SessionStatus {
  if (!activityTimestamp) {
    return 'unknown'
  }

  const now = Math.floor(Date.now() / 1000)
  const idleSeconds = now - activityTimestamp

  return idleSeconds < IDLE_THRESHOLD_SECONDS ? 'working' : 'waiting'
}

function inferAgentType(command: string): AgentType | undefined {
  if (!command) {
    return undefined
  }

  const normalized = command.toLowerCase()

  if (normalized === 'claude' || normalized.startsWith('claude ')) {
    return 'claude'
  }

  if (normalized === 'codex' || normalized.startsWith('codex ')) {
    return 'codex'
  }

  return undefined
}
