# Naming Conventions

## File & Type Naming

| Type | Convention | Example |
|------|------------|---------|
| SwiftData Model | `SD` prefix | `SDAccount`, `SDTransaction` |
| Domain Model | Plain name | `Account`, `Transaction` |
| DTO | `*DTO` suffix | `TransactionDTO`, `AccountDTO` |
| View | `*View` suffix | `DashboardView`, `AccountListView` |
| ViewModel | `*ViewModel` suffix | `DashboardViewModel` |
| Component | Descriptive name | `InsightCard`, `TrendIndicator` |
| Helper/Utility | `*Helper` or `*Formatter` | `KeychainHelper`, `CurrencyFormatter` |
| Response Model | `*Response` suffix | `TagListResponse` |

---

## File Placement

| File Type | Location |
|-----------|----------|
| SwiftData models | `Models/Schema/` |
| Domain/DTO models | `Models/` |
| Main views | `Views/` |
| Reusable components | `Views/Components/` |
| Detail/drill-down views | `Views/Detail/` |
| ViewModels | `ViewModels/` |
| Network, auth, sync | `Services/` |
| Formatters, helpers | `Utils/` |

---

## Method Naming

### ViewModels
```swift
func fetchAll()           // Load all data
func loadData()           // Load from local store
func refresh()            // Force refresh
func setContainer(_:)     // Inject ModelContainer
```

### Services
```swift
func fetch<Entity>()                    // GET requests
func create<Entity>()                   // POST requests
func update<Entity>()                   // PUT requests
func delete<Entity>()                   // DELETE requests
func request<T>(_:method:body:completion:)  // Generic request
```

### Models
```swift
var to<DomainModel>: <DomainModel>     // Conversion property
var metadataDictionary: [String: Any]? // JSON helpers
```

---

## Variable Naming

| Pattern | Example |
|---------|---------|
| Boolean state | `isLoading`, `isSynced`, `hasError` |
| Optional cache | `cachedXIRR`, `xirrCachedAt` |
| Published state | `@Published var items: [Item] = []` |
| Computed flags | `var isValid: Bool { ... }` |

---

## MARK Comments

Use `// MARK: -` for section organization:

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - API Calls
// MARK: - Helpers
```

---

## SwiftData Specifics

### Model Class
```swift
@Model
class SDExample {
    @Attribute(.unique) var id: String  // Primary key
    var name: String                     // Required field
    var optionalField: String?           // Optional field
    var isSynced: Bool = true            // Sync flag
    var updatedAt: Date = Date()         // Timestamp
}
```

### Fetch Descriptors
```swift
let descriptor = FetchDescriptor<SDAccount>(
    predicate: #Predicate { $0.category == "Assets" },
    sortBy: [SortDescriptor(\.name)]
)
```
