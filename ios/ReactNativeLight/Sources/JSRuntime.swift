import Foundation
import JavaScriptCore

final class JSRuntime {
    let context: JSContext
    private let viewRegistry: ViewRegistry
    private let layoutEngine: LayoutEngine

    init(viewRegistry: ViewRegistry, layoutEngine: LayoutEngine) {
        guard let context = JSContext() else {
            fatalError("JSContext init failed")
        }
        self.context = context
        self.viewRegistry = viewRegistry
        self.layoutEngine = layoutEngine
        registerHostFunctions()
    }

    func loadBundle() {
        guard let url = Bundle.main.url(forResource: "bundle", withExtension: "js") else {
            print("[JSRuntime] bundle.js not found in main bundle")
            return
        }
        do {
            let script = try String(contentsOf: url, encoding: .utf8)
            context.evaluateScript(script)
        } catch {
            print("[JSRuntime] failed to read bundle.js: \(error)")
        }
    }

    private func registerHostFunctions() {
        let registry = viewRegistry
        let engine = layoutEngine

        let createView: @convention(block) (String, Int, [String: Any]) -> Void = { type, id, props in
            registry.createView(type: type, id: id, props: props)
        }
        context.setObject(createView, forKeyedSubscript: "createView" as NSString)

        let appendChild: @convention(block) (Int, Int) -> Void = { parentId, childId in
            registry.appendChild(parentId: parentId, childId: childId)
        }
        context.setObject(appendChild, forKeyedSubscript: "appendChild" as NSString)

        let setProp: @convention(block) (Int, String, Any) -> Void = { id, key, value in
            registry.setProp(id: id, key: key, value: value)
        }
        context.setObject(setProp, forKeyedSubscript: "setProp" as NSString)

        let setText: @convention(block) (Int, String) -> Void = { id, text in
            registry.setText(id: id, text: text)
        }
        context.setObject(setText, forKeyedSubscript: "setText" as NSString)

        // 트리 setup이 끝난 후 호출돼 모든 frame 계산.
        // RN 대응: Fabric의 MountingManager가 mount transaction 끝에 layout 적용.
        let layout: @convention(block) (Int) -> Void = { rootId in
            engine.layout(rootId: rootId)
        }
        context.setObject(layout, forKeyedSubscript: "layout" as NSString)
    }
}
