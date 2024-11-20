import Testing
import Foundation
@testable import WooCommerce
import protocol Yosemite.POSItem
@testable import struct Yosemite.POSProduct

struct CartViewTests {
    let orderService: MockPOSOrderService
    let cardPresentPaymentService: MockCardPresentPaymentService
    let posModel: PointOfSaleAggregateModel
    let sut: CartView

    init () async throws {
        let orderService = MockPOSOrderService()
        self.orderService = orderService
        let cardPresentPaymentService = MockCardPresentPaymentService()
        self.cardPresentPaymentService = cardPresentPaymentService
        let posModel = PointOfSaleAggregateModel(itemProvider: MockPOSItemProvider(),
                                                 cardPresentPaymentService: cardPresentPaymentService,
                                                 orderService: orderService)
        self.posModel = posModel
        sut = CartView(cartViewModel: CartViewModel(posModel: posModel))
        //.environmentObject(posModel) //as! CartView
    }

    @Test func shouldPreventCartEditing_when_paymentState_idle_and_order_is_syncing() async throws {
        try #require(sut.shouldPreventCartEditing == false)
        // Given syncing will happen for 1 second on checkOut
        orderService.simulateSyncing = true
        posModel.addToCart(makeItem())

        // When syncing is ongoing on another thread
        Task {
            await posModel.checkOut()
        }
        try await Task.sleep(nanoseconds: UInt64(100 * Double(NSEC_PER_MSEC)))

        // Then
        #expect(sut.shouldPreventCartEditing == true)
    }

    @Test func shouldPreventCartEditing_when_paymentState_cardPaymentSuccessful() async throws {
        try #require(sut.shouldPreventCartEditing == false)
        // Given
        cardPresentPaymentService.paymentEvent = .show(eventDetails: .paymentSuccess(done: {}))

        // When, Then
        #expect(sut.shouldPreventCartEditing == true)
    }

    @Test func shouldPreventCartEditing_when_paymentState_processingPayment() async throws {
        try #require(sut.shouldPreventCartEditing == false)
        // Given
        cardPresentPaymentService.paymentEvent = .show(eventDetails: .processing)

        // When, Then
        #expect(sut.shouldPreventCartEditing == true)
    }

    @Test func shouldPreventCartEditing_false_when_paymentState_acceptingCard() async throws {
        // Given
        cardPresentPaymentService.paymentEvent = .show(
            eventDetails: .preparingForPayment(cancelPayment: {}))
        try #require(sut.shouldPreventCartEditing == true)

        // When
        cardPresentPaymentService.paymentEvent = .show(
            eventDetails: .tapSwipeOrInsertCard(inputMethods: [.tap], cancelPayment: {}))

        // Then
        #expect(sut.shouldPreventCartEditing == false)
    }

    @Test func shouldPreventCartEditing_false_when_paymentState_validatingOrderError() async throws {
        // Given
        cardPresentPaymentService.paymentEvent = .show(
            eventDetails: .paymentError(
                error: CollectOrderPaymentUseCaseError.orderTotalChanged,
                retryApproach: .dontRetry,
                cancelPayment: {}))

        // When, Then
        #expect(sut.shouldPreventCartEditing == false)
    }

}

private func makeItem(name: String = "") -> POSItem {
    return POSProduct(itemID: UUID(),
                      productID: 0,
                      name: name,
                      price: "",
                      formattedPrice: "",
                      itemCategories: [],
                      productImageSource: nil,
                      productType: .simple)
}
