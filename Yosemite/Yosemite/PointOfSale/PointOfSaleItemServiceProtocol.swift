/// POSDisplayableItem contains only the properties required to show an item in the Point Of Sale.
/// The item may only be visible, not neccesarily something you can add to the cart.
/// This protocol will become less specific in future; e.g. not all items in the POS necessarily have a price.
public protocol POSDisplayableItem {
    var id: UUID { get }
    var name: String { get }
    var formattedPrice: String { get }
    var productImageSource: String? { get }

    func isEqual(to other: POSDisplayableItem) -> Bool
}

public extension POSDisplayableItem where Self: Equatable {
    func isEqual(to other: POSDisplayableItem) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

public extension Sequence where Element == POSDisplayableItem {
    func isEqual(to other: any Sequence<Element>) -> Bool {
        let lhsArray = Array(self)
        let rhsArray = Array(other)

        guard lhsArray.count == rhsArray.count else { return false }

        return zip(lhsArray, rhsArray).allSatisfy { lhs, rhs in
            lhs.isEqual(to: rhs)
        }
    }
}

/// POSOrderableItem extends a displayable item with the functions required for using it in an order.
/// This currently includes adding it, and checking whether it's already in an order.
/// This may need to become less specific in future, e.g. we currently convert it to a product input, but
/// other order items might be added as fees or similar. at that point, we will need a different function requirement here.
public protocol POSOrderableItem: POSDisplayableItem & PointOfSaleItemOrderItemConvertable {}

public protocol PointOfSaleItemOrderItemConvertable {
    func toOrderSyncProductInput(quantity: Decimal) -> OrderSyncProductInput
    func matches(orderItem: OrderItem) -> Bool
}

public protocol PointOfSaleItemServiceProtocol {
    func providePointOfSaleItems(pageNumber: Int) async throws -> [POSDisplayableItem]
}

// Default implementation for convenience, so we do not need to pass the first page explicitly
// if no pageNumber is given.
extension PointOfSaleItemServiceProtocol {
    func providePointOfSaleItems(pageNumber: Int = 1) async throws -> [POSDisplayableItem] {
        try await providePointOfSaleItems(pageNumber: pageNumber)
    }
}

public protocol POSParentItem: POSDisplayableItem & PointOfSaleParentItemProtocol {}

public protocol PointOfSaleParentItemProtocol {
    var childrenState: ItemListState { get set }
    var currentPage: Int { get set }
    var hasMoreChildren: Bool { get set }
}

public enum ItemListState: Equatable {
    case empty
    case initialLoading
    case loading(_ currentItems: [POSDisplayableItem])
    case loaded(_ items: [POSDisplayableItem])
    case error(PointOfSaleErrorState)


    public static func == (lhs: ItemListState, rhs: ItemListState) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty),
            (.initialLoading, .initialLoading):
            return true
        case (.loading(let lhsItems), .loading(let rhsItems)),
            (.loaded(let lhsItems), .loaded(let rhsItems)):
            return lhsItems.isEqual(to: rhsItems)
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

public struct PointOfSaleErrorState: Equatable {
    public let title: String
    public let subtitle: String
    public let buttonText: String

    public init(title: String, subtitle: String, buttonText: String) {
        self.title = title
        self.subtitle = subtitle
        self.buttonText = buttonText
    }
}
