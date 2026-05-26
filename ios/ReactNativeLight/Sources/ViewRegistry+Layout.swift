import UIKit

// Flex 레이아웃 prop을 LayoutProps dict로 보관 (frame은 LayoutEngine이 계산).
// 진짜 RN에선 Yoga 라이브러리가 이 영역을 담당하고, 우리 학습 예제에선
// 본 흐름(JS↔Native bridge + render)에서 떼어내 별도 파일로 격리.
//
// RN 대응:
//   Yoga: https://github.com/facebook/yoga
//   각 ComponentView가 자기 Yoga node를 보유, prop 변경 시 Yoga에 전달.
extension ViewRegistry {

    func applyLayoutProp(viewId: Int, key: String, value: Any) -> Bool {
        var props = layoutProps[viewId] ?? LayoutProps()
        switch key {
        case "flexDirection":
            if let s = value as? String {
                props.flexDirection = (s == "row") ? .row : .column
            }
        case "justifyContent":
            if let s = value as? String {
                switch s {
                case "center": props.justifyContent = .center
                case "flex-end": props.justifyContent = .flexEnd
                case "space-between": props.justifyContent = .spaceBetween
                case "space-around": props.justifyContent = .spaceAround
                default: props.justifyContent = .flexStart
                }
            }
        case "alignItems":
            if let s = value as? String {
                switch s {
                case "center": props.alignItems = .center
                case "flex-end": props.alignItems = .flexEnd
                case "stretch": props.alignItems = .stretch
                default: props.alignItems = .flexStart
                }
            }
        case "flex":
            if let n = value as? NSNumber { props.flex = CGFloat(n.doubleValue) }
        case "width":
            if let n = value as? NSNumber { props.width = CGFloat(n.doubleValue) }
        case "height":
            if let n = value as? NSNumber { props.height = CGFloat(n.doubleValue) }
        case "padding":
            if let n = value as? NSNumber { props.padding = CGFloat(n.doubleValue) }
        case "gap":
            if let n = value as? NSNumber { props.gap = CGFloat(n.doubleValue) }
        default:
            return false
        }
        layoutProps[viewId] = props
        return true
    }
}
