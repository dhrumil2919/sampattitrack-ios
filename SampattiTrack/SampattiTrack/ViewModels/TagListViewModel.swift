import Foundation
import Combine

class TagListViewModel: ObservableObject {
    @Published var tags: [Tag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchTags() {
        isLoading = true
        errorMessage = nil
        
        APIClient.shared.listTags { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    if response.success {
                        self?.tags = response.data
                    }
                case .failure(let error):
                    self?.errorMessage = "Failed to load tags: \(error)"
                }
            }
        }
    }
    
    func createTag(name: String, description: String?, color: String?, completion: @escaping (Bool) -> Void) {
        let request = CreateTagRequest(name: name, description: description, color: color)
        
        APIClient.shared.createTag(request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self?.fetchTags()
                        completion(true)
                    } else {
                        completion(false)
                    }
                case .failure:
                    completion(false)
                }
            }
        }
    }
    
    func updateTag(id: String, name: String, description: String?, color: String?, completion: @escaping (Bool) -> Void) {
        let request = CreateTagRequest(name: name, description: description, color: color)
        
        APIClient.shared.updateTag(id: id, request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self?.fetchTags()
                        completion(true)
                    } else {
                        completion(false)
                    }
                case .failure:
                    completion(false)
                }
            }
        }
    }
    
    func deleteTag(id: String, completion: @escaping (Bool) -> Void) {
        APIClient.shared.deleteTag(id: id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self?.fetchTags()
                        completion(true)
                    } else {
                        completion(false)
                    }
                case .failure:
                    completion(false)
                }
            }
        }
    }
}
