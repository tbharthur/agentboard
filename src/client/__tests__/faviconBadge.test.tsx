import { afterEach, describe, expect, test } from 'bun:test'
import TestRenderer, { act } from 'react-test-renderer'
import { updateFaviconBadge, useFaviconBadge } from '../hooks/useFaviconBadge'

const globalAny = globalThis as typeof globalThis & {
  document?: Document
}

const originalDocument = globalAny.document

afterEach(() => {
  globalAny.document = originalDocument
})

function FaviconBadgeTest({ active }: { active: boolean }) {
  useFaviconBadge(active)
  return null
}

describe('updateFaviconBadge', () => {
  test('updates the favicon href when link exists', () => {
    const link = { href: '' }
    const doc = {
      querySelector: (selector: string) =>
        selector === 'link[rel="icon"]' ? link : null,
    } as unknown as Document

    const updated = updateFaviconBadge(true, doc)
    expect(updated).toBe(true)
    expect(link.href).toBe('/favicon-badge.svg')

    updateFaviconBadge(false, doc)
    expect(link.href).toBe('/favicon.svg')
  })

  test('returns false when favicon link is missing', () => {
    const doc = {
      querySelector: () => null,
    } as unknown as Document

    expect(updateFaviconBadge(true, doc)).toBe(false)
  })

  test('useFaviconBadge updates the favicon on mount and change', () => {
    const link = { href: '' }
    globalAny.document = {
      querySelector: () => link,
    } as unknown as Document

    let renderer!: TestRenderer.ReactTestRenderer

    act(() => {
      renderer = TestRenderer.create(<FaviconBadgeTest active />)
    })

    expect(link.href).toBe('/favicon-badge.svg')

    act(() => {
      renderer.update(<FaviconBadgeTest active={false} />)
    })

    expect(link.href).toBe('/favicon.svg')

    act(() => {
      renderer.unmount()
    })
  })
})
