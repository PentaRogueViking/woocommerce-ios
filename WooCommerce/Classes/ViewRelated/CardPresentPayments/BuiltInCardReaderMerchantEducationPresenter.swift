import Foundation
import UIKit
import WordPressUI

final class BuiltInCardReaderMerchantEducationPresenter {
    private weak var rootViewController: ViewControllerPresenting?

    init(rootViewController: ViewControllerPresenting) {
        self.rootViewController = rootViewController
    }
    func presentMerchantEducation(completion: @escaping () -> Void) {
        let viewController = TapToPayEducationViewViewHostingController(onDismiss: completion)
        let topViewController = rootViewController?.presentedViewController ?? rootViewController
        topViewController?.present(viewController, animated: true)
    }
}
