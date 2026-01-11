import { afterEach, describe, expect, test } from 'bun:test'
import TestRenderer, { act } from 'react-test-renderer'
import Header from '../components/Header'
import { getNavShortcutMod } from '../utils/device'

const globalAny = globalThis as typeof globalThis & {
  navigator?: Navigator
}

const originalNavigator = globalAny.navigator

afterEach(() => {
  globalAny.navigator = originalNavigator
})

describe('Header', () => {
  test('renders status dot and triggers new session', () => {
    globalAny.navigator = {
      platform: 'Win32',
      userAgent: 'Chrome',
      maxTouchPoints: 0,
    } as unknown as Navigator

    let created = 0
    const renderer = TestRenderer.create(
      <Header connectionStatus="connected" onNewSession={() => { created += 1 }} />
    )

    const statusDot = renderer.root.findAllByType('span').find((node) =>
      typeof node.props.className === 'string' &&
      node.props.className.includes('rounded-full')
    )
    if (!statusDot) {
      throw new Error('Expected status dot')
    }
    expect(statusDot.props.className).toContain('bg-working')

    const button = renderer.root.findByType('button')
    expect(button.props.title).toBe(`New session (${getNavShortcutMod()}N)`)

    act(() => {
      button.props.onClick()
    })

    expect(created).toBe(1)

    act(() => {
      renderer.unmount()
    })
  })

  test('shows error status styling', () => {
    const renderer = TestRenderer.create(
      <Header connectionStatus="error" onNewSession={() => {}} />
    )

    const statusDot = renderer.root.findAllByType('span').find((node) =>
      typeof node.props.className === 'string' &&
      node.props.className.includes('rounded-full')
    )
    if (!statusDot) {
      throw new Error('Expected status dot')
    }

    expect(statusDot.props.className).toContain('bg-danger')

    act(() => {
      renderer.unmount()
    })
  })
})
