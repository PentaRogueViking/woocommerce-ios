import Foundation

struct PointOfSaleOrderTotals: Equatable {
    let cartTotal: String
    let orderTotal: String
    let taxTotal: String
    let formatter: (String) -> String

    var cartTotalFormatted: String {
        formatter(cartTotal)
    }

    var orderTotalFormatted: String {
        formatter(orderTotal)
    }

    var taxTotalFormatted: String {
        formatter(taxTotal)
    }
}

extension PointOfSaleOrderTotals {
    static func == (lhs: PointOfSaleOrderTotals, rhs: PointOfSaleOrderTotals) -> Bool {
        lhs.cartTotal == rhs.cartTotal &&
        lhs.orderTotal == rhs.orderTotal &&
        lhs.taxTotal == rhs.taxTotal
    }
}
