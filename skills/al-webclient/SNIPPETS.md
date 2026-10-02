# Page-JavaScript snippets for the Web Client

Each snippet is one self-contained expression whose value is its last expression: an IIFE with no top-level `return` and no wrapper, passed as the script text to every driver's evaluate tool.
- Angle-bracket placeholders stand for values the agent reads off the page or the user's request and substitutes before the run; the one placeholder that sits in code, not in a string literal, is named in its section.
- Every snippet but the sign-in opens with the readiness guard, which returns `{ready:false}` instead of throwing, and most then resolve the live page.

## Sign in to the agent container

The agent runs this in the outer document, before the iframe exists. `<username>` is `container.username` and `<password>` is `container.password` from `al-build.json`.

```js
(() => {
  const passwordInput = document.querySelector('input[type=password]');
  if (!passwordInput) return { signInForm: false, outer: document.body.innerText.slice(0, 400) };
  const form = passwordInput.form;
  if (!form) return { signInForm: true, form: false };
  const userInput = [...form.querySelectorAll('input')].find(el => el.offsetParent && ['text', 'email'].includes(el.type));
  const submit = form.querySelector('button[type=submit], input[type=submit], button:not([type])');
  if (!userInput || !submit) return { signInForm: true, username: !!userInput, submit: !!submit };
  const setValue = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  for (const [input, value] of [[userInput, '<username>'], [passwordInput, '<password>']]) {
    input.focus(); setValue.call(input, value);
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }
  submit.click();
  return 'submitted';
})()
```

## Where am I

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false, outer: document.body.innerText.slice(0, 400) };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const heading = view => view.querySelector('form.ms-nav-root-form h1, form.ms-nav-root-form h2, form.ms-nav-root-form [role=heading]')?.innerText.trim();
  return {
    ready: true,
    title: document.title,
    stack: [...frame.querySelectorAll('.spa-view')].map(view => heading(view)),
    page: heading(livePage),
    dialog: [...livePage.querySelectorAll('[role=dialog]')].map(dialog => dialog.innerText.trim().slice(0, 300)),
    text: livePage.innerText.slice(0, 1500)
  };
})()
```

`stack` lists the open pages bottom to top, and `page` is the live one. On a root page `page` can be the company name, so the agent reads the root page's caption, and its record, from `title`. The company shows up only in the role centre's caption, which the agent reads as Company switch describes.

## Open a page with Tell Me

Call 1: the agent opens Tell Me. The header's search button does nothing from script.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  for (const type of ['keydown', 'keyup'])
    frame.dispatchEvent(new frame.defaultView.KeyboardEvent(type, { key: 'q', code: 'KeyQ', keyCode: 81, altKey: true, bubbles: true }));
  return 'sent';
})()
```

Call 2: the agent types into Tell Me's input. That input is the active element whose label, without its closing period, is the live page's own heading; otherwise this throws, so it never types into a data field, and the agent runs call 1 first. The label is localised; the return shows it.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const heading = livePage.querySelector('form.ms-nav-root-form h1, form.ms-nav-root-form h2, form.ms-nav-root-form [role=heading]')?.innerText.trim();
  const input = frame.activeElement;
  if (input?.tagName !== 'INPUT' || !heading || input.getAttribute('aria-label')?.replace(/\.$/, '') !== heading) throw new Error('Tell Me input is not the active element');
  const frameWin = frame.defaultView;
  const setValue = Object.getOwnPropertyDescriptor(frameWin.HTMLInputElement.prototype, 'value').set;
  setValue.call(input, '<page name>');
  input.dispatchEvent(new frameWin.Event('input', { bubbles: true }));
  return { label: input.getAttribute('aria-label'), typed: input.value };
})()
```

Call 3: the agent reads the results. They mix pages, actions of the current page, and searches; Tell Me exposes no active-row state, and its own view is a stack page.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  return [...livePage.querySelectorAll('.ms-DetailsRow')].filter(row => row.offsetParent)
    .map(row => row.innerText.trim().replace(/\s+/g, ' ').slice(0, 80));
})()
```

Call 4: Enter on the input opens the first result, and a click on a result's row opens that result (a row is not focusable, so it cannot take Enter). With `<row text>` empty this presses Enter on the Tell Me input, under call 2's guard; otherwise it clicks the row that starts with that text. Escape does not close Tell Me; opening a page does.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const want = '<row text>';
  if (want) {
    const row = [...livePage.querySelectorAll('.ms-DetailsRow')].filter(el => el.offsetParent)
      .find(el => el.innerText.trim().replace(/\s+/g, ' ').startsWith(want));
    if (!row) return 'row not listed';
    row.click();
    return 'clicked';
  }
  const heading = livePage.querySelector('form.ms-nav-root-form h1, form.ms-nav-root-form h2, form.ms-nav-root-form [role=heading]')?.innerText.trim();
  const input = frame.activeElement;
  if (input?.tagName !== 'INPUT' || !heading || input.getAttribute('aria-label')?.replace(/\.$/, '') !== heading) return 'Tell Me input is not the active element';
  for (const type of ['keydown', 'keypress', 'keyup'])
    input.dispatchEvent(new frame.defaultView.KeyboardEvent(type, { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
  return 'enter';
})()
```

Call 5: the agent runs Where am I, re-reading until `page` is the page asked for. The new page is live on top of the stack, with the page it came from underneath.

## Click a page action by its caption

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const scope = livePage;
  const want = '<caption>';
  const visible = [...scope.querySelectorAll('button,[role=button],a,[role=menuitem]')].filter(el => el.offsetParent);
  const hits = visible.filter(el => [el.innerText, el.getAttribute('aria-label'), el.title].some(text => (text || '').trim() === want));
  if (hits.length !== 1) return { matches: hits.length, visible: visible.map(el => [el.innerText.trim(), el.getAttribute('aria-label'), el.title].find(text => text && /[\p{L}\p{N}]/u.test(text))).filter(Boolean) };
  const target = hits[0];
  if (target.disabled || target.getAttribute('aria-disabled') === 'true' || ['is-disabled', 'itemDisabled'].some(name => target.classList.contains(name)))
    return { disabled: true, hint: target.title };
  target.click();
  return 'clicked';
})()
```

For an action under a menu, the agent first clicks the menu's own button, `<menu caption>` from the `visible` list this snippet returns, in its own call, then queries again.

## Close the top page

The agent runs Click a page action by its caption with `want` set to the title of the page's Back arrow. Done when Where am I shows `stack` one shorter and the expected `page` live.

## Page mode

A card or document page is in view mode, where its fields are text and it has no inputs, or in edit mode. The header's `button.header-action-edit_view` is the toggle in every language: its `aria-pressed` is `true` in edit mode, and its title names what a click does. From a list, Manage → Edit or Manage → View opens the selected record in that mode. The agent reads the mode, and with `<mode>` set to `edit` or `view` switches it, before it types into a field or looks for an input.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const toggle = livePage.querySelector('button.header-action-edit_view');
  const inputs = [...livePage.querySelectorAll('input')].filter(el => el.offsetParent).length;
  if (!toggle) return { toggle: false, inputs };
  const editing = toggle.getAttribute('aria-pressed') === 'true';
  const want = '<mode>';
  if ((want === 'edit' || want === 'view') && (want === 'edit') !== editing) { toggle.click(); return { switched: want }; }
  return { editing, title: toggle.title, inputs };
})()
```

Done when a re-read returns `editing` as wanted and, in edit mode, `inputs` above zero. A page with no toggle (a list, a dialog) returns `toggle:false`.

## Rows

When the page shows a search box (`input[type=search]`), the agent fills it and presses Enter:

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const frameWin = frame.defaultView;
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const input = livePage.querySelector('input[type=search]');
  if (!input) return 'no search box on this page';
  const setValue = Object.getOwnPropertyDescriptor(frameWin.HTMLInputElement.prototype, 'value').set;
  input.focus(); setValue.call(input, '<search text>');
  input.dispatchEvent(new frameWin.Event('input', { bubbles: true }));
  for (const type of ['keydown', 'keypress', 'keyup'])
    input.dispatchEvent(new frameWin.KeyboardEvent(type, { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
  return input.value;
})()
```

Done when a re-read of the rows shows only matches. The agent reads the rows of a grid with:

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  return [...livePage.querySelectorAll('[role=row]')].map(row => ({
    selected: row.getAttribute('aria-selected'),
    text: row.innerText.trim().replace(/\s+/g, ' ').slice(0, 200)
  })).slice(0, 40);
})()
```

The agent selects a row by clicking a cell of the row that holds `<row text>`:

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const flat = text => text.trim().replace(/\s+/g, ' ');
  const hits = [...livePage.querySelectorAll('[role=row]')].filter(row => flat(row.innerText).includes(flat('<row text>')));
  if (hits.length !== 1) return { matches: hits.length };
  const cell = hits[0].querySelector('[role=gridcell]');
  if (!cell) return 'row has no gridcell';
  cell.click();
  return 'clicked';
})()
```

Done when a re-read shows that row with `aria-selected="true"`.

Tile views (Extension Management, role-centre parts) render each record as an `li.brick-entity` with a caption button (`title="Name: <value>"`) and a per-tile "Show more options" button that opens the record's context menu (`[role=menuitem]`).

## Lookup field

Call 1: the agent finds the field's input by its observed `aria-label` (card and grid inputs often carry none: it matches on the current value) and clicks the one caret beside it, an `a[role=button]` titled `Choose a value for <caption>` in a grid cell or on a card (a `button` is accepted too). With `click` set to `false` it reads the field's value alone.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const click = true;
  const field = '<aria-label or current value>';
  const input = [...livePage.querySelectorAll('input')].find(el => el.getAttribute('aria-label') === field || el.value === field);
  if (!input) return 'field not found';
  const buttons = [...(input.closest('[role=gridcell]') ?? input.parentElement).querySelectorAll('button, a[role=button]')];
  if (!click) return { value: input.value };
  if (buttons.length !== 1) return { buttons: buttons.map(button => button.title || button.innerText.trim()) };
  buttons[0].click();
  return 'opened';
})()
```

Call 2: the agent reads the lookup view.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const lookupView = [...frame.querySelectorAll('.spa-view.spa-lookup')].find(view => view.offsetParent);
  if (!lookupView) return 'lookup closed';
  return {
    rows: [...lookupView.querySelectorAll('[role=row]')].map(row => ({ selected: row.getAttribute('aria-selected'), text: row.innerText.trim().replace(/\s+/g, ' ').slice(0, 80) })),
    links: [...lookupView.querySelectorAll('a,button')].filter(el => el.offsetParent).map(el => el.innerText.trim()).filter(Boolean)
  };
})()
```

Call 3: the agent clicks the key's link in the row whose key equals `<key>` exactly. The first click only selects the row, so the call returns `selected`; the agent runs it again, and a click on the selected row's `a[role=button]` commits the pick and returns `picked`. A key with no link falls back to the cell. When the key is not listed, the agent opens the full list from the link call 2 shows, which opens it as a page, and uses Rows there.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const lookupView = [...frame.querySelectorAll('.spa-view.spa-lookup')].find(view => view.offsetParent);
  if (!lookupView) return 'lookup closed';
  const key = '<key>';
  const hits = [...lookupView.querySelectorAll('[role=row]')].filter(row => [...row.querySelectorAll('[role=gridcell]')].some(cell => cell.innerText.trim() === key));
  if (hits.length !== 1) return { matches: hits.length };
  const cell = [...hits[0].querySelectorAll('[role=gridcell]')].find(item => item.innerText.trim() === key);
  const selected = hits[0].getAttribute('aria-selected') === 'true';
  (cell.querySelector('a[role=button]') ?? cell).click();
  return selected ? 'picked' : 'selected';
})()
```

Call 4: the agent runs call 1 with `click` set to `false`, passing `field` as the aria-label or, for an input without one, as the input's current value, which is now `<key>`. Done when call 3 has returned `picked`, it finds the input with `value` equal to `<key>`, and call 2 returns `'lookup closed'`.

## Dialogs

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const dialogs = [...livePage.querySelectorAll('[role=dialog]')];
  if (!dialogs.length) return 'none';
  return dialogs.map((dialog, index) => ({
    index,
    text: dialog.innerText.trim().slice(0, 500),
    buttons: [...dialog.querySelectorAll('button, a[role=button]')].filter(el => el.offsetParent).map(el => el.innerText.trim() || el.title),
    rows: [...dialog.querySelectorAll('[role=row]')].map(row => row.innerText.trim().replace(/\s+/g, ' ').slice(0, 150))
  }));
})()
```

The agent presses a dialog button with Click a page action by its caption, its `scope` set to `livePage.querySelectorAll('[role=dialog]')[<index>]`; `<index>` is the placeholder that sits in code. Done when the Dialogs snippet returns `'none'`.

## What did that click open?

Read-only: this clicks nothing. After the agent's own click, it reports the stack, the live page's caption, the dialogs, the lookup rows, and the visible menu items, so the agent reads what the click opened instead of guessing or clicking again.

```js
(() => {
  const frame = document.querySelector('iframe')?.contentDocument;
  if (!frame?.body) return { ready: false };
  const livePage = frame.querySelector('.spa-view:not(.spa-not-top-most)') ?? frame.body;
  const heading = view => view.querySelector('form.ms-nav-root-form h1, form.ms-nav-root-form h2, form.ms-nav-root-form [role=heading]')?.innerText.trim();
  const flat = el => el.innerText.trim().replace(/\s+/g, ' ');
  const lookupView = [...frame.querySelectorAll('.spa-view.spa-lookup')].find(view => view.offsetParent);
  return {
    stack: [...frame.querySelectorAll('.spa-view')].map(view => heading(view)),
    page: heading(livePage),
    dialogs: [...livePage.querySelectorAll('[role=dialog]')].map(dialog => flat(dialog).slice(0, 300)),
    lookupRows: lookupView ? [...lookupView.querySelectorAll('[role=row]')].map(row => flat(row).slice(0, 80)) : null,
    menuItems: [...frame.querySelectorAll('[role=menuitem]')].filter(el => el.offsetParent).map(el => flat(el).slice(0, 80))
  };
})()
```

## Company switch

1. The agent opens My Settings with Open a page with Tell Me, then reads it with Dialogs.
2. The agent clicks the Company value with Click a page action by its caption. The control has no inner text, so the Dialogs listing shows it by its title, `Review or update the value for Company`. The company list opens as a third stacked view on top of My Settings.
3. The agent clicks the target row's gridcell and confirms the selection as in Rows, then presses the dialog's confirm button with Click a page action by its caption. My Settings shows the new name.
4. The agent presses My Settings' confirm button: the client reloads into that company and the stack collapses to the page in the URL, the role centre when the URL names no page. Done when Where am I shows that page and, on the role centre, the target company as its caption.

Data and setup are per company: clean-up in one company says nothing about the others.
