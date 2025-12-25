import SwiftUI

struct PrivacyOverlay: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)

                Text("SampattiTrack")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Content hidden for your privacy")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    PrivacyOverlay()
}
