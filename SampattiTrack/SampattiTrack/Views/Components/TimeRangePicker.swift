import SwiftUI

struct TimeRangePicker: View {
    @Binding var selection: DateRange

    // Available Ranges
    let ranges: [DateRange] = [
        .last30Days(),
        .lastMonth(),
        .ytd(),
        .all()
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ranges, id: \.name) { range in
                    Button(action: {
                        selection = range
                    }) {
                        Text(range.name)
                            .font(.subheadline)
                            .fontWeight(selection.name == range.name ? .bold : .regular)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selection.name == range.name ? Color.blue : Color(.secondarySystemBackground))
                            .foregroundColor(selection.name == range.name ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}
