# ReactNativeLight

학습용으로 직접 만든 미니 React Native (iOS only).

JSX로 작성한 컴포넌트가 JavaScriptCore에서 실행돼 실제 UIView 트리로 렌더링되고,
탭 이벤트가 JS로 돌아와 `useState`로 화면을 다시 그리는 React 패턴까지 동작.

## 아키텍처

```
[ JS world ]                    [ Native world (Swift) ]

  App.jsx (JSX)                   RNLRootViewController
    ↓ esbuild                       ↓ owns
  bundle.js (IIFE)                JSRuntime (JSContext)
    ↓ JSC가 실행                     ↓ 호스트 함수 주입
  react-light.js                  createView, setText, appendChild,
    (h, useState, render,         setProp, removeAllChildren,
     호스트 함수 직접 호출)         registerCallback, layout
    ↓                                ↓ 위임
                                  ViewRegistry [Int: UIView]
                                  LayoutEngine (flex)
                                     ↓
                                  UIView / UILabel / UIScrollView
                                     ↓
                                  화면

  이벤트 흐름 (반대 방향):
  탭 → UITapGestureRecognizer → TapHandler → ViewRegistry.dispatchEvent
    → JSValue.call → onPress 콜백 → setState → 재렌더
```

## 핵심 원리

- **JS는 명령 emit**: vnode 트리를 walk하면서 `createView` 등 호스트 함수를 직접 호출
- **Native는 호스트**: 명령 받아 UIView 생성/배치, 이벤트는 다시 JS로 돌려보냄
- **JSX는 빌드 타임에 사라짐**: esbuild가 `<View/>` → `h(View)` 변환, 런타임(JSC)은 JSX 모름
- **레이아웃은 선언형**: frame 직접 계산 안 함, flex prop으로 묘사 → LayoutEngine이 계산

## 구현한 것 (✅)

### JS (js/react-light.js 프레임워크, ReactNativeLightDemo/js/App.jsx 데모)
- `h(type, props, ...children)` — vnode 생성 (JSX 컴파일 타깃)
- JSX 문법 (esbuild가 변환)
- `render(vnode, parentId)` — vnode 트리 walk + 호스트 함수 호출
- 함수형 컴포넌트
- `useState(initial)` — 루트 컴포넌트에서만, 다중 hook slot
- tear-down/rebuild 재렌더 — state 변경 시 root 서브트리 전체 재생성
- 동등 값 `setState` bail-out (React 표준 동작)
- `key`/`ref` prop 차단 (React 내부용이라 native로 전달 안 함)
- `on*` 이벤트 핸들러 자동 라우팅 (`onPress` → native gesture → JS 콜백)
- id 할당은 JS 측 (`nextId++`) — Native는 받은 id로 매핑만 관리

### Native (Swift — ReactNativeLight SPM 라이브러리)
- JSContext 호스팅 + exception handler ([JSRuntime.swift](ios/ReactNativeLight/Sources/JSRuntime.swift))
- 호스트 함수 일체 (`createView`, `setText`, `appendChild`,
  `setProp`, `removeAllChildren`, `registerCallback`, `layout`)
- ViewRegistry: id → UIView 매핑 + lifecycle 정리 ([ViewRegistry.swift](ios/ReactNativeLight/Sources/ViewRegistry.swift))
- 호스트 컴포넌트:
  - `View` → `UIView`
  - `Text` → `UILabel` (`numberOfLines = 0`)
  - `ScrollView` → `UIScrollView` (contentSize 자동 계산)
  - `Pressable` → `UIView` + `UITapGestureRecognizer`
- 스타일 prop: `backgroundColor`, `color`, `fontSize`, `textAlign` (hex 색상만)
- 미니 flex 레이아웃 엔진 ([LayoutEngine.swift](ios/ReactNativeLight/Sources/LayoutEngine.swift))
  - `flexDirection: 'row' | 'column'`
  - `justifyContent: 'flex-start' | 'center' | 'flex-end' | 'space-between' | 'space-around'`
  - `alignItems: 'flex-start' | 'center' | 'flex-end' | 'stretch'`
  - `flex: number` (메인 축 비율 분배)
  - `width`, `height` (고정)
  - `padding` (단일 값)
  - `gap` (자식 간 간격)
- JSValue를 dict에 직접 보관해 GC 안전 (JSManagedValue 안 씀)

### 빌드/dev 인프라
- esbuild로 `ios/ReactNativeLightDemo/js/App.jsx` → `ios/ReactNativeLightDemo/Resources/bundle.js` ([js/build.mjs](js/build.mjs))
- ReactNativeLight는 Swift Package (SPM 라이브러리), ReactNativeLightDemo가 이를 import하는 iOS 앱
- Xcode build phase에서 자동 `npm run build` 실행 (⌘R만 누르면 됨)
- User script sandboxing 해제 (외부 경로 쓰기 허용)

## 구현 안 한 것 (❌, 의도적으로)

### 진짜 React Native의 큰 부분
- **Reconciler / diff** — React 본체의 일. 우리는 `tear-down/rebuild`로 갈음
  - 매 setState마다 깜빡임, 스크롤 위치/제스처 상태 손실
  - 진짜 RN은 React에 위임하고 host config만 제공
- **Yoga (full flexbox)** — 우린 subset만. 제외된 것:
  `flex-wrap`, `position: absolute`, 퍼센트 단위, `min/max-width/height`,
  `aspect-ratio`, `flex-shrink`/`flex-basis` 분리, `align-self`, padding-side 분리
- **Hermes** — JSC만 사용. 진짜 RN은 Hermes(AOT 바이트코드)가 0.70+ 기본
- **멀티스레딩** — 메인 스레드만. 진짜 RN은 JS / Shadow / UI thread 분리
- **Fabric (new architecture)** — C++ Shadow Tree, concurrent rendering, JSI
- **HMR / Fast Refresh** — 매번 ⌘R로 앱 재시작
- **Metro 번들러** — esbuild로 갈음 (정적 빌드, dev 서버 X)
- **TurboModules / Codegen** — 비-UI native 모듈 노출 시스템
- **Android** — iOS only

### 호스트 컴포넌트 (진짜 RN은 다 있음)
- `Image` (비동기 로딩, 캐시, placeholder, 디코딩)
- `TextInput` (네이티브 키보드, focus, IME)
- `FlatList` / `SectionList` (가상화, windowing)
- `Modal`, `Switch`, `Slider`, `Picker`, `KeyboardAvoidingView`, `RefreshControl`
- `Animated` / `Reanimated`
- 중첩 Text, RTL/CJK 텍스트, 텍스트 부분 스타일링

### JS API
- 자식 컴포넌트의 `useState` (루트 컴포넌트만 hook 가능 — global slot)
- `useEffect`, `useRef`, `useMemo` 등 다른 hooks
- `setState` 배치(batching) — 한 tick에 여러 setState = 매번 재렌더
- `<Fragment>` / `<>...</>`
- 스타일 단축 prop (`paddingHorizontal`, `marginTop` 등 — 우리는 `padding` 단일 값만)
- 색상 표기법: hex만 (`'red'`, `'rgba(...)'`, named color 안 됨)
- `NativeModules.Alert.alert(...)` 같은 패턴
- `console.log` (미지원 — Swift 측 `print`로만 디버깅)
- 소스맵 / 디버거 연동

### 기타
- 자동화 테스트
- 에러 바운더리
- Suspense / 비동기 컴포넌트

## 프로젝트 구조

```
rn-ios/
├── README.md                            ← 이 파일
├── docs/                                ← 로컬 전용 (gitignored): 설계 문서 + 발표 슬라이드
├── js/                                  ← JS 프레임워크 + 빌드 툴체인
│   ├── react-light.js                   ← h, useState, render, 호스트 함수 호출 (프레임워크)
│   ├── build.mjs                        ← esbuild 빌드 스크립트
│   ├── package.json
│   └── package-lock.json
└── ios/
    ├── ReactNativeLight/                ← SPM 라이브러리 (재사용 가능한 미니 RN 코어)
    │   ├── Package.swift
    │   └── Sources/
    │       ├── JSRuntime.swift          ← JSContext + 호스트 함수 주입
    │       ├── ViewRegistry.swift       ← id→UIView + 이벤트 + style
    │       ├── ViewRegistry+Layout.swift
    │       ├── LayoutEngine.swift       ← 미니 flexbox
    │       └── RNLRootViewController.swift ← root container + 부트
    └── ReactNativeLightDemo/            ← 데모 iOS 앱 (라이브러리 consumer)
        ├── ReactNativeLightDemo.xcodeproj
        ├── js/App.jsx                   ← 데모 앱 JSX (esbuild 진입점)
        ├── Sources/
        │   ├── AppDelegate.swift
        │   └── SceneDelegate.swift
        └── Resources/
            └── bundle.js                ← esbuild 산출물 (gitignored)
```

> 프레임워크 JS(`js/react-light.js`)는 데모에 종속되지 않게 공유 위치에 두고,
> 데모 앱 코드(`App.jsx`)는 ReactNativeLightDemo 안에 둔다. 진짜 RN에서
> `react-native`는 의존성, `App.js`는 앱 프로젝트에 있는 것과 같은 구조.

## 실행

처음 한 번:
```bash
npm install
```

이후:
```bash
open ios/ReactNativeLightDemo/ReactNativeLightDemo.xcodeproj
# Xcode에서 ⌘R
```

JS 수정 → ⌘R 누르면 Xcode build phase가 자동으로 `npm run build` 실행 → 갱신된 `bundle.js`로 시뮬레이터 실행. 따로 `npm run build` 칠 필요 없음.

## Commit 흐름 (학습 순서)

각 챕터가 새 기능을 추가하면서 데모가 진화합니다. **챕터 1은 한 커밋**, 나머지는 **JS (1/2) + Native (2/2) 두 커밋**으로 나눠 어느 쪽에 어떤 변경이 일어났는지 분리해 볼 수 있게 했습니다.

| 챕터 | 커밋 메시지 | 화면 |
|---|---|---|
| 1 | `프로젝트 초기 설정 — JS bridge + esbuild` | 콘솔에 `[JS] hello from JS` (UI 없음) |
| 2 | `첫 UIView + flex 레이아웃 + JSX — JS (1/2)` <br> `첫 UIView + flex 레이아웃 — Native (2/2)` | 빨강/파랑 박스 반반 분할 |
| 3 | `Text 컴포넌트 추가 — JS (1/2)` <br> `Text 컴포넌트 — Native (2/2)` | 파란 배경 가운데 "Hello, ReactNativeLight" |
| 4 | `useState 훅 + tear-down/rebuild 재렌더 — JS (1/2)` <br> `useState 재렌더 — Native (2/2)` | `0` 고정 표시 — useState 연결 완료, setter는 다음 챕터에서 사용 |
| 5 | `Pressable + onPress 이벤트 — JS (1/2)` <br> `Pressable + onPress — Native (2/2)` | `[-]` `0` `[+]` 버튼으로 카운터 조작 |
| 6 | `ScrollView + 카운터 history 데모 — JS (1/2)` <br> `ScrollView — Native (2/2)` | 카운터 + 클릭 history 스크롤 |

발표용으로 `git checkout <chapter-sha>` 후 ⌘R로 그 시점의 화면 확인 가능.

```bash
git log --oneline
```

## React Native와의 매핑

[ViewRegistry.swift](ios/ReactNativeLight/Sources/ViewRegistry.swift)의 각 메서드와 case에
**Legacy(Bridge)와 Fabric(New Architecture) 양쪽**의 대응 클래스 + GitHub 링크가
주석으로 표기되어 있음.

예: `case "Text":` 위에
> RN Legacy: RCTTextView (Core Text 직접 사용)
> Fabric: RCTParagraphComponentView

## 참고

- 진짜 React Native: https://github.com/facebook/react-native
- Yoga (flex 엔진): https://github.com/facebook/yoga
- 우리 LayoutEngine과 진짜 Yoga 비교: [LayoutEngine.swift](ios/ReactNativeLight/Sources/LayoutEngine.swift) 상단 주석
