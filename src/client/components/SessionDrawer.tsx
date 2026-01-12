/**
 * SessionDrawer - Mobile slide-out drawer for session list
 * Slides in from left side, covers ~75% of screen width
 * Tap backdrop or press Escape to close
 */

import { useEffect, useRef } from 'react'
import { useReducedMotion } from 'motion/react'
import type { Session } from '@shared/types'
import SessionList from './SessionList'

interface SessionDrawerProps {
  isOpen: boolean
  onClose: () => void
  sessions: Session[]
  selectedSessionId: string | null
  onSelect: (sessionId: string) => void
  onRename: (sessionId: string, newName: string) => void
  onNewSession: () => void
  loading: boolean
  error: string | null
}

export default function SessionDrawer({
  isOpen,
  onClose,
  sessions,
  selectedSessionId,
  onSelect,
  onRename,
  onNewSession,
  loading,
  error,
}: SessionDrawerProps) {
  const prefersReducedMotion = useReducedMotion()
  const drawerRef = useRef<HTMLDivElement>(null)
  const previousFocusRef = useRef<HTMLElement | null>(null)

  // Handle Escape key to close
  useEffect(() => {
    if (!isOpen) return

    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        onClose()
      }
    }

    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  }, [isOpen, onClose])

  // Focus management - focus drawer when open, return focus when closed
  useEffect(() => {
    if (isOpen) {
      // Store current focus
      previousFocusRef.current = document.activeElement as HTMLElement
      // Focus the drawer
      drawerRef.current?.focus()
    } else if (previousFocusRef.current) {
      // Return focus to previous element
      previousFocusRef.current.focus()
      previousFocusRef.current = null
    }
  }, [isOpen])

  // Handle session selection - close drawer after selecting
  const handleSelect = (sessionId: string) => {
    onSelect(sessionId)
    onClose()
  }

  // Inline styles for reduced motion
  const transitionStyle = prefersReducedMotion
    ? { transition: 'none' }
    : undefined

  return (
    <>
      {/* Backdrop */}
      <div
        className={`session-drawer-backdrop ${isOpen ? 'open' : ''}`}
        style={transitionStyle}
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Drawer panel */}
      <div
        ref={drawerRef}
        className={`session-drawer ${isOpen ? 'open' : ''}`}
        style={transitionStyle}
        role="dialog"
        aria-modal="true"
        aria-label="Session list"
        tabIndex={-1}
      >
        <SessionList
          sessions={sessions}
          selectedSessionId={selectedSessionId}
          onSelect={handleSelect}
          onRename={onRename}
          loading={loading}
          error={error}
        />

        {/* New session button at bottom */}
        <div className="shrink-0 border-t border-border p-2">
          <button
            onClick={() => {
              onNewSession()
              onClose()
            }}
            className="btn btn-primary w-full py-2 text-sm"
          >
            New Session
          </button>
        </div>
      </div>
    </>
  )
}
