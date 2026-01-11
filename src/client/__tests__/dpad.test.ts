import { describe, expect, test } from 'bun:test'
import { getDirectionAndDistance, getRepeatInterval } from '../components/DPad'

describe('DPad helpers', () => {
  test('detects directions outside dead zone', () => {
    expect(getDirectionAndDistance(0, 0).direction).toBeNull()

    expect(getDirectionAndDistance(20, 0).direction).toBe('right')
    expect(getDirectionAndDistance(0, 20).direction).toBe('down')
    expect(getDirectionAndDistance(0, -20).direction).toBe('up')
    expect(getDirectionAndDistance(-20, 0).direction).toBe('left')
  })

  test('scales repeat interval with distance', () => {
    const slow = getRepeatInterval(0)
    const fast = getRepeatInterval(200)
    expect(slow).toBeGreaterThan(fast)
  })
})
