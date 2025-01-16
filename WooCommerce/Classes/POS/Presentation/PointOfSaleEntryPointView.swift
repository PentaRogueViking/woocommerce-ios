import SwiftUI

@available(iOS 17.0, *)
struct PointOfSaleEntryPointView: View {
    @State private var posModel: PointOfSaleAggregateModel
    @StateObject private var posModalManager = POSModalManager()

    private let onPointOfSaleModeActiveStateChange: ((Bool) -> Void)

    init(itemsController: PointOfSaleItemsControllerProtocol,
         onPointOfSaleModeActiveStateChange: @escaping ((Bool) -> Void),
         cardPresentPaymentService: CardPresentPaymentFacade,
         orderController: PointOfSaleOrderControllerProtocol) {
        self.onPointOfSaleModeActiveStateChange = onPointOfSaleModeActiveStateChange

        let posModel = PointOfSaleAggregateModel(
            itemsController: itemsController,
            cardPresentPaymentService: cardPresentPaymentService,
            orderController: orderController)

        self._posModel = State(wrappedValue: posModel)
    }

    var body: some View {
//        print("Entry point recomputed: \(posModel.itemsViewState.description)")
        Self._printChanges()

        return VStack {
            PointOfSaleDashboardView()
            .environmentObject(posModalManager)
            .environment(posModel)
            .onAppear {
                onPointOfSaleModeActiveStateChange(true)
            }
            .onDisappear {
                onPointOfSaleModeActiveStateChange(false)
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview {
    PointOfSaleEntryPointView(itemsController: PointOfSalePreviewItemsController(),
                              onPointOfSaleModeActiveStateChange: { _ in },
                              cardPresentPaymentService: CardPresentPaymentPreviewService(),
                              orderController: PointOfSalePreviewOrderController())
}
#endif
