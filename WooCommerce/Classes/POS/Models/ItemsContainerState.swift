import Foundation

enum ItemsContainerState {
    case loading
    case empty
    case error(PointOfSaleErrorState)
    case content

    var name: String {
        switch self {
        case .loading:
            return "Loading..."
        case .empty:
            return "No items found"
        case .error(let errorState):
            return errorState.title
        case .content:
            return "Items"
        }
    }
}

extension ItemsContainerState: Equatable {}
