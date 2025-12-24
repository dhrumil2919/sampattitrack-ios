import Foundation
import Combine

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()
    
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "api_base_url")
        }
    }
    
    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "api_base_url") ?? ""
    }
    
    enum APIError: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case serverError(String)
        case unauthorized
    }
    
    // Request with Encodable Body
    func request<T: Decodable, B: Encodable>(_ endpoint: String, method: String = "GET", body: B, completion: @escaping (Result<T, APIError>) -> Void) {
        do {
            let data = try JSONEncoder().encode(body)
            request(endpoint, method: method, body: data, completion: completion)
        } catch {
            completion(.failure(.networkError(error)))
        }
    }
    
    // Base Request
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil, completion: @escaping (Result<T, APIError>) -> Void) {
        let cleanBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanBaseURL.isEmpty {
             completion(.failure(.invalidURL))
             return
        }
         
        guard let url = URL(string: cleanBaseURL + endpoint) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.networkError(NSError(domain: "InvalidResponse", code: 0))))
                return
            }
            
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
                completion(.failure(.unauthorized))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.serverError("Status code: \(httpResponse.statusCode)")))
                return
            }
            
            guard let data = data else {
                completion(.failure(.serverError("No data")))
                return
            }
            
            do {
                if T.self == TransactionResponse.self && data.isEmpty {
                     // Handle empty response if needed, but Decodable usually needs data
                }
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                // Sentinel: Do not log full response body as it may contain sensitive data
                print("Decoding failed for endpoint: \(endpoint). Error: \(error)")
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
    
    // MARK: - Price and Unit APIs
    
    /// Lookup price for a specific unit code on a given date
    func lookupPrice(unitCode: String, date: String? = nil, completion: @escaping (Result<PriceLookupResponse, APIError>) -> Void) {
        var endpoint = "/prices/lookup?unit_code=\(unitCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? unitCode)"
        if let date = date {
            endpoint += "&date=\(date)"
        }
        request(endpoint, method: "GET", completion: completion)
    }
    
    /// Fetch list of all available units
    func listUnits(completion: @escaping (Result<UnitListResponse, APIError>) -> Void) {
        request("/units", method: "GET", completion: completion)
    }
    
    // MARK: - Tag APIs
    
    /// Fetch top tags by expense amount
    func fetchTopTags(completion: @escaping (Result<TopTagsResponse, APIError>) -> Void) {
        request("/analysis/tags/top", method: "GET", completion: completion)
    }
    
    /// Fetch all tags
    func listTags(completion: @escaping (Result<TagListResponse, APIError>) -> Void) {
        request("/tags", method: "GET", completion: completion)
    }
    
    /// Create a new tag
    func createTag(_ tag: CreateTagRequest, completion: @escaping (Result<SingleTagResponse, APIError>) -> Void) {
        request("/tags", method: "POST", body: tag, completion: completion)
    }
    
    /// Update an existing tag
    func updateTag(id: String, _ tag: CreateTagRequest, completion: @escaping (Result<SingleTagResponse, APIError>) -> Void) {
        request("/tags/\(id)", method: "PUT", body: tag, completion: completion)
    }
    
    /// Delete a tag
    func deleteTag(id: String, completion: @escaping (Result<EmptyResponse, APIError>) -> Void) {
        request("/tags/\(id)", method: "DELETE", completion: completion)
    }
    
    // MARK: - Raw JSON Request (for offline queue)
    
    /// Request with raw JSON dictionary (for queue items)
    func requestRaw<T: Decodable>(_ endpoint: String, method: String = "GET", body: [String: Any]?, completion: @escaping (Result<T, APIError>) -> Void) {
        do {
            let data = body != nil ? try JSONSerialization.data(withJSONObject: body!) : nil
            request(endpoint, method: method, body: data, completion: completion)
        } catch {
            completion(.failure(.networkError(error)))
        }
    }
}

