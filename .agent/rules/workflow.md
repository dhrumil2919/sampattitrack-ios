# Coding Workflow

## Pre-Coding Analysis (MANDATORY)

Before ANY code change, you MUST:

### 1. Understand Existing Patterns
- [ ] Scan `Models/Schema/` for data models
- [ ] Scan `Models/` for domain models
- [ ] Check `Services/` for existing functionality
- [ ] Review `Views/Components/` for reusable UI

### 2. Identify Reusable Code
- [ ] Search for similar functionality
- [ ] Check if a service method already exists
- [ ] Look for existing UI components
- [ ] Review utilities in `Utils/`

### 3. Clarify Requirements
If ANY of the following is unclear, ASK before coding:
- Where should new files go?
- Should I extend an existing service or create new?
- Does this require sync support?
- Are there related tests to update?

---

## Implementation Workflow

For each task, follow this sequence:

### Step 1: Restate Understanding
Confirm your understanding of the task before coding.

### Step 2: Identify Affected Modules
List all files and modules that will be touched.

### Step 3: Propose Approach
Describe the implementation approach, including:
- New files to create
- Existing files to modify
- Patterns to follow

### Step 4: List Changes
Provide a concrete list:
```
Files to ADD:
- Models/Schema/SDNewEntity.swift
- ViewModels/NewEntityViewModel.swift
- Views/NewEntityView.swift

Files to MODIFY:
- Services/APIClient.swift (add fetch method)
```

### Step 5: Implement
Follow all conventions and patterns.

### Step 6: Verify Build
Run build command to confirm no errors.

### Step 7: Document Risks
Highlight any assumptions, edge cases, or risks.

---

## Adding New Features Checklist

### Models
- [ ] Domain model in `Models/`
- [ ] SwiftData model in `Models/Schema/` with `SD` prefix
- [ ] Include `isSynced`, `updatedAt` fields
- [ ] Provide `to<DomainModel>` conversion property

### Views
- [ ] Place in correct folder (`Views/`, `Components/`, `Detail/`)
- [ ] Follow `*View` naming
- [ ] Keep logic minimal—delegate to ViewModel
- [ ] Use existing components where possible

### ViewModels
- [ ] One ViewModel per major view
- [ ] Use `@Published` for reactive state
- [ ] Load from SwiftData (offline-first)
- [ ] Inject container via `setContainer(_:)`

### Services
- [ ] Extend existing services first
- [ ] New API calls go in `APIClient.swift`
- [ ] Use `Result<T, APIError>` pattern

### Sync Support
- [ ] New entities need `SyncQueueItem` integration
- [ ] Include `isSynced` flag in schema
- [ ] Add push/pull logic to `SyncActor`

---

## Quality Checklist (MUST PASS)

Before completing ANY task:

- [ ] Code follows MVVM architecture
- [ ] SwiftData models have `SD` prefix and sync fields
- [ ] No duplicate abstractions introduced
- [ ] Files in correct folders
- [ ] Naming matches conventions
- [ ] No unused code or imports
- [ ] Offline-first pattern preserved
- [ ] No breaking changes to sync logic
- [ ] Build compiles without errors
