import type { Session } from '@shared/types'

export function formatCommandLabel(session: Session): string | null {
  const dirLabel = getPathLeaf(session.projectPath)
  const baseLabel = session.agentType || session.command || ''
  const parts = [baseLabel, dirLabel].filter(Boolean)

  if (parts.length === 0) {
    return null
  }

  return parts.join(' / ')
}

export function getPathLeaf(value: string): string | null {
  const trimmed = value.trim()
  if (!trimmed) {
    return null
  }

  const normalized = trimmed.replace(/[\\/]+$/, '')
  if (!normalized) {
    return null
  }

  const parts = normalized.split(/[\\/]/)
  return parts[parts.length - 1] || null
}
