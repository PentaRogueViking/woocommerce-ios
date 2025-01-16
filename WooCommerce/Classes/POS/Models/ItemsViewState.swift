import Foundation
import Codegen

@Observable
@available(iOS 17.0, *)
final class ItemsViewState {
    var containerState: ItemsContainerState
    var itemsStack: ItemsStackState

    init(containerState: ItemsContainerState, itemsStack: ItemsStackState) {
        self.containerState = containerState
        self.itemsStack = itemsStack
    }
}

@available(iOS 17.0, *)
extension ItemsViewState: GeneratedCopiable, Equatable {
    static func == (lhs: ItemsViewState, rhs: ItemsViewState) -> Bool {
        return lhs.containerState == rhs.containerState &&
        lhs.itemsStack == rhs.itemsStack
    }
}
