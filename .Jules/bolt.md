# Bolt's Journal - Critical Learnings

## 2024-05-23 - Combined Pass for Transaction Display Logic
**Learning:** In list views displaying complex entities (like double-entry transactions), separate computed properties for `type` (expense/income) and `amount` often duplicate iteration logic. Combining them into a single pass reduced string-to-double parsing by 50% per row.
**Action:** When an entity requires multiple derived values that depend on iterating the same collection (especially with expensive parsing), prefer returning a tuple/struct from a single calculation method over multiple computed properties.
