import enum Yosemite.ItemListState

extension ItemListState {
    var isLoadingAfterInitialLoad: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }
}
