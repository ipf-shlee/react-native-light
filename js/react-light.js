let nextId = 1;

export const ROOT_ID = 0;

export const View = 'View';
export const Text = 'Text';

export function h(type, props, ...children) {
  return { type, props: props || {}, children: children.flat(Infinity) };
}

// ---------------------------------------------------------------------------
// 학습용 데모 runtime — reconciler 아님.
//
// 진짜 RN은 React reconciler가 diff/patch. 우리는 그 레이어를 안 만들고
// 호스트 브릿지 위에서 가장 단순한 모델 사용: state 변경 시 root 서브트리를
// 통째로 폐기하고 처음부터 다시 emit.
//
// 한계:
//   - 스크롤 위치/제스처 상태 손실, 깜빡임
//   - 루트 컴포넌트만 useState 가능 (전역 hook slot 하나)
// ---------------------------------------------------------------------------

let rootComponent = null;
let rootParentId = ROOT_ID;
let hookSlots = [];
let currentHookIndex = 0;
let isRendering = false;

export function useState(initial) {
  const i = currentHookIndex++;
  if (!(i in hookSlots)) hookSlots[i] = initial;
  const setter = (next) => {
    const newValue = typeof next === 'function' ? next(hookSlots[i]) : next;
    // 값이 같으면 재렌더 스킵 — React/RN의 표준 동작.
    // 우리 모델에선 매 재렌더가 전체 폐기/재생성이라 특히 중요.
    if (newValue === hookSlots[i]) return;
    hookSlots[i] = newValue;
    if (!isRendering) rerenderRoot();
  };
  return [hookSlots[i], setter];
}

function rerenderRoot() {
  isRendering = true;
  try {
    removeAllChildren(rootParentId);
    currentHookIndex = 0;
    renderTree(h(rootComponent), rootParentId);
    layout(rootParentId);
  } finally {
    isRendering = false;
  }
}

// 공개 진입점. 함수형 컴포넌트면 rootComponent로 추적 → 재렌더 가능.
export function render(vnode, parentId = ROOT_ID) {
  if (vnode && typeof vnode === 'object' && typeof vnode.type === 'function') {
    rootComponent = vnode.type;
    rootParentId = parentId;
    hookSlots = [];
    rerenderRoot();
  } else {
    rootComponent = null;
    renderTree(vnode, parentId);
    layout(parentId);
  }
}

function renderTree(vnode, parentId) {
  if (vnode == null || typeof vnode === 'boolean') return;
  if (typeof vnode === 'string' || typeof vnode === 'number') return;

  if (typeof vnode.type === 'function') {
    return renderTree(vnode.type(vnode.props), parentId);
  }

  const props = splitProps(vnode.props);
  const id = nextId++;
  createView(vnode.type, id, props);
  appendChild(parentId, id);

  if (vnode.type === 'Text') {
    const text = vnode.children
      .filter((c) => typeof c === 'string' || typeof c === 'number')
      .map(String)
      .join('');
    setText(id, text);
    return id;
  }

  for (const child of vnode.children) renderTree(child, id);
  return id;
}

function splitProps(all) {
  const props = {};
  for (const k in all) {
    if (k === 'key' || k === 'ref') continue;
    props[k] = all[k];
  }
  return props;
}
