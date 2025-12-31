import Foundation

/// Sentinel 🛡️: Utility class for security-related validation and sanitization.
/// Centralizes input validation to prevent Denial of Service (DoS) via large payloads
/// and ensures data consistency.
struct SecurityUtils {

    // Default Limits
    static let maxNameLength = 100
    static let maxCodeLength = 20
    static let maxDescriptionLength = 255
    static let maxNoteLength = 1000

    /// Validates that the input string does not exceed the maximum length.
    /// - Parameters:
    ///   - input: The string to validate.
    ///   - maxLength: The maximum allowed length.
    /// - Returns: `true` if the input length is less than or equal to `maxLength`, `false` otherwise.
    static func isValidLength(_ input: String, maxLength: Int) -> Bool {
        return input.count <= maxLength
    }

    /// Sanitizes the input string by trimming whitespace and newlines.
    /// - Parameter input: The string to sanitize.
    /// - Returns: The sanitized string.
    static func sanitizeInput(_ input: String) -> String {
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Validates if the input contains only allowed characters for a code (alphanumeric and underscore).
    /// - Parameter input: The string to validate.
    /// - Returns: `true` if valid, `false` otherwise.
    static func isValidCode(_ input: String) -> Bool {
        // Allow empty string (let required check handle it) or check strictly
        if input.isEmpty { return true }
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        return input.rangeOfCharacter(from: allowedCharacterSet.inverted) == nil
    }
}
