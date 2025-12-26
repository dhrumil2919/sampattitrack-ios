import SwiftUI

struct PrivacyOverlay: View {
    var body: some View {
        ZStack {
            // Solid background to block visibility
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)

                Text("SampattiTrack")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Content hidden for privacy")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Privacy Shield active. Content hidden.")
    }
}

#Preview {
    PrivacyOverlay()
}
