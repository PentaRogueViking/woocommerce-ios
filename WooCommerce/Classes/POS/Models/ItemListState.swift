import enum Yosemite.POSItem
import Codegen

enum ItemListState {
    case loading(_ currentItems: [POSItem])
    case loaded(_ items: [POSItem], hasMoreItems: Bool)
    case inlineError(_ items: [POSItem], error: PointOfSaleErrorState)
    case error(PointOfSaleErrorState)

    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .loading(let items):
            return "Loading \(items.count) items..."
        case .loaded(let items, let hasMore):
            return "Loaded \(items.count) items\(hasMore ? ", more available" : "")"
        case .inlineError(let items, let error):
            return "Error loading \(items.count) existing items: \(error)"
        case .error(let error):
            return "Error: \(error)"
        }
    }
}

extension ItemListState {
    var items: [POSItem] {
        switch self {
        case .loading(let items),
                .loaded(let items, _),
                .inlineError(let items, _):
            return items
        case .error:
            return []
        }
    }
}

extension ItemListState: Equatable, GeneratedCopiable {}
