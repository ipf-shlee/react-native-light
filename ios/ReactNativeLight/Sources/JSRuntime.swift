import Foundation
import JavaScriptCore

final class JSRuntime {
    let context: JSContext

    init() {
        guard let context = JSContext() else {
            fatalError("JSContext init failed")
        }
        self.context = context
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
}
