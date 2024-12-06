import Foundation
import Combine
import protocol Yosemite.POSDisplayableItem
import protocol Yosemite.PointOfSaleItemServiceProtocol
import enum Yosemite.PointOfSaleProductServiceError
import enum Yosemite.ItemListState
import protocol Yosemite.POSParentItem
import protocol Yosemite.POSChildFetchStrategy
import struct Yosemite.PointOfSaleErrorState
import struct Yosemite.POSVariableProductParent
import struct Yosemite.ProductVariationFetchStrategy

protocol PointOfSaleItemsControllerProtocol {
    var itemListStatePublisher: any Publisher<ItemListState, Never> { get }
    func loadInitialItems() async
    func loadNextItems() async
    func reload() async

    func sublistPublisher(for item: POSParentItem) -> AnyPublisher<ItemListState, Never>
    func loadSublist(for item: POSParentItem) async
    func loadMoreChildren(for item: POSParentItem) async
}

import protocol Yosemite.POSChildFetchStrategy

class PointOfSaleItemsController: PointOfSaleItemsControllerProtocol {
    private(set) var itemListStatePublisher: any Publisher<ItemListState, Never>
    private var itemListStateSubject: PassthroughSubject<ItemListState, Never> = .init()
    private var allItems: [POSDisplayableItem] = []
    private var currentPage: Int = Constants.initialPage
    private var mightHaveMorePages: Bool = true
    private let itemProvider: PointOfSaleItemServiceProtocol

    private var sublistSubjects: [UUID: PassthroughSubject<ItemListState, Never>] = [:]
    private var fetchStrategies: [TypeIdentifier: any POSChildFetchStrategy]

    init(itemProvider: PointOfSaleItemServiceProtocol) {
        self.itemProvider = itemProvider
        itemListStatePublisher = itemListStateSubject.eraseToAnyPublisher()
        configureFetchStrategies()
    }

    @MainActor
    func loadInitialItems() async {
        mightHaveMorePages = true
        itemListStateSubject.send(.initialLoading)
        try? await load(pageNumber: Constants.initialPage)
    }

    @MainActor
    func loadNextItems() async {
        do {
            guard mightHaveMorePages else {
                return
            }
            itemListStateSubject.send(.loading(allItems))

            let nextPage = currentPage + 1
            try await load(pageNumber: nextPage)
            currentPage = nextPage
        } catch {
            // Handle errors without incrementing currentPage.
        }
    }

    @MainActor
    func reload() async {
        allItems.removeAll()
        currentPage = Constants.initialPage
        mightHaveMorePages = true
        itemListStateSubject.send(.loading(allItems))
        try? await load(pageNumber: currentPage)
    }

    @MainActor
    private func load(pageNumber: Int) async throws {
        do {
            try await fetchItems(pageNumber: pageNumber)
            mightHaveMorePages = true
            updateItemListStateAfterLoadAttempt()
        } catch PointOfSaleProductServiceError.pageOutOfRange {
            mightHaveMorePages = false
            updateItemListStateAfterLoadAttempt()
            throw PointOfSaleProductServiceError.pageOutOfRange
        } catch {
            itemListStateSubject.send(.error(PointOfSaleErrorState.errorOnLoadingProducts()))
            throw error
        }
    }

    @MainActor
    private func fetchItems(pageNumber: Int) async throws {
        let newItems = try await itemProvider.providePointOfSaleItems(pageNumber: pageNumber)
        let uniqueNewItems = newItems.filter { newItem in
            !allItems.contains(where: { $0.isEqual(to: newItem) })
        }
        allItems.append(contentsOf: uniqueNewItems)
    }

    private func updateItemListStateAfterLoadAttempt() {
        if allItems.isEmpty {
            itemListStateSubject.send(.empty)
        } else {
            itemListStateSubject.send(.loaded(allItems))
        }
    }

    private enum Constants {
        static let initialPage: Int = 1
    }
}

import Networking

extension PointOfSaleItemsController {
    private func configureFetchStrategies() {
        fetchStrategies = [
            TypeIdentifier(POSVariableProductParent.self): ProductVariationFetchStrategy(
                network: AlamofireNetwork(credentials: ServiceLocator.stores.sessionManager.defaultCredentials),
                siteID: ServiceLocator.stores.sessionManager.defaultSite?.siteID ?? 0)
        ]
    }

    func sublistPublisher(for item: POSParentItem) -> AnyPublisher<ItemListState, Never> {
        if let existingSubject = sublistSubjects[item.id] {
            return existingSubject.eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<ItemListState, Never>()
        sublistSubjects[item.id] = subject
        return subject.eraseToAnyPublisher()
    }

    @MainActor
    func loadSublist(for item: POSParentItem) async {
        guard let subject = sublistSubjects[item.id] else { return }

        subject.send(.initialLoading)
        do {
            let children = try await fetchSublist(for: item, pageNumber: 1)
            item.currentPage = 1
            item.hasMoreChildren = !children.isEmpty
            subject.send(.loaded(children))
        } catch {
            subject.send(.error(PointOfSaleErrorState.errorOnLoadingProducts()))
        }
    }

    @MainActor
    func loadMoreChildren(for item: POSParentItem) async {
        guard item.hasMoreChildren,
              let subject = sublistSubjects[item.id] else { return }

        subject.send(.loading([])) // Could include current children here
        do {
            let nextPage = item.currentPage + 1
            let newChildren = try await fetchSublist(for: item, pageNumber: nextPage)
            item.currentPage = nextPage
            item.hasMoreChildren = !newChildren.isEmpty
            subject.send(.loaded(newChildren))
        } catch {
            subject.send(.error(PointOfSaleErrorState.errorOnLoadingProducts()))
        }
    }

    @MainActor
    private func fetchSublist(for item: POSParentItem, pageNumber: Int) async throws -> [POSDisplayableItem] {
        guard let strategy = fetchStrategies[TypeIdentifier(item)] else {
            throw PointOfSaleErrorState.unknownItemType(item.type)
        }
        return try await strategy.fetchChildren(for: item, page: pageNumber)
    }
}

struct TypeIdentifier: Hashable {
    private let type: Any.Type

    init(_ type: Any.Type) {
        self.type = type
    }

    init(_ item: any POSParentItem) {
        self.init(Swift.type(of: item))
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
    }

    static func == (lhs: TypeIdentifier, rhs: TypeIdentifier) -> Bool {
        return lhs.type == rhs.type
    }
}

public struct AnyPOSChildFetchStrategy: POSChildFetchStrategy {
    public typealias ParentItem = POSParentItem

    private let _fetchChildren: (POSParentItem, Int) async throws -> [POSDisplayableItem]

    public init<S: POSChildFetchStrategy>(_ strategy: S) where S.ParentItem: POSParentItem {
        self._fetchChildren = { item, page in
            guard let typedItem = item as? S.ParentItem else {
                fatalError("Type mismatch: expected \(S.ParentItem.self), got \(type(of: item))")
            }
            return try await strategy.fetchChildren(for: typedItem, page: page)
        }
    }

    public func fetchChildren(for item: POSParentItem, page: Int) async throws -> [POSDisplayableItem] {
        return try await _fetchChildren(item, page)
    }
}
