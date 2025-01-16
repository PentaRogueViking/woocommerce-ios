import Foundation
import Codegen
import enum Yosemite.POSItem

struct ItemsStackState {
    var root: ItemListState
    var itemStates: [POSItem: ItemListState]
}

extension ItemsStackState: Equatable, GeneratedCopiable {}
