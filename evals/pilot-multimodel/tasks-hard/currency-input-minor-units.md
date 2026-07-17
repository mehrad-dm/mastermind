---
id: currency-input-minor-units
domain: frontend
difficulty: hard
---

## Prompt

Build a correct money input for React/TypeScript. Fix this component. Contract: it emits amounts as integer minor units (cents) via `onChange(cents: number | null)`; it must support locale-aware entry (prop `locale: string`, e.g. 'de-DE' where users type '1.234,56'); display formatting uses the locale and `currency: string` prop.

```tsx
import { useState } from 'react';

export function MoneyInput({ onChange }: { onChange: (cents: number) => void }) {
  const [value, setValue] = useState('');
  return (
    <input
      type="number"
      value={value}
      onChange={(e) => {
        const v = e.target.value;
        setValue(v);
        onChange(parseFloat(v.replace(',', '')) * 100);
      }}
      onBlur={() => setValue('$' + parseFloat(value).toFixed(2))}
    />
  );
}
```

Known symptoms to fix: entering 19.99 sometimes emits 1998 cents; German users cannot type a decimal comma; the caret jumps to the end when editing the middle of a formatted value; typing letters emits NaN; clearing the field emits 0. Return the complete fixed component. No libraries beyond Intl.

## Rubric

1. Emitted values are exact integer minor units: '19.99' emits exactly 1999 — conversion parses the string parts as integers (whole*100 + fraction) or applies Math.round to the scaled float; bare `parseFloat(v) * 100` truncation (1998.9999… → 1998) is eliminated.
2. Locale decimal and grouping separators are derived from Intl (e.g., Intl.NumberFormat(locale).formatToParts on a probe number), not hardcoded '.' and ',': in de-DE, '1.234,56' parses to 123456 cents.
3. The input is type="text" (or equivalent) with inputMode="decimal" — not type="number", which blocks locale separators and formatted values — and has an associated accessible label.
4. Invalid input (letters, multiple decimal separators) never emits NaN: the component either withholds onChange or emits the last valid value/null, per a consistent documented rule.
5. An empty field emits null (distinct from 0), and 0 itself is a valid emittable amount.
6. More than two fraction digits are handled by an explicit consistent rule (reject the keystroke, or round with a stated mode) — '1.999' can never emit a non-integer or silently become 199.9.
7. Display formatting uses Intl.NumberFormat with style: 'currency' and the currency prop — no manual '$' + toFixed concatenation.
8. Caret position is preserved on reformat: after programmatic formatting, selectionStart/selectionEnd are restored relative to the edit position (e.g., counting digits left of the caret), so editing mid-value does not jump the caret to the end.
9. Amounts whose minor units would exceed Number.MAX_SAFE_INTEGER are rejected or clamped with an explicit guard — no silent precision loss on very large values.
10. Negative amounts are either supported correctly through parse/format/emit (locale minus sign included) or explicitly rejected — one consistent rule, no path where '-' produces NaN or a positive result.
