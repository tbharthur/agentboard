import type { Session } from '@shared/types'

const SESSION_STATUS_ORDER: Record<Session['status'], number> = {
  waiting: 0,
  working: 1,
  unknown: 2,
}

export function sortSessions(sessions: Session[]): Session[] {
  return [...sessions].sort((a, b) => {
    const aOrder = SESSION_STATUS_ORDER[a.status] ?? SESSION_STATUS_ORDER.unknown
    const bOrder = SESSION_STATUS_ORDER[b.status] ?? SESSION_STATUS_ORDER.unknown
    if (aOrder !== bOrder) return aOrder - bOrder
    return Date.parse(b.lastActivity) - Date.parse(a.lastActivity)
  })
}
