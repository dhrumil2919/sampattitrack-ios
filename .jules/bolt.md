## 2024-05-23 - [Caching Computed Properties for SwiftData Models]
**Learning:**
I encountered a performance bottleneck in `DashboardCalculator` where computed properties on SwiftData models (`SDTransaction.displayAmount` and `determineType`) were causing excessive recalculations.
These properties iterate over related `postings` and perform String-to-Double conversions. In aggregation loops (like calculating monthly totals or net worth history), these computations were repeated thousands of times, leading to massive overhead (O(N*P) conversions where N is transactions and P is postings).

**Action:**
I implemented a `CachedTransaction` struct within the service layer (`DashboardCalculator`) to store the pre-calculated results of these expensive operations.
This "Value Object" pattern allows us to pay the computation cost exactly once during the cache refresh cycle. Subsequent aggregations and chart calculations iterate over the lightweight structs using simple arithmetic operations, bypassing the expensive model accessors entirely.

**Pattern:**
When performing heavy aggregations on SwiftData/CoreData models with computed properties:
1. Identify the stable properties needed for calculation (e.g., amount, date, type).
2. Create a lightweight struct to hold these values.
3. Map the persistent models to these structs *once* (eager loading).
4. Perform all aggregation logic on the structs.
This reduced the time complexity of the dashboard refresh significantly by eliminating redundant parsing.
