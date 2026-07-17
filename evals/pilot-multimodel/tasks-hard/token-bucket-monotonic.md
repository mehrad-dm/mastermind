---
id: token-bucket-monotonic
domain: general
difficulty: hard
---

## Prompt

Fix this per-key token-bucket rate limiter (TypeScript, single process, may be called from many concurrent request handlers). Contract: capacity C tokens per key, refill R tokens/second continuously, `tryAcquire(key, cost)` returns true and deducts if enough tokens are available, else false without deducting. Keys are arbitrary client-supplied strings (e.g., IPs), and the process runs for months.

```ts
export class RateLimiter {
  private buckets = new Map<string, { tokens: number; last: number }>();
  constructor(private capacity: number, private refillPerSec: number) {}

  tryAcquire(key: string, cost = 1): boolean {
    const now = Date.now();
    let b = this.buckets.get(key);
    if (!b) {
      b = { tokens: this.capacity, last: now };
      this.buckets.set(key, b);
    }
    const elapsedSec = Math.floor((now - b.last) / 1000);
    b.tokens = b.tokens + elapsedSec * this.refillPerSec;
    b.last = now;
    if (b.tokens >= cost) {
      b.tokens -= cost;
      return true;
    }
    return false;
  }
}
```

Known symptoms: a client polling every 500ms is starved forever even at low request rates; a key idle for an hour can burst thousands of requests; the map grows without bound under IP churn; the system clock stepping backwards (NTP) breaks it. Fix all of these, make the time source injectable, and include deterministic unit tests (no real sleeps) demonstrating the fixes. Return the full class plus tests.

## Rubric

1. Fractional refill is correct: the floor-seconds + last=now combination is gone — either `last` only advances when refill is actually credited, or elapsed time is kept fractional — so 10 calls spaced 100ms apart with R=1/s accumulate ~1 token instead of starving forever.
2. Tokens are capped at capacity on refill, so a long-idle key can burst at most C requests, never elapsed*R.
3. A time source reading lower than the stored `last` (clock stepped backwards) is handled: elapsed is clamped to >= 0, tokens never decrease from refill, and no NaN/negative state is possible.
4. The clock is injectable (constructor/option) and the default is a monotonic source (performance.now / process.hrtime.bigint), not Date.now — or Date.now retained only with explicit backwards-clamping and a comment justifying it.
5. cost > capacity returns false immediately (it can never succeed) without corrupting the bucket's token count or timestamp for subsequent calls.
6. cost that is <= 0, NaN, Infinity, or non-numeric is rejected (throw or false per a documented rule) and cannot mint tokens or corrupt state.
7. Memory is bounded: full-and-idle buckets are evicted (sweep, LRU, or max-size policy) so unbounded unique keys cannot grow the Map forever.
8. Eviction is semantically safe: only buckets whose state is reconstructible as 'full' (tokens would be >= capacity given elapsed time) are evicted, so a re-created bucket starting at capacity can never grant a request the un-evicted bucket would have denied.
9. Floating-point drift cannot deny valid requests: token accounting uses an epsilon-tolerant comparison, ordered arithmetic that provably re-reaches capacity, or integer micro-token units — the tokens >= cost check is robust after many fractional refills.
10. Tests use the injected fake clock (manually advanced, no sleeps/timers) and concretely demonstrate at least the starvation fix, the capacity cap after idle, and the backwards-clock case.
