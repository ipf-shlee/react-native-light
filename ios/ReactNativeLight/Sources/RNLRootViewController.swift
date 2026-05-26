import UIKit

public final class RNLRootViewController: UIViewController {
    private let jsRuntime = JSRuntime()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        jsRuntime.loadBundle()
    }
}
