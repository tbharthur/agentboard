import { describe, expect, test, mock } from 'bun:test'

mock.module('xterm', () => ({ Terminal: class {} }))
mock.module('xterm-addon-fit', () => ({ FitAddon: class {} }))
mock.module('@xterm/addon-clipboard', () => ({ ClipboardAddon: class {} }))
mock.module('xterm-addon-webgl', () => ({ WebglAddon: class {} }))

const { forceTextPresentation } = await import('../hooks/useTerminal')

describe('forceTextPresentation', () => {
  test('returns input when no emoji substitutions needed', () => {
    expect(forceTextPresentation('hello')).toBe('hello')
  })

  test('inserts text presentation selector for emoji-like chars', () => {
    const result = forceTextPresentation(`x\u23FAy`)
    expect(result).toBe(`x\u23FA\uFE0Ey`)
  })
})
