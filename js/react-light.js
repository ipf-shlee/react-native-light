let nextId = 1;

export const ROOT_ID = 0;

// JSX with capitalized tags compiles to `h(View, ...)` (variable reference),
// so View constant resolves to the host type string the native side knows.
export const View = 'View';

// JSX의 빌드 타깃이 될 함수. 그냥 vnode 객체 만드는 평범한 함수.
export function h(type, props, ...children) {
  return { type, props: props || {}, children: children.flat(Infinity) };
}

// 공개 진입점. 트리를 walk하면서 host 함수 emit → 마지막에 layout 1회 호출.
export function render(vnode, parentId = ROOT_ID) {
  renderTree(vnode, parentId);
  layout(parentId);
}

// 함수형 컴포넌트는 호출 결과 vnode를 재귀.
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

  for (const child of vnode.children) renderTree(child, id);
  return id;
}

// key/ref는 React 내부용 prop. 네이티브로 보내면 unsupported prop 경고 발생.
function splitProps(all) {
  const props = {};
  for (const k in all) {
    if (k === 'key' || k === 'ref') continue;
    props[k] = all[k];
  }
  return props;
}
