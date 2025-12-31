## 2024-05-23 - Standardizing Empty States
**Learning:** `ContentUnavailableView` (iOS 17+) significantly reduces boilerplate for empty states and search results compared to custom `VStack` implementations. It automatically handles layout, spacing, and system-standard styling, making the app feel more native.
**Action:** Replace custom "No Data" or "No Results" VStacks with `ContentUnavailableView` wherever possible, especially for search results (`.search(text:)`).
