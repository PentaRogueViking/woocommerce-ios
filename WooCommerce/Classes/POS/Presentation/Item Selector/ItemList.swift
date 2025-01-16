import SwiftUI
import enum Yosemite.POSItem
import protocol WooFoundation.Analytics
import struct Yosemite.POSVariableParentProduct

/// Displays a list of POS items or placeholder card based on the given state.
@available(iOS 17.0, *)
struct ItemList<HeaderView: View>: View {
    @Environment(\.floatingControlAreaSize) private var floatingControlAreaSize: CGSize
    @Environment(PointOfSaleAggregateModel.self) var posModel: PointOfSaleAggregateModel
    @StateObject private var infiniteScrollTriggerDeterminer = ThresholdInfiniteScrollTriggerDeterminer()

    private var state: ItemListState {
        switch node {
        case .root:
            posModel.itemsViewState.itemsStack.root
        case .parent(let item):
            posModel.itemsViewState.itemsStack.itemStates[item] ?? .loaded([], hasMoreItems: false)
        }
    }
    private let node: ItemListBaseItem
    private let headerView: HeaderView

    init(node: ItemListBaseItem = .root,
         @ViewBuilder headerView: () -> HeaderView = { EmptyView() }) {
        self.node = node
        self.headerView = headerView()
    }

    var body: some View {
        InfiniteScrollView(
            triggerDeterminer: infiniteScrollTriggerDeterminer,
            loadMore: {
                guard case .loaded(_, let hasMoreItems) = state,
                      hasMoreItems
                else { return }
                await posModel.loadNextItems(base: node)
            },
            content: {
                LazyVStack {
                    headerView

                    ForEach(state.items) { item in
                        ItemListRow(item: item)
                    }

                    footerRows
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Constants.itemListPadding)
                .padding(.bottom, floatingControlAreaSize.height)
            }
        )
    }

    @ViewBuilder var footerRows: some View {
        VStack {
            switch state {
            case .loading:
                GhostItemCardView()
            case .inlineError(_, let errorState):
                ItemListErrorCardView(errorState: errorState,
                                      buttonAction: {
                    Task { @MainActor in
                        await posModel.loadNextItems(base: node)
                    }
                })
            case .loaded, .error:
                EmptyView()
            }
        }
    }
}

private enum Constants {
    static let itemListPadding: CGFloat = 16
}

@available(iOS 17.0, *)
private struct ItemListRow: View {
    let item: POSItem
    let analytics: Analytics = ServiceLocator.analytics
    @Environment(PointOfSaleAggregateModel.self) var posModel: PointOfSaleAggregateModel

    var body: some View {
        switch item {
        case let .simpleProduct(product):
            Button(action: {
                posModel.addToCart(product)
                analytics.track(event: .PointOfSale.addItemToCart(type: .simpleProduct))
            }, label: {
                SimpleProductCardView(product: product)
            })
        case let .variableParentProduct(parentProduct):
            NavigationLink(value: item) {
                ParentProductCardView(name: parentProduct.name,
                                      imageSource: parentProduct.productImageSource,
                                      detailView: {
                    Text(Localization.variationsAvailable)
                        .foregroundStyle(Color.posSecondaryText)
                        .font(.posBodyRegular)
                })
            }
        case let .variation(variation):
            Button(action: {
                posModel.addToCart(variation)
                analytics.track(event: .PointOfSale.addItemToCart(type: .variation))
            }, label: {
                VariationCardView(variation: variation)
            })
        }
    }
}

@available(iOS 17.0, *)
private extension ItemListRow {
    enum Localization {
        static let variationsAvailable = NSLocalizedString(
            "pos.parentProductCard.optionsAvailable",
            value: "Options available",
            comment: "Text indicating that there are options available for a parent product"
        )
    }
}

//#if DEBUG
//@available(iOS 17.0, *)
//#Preview("Loaded with items") {
//    ItemList(
//        state:
//                .loaded(
//                    [
//                        .simpleProduct(
//                            .init(
//                                id: .init(),
//                                name: "Strong latte 16oz",
//                                formattedPrice: "$4.00",
//                                productID: 12,
//                                price: "4.00"
//                            )
//                        ),
//                        .variableParentProduct(
//                            .init(
//                                id: .init(),
//                                name: "Variable mocha",
//                                productImageSource: "https://pd.w.org/2024/12/986762d0d4d4cf17.82435881-scaled.jpeg",
//                                productID: 16
//                            )
//                        )
//                    ],
//                    hasMoreItems: false
//                )
//    )
//}
//
//@available(iOS 17.0, *)
//#Preview("Loading") {
//    let posModel = PointOfSaleAggregateModel(
//        itemsController: PointOfSalePreviewItemsController(),
//        cardPresentPaymentService: CardPresentPaymentPreviewService(),
//        orderController: PointOfSalePreviewOrderController())
//    ItemList(state: .loading([]))
//        .environment(posModel)
//}
//
//#endif
