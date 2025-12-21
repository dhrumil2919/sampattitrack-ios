import Foundation
import SwiftData

@Model
class SDTransaction {
    @Attribute(.unique) var id: UUID
    var date: String
    var desc: String // Renamed from description to avoid clash
    var note: String?
    
    @Relationship(deleteRule: .cascade, inverse: \SDPosting.transaction)
    var postings: [SDPosting]?
    
    // Sync Metadata
    var isSynced: Bool = false
    var isDeleted: Bool = false
    var updatedAt: Date = Date()
    
    init(id: UUID = UUID(), date: String, desc: String, note: String? = nil, isSynced: Bool = false) {
        self.id = id
        self.date = date
        self.desc = desc
        self.note = note
        self.isSynced = isSynced
        self.updatedAt = Date()
    }
    
    var toTransaction: Transaction {
        Transaction(
            id: id,
            date: date,
            description: desc,
            note: note,
            postings: (postings ?? []).map { p in
                Posting(
                    id: p.id,
                    accountID: p.accountID,
                    accountName: p.accountName,
                    amount: p.amount,
                    quantity: p.quantity,
                    unitCode: p.unitCode,
                    tags: nil
                )
            }
        )
    }
}
