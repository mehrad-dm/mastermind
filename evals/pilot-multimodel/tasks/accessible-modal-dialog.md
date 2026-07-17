---
id: accessible-modal-dialog
domain: frontend
difficulty: medium
---

## Prompt

This React modal 'works' visually but fails accessibility review. Fix it so it behaves like a proper modal dialog for keyboard and screen-reader users, without adding any dependencies.

```tsx
import { useState } from 'react';

export function DeleteConfirm({ onDelete }: { onDelete: () => void }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <div className='btn' onClick={() => setOpen(true)}>Delete account</div>
      {open && (
        <div className='overlay' onClick={() => setOpen(false)}>
          <div className='modal' onClick={(e) => e.stopPropagation()}>
            <span className='close' onClick={() => setOpen(false)}>x</span>
            <h2>Are you sure?</h2>
            <p>This permanently deletes your account.</p>
            <div className='btn' onClick={() => { onDelete(); setOpen(false); }}>Confirm delete</div>
          </div>
        </div>
      )}
    </>
  );
}
```

Return the corrected component.

## Rubric

1. All interactive elements (trigger, close, confirm) are semantic <button> elements (or equivalent focusable elements with correct role and keyboard activation), not divs/spans with onClick
2. The dialog container has role='dialog' (or uses the native <dialog> element) with aria-modal='true' and an accessible name (aria-labelledby pointing at the heading or aria-label)
3. Pressing Escape closes the modal
4. When the modal opens, focus moves into it, and while open, Tab focus is trapped inside the modal (or native <dialog> showModal() is used, which provides this)
5. When the modal closes, focus returns to the trigger button
6. Existing behavior is preserved: clicking the overlay still closes, clicking inside does not, and Confirm still calls onDelete and closes
