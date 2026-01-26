import { useState, useRef, useEffect } from 'react'

/**
 * Tracks IDs that are newly added to a set compared to previous render.
 * The returned set clears automatically after a brief delay.
 *
 * @param currentIds - Set of current IDs
 * @param clearDelayMs - Delay before clearing newly entered set (default: 500ms)
 * @returns Set of IDs that were just added
 */
export function useNewlyEnteredIds(
  currentIds: Set<string>,
  clearDelayMs = 500
): Set<string> {
  const prevIdsRef = useRef<Set<string>>(currentIds)
  const [newlyEntered, setNewlyEntered] = useState<Set<string>>(new Set())

  useEffect(() => {
    const newIds = new Set<string>()
    for (const id of currentIds) {
      if (!prevIdsRef.current.has(id)) {
        newIds.add(id)
      }
    }
    prevIdsRef.current = currentIds

    if (newIds.size > 0) {
      setNewlyEntered(newIds)
      const timer = setTimeout(() => setNewlyEntered(new Set()), clearDelayMs)
      return () => clearTimeout(timer)
    }
  }, [currentIds, clearDelayMs])

  return newlyEntered
}
