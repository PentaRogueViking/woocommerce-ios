import WooFoundation

struct POSProduct: POSOrderableItem, OrderSyncProductTypeProtocol, Equatable {
    // POSOrderableItem
    let id: UUID
    let name: String
    let formattedPrice: String
    var productImageSource: String?

    // OrderSyncProductTypeProtocol
    let productID: Int64
    let price: String
    let productType: ProductType = .simple
    let bundledItems: [ProductBundleItem] = []
}

extension POSProduct: Hashable {
    func toOrderSyncProductInput(quantity: Decimal) -> OrderSyncProductInput {
        OrderSyncProductInput(product: .product(self), quantity: quantity)
    }

    func matches(orderItem: OrderItem) -> Bool {
        // TODO: https://github.com/woocommerce/woocommerce-ios/pull/13328/files#r1687631533
        // - we should also add a logic to compare prices
        // - but we should be aware of the fact that some
        // products already have tax in the price
        return productID == orderItem.productID
    }
}

struct POSVariableProductParent: POSDisplayableItem, POSParentItem, Equatable {
    static func == (lhs: POSVariableProductParent, rhs: POSVariableProductParent) -> Bool {
        return lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.formattedPrice == rhs.formattedPrice &&
        lhs.productImageSource == rhs.productImageSource
    }
    
    // POSDisplayableItem
    let id: UUID
    let name: String
    let formattedPrice: String
    let productImageSource: String?

    // POSParentItem
    var childrenState: ItemListState
    var currentPage: Int
    var hasMoreChildren: Bool

    // VariableProduct fetch requirements
    let productID: Int64
}

struct POSVariableProduct: POSOrderableItem, Equatable {
    // POSDisplayableItem
    var id: UUID
    var name: String
    var formattedPrice: String
    var productImageSource: String?

    // POSOrderableItem
    func toOrderSyncProductInput(quantity: Decimal) -> OrderSyncProductInput {
        <#code#>
    }

    func matches(orderItem: OrderItem) -> Bool {
        <#code#>
    }
}
