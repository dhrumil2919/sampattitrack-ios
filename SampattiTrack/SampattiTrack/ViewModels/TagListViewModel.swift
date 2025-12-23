import Foundation
import SwiftData
import Combine

/// TagListViewModel - OFFLINE-FIRST
/// Uses local SwiftData for tag management. No API calls.
class TagListViewModel: ObservableObject {
    @Published var tags: [SDTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchTags()
    }
    
    /// Fetch tags from LOCAL SwiftData - no API call
    func fetchTags() {
        guard let context = modelContext else { return }
        
        isLoading = true
        do {
            let descriptor = FetchDescriptor<SDTag>(sortBy: [SortDescriptor(\.name)])
            tags = try context.fetch(descriptor)
            isLoading = false
        } catch {
            errorMessage = "Failed to load tags: \(error)"
            isLoading = false
        }
    }
    
    /// Create tag locally with isSynced=false
    func createTag(name: String, description: String?, color: String?) {
        guard let context = modelContext else { return }
        
        let newTag = SDTag(
            id: UUID().uuidString,
            name: name,
            desc: description,
            color: color,
            isSynced: false
        )
        context.insert(newTag)
        
        do {
            try context.save()
            fetchTags()
        } catch {
            errorMessage = "Failed to create tag: \(error)"
        }
    }
    
    /// Update tag locally with isSynced=false
    func updateTag(id: String, name: String, description: String?, color: String?) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<SDTag>(predicate: #Predicate { $0.id == id })
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
                existing.desc = description
                existing.color = color
                existing.isSynced = false
                try context.save()
                fetchTags()
            }
        } catch {
            errorMessage = "Failed to update tag: \(error)"
        }
    }
    
    /// Delete tag locally
    func deleteTag(id: String) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<SDTag>(predicate: #Predicate { $0.id == id })
        
        do {
            if let existing = try context.fetch(descriptor).first {
                context.delete(existing)
                try context.save()
                fetchTags()
            }
        } catch {
            errorMessage = "Failed to delete tag: \(error)"
        }
    }
}
