import Foundation
import Codegen
import enum Yosemite.POSItem

@Observable
@available(iOS 17.0, *)
final class ItemsStackState {
    var root: ItemListState
    var itemStates: [POSItem: ItemListState]

    init(root: ItemListState, itemStates: [POSItem : ItemListState]) {
        self.root = root
        self.itemStates = itemStates
    }

    var description: String {
        let itemStatesDescription = itemStates.map { (key, value) in
            return "\(key.typeName): \(value.description)"
        }
        return "ItemsStackState(\(root.description), \(itemStatesDescription.joined(separator: ", ")))"
    }
}

@available(iOS 17.0, *)
extension ItemsStackState: Equatable, GeneratedCopiable {
    static func ==(lhs: ItemsStackState, rhs: ItemsStackState) -> Bool {
        return lhs.root == rhs.root &&
        lhs.itemStates == rhs.itemStates
    }
}
