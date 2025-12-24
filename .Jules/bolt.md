# Bolt's Journal

## 2024-05-23 - Initial Setup
**Learning:** Performance requires measurement.
**Action:** Establish a baseline before optimizing.

## 2024-05-23 - Currency Formatter Optimization
**Learning:** `NumberFormatter` creation is expensive and often done inside SwiftUI View `body`. Caching the default instance can significantly reduce overhead on the main thread.
**Action:** Check for expensive object creations (Formatters, Calendars) inside View updates and cache them.
