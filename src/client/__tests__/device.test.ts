import { describe, expect, test } from 'bun:test'
import { isIOSDevice } from '../utils/device'

const globalAny = globalThis as typeof globalThis & {
  navigator?: any
}

describe('isIOSDevice', () => {
  test('returns false without navigator', () => {
    const originalNavigator = globalAny.navigator
    try {
      globalAny.navigator = undefined
      expect(isIOSDevice()).toBe(false)
    } finally {
      globalAny.navigator = originalNavigator
    }
  })

  test('detects iPhone user agent', () => {
    const originalNavigator = globalAny.navigator
    try {
      globalAny.navigator = {
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)',
        platform: 'iPhone',
        maxTouchPoints: 1,
      } as any
      expect(isIOSDevice()).toBe(true)
    } finally {
      globalAny.navigator = originalNavigator
    }
  })

  test('detects iPadOS via MacIntel platform with touch', () => {
    const originalNavigator = globalAny.navigator
    try {
      globalAny.navigator = {
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
        platform: 'MacIntel',
        maxTouchPoints: 5,
      } as any
      expect(isIOSDevice()).toBe(true)
    } finally {
      globalAny.navigator = originalNavigator
    }
  })
})
