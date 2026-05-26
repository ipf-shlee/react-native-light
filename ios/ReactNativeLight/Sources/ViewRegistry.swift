import UIKit

// ----------------------------------------------------------------------------
// ViewRegistry
//
// 학습용으로 단일 클래스에서 처리하지만, 진짜 RN에서는 책임이 여러 클래스로
// 분산되어 있습니다. 각 메서드에 RN 대응 클래스와 GitHub 링크 표기.
//
// 저장소: https://github.com/facebook/react-native
//
// flex 레이아웃 prop 처리는 ViewRegistry+Layout.swift 참고
// (진짜 RN에선 Yoga가 담당하는 영역).
// ----------------------------------------------------------------------------

// Flex 레이아웃 prop 저장용.
// RN 대응:
//   진짜 RN은 Yoga(별도 라이브러리)가 이 일을 함 (https://github.com/facebook/yoga)
//   각 ComponentView가 자기 Yoga node를 보유, prop 변경 시 Yoga에 전달.
//   우리는 Yoga 흉내내는 미니 알고리즘을 LayoutEngine.swift에 직접 구현.
enum FlexDirection { case row, column }
enum JustifyContent { case flexStart, center, flexEnd, spaceBetween, spaceAround }
enum AlignItems { case flexStart, center, flexEnd, stretch }

struct LayoutProps {
    var flexDirection: FlexDirection = .column
    var justifyContent: JustifyContent = .flexStart
    var alignItems: AlignItems = .stretch
    var flex: CGFloat = 0
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var padding: CGFloat = 0
    var gap: CGFloat = 0
}

final class ViewRegistry {
    static let rootId = 0

    // id → UIView 매핑.
    // RN 대응:
    //   Legacy: RCTUIManager 내부 _viewRegistry
    //   https://github.com/facebook/react-native/blob/main/packages/react-native/React/Modules/RCTUIManager.mm
    //   Fabric: RCTComponentViewRegistry
    //   https://github.com/facebook/react-native/blob/main/packages/react-native/React/Fabric/Mounting/RCTComponentViewRegistry.h
    private var views: [Int: UIView] = [:]

    // id → flex 레이아웃 prop. LayoutEngine이 읽어서 frame 계산.
    // (ViewRegistry+Layout 확장에서 쓰기 → 같은 모듈이라 internal로 노출)
    // RN 대응: Yoga node (https://github.com/facebook/react-native/blob/main/packages/react-native/ReactCommon/yoga/yoga/YGNode.h)
    var layoutProps: [Int: LayoutProps] = [:]

    func registerRoot(_ view: UIView) {
        views[Self.rootId] = view
    }

    // LayoutEngine이 ViewRegistry 데이터를 읽기 위한 접근자.
    func view(for id: Int) -> UIView? {
        return views[id]
    }

    func props(for id: Int) -> LayoutProps {
        return layoutProps[id] ?? LayoutProps()
    }

    // 타입별 UIView 생성 + prop 초기 적용.
    // RN 대응:
    //   Legacy: RCTViewManager + RCTComponentData (매크로 + 리플렉션)
    //   Fabric: RCTComponentViewFactory.createComponentViewWithComponentHandle:
    func createView(type: String, id: Int, props: [String: Any]) {
        let view: UIView
        switch type {
        case "View":
            // RN Legacy: RCTView / Fabric: RCTViewComponentView
            view = UIView()
        case "Text":
            // RN Legacy: RCTTextView (Core Text 직접 사용)
            // https://github.com/facebook/react-native/blob/main/packages/react-native/Libraries/Text/Text/RCTTextView.mm
            // Fabric: RCTParagraphComponentView
            // https://github.com/facebook/react-native/blob/main/packages/react-native/React/Fabric/Mounting/ComponentViews/Text/RCTParagraphComponentView.mm
            let label = UILabel()
            label.numberOfLines = 0
            view = label
        default: view = UIView()
        }
        view.tag = id
        views[id] = view
        applyProps(to: view, props: props)
    }

    // Text 콘텐츠 설정.
    // RN 대응:
    //   Legacy: RCTTextViewManager + RCTShadowText
    //   Fabric: RCTParagraphComponentView.updateState:oldState:
    func setText(id: Int, text: String) {
        guard let label = views[id] as? UILabel else { return }
        label.text = text
    }

    // 트리에 자식 추가.
    // RN 대응:
    //   Legacy: RCTComponent.insertReactSubview:atIndex:
    //   Fabric: RCTComponentViewProtocol.mountChildComponentView:index:
    func appendChild(parentId: Int, childId: Int) {
        guard let parent = views[parentId], let child = views[childId] else { return }
        parent.addSubview(child)
    }

    // 단일 prop 갱신.
    func setProp(id: Int, key: String, value: Any) {
        guard let view = views[id] else { return }
        applyProp(to: view, key: key, value: value)
    }

    private func applyProps(to view: UIView, props: [String: Any]) {
        for (key, value) in props {
            applyProp(to: view, key: key, value: value)
        }
    }

    // 개별 prop → 네이티브 속성 또는 LayoutProps 변환.
    // flex 레이아웃 관련 prop은 ViewRegistry+Layout의 applyLayoutProp으로 위임.
    // RN 대응:
    //   Legacy: RCT_EXPORT_VIEW_PROPERTY 매크로
    //   Fabric: 각 ComponentView.updateProps:oldProps:
    private func applyProp(to view: UIView, key: String, value: Any) {
        if applyLayoutProp(viewId: view.tag, key: key, value: value) {
            return
        }
        switch key {
        case "backgroundColor":
            if let hex = value as? String {
                view.backgroundColor = UIColor(hex: hex)
            }
        case "fontSize":
            if let label = view as? UILabel, let n = value as? NSNumber {
                label.font = .systemFont(ofSize: CGFloat(n.doubleValue))
            }
        case "color":
            if let label = view as? UILabel, let hex = value as? String {
                label.textColor = UIColor(hex: hex)
            }
        case "textAlign":
            if let label = view as? UILabel, let align = value as? String {
                switch align {
                case "center": label.textAlignment = .center
                case "right": label.textAlignment = .right
                case "left": label.textAlignment = .left
                default: break
                }
            }
        default: break
        }
    }
}

// 색상 hex 파싱.
// RN 대응: RCTConvert.UIColor: ("rgba()", "red", "#fff" 등 모든 표현)
//   https://github.com/facebook/react-native/blob/main/packages/react-native/React/Base/RCTConvert.mm
private extension UIColor {
    convenience init?(hex: String) {
        var hex = hex
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 || hex.count == 8 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }
        let r, g, b, a: CGFloat
        if hex.count == 6 {
            r = CGFloat((rgb >> 16) & 0xff) / 255
            g = CGFloat((rgb >> 8) & 0xff) / 255
            b = CGFloat(rgb & 0xff) / 255
            a = 1
        } else {
            r = CGFloat((rgb >> 24) & 0xff) / 255
            g = CGFloat((rgb >> 16) & 0xff) / 255
            b = CGFloat((rgb >> 8) & 0xff) / 255
            a = CGFloat(rgb & 0xff) / 255
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
