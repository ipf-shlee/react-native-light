let nextId = 1;

export const ROOT_ID = 0;

export const View = 'View';
export const Text = 'Text';

export function h(type, props, ...children) {
  return { type, props: props || {}, children: children.flat(Infinity) };
}

export function render(vnode, parentId = ROOT_ID) {
  renderTree(vnode, parentId);
  layout(parentId);
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
    // 원시 children을 문자열로 합쳐서 setText.
    // <Text>Count: {count}</Text> 같은 interpolation 처리.
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
