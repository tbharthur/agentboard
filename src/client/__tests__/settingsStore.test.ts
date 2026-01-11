import { afterAll, beforeEach, describe, expect, test } from 'bun:test'

const globalAny = globalThis as typeof globalThis & {
  window?: { localStorage: Storage }
  localStorage?: Storage
}

const originalWindow = globalAny.window
const originalLocalStorage = globalAny.localStorage

function createStorage(): Storage {
  const store = new Map<string, string>()
  return {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => {
      store.set(key, value)
    },
    removeItem: (key: string) => {
      store.delete(key)
    },
    clear: () => {
      store.clear()
    },
    key: (index: number) => Array.from(store.keys())[index] ?? null,
    get length() {
      return store.size
    },
  } as Storage
}

const storage = createStorage()
globalAny.localStorage = storage
globalAny.window = { localStorage: storage } as typeof window

const settingsModule = await import('../stores/settingsStore')
const { useSettingsStore, DEFAULT_PROJECT_DIR, DEFAULT_COMMAND } = settingsModule

beforeEach(() => {
  storage.clear()
  useSettingsStore.setState({
    defaultProjectDir: DEFAULT_PROJECT_DIR,
    defaultCommand: DEFAULT_COMMAND,
    lastProjectPath: null,
  })
})

describe('useSettingsStore', () => {
  test('exposes default values', () => {
    const state = useSettingsStore.getState()
    expect(state.defaultProjectDir).toBe(DEFAULT_PROJECT_DIR)
    expect(state.defaultCommand).toBe(DEFAULT_COMMAND)
    expect(state.lastProjectPath).toBeNull()
  })

  test('updates default project dir', () => {
    useSettingsStore.getState().setDefaultProjectDir('/tmp')
    expect(useSettingsStore.getState().defaultProjectDir).toBe('/tmp')
  })

  test('updates default command', () => {
    useSettingsStore.getState().setDefaultCommand('codex')
    expect(useSettingsStore.getState().defaultCommand).toBe('codex')
  })

  test('updates last project path', () => {
    useSettingsStore.getState().setLastProjectPath('/projects/app')
    expect(useSettingsStore.getState().lastProjectPath).toBe('/projects/app')
  })
})

afterAll(() => {
  globalAny.window = originalWindow
  globalAny.localStorage = originalLocalStorage
})
