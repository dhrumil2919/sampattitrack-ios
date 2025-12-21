## 2024-05-23 - Filtered List Empty States
**Learning:** Users can be confused when a filtered list returns no results if there is no feedback. A standard "empty list" state is often only triggered when the source data is empty, ignoring the filtered state.
**Action:** Always check if the *filtered* dataset is empty. If so, provide context-aware feedback (e.g., "No Asset accounts found" or "No results for 'search'").
