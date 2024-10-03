//
//  InventoryListViewModel.swift
//  XCAInventoryTracker
//
//  Created by Đoàn Văn Khoan on 3/10/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore

class InventoryListViewModel: ObservableObject {
    @Published var items = [InventoryItem]()
    
    @MainActor
    func listenToItems() {
        Firestore.firestore().collection("items")
            .order(by: "name")
            .limit(toLast: 100)
            .addSnapshotListener { snapshot, error in
                guard let snapshot else {
                    print("Error fetching snapshot: \(error?.localizedDescription ?? "error")")
                    return
                }
                
                let docs = snapshot.documents

                let items = docs.compactMap {
                    try? $0.data(as: InventoryItem.self)
                }
                
                
                withAnimation {
                    self.items = items
                }
            }
    }
}
