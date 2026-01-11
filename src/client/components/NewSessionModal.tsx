import { useEffect, useState } from 'react'

interface NewSessionModalProps {
  isOpen: boolean
  onClose: () => void
  onCreate: (projectPath: string, name?: string, command?: string) => void
  defaultProjectDir: string
  defaultCommand: string
  lastProjectPath?: string | null
  activeProjectPath?: string
}

export type CommandMode = 'claude' | 'codex' | 'custom'

const COMMAND_PRESETS = [
  { label: 'Claude', value: 'claude' },
  { label: 'Codex', value: 'codex' },
  { label: 'Custom', value: '' },
] as const

export function getCommandMode(defaultCommand: string): CommandMode {
  if (defaultCommand === 'claude') return 'claude'
  if (defaultCommand === 'codex') return 'codex'
  return 'custom'
}

export function resolveCommand(commandMode: CommandMode, command: string): string {
  return commandMode === 'custom' ? command.trim() : commandMode
}

export function resolveProjectPath({
  value,
  activeProjectPath,
  lastProjectPath,
  defaultProjectDir,
}: {
  value: string
  activeProjectPath?: string
  lastProjectPath?: string | null
  defaultProjectDir: string
}): string {
  const trimmedValue = value.trim()
  const baseDir =
    activeProjectPath?.trim() || lastProjectPath || defaultProjectDir.trim()
  if (!trimmedValue) {
    return baseDir
  }

  const isAbsolute =
    trimmedValue.startsWith('/') ||
    trimmedValue.startsWith('~') ||
    /^[A-Za-z]:[\\/]/.test(trimmedValue)

  if (isAbsolute || !baseDir) {
    return trimmedValue
  }

  const base = baseDir.replace(/[\\/]+$/, '')
  return `${base}/${trimmedValue}`
}

export default function NewSessionModal({
  isOpen,
  onClose,
  onCreate,
  defaultProjectDir,
  defaultCommand,
  lastProjectPath,
  activeProjectPath,
}: NewSessionModalProps) {
  const [projectPath, setProjectPath] = useState('')
  const [name, setName] = useState('')
  const [command, setCommand] = useState('')
  const [commandMode, setCommandMode] = useState<CommandMode>('claude')

  useEffect(() => {
    if (!isOpen) {
      setProjectPath('')
      setName('')
      setCommand('')
      setCommandMode('claude')
      return
    }
    // Priority: active session -> last used -> default
    const basePath =
      activeProjectPath?.trim() || lastProjectPath || defaultProjectDir
    setProjectPath(basePath)
    setName('')
    const nextMode = getCommandMode(defaultCommand)
    setCommandMode(nextMode)
    setCommand(nextMode === 'custom' ? defaultCommand : '')
  }, [activeProjectPath, defaultCommand, defaultProjectDir, isOpen, lastProjectPath])

  useEffect(() => {
    if (!isOpen) return

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, onClose])

  if (!isOpen) {
    return null
  }

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    const resolvedPath = resolveProjectPath({
      value: projectPath,
      activeProjectPath,
      lastProjectPath,
      defaultProjectDir,
    })
    if (!resolvedPath) {
      return
    }
    const finalCommand = resolveCommand(commandMode, command)
    onCreate(
      resolvedPath,
      name.trim() || undefined,
      finalCommand || undefined
    )
    onClose()
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose()
      }}
    >
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-md border border-border bg-elevated p-6"
      >
        <h2 className="text-sm font-semibold uppercase tracking-wider text-primary">
          New Session
        </h2>
        <p className="mt-2 text-xs text-muted">
          Enter an absolute project path or a folder name. Relative paths use
          the base directory.
        </p>
        {(activeProjectPath?.trim() || lastProjectPath || defaultProjectDir.trim()) ? (
          <p className="mt-1 text-xs text-muted">
            Base: {activeProjectPath?.trim() || lastProjectPath || defaultProjectDir.trim()}
          </p>
        ) : null}

        <div className="mt-5 space-y-4">
          <div>
            <label className="mb-1.5 block text-xs text-secondary">
              Project Path
            </label>
            <input
              value={projectPath}
              onChange={(event) => setProjectPath(event.target.value)}
              placeholder={
                activeProjectPath ||
                lastProjectPath ||
                defaultProjectDir ||
                '/Users/you/code/my-project'
              }
              className="input"
              autoFocus
            />
          </div>
          <div>
            <label className="mb-1.5 block text-xs text-secondary">
              Display Name
            </label>
            <input
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="auto-generated"
              className="input placeholder:italic"
            />
          </div>
          <div>
            <label className="mb-1.5 block text-xs text-secondary">
              Command
            </label>
            <div className="flex gap-2">
              {COMMAND_PRESETS.map((preset) => {
                const mode = preset.value || 'custom'
                const isActive = commandMode === mode
                return (
                  <button
                    key={mode}
                    type="button"
                    onClick={() => {
                      setCommandMode(mode as 'claude' | 'codex' | 'custom')
                      if (mode !== 'custom') setCommand('')
                    }}
                    className={`btn flex-1 text-xs ${isActive ? 'btn-primary' : ''}`}
                  >
                    {preset.label}
                  </button>
                )
              })}
            </div>
            {commandMode === 'custom' && (
              <input
                value={command}
                onChange={(event) => setCommand(event.target.value)}
                placeholder="Enter custom command..."
                className="input mt-2 font-mono"
                autoFocus
              />
            )}
          </div>
        </div>

        <div className="mt-6 flex justify-end gap-2">
          <button type="button" onClick={onClose} className="btn">
            Cancel
          </button>
          <button type="submit" className="btn btn-primary">
            Create
          </button>
        </div>
      </form>
    </div>
  )
}
