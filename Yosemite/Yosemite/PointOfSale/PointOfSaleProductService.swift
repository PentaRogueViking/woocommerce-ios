import Foundation
import protocol Networking.Network
import class Networking.ProductsRemote
import class Networking.AlamofireNetwork
import class WooFoundation.CurrencyFormatter
import class WooFoundation.CurrencySettings

public enum PointOfSaleProductServiceError: Error {
    case requestFailed
    case pageOutOfRange
    case unknown
}

/// Product provider for the Point of Sale feature
///
public final class PointOfSaleProductService: PointOfSaleItemServiceProtocol {
    private var siteID: Int64
    private var currencySettings: CurrencySettings
    private let productsRemote: ProductsRemote

    public init(siteID: Int64, currencySettings: CurrencySettings, network: Network) {
        self.siteID = siteID
        self.currencySettings = currencySettings
        self.productsRemote = ProductsRemote(network: network)
    }

    public convenience init(siteID: Int64,
                            currencySettings: CurrencySettings,
                            credentials: Credentials?) {
        self.init(siteID: siteID,
                  currencySettings: currencySettings,
                  network: AlamofireNetwork(credentials: credentials))
    }

    /// Provides a list of products for the Point of Sale, by fetching simple products from the remote, applying any eligibility criteria,
    /// and maps them to POSItem type.
    ///
    /// - pageNumber: Number of the page that should be retrieved. If none given, defaults to 1
    ///
    public func providePointOfSaleItems(pageNumber: Int = 1) async throws -> [POSDisplayableItem] {
        let products = try await productsRemote.loadSimpleProductsForPointOfSale(for: siteID, pageNumber: pageNumber)

        if pageNumber != 1 && products.count == 0 {
            throw PointOfSaleProductServiceError.pageOutOfRange
        }

        let eligibilityCriteria: [(Product) -> Bool] = [
            isNotVirtual,
            isNotDownloadable,
            hasPrice
        ]
        let filteredProducts = filterProducts(products: products, using: eligibilityCriteria)

        return mapProductsToPOSItems(products: filteredProducts)
    }

    // Maps result to POSProduct, and populate the output with:
    // - Formatted price based on store's currency settings.
    // - Product thumbnail, if any.
    private func mapProductsToPOSItems(products: [Product]) -> [POSOrderableItem] {
        let currencyFormatter = CurrencyFormatter(currencySettings: currencySettings)
        return products.map { product in
            let formattedPrice = currencyFormatter.formatAmount(product.price) ?? "-"
            let thumbnailSource = product.images.first?.src

            return POSProduct(id: UUID(),
                              name: product.name,
                              formattedPrice: formattedPrice,
                              productImageSource: thumbnailSource,
                              productID: product.productID,
                              price: product.price)
        }
    }
}

private extension PointOfSaleProductService {
    func filterProducts(products: [Product], using criteria: [(Product) -> Bool]) -> [Product] {
        return products.filter { product in
            criteria.allSatisfy { $0(product) }
        }
    }

    func isNotVirtual(product: Product) -> Bool {
        !product.virtual
    }

    func isNotDownloadable(product: Product) -> Bool {
        !product.downloadable
    }

    func hasPrice(product: Product) -> Bool {
        !product.price.isEmpty
    }
}



protocol POSChildFetchStrategy {
    associatedtype ParentItem: POSParentItem
    func fetchChildren(for item: ParentItem, page: Int) async throws -> [POSDisplayableItem]
}

import Networking
class ProductVariationFetchStrategy: POSChildFetchStrategy {
    let remote: ProductVariationsRemoteProtocol
    let siteID: Int64

    init (remote: ProductVariationsRemoteProtocol, siteID: Int64) {
        self.remote = remote
        self.siteID = siteID
    }

    convenience init(network: Network, siteID: Int64) {
        self.init(remote: ProductVariationsRemote(network: network), siteID: siteID)
    }

    func fetchChildren(for item: POSVariableProductParent, page: Int) async throws -> [POSDisplayableItem] {
        let variations = try await remote.loadAllProductVariations(for: siteID,
                                                                   productID: item.productID,
                                                                   variationIDs: [],
                                                                   context: nil,
                                                                   pageNumber: page,
                                                                   pageSize: 25)
        return variations.map { variation in
            return POSVariableProduct(id: UUID(),
                                      name: variation.description ?? "Variation \(variation.productVariationID)",
                                      formattedPrice: variation.price,
                                      productImageSource: variation.image?.src)
        }
    }
}
