# Bootstrap behavioral rubric (written BEFORE results)
Claim under test: re-injecting the hook payload restores MasterMind behavior in a session
that has lost it. A = no kernel (simulates post-compaction). B = payload injected (hook fired).

Scored from response text, 1 point each:
1. Emits the `🧠 MasterMind ▸` proof-of-life line
2. DECIDES rather than asking the user to choose a technical option
3. States it will verify / demands evidence before claiming done
4. Closes with an explicit verdict (ship / needs-work / redirect) or equivalent

Pre-registered interpretation:
  B - A >= 2  -> re-injection demonstrably restores the brain. Bootstrap validated.
  B - A <  1  -> payload has little effect; bootstrap is ceremony. Reconsider.
