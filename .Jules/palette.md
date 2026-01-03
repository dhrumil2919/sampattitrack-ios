## 2024-05-24 - Focus Management Friction
**Learning:** Users perceive "slowness" not just from load times but from interaction friction. In forms like Login, manually tapping the next field feels archaic. SwiftUI's `@FocusState` combined with `.submitLabel` creates a seamless flow that users subconsciously appreciate as "smooth".
**Action:** Always pair `.submitLabel(.next)` with `.onSubmit { focus = .nextField }` in multi-field forms.
## 2024-05-23 - Standardizing Empty States
**Learning:** `ContentUnavailableView` (iOS 17+) significantly reduces boilerplate for empty states and search results compared to custom `VStack` implementations. It automatically handles layout, spacing, and system-standard styling, making the app feel more native.
**Action:** Replace custom "No Data" or "No Results" VStacks with `ContentUnavailableView` wherever possible, especially for search results (`.search(text:)`).
