# Session Filters Implementation Plan

## Overview

Add project-based filtering to the sessions sidebar, with a compact dropdown UI and persistence. Include an orange notification dot when filtered-out sessions need permission.

## Requirements

- Dropdown in sidebar header next to session count
- "All Projects" as default, plus dynamic list from current sessions
- Filter applies to both active and inactive sessions
- Persist selection to localStorage
- Orange dot indicator when hidden sessions have `permission` status
- Click dot to clear filter

---

## Implementation Steps

### 1. Update Settings Store

**File:** `src/client/stores/settingsStore.ts`

Add new persisted state:

```ts
interface SettingsState {
  // ... existing
  projectFilter: string | null  // null = "All Projects"
  setProjectFilter: (filter: string | null) => void
}
```

- Add to the persisted zustand store
- Default value: `null`

---

### 2. Create Filter Dropdown Component

**File:** `src/client/components/ProjectFilterDropdown.tsx` (new)

Props:
```ts
interface ProjectFilterDropdownProps {
  projects: string[]              // unique project paths
  selectedProject: string | null  // current filter
  onSelect: (project: string | null) => void
  hasHiddenPermissions: boolean   // show orange dot
}
```

Implementation:
- Use a `<select>` or custom dropdown (match existing UI patterns)
- First option: "All Projects"
- Remaining options: project display names
- Truncate long names in trigger, show full path on hover/title
- Orange dot positioned top-right of dropdown when `hasHiddenPermissions && selectedProject !== null`

**Duplicate folder name handling:**
- Create utility function `getProjectDisplayNames(paths: string[]): Map<string, string>`
- If leaf names are unique, use leaf (e.g., "api")
- If duplicates exist, walk up path until unique (e.g., "work/api", "personal/api")

---

### 3. Add Project Extraction Utility

**File:** `src/client/utils/sessions.ts`

```ts
export function getUniqueProjects(
  sessions: Session[],
  inactiveSessions: AgentSession[]
): string[]
```

- Extract `projectPath` from both arrays
- Dedupe and sort alphabetically
- Memoize in component to avoid recalc on every render

---

### 4. Add Display Name Utility

**File:** `src/client/utils/sessionLabel.ts` (extend existing)

```ts
export function getDisambiguatedProjectNames(
  paths: string[]
): Map<string, string>
```

- Input: array of full project paths
- Output: map from full path → display name
- Logic: start with leaf, add parent segments only where needed to disambiguate

---

### 5. Update SessionList Component

**File:** `src/client/components/SessionList.tsx`

**Changes:**

1. Import new components/utilities
2. Get filter state from settings store:
   ```ts
   const projectFilter = useSettingsStore((state) => state.projectFilter)
   const setProjectFilter = useSettingsStore((state) => state.setProjectFilter)
   ```

3. Extract unique projects (memoized):
   ```ts
   const uniqueProjects = useMemo(
     () => getUniqueProjects(sessions, inactiveSessions),
     [sessions, inactiveSessions]
   )
   ```

4. Filter sessions:
   ```ts
   const filteredSessions = useMemo(() => {
     if (!projectFilter) return sortedSessions
     return sortedSessions.filter(s => s.projectPath === projectFilter)
   }, [sortedSessions, projectFilter])

   const filteredInactiveSessions = useMemo(() => {
     if (!projectFilter) return inactiveSessions
     return inactiveSessions.filter(s => s.projectPath === projectFilter)
   }, [inactiveSessions, projectFilter])
   ```

5. Calculate hidden permission count:
   ```ts
   const hiddenPermissionCount = useMemo(() => {
     if (!projectFilter) return 0
     return sortedSessions.filter(
       s => s.projectPath !== projectFilter && s.status === 'permission'
     ).length
   }, [sortedSessions, projectFilter])
   ```

6. Clear invalid filter on load:
   ```ts
   useEffect(() => {
     if (projectFilter && !uniqueProjects.includes(projectFilter)) {
       setProjectFilter(null)
     }
   }, [projectFilter, uniqueProjects, setProjectFilter])
   ```

7. Update header JSX:
   ```tsx
   <div className="flex h-10 shrink-0 items-center justify-between border-b border-border px-3">
     <span className="text-xs font-medium uppercase tracking-wider text-muted">
       Sessions
     </span>
     <div className="flex items-center gap-2">
       <ProjectFilterDropdown
         projects={uniqueProjects}
         selectedProject={projectFilter}
         onSelect={setProjectFilter}
         hasHiddenPermissions={hiddenPermissionCount > 0}
       />
       <span className="text-xs text-muted">
         {filteredSessions.length}
       </span>
     </div>
   </div>
   ```

8. Replace `sortedSessions` → `filteredSessions` in render
9. Replace `inactiveSessions` → `filteredInactiveSessions` in render
10. Update inactive section count to show filtered count

---

### 6. Handle Orange Dot Click

In `ProjectFilterDropdown`:
- When dot is clicked, call `onSelect(null)` to clear filter
- Optional: show tooltip on hover "Hidden sessions need attention"

---

### 7. Styling

**File:** `src/client/styles/index.css` (or component styles)

- Orange dot: `bg-approval` (already exists for permission status)
- Size: ~6-8px circle
- Position: absolute, top-right corner of dropdown trigger
- Animation: subtle pulse (reuse existing `pulse-approval` if appropriate)

---

## Edge Cases Handled

| Case | Solution |
|------|----------|
| Duplicate folder names | Disambiguate with parent path segments |
| Selected project gone | Clear filter on load if invalid |
| Very long project list | Scrollable dropdown with max-height |
| Mobile viewport | Truncate names, use native select if needed |
| Rapid session changes | Memoize project extraction |
| Permission + filtered | Orange dot, click to clear |

---

## Testing

1. **Unit tests** (`src/client/utils/`)
   - `getUniqueProjects` - deduplication, sorting
   - `getDisambiguatedProjectNames` - various duplicate scenarios

2. **Manual testing**
   - Filter persists across refresh
   - Filter clears when project no longer exists
   - Orange dot appears/disappears correctly
   - Inactive sessions filter correctly
   - Session count updates with filter

---

## Future Extensions

- Status filter (working/waiting/permission) - add `statusFilter: SessionStatus[] | null` to store
- Search/filter within long project dropdown
- Filter presets / saved filters

---

## Files Changed

| File | Change |
|------|--------|
| `src/client/stores/settingsStore.ts` | Add `projectFilter` state |
| `src/client/components/ProjectFilterDropdown.tsx` | New component |
| `src/client/components/SessionList.tsx` | Integrate filter |
| `src/client/utils/sessions.ts` | Add `getUniqueProjects` |
| `src/client/utils/sessionLabel.ts` | Add `getDisambiguatedProjectNames` |
| `src/client/styles/index.css` | Orange dot styles (if needed) |
