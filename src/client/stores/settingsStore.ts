import { create } from 'zustand'
import { persist } from 'zustand/middleware'

const DEFAULT_PROJECT_DIR = '~/Documents/GitHub'
const DEFAULT_COMMAND = 'claude'

interface SettingsState {
  defaultProjectDir: string
  setDefaultProjectDir: (dir: string) => void
  defaultCommand: string
  setDefaultCommand: (cmd: string) => void
  lastProjectPath: string | null
  setLastProjectPath: (path: string) => void
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      defaultProjectDir: DEFAULT_PROJECT_DIR,
      setDefaultProjectDir: (dir) => set({ defaultProjectDir: dir }),
      defaultCommand: DEFAULT_COMMAND,
      setDefaultCommand: (cmd) => set({ defaultCommand: cmd }),
      lastProjectPath: null,
      setLastProjectPath: (path) => set({ lastProjectPath: path }),
    }),
    { name: 'agentboard-settings' }
  )
)

export { DEFAULT_PROJECT_DIR, DEFAULT_COMMAND }
