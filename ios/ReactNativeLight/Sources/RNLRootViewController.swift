import UIKit

public final class RNLRootViewController: UIViewController {

    private let viewRegistry = ViewRegistry()
    private lazy var layoutEngine = LayoutEngine(registry: viewRegistry)
    private lazy var jsRuntime = JSRuntime(viewRegistry: viewRegistry, layoutEngine: layoutEngine)
    private var hasLoadedBundle = false
    private let root = UIView()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        view.addSubview(root)
        viewRegistry.registerRoot(root)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Safe area 안에서 그리도록 매 layout 사이클마다 root frame 갱신.
        // 회전 / iPad split view / 키보드 등으로 safe area가 바뀔 때도 자동 대응.
        root.frame = view.safeAreaLayoutGuide.layoutFrame

        // viewDidLoad에서 root.bounds는 .zero일 수 있어서, 실제 bounds가 정해진
        // viewDidLayoutSubviews 시점에 처음으로 번들을 로드. 이후 호출(회전 등)
        // 에서는 layout만 재실행.
        if !hasLoadedBundle {
            hasLoadedBundle = true
            jsRuntime.loadBundle()
        } else {
            layoutEngine.layout(rootId: ViewRegistry.rootId)
        }
    }
}
