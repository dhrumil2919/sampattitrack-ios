## 2024-05-24 - Sensitive Data in Decoding Error Logs
**Vulnerability:** The application was logging the entire raw response body when a JSON decoding error occurred in `APIClient.swift`. This could expose PII, authentication tokens, or financial data if the API returned a malformed but sensitive response (or a successful response that the client failed to parse).
**Learning:** Developers often add full body logging to debug "why" decoding failed (e.g., to see the field mismatch), but this practice violates security principles by persisting sensitive data into system logs which might be accessible to other apps or crash reporters.
**Prevention:** Use targeted logging that describes *where* the error occurred (endpoint) and *what* the error was (type mismatch) without dumping the *data* itself. If full body debugging is needed, it must be wrapped in `#if DEBUG` and ideally sanitized, but even then it's risky.

## 2025-05-27 - Phantom Security Features
**Vulnerability:** The documentation and team memory claimed a "Privacy Shield" was implemented to hide sensitive financial data in the app switcher, but the feature was entirely missing from the codebase.
**Learning:** Security features in documentation often drift from reality. Developers might assume a "standard" feature exists because it's mentioned in a spec or a wiki, but without code verification (grep), these features may be missing or regressed.
**Prevention:** Verify the existence of security controls by auditing the code, not just the documentation. Use automated UI tests to verify the presence of overlays during background states.
