import SwiftUI
import SwiftData

/// TagListView - OFFLINE-FIRST
/// Uses @Query for local SDTag data. No API calls.
struct TagListView: View {
    @Query(sort: \SDTag.name) private var tags: [SDTag]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingCreateSheet = false
    @State private var editingTag: SDTag? = nil
    
    var body: some View {
        NavigationView {
            Group {
                if tags.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Tags")
                            .font(.headline)
                        Text("Create tags to categorize your transactions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Create Tag") {
                            showingCreateSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(tags) { tag in
                            SDTagRowView(tag: tag)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingTag = tag
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let tag = tags[index]
                                modelContext.delete(tag)
                            }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                SDTagEditSheet(
                    tag: nil,
                    onSave: { name, description, color in
                        let newTag = SDTag(
                            id: UUID().uuidString,
                            name: name,
                            desc: description,
                            color: color,
                            isSynced: false
                        )
                        modelContext.insert(newTag)
                        try? modelContext.save()
                        showingCreateSheet = false
                    },
                    onCancel: {
                        showingCreateSheet = false
                    }
                )
            }
            .sheet(item: $editingTag) { tag in
                SDTagEditSheet(
                    tag: tag,
                    onSave: { name, description, color in
                        tag.name = name
                        tag.desc = description
                        tag.color = color
                        tag.isSynced = false
                        try? modelContext.save()
                        editingTag = nil
                    },
                    onCancel: {
                        editingTag = nil
                    }
                )
            }
        }
    }
}

// MARK: - SDTag Row View

struct SDTagRowView: View {
    let tag: SDTag
    
    var tagColor: Color {
        if let colorHex = tag.color {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tagColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.headline)
                if let description = tag.desc, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SDTag Edit Sheet

struct SDTagEditSheet: View {
    let tag: SDTag?
    let onSave: (String, String?, String?) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedColor: Color = .blue
    
    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .teal, .cyan, .blue, .indigo, .purple, .pink, .brown
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(presetColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(tag == nil ? "New Tag" : "Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(name, description.isEmpty ? nil : description, selectedColor.toHex())
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let tag = tag {
                    name = tag.name
                    description = tag.desc ?? ""
                    if let colorHex = tag.color {
                        selectedColor = Color(hex: colorHex) ?? .blue
                    }
                }
            }
        }
    }
}

// MARK: - Color Extensions

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}
