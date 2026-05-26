import UIKit

// ----------------------------------------------------------------------------
// LayoutEngine — 미니 flexbox 알고리즘.
//
// 진짜 RN은 Yoga(별도 C++ 라이브러리)를 사용. RN 자체 코드는 통합 layer만 작성.
// Yoga 원본: https://github.com/facebook/yoga
// RN의 Yoga 통합:
//   https://github.com/facebook/react-native/tree/main/packages/react-native/ReactCommon/yoga
//
// 우리는 작은 subset 직접 구현:
//   flexDirection, justifyContent, alignItems, flex, width/height, padding, gap
//
// 제외: flex-wrap, align-self, position: absolute, 퍼센트, min/max, aspect-ratio
// ----------------------------------------------------------------------------

final class LayoutEngine {
    private let registry: ViewRegistry

    init(registry: ViewRegistry) {
        self.registry = registry
    }

    // 진입점 — root의 자식들을 root.bounds 안에서 배치.
    // RN 대응:
    //   Fabric: RCTMountingManager가 mount transaction 끝에 layout 적용.
    //   실제 계산은 C++ Shadow Tree + Yoga가 별도 thread에서.
    //   https://github.com/facebook/react-native/blob/main/packages/react-native/React/Fabric/Mounting/RCTMountingManager.mm
    func layout(rootId: Int) {
        guard let root = registry.view(for: rootId) else {
            print("[LayoutEngine] root \(rootId) not found")
            return
        }
        layoutContainer(container: root, availableSize: root.bounds.size)
    }

    // measure → 분배 → 배치 3-pass.
    private func layoutContainer(container: UIView, availableSize: CGSize) {
        let props = registry.props(for: container.tag)
        let children = container.subviews
        if children.isEmpty {
            if let scroll = container as? UIScrollView {
                scroll.contentSize = .zero
            }
            return
        }

        let isRow = props.flexDirection == .row
        let isScroll = container is UIScrollView

        let contentWidth = max(0, availableSize.width - props.padding * 2)
        let contentHeight = max(0, availableSize.height - props.padding * 2)

        let crossSize = isRow ? contentHeight : contentWidth
        // ScrollView 메인 축은 unbounded — 자식 크기만큼 흘러나가서 contentSize로 표현.
        let mainSize = isScroll ? CGFloat.greatestFiniteMagnitude : (isRow ? contentWidth : contentHeight)

        // -- Phase 1: 비-flex 자식 측정 + totalFlex 합산 --
        var childMains: [CGFloat] = []
        var totalFlex: CGFloat = 0
        var fixedMainTotal: CGFloat = 0

        for child in children {
            let cp = registry.props(for: child.tag)

            if cp.flex > 0 && !isScroll {
                childMains.append(-1)
                totalFlex += cp.flex
                continue
            }

            let mainExplicit = isRow ? cp.width : cp.height
            let main: CGFloat
            if let m = mainExplicit {
                main = m
            } else if let label = child as? UILabel {
                main = textMain(label: label, crossSize: crossSize, isRow: isRow)
            } else {
                main = intrinsicMain(of: child, axis: isRow)
            }
            childMains.append(main)
            fixedMainTotal += main
        }

        // -- Phase 2: flex 자식들에게 남은 공간 분배 --
        let gapsTotal = props.gap * CGFloat(max(0, children.count - 1))
        let availableForFlex = max(0, mainSize - fixedMainTotal - gapsTotal)
        let flexUnit = totalFlex > 0 ? availableForFlex / totalFlex : 0

        for i in 0..<children.count {
            if childMains[i] == -1 {
                let cp = registry.props(for: children[i].tag)
                childMains[i] = flexUnit * cp.flex
            }
        }

        // -- Phase 3: justifyContent에 따라 시작 offset + 자식 간 추가 gap --
        var startMain: CGFloat = 0
        var extraGap: CGFloat = 0
        if !isScroll {
            let totalUsed = childMains.reduce(0, +) + gapsTotal
            let remaining = max(0, mainSize - totalUsed)
            switch props.justifyContent {
            case .flexStart:
                startMain = 0
            case .center:
                startMain = remaining / 2
            case .flexEnd:
                startMain = remaining
            case .spaceBetween:
                if children.count > 1 {
                    extraGap = remaining / CGFloat(children.count - 1)
                }
            case .spaceAround:
                let per = children.count > 0 ? remaining / CGFloat(children.count) : 0
                startMain = per / 2
                extraGap = per
            }
        }

        // -- Phase 4: 각 자식 frame 설정 + 재귀 --
        var currentMain = props.padding + startMain
        for i in 0..<children.count {
            let child = children[i]
            let cp = registry.props(for: child.tag)
            let childMain = childMains[i]

            let crossExplicit = isRow ? cp.height : cp.width
            let childCross: CGFloat
            if props.alignItems == .stretch && crossExplicit == nil {
                childCross = crossSize
            } else if let e = crossExplicit {
                childCross = e
            } else if let label = child as? UILabel {
                childCross = textCross(label: label, mainSize: childMain, isRow: isRow)
            } else {
                childCross = 0
            }

            var crossOffset = props.padding
            switch props.alignItems {
            case .flexStart, .stretch:
                break
            case .center:
                crossOffset += (crossSize - childCross) / 2
            case .flexEnd:
                crossOffset += crossSize - childCross
            }

            if isRow {
                child.frame = CGRect(x: currentMain, y: crossOffset, width: childMain, height: childCross)
            } else {
                child.frame = CGRect(x: crossOffset, y: currentMain, width: childCross, height: childMain)
            }

            // 자식의 자식 layout (재귀)
            layoutContainer(container: child, availableSize: child.bounds.size)

            currentMain += childMain + props.gap + extraGap
        }

        // -- ScrollView contentSize 갱신 --
        if let scroll = container as? UIScrollView {
            let totalChildrenMain = childMains.reduce(0, +) + gapsTotal
            let contentMain = totalChildrenMain + props.padding * 2
            let contentCross: CGFloat = isRow ? availableSize.height : availableSize.width
            scroll.contentSize = isRow
                ? CGSize(width: contentMain, height: contentCross)
                : CGSize(width: contentCross, height: contentMain)
        }
    }

    // 명시적 size 없는 container의 메인 축을 자식들로부터 추정.
    private func intrinsicMain(of container: UIView, axis isRow: Bool) -> CGFloat {
        if container is UIScrollView { return 0 }
        let props = registry.props(for: container.tag)
        let children = container.subviews
        if children.isEmpty { return 0 }

        let viewIsRow = props.flexDirection == .row
        if viewIsRow == isRow {
            var total: CGFloat = 0
            for child in children {
                total += childIntrinsic(child, axis: isRow)
            }
            total += props.gap * CGFloat(max(0, children.count - 1))
            total += props.padding * 2
            return total
        } else {
            var maxV: CGFloat = 0
            for child in children {
                maxV = max(maxV, childIntrinsic(child, axis: isRow))
            }
            return maxV + props.padding * 2
        }
    }

    private func childIntrinsic(_ view: UIView, axis isRow: Bool) -> CGFloat {
        let cp = registry.props(for: view.tag)
        let explicit = isRow ? cp.width : cp.height
        if let e = explicit { return e }
        if let label = view as? UILabel {
            let unbounded: CGFloat = .greatestFiniteMagnitude
            let size = label.sizeThatFits(CGSize(width: unbounded, height: unbounded))
            return isRow ? size.width : size.height
        }
        return intrinsicMain(of: view, axis: isRow)
    }

    private func textMain(label: UILabel, crossSize: CGFloat, isRow: Bool) -> CGFloat {
        let constraint = isRow
            ? CGSize(width: .greatestFiniteMagnitude, height: crossSize)
            : CGSize(width: crossSize, height: .greatestFiniteMagnitude)
        let size = label.sizeThatFits(constraint)
        return isRow ? size.width : size.height
    }

    private func textCross(label: UILabel, mainSize: CGFloat, isRow: Bool) -> CGFloat {
        let constraint = isRow
            ? CGSize(width: mainSize, height: .greatestFiniteMagnitude)
            : CGSize(width: .greatestFiniteMagnitude, height: mainSize)
        let size = label.sizeThatFits(constraint)
        return isRow ? size.height : size.width
    }
}
