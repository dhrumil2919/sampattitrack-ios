## 2024-05-23 - Filtered List Empty States
**Learning:** Users can be confused when a filtered list returns no results if there is no feedback. A standard "empty list" state is often only triggered when the source data is empty, ignoring the filtered state.
**Action:** Always check if the *filtered* dataset is empty. If so, provide context-aware feedback (e.g., "No Asset accounts found" or "No results for 'search'").

## 2024-05-25 - Explaining Disabled States
**Learning:** Simply disabling a primary action button (like "Save") without explanation frustrates users who believe they have completed the form.
**Action:** When disabling a primary button, provide a footer or nearby helper text explaining *why* it is disabled (e.g., "Transaction must be balanced").
