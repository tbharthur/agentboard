import { describe, expect, test } from 'bun:test'
import {
  getCommandMode,
  resolveCommand,
  resolveProjectPath,
} from '../components/NewSessionModal'

describe('NewSessionModal helpers', () => {
  test('resolves project paths with base directories', () => {
    const resolvedBase = resolveProjectPath({
      value: ' ',
      activeProjectPath: ' /active ',
      lastProjectPath: '/last',
      defaultProjectDir: '/default',
    })
    expect(resolvedBase).toBe('/active')

    const resolvedRelative = resolveProjectPath({
      value: 'repo',
      activeProjectPath: undefined,
      lastProjectPath: '/base/',
      defaultProjectDir: '/default',
    })
    expect(resolvedRelative).toBe('/base/repo')

    const resolvedAbsolute = resolveProjectPath({
      value: '/abs/path',
      activeProjectPath: undefined,
      lastProjectPath: null,
      defaultProjectDir: '/default',
    })
    expect(resolvedAbsolute).toBe('/abs/path')

    const resolvedWindows = resolveProjectPath({
      value: 'C:\\work\\app',
      activeProjectPath: undefined,
      lastProjectPath: null,
      defaultProjectDir: '/default',
    })
    expect(resolvedWindows).toBe('C:\\work\\app')
  })

  test('derives command modes and final commands', () => {
    expect(getCommandMode('claude')).toBe('claude')
    expect(getCommandMode('codex')).toBe('codex')
    expect(getCommandMode('bun run dev')).toBe('custom')

    expect(resolveCommand('custom', ' bun ')).toBe('bun')
    expect(resolveCommand('claude', 'ignored')).toBe('claude')
  })
})
