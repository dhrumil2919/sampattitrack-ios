# SampattiTrack

SampattiTrack is a comprehensive iOS application designed to help you track your assets, expenses, and overall financial health. Built with **SwiftUI** and **SwiftData**, it offers a modern, seamless, and offline-first experience for managing your personal finances.

## Features

*   **Account Management**: Create and organize accounts with custom categories, types, and currencies.
*   **Transaction Tracking**: Record complex transactions with support for multiple postings (split transactions) to accurately reflect money movement.
*   **Seamless Synchronization**: Keep your data in sync with a backend server using the custom `SyncManager`, ensuring your financial records are up-to-date across devices.
*   **Dashboard & Insights**: Visualize your financial data with interactive charts and insight cards.
*   **Unit & Price Tracking**: Track different units (e.g., stocks, commodities) and their prices.
*   **Tagging System**: Organize transactions and analyze spending habits with custom tags.
*   **Offline First**: Built with SwiftData for robust local persistence, allowing you to view and modify data without an internet connection.

## Tech Stack

*   **Language**: Swift 5.9+
*   **UI Framework**: SwiftUI
*   **Persistence**: SwiftData
*   **Concurrency**: Async/Await, Combine
*   **Architecture**: MVVM (Model-View-ViewModel)

## Requirements

*   **iOS**: 17.0+
*   **Xcode**: 15.0+

## Getting Started

### Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/yourusername/SampattiTrack.git
    cd SampattiTrack
    ```

2.  Open the project in Xcode:
    ```bash
    open SampattiTrack/SampattiTrack.xcodeproj
    ```

3.  Build and run the app on your simulator or physical device.

### Configuration

The application requires a backend API to sync data. The API Base URL is stored in `UserDefaults`.

1.  Launch the app.
2.  Navigate to the **Configuration** view (usually accessible via settings or a gear icon).
3.  Enter your API Base URL (e.g., `https://api.sampattitrack.com`).
    *   *Note: If you are running a local backend, you might use `http://localhost:8080`.*

## Architecture Overview

SampattiTrack follows a clean **MVVM** architecture:

*   **Models**:
    *   `Schema` models (e.g., `SDTransaction`, `SDAccount`) define the local database schema using SwiftData.
    *   Domain models (e.g., `Transaction`, `Account`) are used for data transfer and business logic.
*   **Views**: SwiftUI views are responsible for the UI layout and user interaction.
*   **ViewModels**: Handle business logic, data transformation, and state management for the views.
*   **Services**:
    *   `SyncManager`: Orchestrates the bidirectional synchronization between the local SwiftData store and the remote API.
    *   `APIClient`: A shared network layer that handles HTTP requests and responses.

## Contributing

Contributions are welcome! If you have suggestions for improvements or bug fixes, please follow these steps:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## License

[Add License Information Here]
