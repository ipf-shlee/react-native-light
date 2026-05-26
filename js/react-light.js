let nextId = 1;

export const ROOT_ID = 0;

export const View = 'View';
export const Text = 'Text';
export const Pressable = 'Pressable';

export function h(type, props, ...children) {
  return { type, props: props || {}, children: children.flat(Infinity) };
}

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

  const { props, handlers } = splitProps(vnode.props);
  const id = nextId++;
  createView(vnode.type, id, props);
  wireHandlers(id, handlers);
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

// 함수 prop이면서 on으로 시작하면 event handler, 그 외엔 일반 prop.
// key/ref는 React 내부용 prop이라 native로 안 보냄.
function splitProps(all) {
  const props = {};
  const handlers = {};
  for (const k in all) {
    if (k === 'key' || k === 'ref') continue;
    const v = all[k];
    if (typeof v === 'function' && k.startsWith('on') && k.length > 2) handlers[k] = v;
    else props[k] = v;
  }
  return { props, handlers };
}

function wireHandlers(id, handlers) {
  for (const k in handlers) {
    // 'onPress' → 'press'
    const event = k.charAt(2).toLowerCase() + k.slice(3);
    registerCallback(id, event, handlers[k]);
  }
}
