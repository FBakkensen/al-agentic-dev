# Page-JavaScript snippets for the Web Client

Each snippet is one self-contained expression whose value is its last expression: an IIFE, async where it awaits, with no top-level `return` and no wrapper, so the same text runs in every driver's evaluate tool. `playwright-cli eval` takes it as its function argument; `run-code` runs Playwright code, so there the snippet travels inside `page.evaluate`. Placeholders in angle brackets sit inside string literals; read each value off the page or the user's request before substituting. Every snippet but the sign-in opens with the readiness guard, which returns `{ready:false}` instead of throwing, and most then resolve the top page.

## Sign in to the agent container

Runs in the outer document, before the iframe exists. `<username>` and `<password>` are `container.username` and `container.password` from `al-build.json`.

```js
(() => {
  const pw = document.querySelector('input[type=password]');
  if (!pw) return { signInForm: false, outer: document.body.innerText.slice(0, 400) };
  const form = pw.form ?? document;
  const user = [...form.querySelectorAll('input')].find(i => i.offsetParent && ['text', 'email'].includes(i.type));
  if (!user) return { signInForm: true, username: false };
  const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  for (const [i, v] of [[user, '<username>'], [pw, '<password>']]) {
    i.focus(); set.call(i, v);
    i.dispatchEvent(new Event('input', { bubbles: true }));
  }
  form.querySelector('[type=submit], button')?.click();
  return 'submitted';
})()
```

## Where am I

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false, outer: document.body.innerText.slice(0, 400) };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const cap = v => v.querySelector('form.ms-nav-root-form h1, form.ms-nav-root-form h2, form.ms-nav-root-form [role=heading]')?.innerText.trim();
  return {
    ready: true,
    stack: [...f.querySelectorAll('.spa-view')].map(cap),
    page: cap(top),
    dialog: [...top.querySelectorAll('[role=dialog]')].map(d => d.innerText.trim().slice(0, 300)),
    text: top.innerText.slice(0, 1500)
  };
})()
```

`stack` lists the open pages bottom to top; `page` is the only one that accepts clicks. The company is not in it; see Company switch.

## Open a page with Tell Me

Call 1 opens Tell Me. The header's search button does nothing from script.

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  for (const t of ['keydown', 'keyup'])
    f.dispatchEvent(new KeyboardEvent(t, { key: 'q', code: 'KeyQ', keyCode: 81, altKey: true, bubbles: true }));
  return 'sent';
})()
```

Call 2 finds the search input and types into it. The input's label is localised; the return shows it.

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const i = f.activeElement?.tagName === 'INPUT' ? f.activeElement
          : [...top.querySelectorAll('input')].find(e => e.offsetParent && e.getAttribute('role') === 'combobox');
  if (!i) return 'tell me not open';
  const set = Object.getOwnPropertyDescriptor(f.defaultView.HTMLInputElement.prototype, 'value').set;
  i.focus(); set.call(i, '<page name>');
  i.dispatchEvent(new f.defaultView.Event('input', { bubbles: true }));
  return { label: i.getAttribute('aria-label'), typed: i.value };
})()
```

Call 3 reads the results. They mix pages, actions of the current page, and searches; Tell Me exposes no active-row state, and its own view is a stack page.

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  return [...top.querySelectorAll('.ms-DetailsRow')].filter(r => r.offsetParent)
    .map(r => r.innerText.trim().replace(/\s+/g, ' ').slice(0, 80));
})()
```

Call 4 opens a result other than the first: it focuses that row and presses Enter on it. Escape does not close Tell Me; opening a page does.

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const row = [...top.querySelectorAll('.ms-DetailsRow')].filter(r => r.offsetParent)
    .find(r => r.innerText.trim().replace(/\s+/g, ' ').startsWith('<row text>'));
  if (!row) return 'row not listed';
  row.focus();
  for (const t of ['keydown', 'keypress', 'keyup'])
    f.activeElement.dispatchEvent(new KeyboardEvent(t, { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
  return 'enter';
})()
```

Call 5 is Where am I after about two seconds. The new page is on top of the stack, with the page you came from underneath.

## Click a page action by its caption

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const scope = top;   // a dialog button: the dialog element, from the Dialogs listing
  const want = '<caption>';
  const visible = [...scope.querySelectorAll('button,[role=button],a,[role=menuitem]')].filter(e => e.offsetParent);
  const hits = visible.filter(e => [e.innerText, e.getAttribute('aria-label'), e.title].some(s => (s || '').trim() === want));
  if (hits.length !== 1) return { matches: hits.length, visible: visible.map(e => e.innerText.trim() || e.title).filter(Boolean) };
  const h = hits[0];
  if (h.disabled || h.getAttribute('aria-disabled') === 'true' || /itemDisabled|is-disabled/.test(h.className))
    return { disabled: true, hint: h.title };
  h.click();
  return 'clicked';
})()
```

An action under a "More options" or "Actions" menu needs that menu clicked first, in its own call, then a fresh query.

## Close the top page

Run the caption snippet with `want` set to the title of the page's Back arrow. Done when Where am I shows `stack` one shorter and the expected `page` on top.

## Rows

Every list page has a search box, `input[type=search]` with `aria-label="Search <caption>"`. This fills it and presses Enter:

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const w = f.defaultView;
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const i = top.querySelector('input[type=search]');
  if (!i) return 'no search box on this page';
  const set = Object.getOwnPropertyDescriptor(w.HTMLInputElement.prototype, 'value').set;
  i.focus(); set.call(i, '<search text>');
  i.dispatchEvent(new w.Event('input', { bubbles: true }));
  for (const t of ['keydown', 'keypress', 'keyup'])
    i.dispatchEvent(new w.KeyboardEvent(t, { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
  return i.value;
})()
```

Done when a re-read of the rows shows only matches. Rows in a grid:

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  return [...top.querySelectorAll('[role=row]')].map(r => ({
    selected: r.getAttribute('aria-selected'),
    text: r.innerText.trim().replace(/\s+/g, ' ').slice(0, 200)
  })).slice(0, 40);
})()
```

Select a row by clicking a cell of the row that holds `<row text>`:

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const hits = [...top.querySelectorAll('[role=row]')].filter(r => r.innerText.includes('<row text>'));
  if (hits.length !== 1) return { matches: hits.length };
  hits[0].querySelector('[role=gridcell]').click();
  return 'clicked';
})()
```

Done when a re-read shows that row with `aria-selected="true"`.

Tile views, such as role-centre parts, render each record as an `li.brick-entity` with a caption button (`title="<label>: <value>"`) and a per-tile button whose menu (`[role=menuitem]`) belongs to that record.

## Lookup field

Call 1 finds the field's input by its observed `aria-label` (grid inputs often carry none: match on the current value) and clicks the one button in the same gridcell, the caret. Set `click` to `false` to read the field's value alone.

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const click = true;
  const field = '<aria-label or current value>';
  const i = [...top.querySelectorAll('input')].find(e => e.getAttribute('aria-label') === field || e.value === field);
  if (!i) return 'field not found';
  const buttons = [...(i.closest('[role=gridcell]') ?? i.parentElement).querySelectorAll('button')];
  if (!click) return { value: i.value };
  if (buttons.length !== 1) return { buttons: buttons.map(b => b.title || b.innerText.trim()) };
  buttons[0].click();
  return 'opened';
})()
```

Call 2 reads the lookup view:

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const lk = [...f.querySelectorAll('.spa-view.spa-lookup')].find(e => e.offsetParent);
  if (!lk) return 'lookup closed';
  return {
    rows: [...lk.querySelectorAll('[role=row]')].map(r => ({ sel: r.getAttribute('aria-selected'), t: r.innerText.trim().replace(/\s+/g, ' ').slice(0, 80) })),
    links: [...lk.querySelectorAll('a,button')].filter(b => b.offsetParent).map(b => b.innerText.trim()).filter(Boolean)
  };
})()
```

Call 3 clicks a gridcell of the row whose key equals `<key>` exactly; the dropdown commits on click. A key that is not listed means the link to the full list, which opens it as a page, and Rows on that page.

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const lk = [...f.querySelectorAll('.spa-view.spa-lookup')].find(e => e.offsetParent);
  if (!lk) return 'lookup closed';
  const key = '<key>';
  const hits = [...lk.querySelectorAll('[role=row]')].filter(r => [...r.querySelectorAll('[role=gridcell]')].some(c => c.innerText.trim() === key));
  if (hits.length !== 1) return { matches: hits.length };
  hits[0].querySelector('[role=gridcell]').click();
  return 'picked';
})()
```

Call 4 is call 1 with `click` set to `false`. Done when its `value` equals `<key>` and call 2 returns `'lookup closed'`.

## Dialogs

```js
(() => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const ds = [...top.querySelectorAll('[role=dialog]')];
  if (!ds.length) return 'none';
  return ds.map((d, index) => ({
    index,
    text: d.innerText.trim().slice(0, 500),
    buttons: [...d.querySelectorAll('button, a[role=button]')].filter(b => b.offsetParent).map(b => b.innerText.trim() || b.title),
    rows: [...d.querySelectorAll('[role=row]')].map(r => r.innerText.trim().replace(/\s+/g, ' ').slice(0, 150))
  }));
})()
```

Press a dialog button with the caption snippet, its `scope` set to `top.querySelectorAll('[role=dialog]')[<index>]`. Done when the Dialogs snippet returns `'none'`.

## What did that click open?

When an action or caret produced no dialog and no new stack page, this clicks the control and returns `tops`, the outermost elements that appeared: a `.spa-lookup`, a context menu, a notification, a FactBox.

```js
(async () => {
  const f = document.querySelector('iframe')?.contentDocument;
  if (!f?.body) return { ready: false };
  const top = f.querySelector('.spa-view:not(.spa-not-top-most)') ?? f.body;
  const want = '<caption>';
  const visible = [...top.querySelectorAll('button,[role=button],a,[role=menuitem]')].filter(e => e.offsetParent);
  const hits = visible.filter(e => [e.innerText, e.getAttribute('aria-label'), e.title].some(s => (s || '').trim() === want));
  if (hits.length !== 1) return { matches: hits.length };
  const before = new Set([...f.querySelectorAll('*')].filter(e => e.offsetParent));
  hits[0].click();
  await new Promise(r => setTimeout(r, 1200));
  const appeared = [...f.querySelectorAll('*')].filter(e => e.offsetParent && !before.has(e));
  const tops = appeared.filter(e => !appeared.includes(e.parentElement));
  return tops.slice(0, 10).map(e => ({ tag: e.tagName, role: e.getAttribute('role'), cls: e.className.toString().slice(0, 80), text: e.innerText?.trim().replace(/\s+/g, ' ').slice(0, 200) }));
})()
```

## Company switch

1. Open My Settings with Tell Me, then read it with Dialogs.
2. Click the Company value, an `a[role=button]` whose `title` the Dialogs listing shows, with the caption snippet. The company list opens as a second dialog.
3. Click the target row's gridcell, confirm `aria-selected="true"` on it, then press the dialog's confirm button with the caption snippet. My Settings shows the new name.
4. Press My Settings' confirm button: the client reloads into that company and the stack collapses to its role centre. Done when Where am I shows the role centre captioned with the target company.

Data and setup are per company: clean-up in one company says nothing about the others.
