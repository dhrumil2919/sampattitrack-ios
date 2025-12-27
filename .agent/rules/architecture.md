# Architecture

## Overview

- **Pattern**: MVVM (Model-View-ViewModel)
- **UI Framework**: SwiftUI
- **Persistence**: SwiftData (offline-first)
- **Concurrency**: Async/Await, Combine
- **Minimum iOS**: 17.0+

---

## Project Structure

```
SampattiTrack/
├── Models/
│   ├── Schema/           # SwiftData models (SD* prefix)
│   │   ├── SDAccount.swift
│   │   ├── SDTransaction.swift
│   │   ├── SDPosting.swift
│   │   ├── SDTag.swift
│   │   ├── SDUnit.swift
│   │   ├── SDPrice.swift
│   │   ├── SDExtensions.swift
│   │   └── SyncQueueItem.swift
│   └── *.swift           # Domain/DTO models
├── Views/
│   ├── Components/       # Reusable UI components
│   ├── Detail/           # Detail views
│   └── *View.swift       # Feature views
├── ViewModels/
│   └── *ViewModel.swift  # ViewModels for views
├── Services/
│   ├── APIClient.swift       # Network layer (singleton)
│   ├── AuthManager.swift     # Authentication (singleton)
│   ├── SyncManager.swift     # Sync coordinator
│   ├── SyncActor.swift       # Background sync actor
│   ├── DataRepository.swift  # Data access layer
│   └── DashboardCalculator.swift
├── Utils/
│   ├── CurrencyFormatter.swift
│   ├── DateFormatterCache.swift
│   ├── KeychainHelper.swift
│   └── OfflineQueueHelper.swift
└── Assets.xcassets
```

---

## Key Patterns

### 1. SwiftData Schema Models

Located in `Models/Schema/`. Prefix with `SD`.

```swift
@Model
class SDExample {
    @Attribute(.unique) var id: String
    var isSynced: Bool = true
    var updatedAt: Date = Date()
    
    var toExample: Example {
        Example(id: id, ...)
    }
}
```

**Required fields:**
- `@Attribute(.unique) var id: String`
- `var isSynced: Bool = true`
- `var updatedAt: Date = Date()`
- Conversion computed property: `var to<DomainModel>: <DomainModel>`

---

### 2. Services Pattern

| Service | Type | Purpose |
|---------|------|---------|
| `APIClient.shared` | Singleton | Network layer, HTTP requests |
| `AuthManager.shared` | Singleton | Authentication, token management |
| `SyncActor` | Actor | Background sync (model-isolated) |
| `SyncManager` | Class | Sync orchestration |
| `DataRepository` | Class | Data access abstraction |

**API call pattern:**
```swift
func fetchSomething(completion: @escaping (Result<T, APIError>) -> Void)
```

---

### 3. ViewModels

- Conform to `ObservableObject`
- Use `@Published` for state
- Inject container via `setContainer(_:)`
- Load data from SwiftData (offline-first)

```swift
class ExampleViewModel: ObservableObject {
    @Published var data: [Item] = []
    @Published var isLoading = false
    
    private var container: ModelContainer?
    
    func setContainer(_ container: ModelContainer) {
        self.container = container
        loadData()
    }
}
```

---

### 4. Offline-First Sync

1. Local changes queued via `SyncQueueItem`
2. Push local changes before pulling remote
3. `isSynced` flag tracks sync state
4. Background sync via `SyncActor` (actor isolation)

**Queue item structure:**
```swift
@Model
class SyncQueueItem {
    var endpoint: String
    var method: String
    var payload: Data?
    var retryCount: Int = 0
}
```

---

### 5. Configuration

- Base URL: `UserDefaults` key `api_base_url`
- Auth token: `KeychainHelper`
- Set via `ConfigurationView`

---

## Layer Responsibilities

| Layer | Responsibility |
|-------|----------------|
| **Views** | UI layout, user interaction only |
| **ViewModels** | State, presentation logic, data loading |
| **Services** | Network, auth, sync, data access |
| **Models/Schema** | SwiftData persistence |
| **Models** | Domain objects, DTOs |
| **Utils** | Formatters, helpers, caching |
