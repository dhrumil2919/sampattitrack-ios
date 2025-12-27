# Rules & Prohibitions

## Strict Prohibitions

You MUST NOT:

### Architecture
- ❌ Create new architectural patterns without explicit approval
- ❌ Bypass existing abstractions (`APIClient`, `AuthManager`, `SyncActor`)
- ❌ Create parallel services that duplicate existing functionality
- ❌ Put business logic in Views
- ❌ Put UI logic in ViewModels (presentation logic only)

### Structure
- ❌ Reorganize folder structure without explicit instruction
- ❌ Move files between modules without approval
- ❌ Create new top-level folders

### Dependencies
- ❌ Add new dependencies or frameworks without approval
- ❌ Upgrade existing dependencies without approval
- ❌ Import frameworks not already in the project

### Code Quality
- ❌ Hardcode URLs, secrets, or environment values
- ❌ Duplicate models, services, or utilities
- ❌ Leave unused code or imports
- ❌ Skip the `isSynced` pattern for new SwiftData models
- ❌ Create non-singleton services that should be singletons

### Refactoring
- ❌ Rewrite working code unless explicitly asked
- ❌ Change public API signatures without approval
- ❌ Modify sync logic without careful review

---

## Required Patterns

You MUST:

### Models
- ✅ Use `SD` prefix for all SwiftData models
- ✅ Include `isSynced` and `updatedAt` in schema models
- ✅ Provide `to<DomainModel>` conversion property
- ✅ Use `@Attribute(.unique)` for primary keys

### Views
- ✅ Place components in `Views/Components/`
- ✅ Use `*View` suffix for all views
- ✅ Keep views focused on UI only
- ✅ Reuse existing components

### ViewModels
- ✅ Use `@Published` for all state
- ✅ Accept `ModelContainer` via `setContainer(_:)`
- ✅ Load from SwiftData first (offline-first)
- ✅ Conform to `ObservableObject`

### Services
- ✅ Use singleton pattern for shared services
- ✅ Use `Result<T, APIError>` for API callbacks
- ✅ Add new API methods to `APIClient.swift`

### Sync
- ✅ Queue local changes via `SyncQueueItem`
- ✅ Track sync state with `isSynced` flag
- ✅ Handle offline scenarios gracefully

---

## Approval Required For

The following changes require explicit user approval:

1. Adding new Swift packages or dependencies
2. Creating new architectural patterns
3. Modifying the sync engine (`SyncActor`, `SyncManager`)
4. Changing the folder structure
5. Modifying `APIClient` error handling
6. Changing authentication flow
7. Adding new configuration keys

---

## Communication Guidelines

When working on tasks:

- ✅ Be concise and technical
- ✅ Call out trade-offs explicitly
- ✅ Flag unclear requirements early
- ✅ Prefer explicit over implicit behavior
- ✅ Document assumptions and risks
- ✅ Act like a senior iOS code reviewer

When uncertain:
- ✅ ASK before implementing
- ✅ Propose alternatives with trade-offs
- ✅ Reference existing patterns in the codebase
