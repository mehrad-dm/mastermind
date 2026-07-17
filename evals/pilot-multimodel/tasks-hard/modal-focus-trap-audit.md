---
id: modal-focus-trap-audit
domain: frontend
difficulty: hard
---

## Prompt

Fix this React modal so it is a correct, accessible dialog. No libraries.

```tsx
import { useState } from 'react';

export function DeleteDialog({ open, onClose, onConfirm }: {
  open: boolean; onClose: () => void; onConfirm: () => void;
}) {
  if (!open) return null;
  return (
    <div className="overlay" onClick={onClose}>
      <div
        className="modal animate-pop"
        onKeyDown={(e) => { if (e.key === 'Escape') onClose(); }}
      >
        <h2>Delete item?</h2>
        <p>This cannot be undone.</p>
        <input placeholder="Type DELETE to confirm" />
        <button disabled>Delete</button>
        <button onClick={onClose} autoFocus>Cancel</button>
      </div>
    </div>
  );
}

/* CSS: .animate-pop { animation: pop 250ms ease-out; }
   @keyframes pop { from { transform: scale(.8); opacity: 0 } } */
```

Requirements: proper dialog semantics; a real focus trap; focus restoration; Escape handling; the page behind must be inert and not scrollable while open (without the layout jumping when the scrollbar disappears); the entrance animation must respect user motion preferences; clicking the overlay closes but clicking inside must not; everything must clean up correctly if the component unmounts while open. Return the complete fixed component (plus any CSS changes as comments).

## Rubric

1. On open, focus moves inside the dialog to a sensible initial element, and Tab/Shift+Tab wrap at both ends (Shift+Tab on the first focusable lands on the last, and vice versa).
2. The focusable-element detection excludes disabled and hidden elements (the disabled Delete button must never receive trapped focus), and is computed at keydown time, not once at mount (the Delete button enables after typing DELETE).
3. On close, focus returns to the element focused before opening, with a guarded fallback if that element no longer exists or is disconnected (no throw, focus goes somewhere deterministic).
4. Escape closes the dialog even when focus is on the overlay/edge cases — handled via a document-level (or reliably focused container) keydown listener added on open and removed on close/unmount, not only a React onKeyDown on the inner div.
5. The rest of the app is made inert while open (inert attribute or aria-hidden on the app root, applied without hiding the dialog itself) and fully restored on close AND on unmount-while-open.
6. Body scroll is locked while open with scrollbar-width compensation (e.g., padding-right equal to the scrollbar width) so content does not shift, and the original styles are restored on close/unmount.
7. Dialog semantics: role="dialog", aria-modal="true", and aria-labelledby (or aria-label) tied to the heading; the confirm input has an associated accessible label, not just a placeholder.
8. Overlay click closes only on genuine outside clicks: clicks inside the dialog do not close it (stopPropagation or e.target === e.currentTarget check), and a drag that starts inside and ends on the overlay does not close it (mousedown-origin check).
9. The entrance animation is disabled or reduced under prefers-reduced-motion (media query in CSS or matchMedia in JS).
10. All side effects (listeners, inert/aria-hidden, body styles) are applied in effects keyed to `open` with complete cleanup functions — the early `return null` before hooks pattern is restructured so hook order is valid and unmount-while-open leaks nothing.
