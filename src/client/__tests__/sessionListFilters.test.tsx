import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, test, mock } from 'bun:test'
import TestRenderer, { act } from 'react-test-renderer'
import type { Session } from '@shared/types'
import { useSettingsStore } from '../stores/settingsStore'
import { useSessionStore } from '../stores/sessionStore'

const globalAny = globalThis as typeof globalThis & {
  window?: Window & typeof globalThis
}

const originalWindow = globalAny.window

let SessionList: typeof import('../components/SessionList').default
let dropdownProps: {
  projects: string[]
  selectedProjects: string[]
  hasHiddenPermissions: boolean
} | null = null

mock.module('../components/ProjectFilterDropdown', () => ({
  default: (props: typeof dropdownProps) => {
    dropdownProps = props
    return null
  },
}))

beforeAll(async () => {
  SessionList = (await import('../components/SessionList')).default
})

beforeEach(() => {
  dropdownProps = null
  globalAny.window = {
    matchMedia: () => ({
      matches: false,
      addEventListener: () => {},
      removeEventListener: () => {},
      addListener: () => {},
      removeListener: () => {},
    }),
  } as unknown as Window & typeof globalThis

  useSettingsStore.setState({
    sessionSortMode: 'created',
    sessionSortDirection: 'desc',
    manualSessionOrder: [],
    inactiveSessionsExpanded: false,
    showProjectName: true,
    showLastUserMessage: true,
    showSessionIdPrefix: false,
    projectFilters: [],
  })

  useSessionStore.setState({
    exitingSessions: new Map(),
  })
})

afterEach(() => {
  globalAny.window = originalWindow
  useSettingsStore.setState({
    sessionSortMode: 'created',
    sessionSortDirection: 'desc',
    manualSessionOrder: [],
    inactiveSessionsExpanded: false,
    showProjectName: true,
    showLastUserMessage: true,
    showSessionIdPrefix: false,
    projectFilters: [],
  })
  useSessionStore.setState({
    exitingSessions: new Map(),
  })
})

afterAll(() => {
  mock.restore()
})

const baseSession: Session = {
  id: 'session-1',
  name: 'alpha',
  tmuxWindow: 'agentboard:1',
  projectPath: '/tmp/alpha',
  status: 'working',
  lastActivity: '2024-01-01T00:00:00.000Z',
  createdAt: '2024-01-01T00:00:00.000Z',
  source: 'managed',
}

describe('SessionList project filters', () => {
  test('marks hidden permission sessions when filters exclude them', () => {
    useSettingsStore.setState({ projectFilters: ['/tmp/visible'] })

    const sessions: Session[] = [
      { ...baseSession, id: 'visible', projectPath: '/tmp/visible', status: 'working' },
      { ...baseSession, id: 'hidden', projectPath: '/tmp/hidden', status: 'permission' },
    ]

    let renderer!: TestRenderer.ReactTestRenderer
    act(() => {
      renderer = TestRenderer.create(
        <SessionList
          sessions={sessions}
          inactiveSessions={[]}
          selectedSessionId={null}
          loading={false}
          error={null}
          onSelect={() => {}}
          onRename={() => {}}
        />
      )
    })

    expect(dropdownProps?.selectedProjects).toEqual(['/tmp/visible'])
    expect(dropdownProps?.projects).toEqual(
      expect.arrayContaining(['/tmp/visible', '/tmp/hidden'])
    )
    expect(dropdownProps?.hasHiddenPermissions).toBe(true)

    act(() => {
      renderer.unmount()
    })
  })
})
