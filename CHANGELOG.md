## [0.6.1] - 2026-08-03 — three declared properties are now read

**Two deprecation warnings were pointed at the wrong people.**

The legacy `tools.<tool>.result` mirror warned where it is *written* — on
every successful tool call. An author using auto-merge, which is the
recommended path and the common one, was told about a deprecation they cannot
act on; an author who actually reads that namespace heard nothing, because
reading a value that is present succeeds quietly. When the mirror goes, the
second author is the one whose document stops resolving. The warning now fires
at the read, once per path. The mirror itself still writes: removing it today
would break those readers silently, which is the failure the warning exists to
prevent. Its "removal in 0.6.0" line is gone too — this release is 0.6.1 and
the mirror is still here, so the sentence had stopped being true.

A theme that declares a role Material 3 retired (`background`, `onBackground`)
now says so rather than quietly resolving to the replacement.

**Chart padding scales with the box.** Every paint method opened with a flat
40px gutter and returned early when it left no room. A 140-tall chart with a
legend has 77px for the plot, so it drew a panel and nothing inside it — no
exception, no error widget, no warning. Turning the legend on by default made
that the common case; the flat number is what made it silent.

**`data:` images are decoded once per URI.** `MemoryImage` keys on the byte
list's identity, so decoding the same URI again produced a provider Flutter's
image cache had never seen: every rebuild re-ran the base64 decode and the
image decode for a picture that had not changed. Bounded at 64 entries,
oldest-first — a document can name any number of data URIs, and holding all of
them trades a stutter for a leak.

**`label` is declared on the eleven input widgets whose factories already read
it.** `otpInput` and `rating` are left alone: theirs do not.


**Three properties were declared, validated, and never drawn.** A new suite
asks what a widget *shows* rather than whether it drew — the render matrix
cannot tell a working widget from one that ignores half its document, because
both produce a clean frame.

- `chart` read only `showLegend`, a name that appears nowhere in §10, and
  defaulted it to false. A chart written the documented way — with
  `options.legend.position` — declared its dataset labels and drew no legend
  at all. The position is now read and honoured (`none` hides it); the legacy
  flag is consulted only when the documented property is absent, so a stale
  key cannot override the spec'd one.
- `scrollView` read `child` and ignored `children` and `slivers`, both of
  which the registry declares. Its own example scrolled an empty viewport.
  Slivers are laid out in order rather than dropped: this scroll view cannot
  host the sliver protocol, and content in the wrong arrangement beats content
  that vanishes.
- `floatingActionButton` required an undeclared `isExtended` flag before it
  would draw its `label` — which §2.8.7 documents as "Extended FAB label",
  with no such flag anywhere. Supplying a label now asks for the extended
  form; `isExtended` still wins when set explicitly.

**Theme roles resolve the same from both positions.** `{{theme.color.<role>}}`
went through a path that only knew what the bundle had declared, while
`color: "<role>"` derived the rest from `seed` — so a seed-only theme answered
one way in a colour property and returned empty to a binding. §5.3.1 says the
missing roles derive; that is now true from either.

**`MCPLogger.onRecord`** lets a host receive the runtime's diagnostics.
Without it they reach `dart:developer` and nobody else, which is the wrong
audience for a message aimed at whoever wrote the document — a theme role
declared and dropped, for instance. Records reach an installed sink in every
build mode; `enableLogging` still governs only the developer-log path.
Declaring a role Material 3 retired (`background`, `onBackground`) now says so
instead of quietly resolving to its replacement.


**`registerWidget` may now be called before `initialize`, and validation
honours what it registers.** It used to throw before initialization, which
made host widgets impossible to use as documented: schema validation runs
inside `initialize`, so a type registered afterwards was rejected in the very
document that introduced it, and the host was told its own extension was
malformed. Offering an extension mechanism and refusing what it produces is a
contract disagreeing with itself. The extension's own subtree is the host's
contract and is not checked; everything around it still is, so an unregistered
type stays the error it should be. `registerAction` is unchanged.

`StateChangeEvent` is exported alongside `StateManager` — a host bridging two
runtimes has to name the type it receives from `StateManager.stream`.


**Widgets are now drawn before release, not only validated.**
`test/spec_compliance/widget_render_matrix_test.dart` renders every widget in
the registry — each example the spec ships for it, plus a document synthesized
from its required properties — and fails on a drawn error widget as well as on
a thrown exception, since the renderer reports a broken widget by painting a
red box rather than by throwing. The first run failed 29 of 158. Everything
below is what that found; none of it was new breakage, and none of it was
reachable by schema validation, unit tests or a build, all of which were green.

- **`resolve<T>(null)` threw whenever `T` was non-nullable.** Factories were
  written as `resolve<String>(properties['x']) as String? ?? ''` — the author
  expecting null and supplying a fallback — and the cast threw before the
  fallback could run, so **every one of those fallbacks was dead code**. That
  is why `markdown` never once resolved the `content` alias its own source
  comment says it accepts, and why any binding that had not been set yet
  crashed the widget rather than falling back. Fixed at 26 call sites.
- **JSON integers were cast straight to `double`.** `"width": 640` threw in 19
  places across 8 widgets. They now go through `parseDimension`, which takes
  both the number and the `{value, unit}` object the schema allows.
- `dataTable` read `sortColumn` / `sortAscending` without resolving them,
  though the spec declares both `binding` — the documented form threw. Both
  were also read and discarded behind `ignore: unused_local_variable`, so the
  documented sort did nothing at all. It now dispatches `onSort` from sortable
  headers with `event.column` and applies the sort to the rendered rows.
- `staggeredGrid` cast `columns` to a number, though §declares
  `number | object` and its own example passes the responsive
  `{ default, md, lg }` map; `scrollDirection` was read and discarded, so
  `horizontal` looked like it had taken. Both honored.
- `stepper` required each step's `title` to be a widget while §2.6.20's
  example writes a string, falling back to a `titleText` key that appears
  nowhere in the spec.
- `splitter` read `sizes` as a string only, so the literal array in its own
  example threw. `segmentedControl` asserted when its bound selection had no
  value yet — the normal state of a fresh document. `dragTarget` rejected the
  `children` form the registry documents. `webView` called `setState` from
  `initState`, so any platform without a web view failed the whole page
  instead of reporting through `onError`.


`dateTimePicker.dateFormat` / `timeFormat` and `pdfViewer.showZoom` were
declared in the spec and never read by their factories, so setting them did
nothing. Found by the drift audit once its prose parser learned to read table
rows that name two properties in one cell.

`dateFormat` / `timeFormat` substitute the common pattern tokens (`yyyy`,
`MM`, `dd`, `HH`, `hh`, `mm`, `ss`, `a`); the bound value stays ISO-8601
regardless, so this changes only what the closed field shows. `showZoom: false`
pins the view, since the PDF open-parameter set has no control for hiding the
zoom widget on its own.

Picks up `flutter_mcp_ui_core 0.5.1`, whose schema stops silently accepting
malformed children. The floor stays `^0.5.0` — this is the same 1.4 cut,
finished, not a second one. Two documents in this package's own suite were
relying on the gap: the `demo_ui` timeline fixture bound its entries to
`events`, which the factory does not read (that panel had been rendering
empty), and a form-flow document carried `marginTop` / `marginBottom` inside
`style`, which nothing reads.

## [0.6.0] - 2026-08-03 — One asset path, 23 widgets, openUrl (spec 1.4)

### Changed — documentation

- README states 1.4 rather than 1.3, and its Quick Start compiles. It showed
  an `MCPUIRenderer` widget that **has never existed** in this package, with no
  Flutter import. Rewritten around `MCPUIRuntime.initialize` + `buildUI()`,
  including the point that `buildUI()` supplies its own MaterialApp when the
  definition declares navigation — wrapping it in another is what made every
  test in the showcase example see two Scaffolds.

### Fixed — the report that started this

A server read its own bundle, resolved the assets to `data:` URIs and put them
in state, and **neither widget that can paint an image could show them**.
`image` rendered the words "Base64 not supported" where the picture belonged.
`box.decoration.image` was the only field in its own resolver that never went
through `context.resolve`, so a bound source arrived as the literal
`"{{item.picture}}"` and matched no scheme.

Both were symptoms of one absence: every factory hand-rolled its own
`startsWith` chain, and between all of them only `http(s)`, `assets/` and
`data:` were ever handled — exactly the three a **synchronous** loader can
build. `bundle://` and `client://` were declared by the spec and implemented
nowhere.

- **`lib/src/assets/`** — `AssetRef` parsing, `AssetResolver` with injected
  readers for bundle / client / origin sources, and `AssetRefImage` so the
  asynchronous forms wait inside an `ImageProvider` and widgets stay
  synchronous (spec §6.12.5).
- `supportedForms` is honest by construction: a form appears only when the
  reader serving it was injected, so a runtime cannot declare more than the
  host wired (§6.12.4, §18.2.12).
- `image` / `avatar` / `icon` / `box.decoration` converge on that one path.
  `avatar` and `icon` consequently accept `data:`, `bundle://`, `client://`
  and the object form, where they used to accept two schemes and one.
- No `dart:io`: `client://` is an injected port, so the runtime still builds
  for web and each host supplies the reader its platform can honour.

### Changed — narrowing (why this is a minor)

- An empty string is no longer a valid asset source. A source that may be
  absent is expressed as a binding; the runtime treats a binding resolving to
  empty as unresolved (§6.12.2a, §6.12.4).
- `segmentedControl` renders its three variants differently. All three
  resolved to `SegmentedButton`, so a document declaring `tabs` or `buttons`
  got the same control and its declaration meant nothing.

### Added — 23 widgets

**Core** `fileInput` `multiSelect` `combobox` `otpInput` `dateTimePicker`
`accordion` `popover` `menu` `contextMenu` `breadcrumb` `pagination` `link`
**Advanced** `qrCode` `barcode` `pdfViewer` `diffViewer` `richTextEditor`
`splitter` `resizable` `kanban` `gantt` `spreadsheet`
**Client** `voiceInput`

Each carries the part its composition drops. `otpInput` distributes a pasted
or autofilled code across cells and declares one-time-code intent through a
single field — a row of `textInput`s has neither. `combobox` owns focus: the
list never takes it, arrows move a highlight without moving the caret, Escape
closes without clearing. `accordion` keeps collapsed panels in the tree, since
a removed subtree reads to assistive technology as content that does not
exist. `kanban`'s drop targets are the gaps between cards, so a move reports
*where* it landed. `gantt` lays header and rows from one scale, which is what
a grid-based composition cannot keep aligned through scroll. `spreadsheet`
evaluates formulas through the binding engine — the §7.1 sandbox — or not at
all, and `formulas` is off by default.

`qrCode` and `barcode` carry pure-Dart encoders rather than a dependency: this
runtime is embedded in several hosts, so a rendering dependency here is one
all of them take on every platform. Both refuse rather than emit something
wrong — a payload past capacity, contrast below 3:1, an EAN-13 whose check
digit does not match.

`pdfViewer` and `voiceInput` split by conditional import. The web branch works
for real (the browser's own PDF support; `SpeechRecognition`); the branch that
cannot reports through `onError` rather than rendering a control that does
nothing.

### Added — `navigation.openUrl` (spec §4.3.3)

Core had no way out of the application. Opening is the host's act, so the
runtime enforces the §7.3.4 scheme policy — `javascript:`, `data:`, `file:`,
`blob:`, `vbscript:` refused before the host is asked — and delegates through
a callback, the shape `openApp` and `exitApp` already use. Every refusal
reports: no handler, a host that declines, and a host that throws all fail
loudly, because a silent no-op is indistinguishable from a broken document.

### Added — 17 palette aliases

`dataGrid` `treeView` `meter` `video` `audio` `modal` `dialog` `alert`
`confirmDialog` `toast` `skeleton` `tag` `steps` `scrollArea` `numberInput`
`dropdownMenu` `code` `label`, plus `autocomplete` `collapsible` `hoverCard`
`navLink` on the new widgets. Accepted on input, never emitted.

### Fixed — an intermittent lifecycle test, and the code under it

`ResourceEntry.updateState` compared age with a strict `>`, so `Duration.zero`
— which means "already stale/expired on load" — only took effect if the clock
had ticked between `markReady` and the call. The same assertion passed or
failed by scheduling, and the suite failed intermittently on a different case
each run. Now inclusive; non-zero durations are unaffected, since age crosses
those between ticks either way.

### Dependencies

- `flutter_mcp_ui_core ^0.4.3 → ^0.5.0`, `mcp_bundle ^0.4.8 → ^0.4.9`
- adds `web` — reached only through conditional imports, never compiled into
  native builds. `isA<JSFunction>` was avoided so the SDK floor stays at 3.0.

## [0.5.4] - 2026-07-31

### Fixed — `registerAction` could not be called from outside the package

`MCPUIRuntime.registerAction(String type, ActionExecutor executor)` is public, but neither `ActionExecutor` — the type it asks for — nor `ActionResult` — the type that must be returned — was exported from the library. A host had no way to name either, so the method was unreachable and custom action executors could not be supplied at all.

Both are now exported. Additive: no existing name moved or changed. A regression compiles a host-defined executor against the library barrel, which is the only thing that can catch this — every in-package test names the types through their source files and passes regardless.

### Fixed — a definition's own initial state discarded `entry.*` and `identity.*` (§8.9)

A host adopts the entry and identity, then the definition's initial state is installed as a wholesale replacement of the state container — which cleared the roots they had just been published into. Every `entry.*` / `identity.*` binding then resolved to `null` for any definition declaring `state.initial`.

The symptom is silence rather than an error. A deep-linked screen renders with blanks where the link's parameters belong and reads as an ordinary visit by someone who is not signed in, which is precisely the reading §8.9.6 reserves for a runtime that does not implement this section at all.

Both definition types were affected through different calls — an application replaces the container, a page initializes it — and every sample document is a page. Routing was never affected: a launch route is read from the session rather than from state, so the deep link landed on the right screen and only its parameters went missing. `identity.*` recovered on the next promotion, since that writes a single path; `entry.*` never returned, because nothing re-adopts it.

`StateManager` now takes reservations: `reserveHostRoot(root)` marks a root as held on behalf of someone other than the document, and both `setState` and `initialize` carry reserved roots across a replacement. `EntrySession` reserves `entry` and `identity` when it is constructed. A reserved key present in the incoming state does not win — §8.9.2 makes these read-only to the document, so a collision is shadowing rather than supplying.

The reservation is registered rather than named inside `StateManager`, so a container that holds no host facts — an embedded scope's own state tree (§6.11.3) — reserves nothing, and a document there may keep its own state under those names.

**Why it shipped:** the §8.9 suite booted definitions with no `state.initial`, which is the one shape that hides this, and the launch-route assertions read the session object rather than a binding. Both gaps are closed: the regressions now cover application and page, and assert through resolved bindings.

## [0.5.3] - 2026-07-28 — Composition Profile: rendering definitions from other origins (spec 1.4)

Implements the consumer side of composition. Spec 1.3 §11.9 `dashboard` already said how an application presents itself *when embedded* — nothing said how an application *embeds*. This release adds that, so one bundle can compose several MCP servers into one product.

### Fixed — lifecycle hooks (spec §1.5, §6.8, §9.9.1, §18)

Auditing the seven hooks of §1.5.1 against this runtime found that no mount path implemented the full set, and that hooks were being dropped before execution ever came into it. A page written exactly the way §6.8.1 shows it — subscribe in `onReady`, release in `onDestroy` — parsed as a page with no hooks at all, so a device's live reading streamed when the page was embedded and sat blank when the same page was opened on its own, with every layer beneath reporting success.

**Parsing.** `LifecycleDefinition.fromDefinition(definition)` replaces `fromJson(lifecycleObject)`:
- Reads **both placements** §1.5.3 allows — top-level hook fields on the definition and a grouped `lifecycle` object — and merges them. Only the grouped form was read before.
- Accepts **a single Action** as well as an array (§1.5.1). A bare Action returned null, which is a hook that never runs.
- The canonical name is **`onInit`** (§1.5.1). `onInitialize` is accepted as a deprecated alias.
- `onEnter` / `onLeave` are not spec hooks — §6.8.3 already routes a page through `onMount` / `onUnmount` — so they are folded onto those as deprecated aliases.
- A hook named in both placements is an error per §1.5.3; until 0.6.0 it warns (`LifecycleDefinition.aliasWarnings`) and keeps one copy, so a document that used to load still loads. `fromJson` remains as a deprecated shim. Both removals land in 0.6.0 alongside the deprecations already announced for that release.

**Execution.** New `LifecycleRunner` owns hook order for every mount site; a site now says only *when* it mounted:
- **Routed pages** run `onInit` / `onReady` / `onDestroy`, which they never did — they ran only `onEnter` / `onMount` / `onLeave` / `onUnmount`, two of which are not spec hooks.
- **Applications** run `onMount` / `onUnmount`, and take `onPause` / `onResume` from the parsed definition rather than only from a legacy runtime-config path that a document could not reach.
- **Embedded `view`s** release on unmount. The embedded path started subscriptions and never ended them, so a tile that went away left the node streaming to a scope nobody read.
- **Teardown has one owner** — the widget that mounted the definition. Navigation used to tear the outgoing page down as well; with `onLeave` folded onto `onUnmount` that overlap would have fired the same hook up to three times and `onDestroy` twice.

**Placements that were never implemented at all:**
- **Instance-level hooks on any widget** (§6.8.2) — a widget's own `lifecycle: {}` block was read nowhere, so it was silently dropped. New `LifecycleHost` wraps a widget only when it declares hooks.
- **Template instances** (§9.9.1, and a MUST in §18) — a template's `onMount` / `onUnmount` fire once per instance. `UseTemplateFactory` ran neither.

Covered by `test/runtime/lifecycle_matrix_test.dart`: the same document mounted as a routed page, as an embedded `view`, and as an instance-level block must run the same hooks in the same order. Each path passed its own tests in isolation before, which is why the divergence stayed invisible.

### Added — entry & identity (spec 1.4 §8.9)

A definition is often reached from outside the app — a scanned code, a tag, a link — and the viewer may or may not be signed in. This adds the consumer side of that: what a document may read about its arrival, and the one transition it may request.

- **`entry.*` / `identity.*` bindings** — `entry.route`, `entry.params.*`, `entry.issuer.*`, `entry.grant.scope`, `entry.canSteward`, `entry.notice`, `identity.state`, `identity.subject.*`, `identity.canPromote`. Read-only, and `null` on a runtime whose host wired nothing (§8.9.6), so a document written against §8.9 degrades to its guest rendering instead of failing.
- **`identity.promote` / `identity.release` actions** — carry no credential in either direction; the result reports only whether the transition occurred. Unsupported (not failed) when the host wired no handler.
- The value types (`EntryContext` / `IdentityContext` and friends) live in `flutter_mcp_ui_core` alongside the other spec types; this package re-exports them and owns the behaviour. A type that only a Flutter runtime can name is a type an authoring tool or validator cannot check.
- **`EntrySession`** on the runtime — the host adopts an entry, adopts or replaces the principal, and registers promotion handlers. Replacing the principal re-evaluates bound expressions **in place**: the document is not rebuilt and its state is not discarded (§8.9.4).
- **Launch route** — `MCPUIRuntime.initialize(..., launchRoute:)` opens the definition at a requested page instead of its own `initialRoute`, and `entry:` implies one when the entry named a route. The two are kept apart deliberately: §8.9.1 reserves the `entry.*` tree for definitions reached from **outside**, so an in-app `navigation.openApp` sets only the route. Folding it into an entry would make every app-to-app open read as a scan to a document asking how it was reached. A route the document no longer declares is **not** honoured silently: the runtime falls back and reports `RouteManager.launchRouteMissing`, because a stale binding that renders the home page looks exactly like a working one.

`entry.params` is a separate root from `route.params` by design — route parameters say where in the document the viewer is, entry parameters say what was scanned to get here, and only the latter survives internal navigation.

**These bindings are not authority.** They decide what a screen offers; every privileged operation is still authorized at the serving origin (§8.9.5).

Two guards found by mutating the harness rather than by review:
- A `state` action targeting `entry.*` / `identity.*` is rejected (`READ_ONLY_BINDING`) instead of silently dropped.
- Resolution has a **dedicated branch** ahead of the generic fallback. Without it the fallback searches page and app state first, so a document could set its own `page.entry` and forge both `canSteward` and a launch route. Pinned by `test/entry/entry_identity_test.dart` "document state cannot shadow entry.* or identity.*" — the first version of that suite passed with the branch removed, which is what surfaced the hole.

### Added
- **`view` widget** (`src/widgets/utility/view_factory.dart`, spec §2.13.1) — embeds a `DefinitionSource` anywhere in a tree. Accepts all four source forms (§1.9.1): an inline definition, a `ui://` uri on the current origin, a qualified `{ $ref, from }` reference to another origin, or a binding to a definition held in state. Supports `props` / `fallback` / `loading` / `onError` / `theme`.
- **`MCPUIRuntime.registerDefinitionResolver(resolve)`** — the host seam, mirroring `registerStreamSource`. The runtime never learns how a connection is opened; establishing outbound connections is a host capability (§6.11.1). Held on `Renderer` (root contexts are created on demand) and carried down by `RenderContext.createChildContext`.
- **`RenderContext.createEmbeddedScope({props, inheritTheme})`** — the isolated scope an embedded definition renders in (§6.11.3, §7.10.1). A fresh `StateManager` is what makes the isolation real; `props` is the only embedder→embedded channel, and `localVariables` are deliberately not inherited.
- **`RouteValue` widened to any `DefinitionSource`** (`src/routing/route_value.dart`, spec §1.2.1) — a whole route may be another origin's page. Origin-carrying route values normalise to a page whose content is a single `view`, so the route surface and the widget surface cannot drift apart; both go through one implementation. Inline `PageDefinition` route values (a v1.0 spec form this runtime had never supported) now work too, as does the v1.3 `{page, transition}` wrapper.

### Changed
- `RouteInfo.pageUri` typed `String` → `dynamic`. A route value is no longer necessarily a uri. Source-compatible (Dart implicitly downcasts from `dynamic`), and a uri route still yields a `String`; only the new structural forms differ. No consumer outside this package's own tests reads it.
- Page caching keys through `routeValueCacheKey()` in both consumers (`RouteManager`, `ApplicationShell`). Structural routes key by route path, not by uri — two routes reading the same uri from **different** origins must not share a cache entry, which would render one device's UI on the other's route. The same key is used by the lifecycle lookups so `onEnter` / `onLeave` / `pagePause` keep firing for composed routes.
- `flutter_mcp_ui_core` floor raised `^0.4.2 → ^0.4.3` (the regenerated widgets schema carrying `view`). Consumers should bump to `^0.5.3`.

### Security
- Registering a resolver is how a host **claims** the Composition Profile. Without one, `view` fails closed and renders its `fallback` — it does **not** resolve a foreign `$ref` against the host's own origin, which would put one server's UI under another's identity (spec §7.10.1 rule 6, §18.7.3).
- An embedded scope cannot read the embedder's state, and failure is contained per view: a dead origin renders that view's `fallback` while its siblings and the embedding page keep rendering.

### Fixed — analyser cleanup shipped in the same cut (62 issues → 0)

Not cosmetic-only; three of these change behaviour and are called out as such.

- **`BuildContext` used across `await` (6 sites)** — `PermissionManager._promptUser` / `checkAndPrompt` and `ClientActionHandler` could raise a dialog on an element that had already been unmounted (a page popped while the action was in flight), which throws. All six now re-check `context.mounted` first; a gone surface yields "no decision" instead of an exception. One pre-existing `// ignore: use_build_context_synchronously` was replaced by a real guard. **Behaviour change**: a permission prompt whose surface disappeared mid-flight is now declined rather than throwing.
- **`Radio` / `RadioListTile` migrated to a `RadioGroup` ancestor** — Flutter deprecated the per-widget `groupValue`/`onChanged` pair. `radioGroup` now wraps its tiles in one `RadioGroup`; the standalone `radio` widget carries its own single-item group so DSL documents are unchanged. **Behaviour change**: the widget tree gains a `RadioGroup` node, which downstream widget tests that assert on tree shape may see.
- **`SemanticsService.announce` → `sendAnnouncement`** — the replacement requires a `FlutterView`, and these call sites are manager classes with no `BuildContext`, so they now resolve the same implicit view the deprecated call used internally. **Behaviour change**: with no implicit view (multi-window / view-less embedder) an announcement is skipped rather than asserted.
- `cacheExtent` → `ScrollCacheExtent.pixels(...)` in `listview_factory` / `virtualized_list` (typed replacement; same pixel value, DSL key unchanged).
- `Matrix4.scale` / `translate` → `scaleByDouble` / `translateByDouble`.
- Deferred-renderer placeholders in `phase_2_4_factories` no longer bind unused locals (the property reads that record author intent remain).
- Legacy-form bundle adapters (`bundle_page_adapter`, `bundle_ui_adapter`, `ui_definition`) read deprecated inline fields **on purpose** — that is what makes older bundles keep working. Those reads now carry a single-line `// ignore:` with the reason stated, instead of appearing as unresolved debt.
- Assorted lints: `curly_braces_in_flow_control_structures`, `prefer_const_constructors`, `unnecessary_brace_in_string_interps`, `no_leading_underscores_for_local_identifiers`, a nullable `TabController` that is non-nullable.

`dart analyze lib` is now **No issues found**, and the publish dry-run no longer reports an analyser warning.

### Notes
- Purely additive for existing documents: `from` absent means the current origin, so every 1.3 document keeps its exact meaning.
- Tests: 21 new (`test/widgets/v14/` — `view` 10, `RouteValue` 11). **4341/4341 green** (full suite, re-run after the cleanup above).

## [0.5.2] - 2026-07-19 — `client.mcpStream` channel type: MCP-server-pushed live streams (spec 1.3 §8.6.2)

### Added
- **`client.mcpStream` channel type** — the first channel that carries an MCP-server-**pushed** live stream. The prior five types cannot: `client.poll` re-invokes a tool on an interval (pull) and `client.websocket` is a raw socket outside MCP. `client.mcpStream` subscribes a host-registered stream source identified by its `uri` scheme and forwards each server push through the normal channel machinery (lifecycle, backpressure, `onMessage`/`onError`/`onConnect`/`onDisconnect`). `McpStreamChannel` (`src/channels/channel_types/mcp_stream_channel.dart`) implements it; `ChannelManager._createChannel` gains the case with a **late-bound** resolver (the channel is created at page init but the host registers its source after runtime init, so resolution is deferred to `start()`).
- **`MCPUIRuntime.registerStreamSource(scheme, open)`** — the host seam. A host wires a real transport per uri scheme (e.g. `ble` → a BLE scan hub) while the runtime stays transport-agnostic; all schemes share one resolver on the channel manager. Mirrors `registerToolExecutor`.

### Changed
- `flutter_mcp_ui_core` floor raised `^0.4.1 → ^0.4.2` (the regenerated page schema listing `client.mcpStream`); `mcp_bundle` floor raised `^0.4.0 → ^0.4.8` (floors-at-latest on cut). Consumers should bump to `^0.5.2`.

### Notes
- Purely additive and version-neutral: a runtime predating the type hits `_createChannel`'s `default` branch and ignores the unknown type (graceful coexistence). The `major.minor` DSL-version gate (`MCPUIDSLVersion`) is unchanged — `since v1.3`.

## [0.5.1] - 2026-05-23 — spec compliance Round 2 + mcp_bundle 0.4.0 cascade

### Changed (cascade)
- `mcp_bundle` caret bumped from `^0.3.0` to `^0.4.0`. The downstream `UiSection.pages` field switched to `Map<String, PageDefinition>`; this runtime's `bundle/bundle_page_adapter.dart` now iterates `uiSection.pages.values` so bundle activation still walks every page. Consumers should bump to `^0.5.1`.
- `flutter_mcp_ui_core` caret bumped to `^0.4.1` (mcp_bundle cascade).

### Added
- MCP wire shape unwrap — tool responses shaped as `{content:[{type:'text', text:S}], isError:bool}` now unwrap and JSON parse `S` before auto-merge (spec §3.10).
- `StateChangeEvent.source` canonical enum (`action` / `tool` / `subscription` / `system`) per spec §3.11. `mergeState` defaults to `'tool'`, `StateActionExecutor` to `'action'`, resource notification to `'subscription'`, `updateAll` to `'system'`.
- `RenderContext.onResourceRead` / `onResourceList` — separate host callbacks for spec §4.5 `read` / `list` sub-actions (fallback to `onResourceSubscribe` for backward compat).
- `onSubscriptionError` callback — spec §4.5 named field, dispatched when host subscribe handler throws. `event.{uri, binding, message}` child context.
- Non-Map response `event.value` wrap — spec §4.4.2: list / scalar / null tool responses expose `event.value = <response>` (with other `event.*` keys null).
- Common `click` field auto-wrap (spec 1.3.4 §2.2) — `WidgetFactory.applyCommonWrappers` now wraps any widget carrying a `click: Action` property in a `GestureDetector` and dispatches the action through `RenderContext.actionHandler` on tap. Universal across all 97 factories that call `applyCommonWrappers`; pure layout / decoration widgets (`box`, `card`, `linear`, `stack`, ...) become tappable without nesting a `gestureDetector` wrapper. `click` is resolved through the binding engine, so action maps may be supplied inline or via `{{...}}` binding. Click is applied BEFORE the enabled-state wrap so `enabled: false` (IgnorePointer) correctly suppresses the gesture surface. Widget-local activation slots (`button.onTap`, `iconButton.onTap`, `richText.spans[].onTap`, ...) remain canonical for those widgets and are unaffected.
- 26 new regression cases under `test/spec_compliance/runtime_spec_fix_2026_05_14_test.dart` locking the above.
- 6 new regression cases under `test/renderer/widget_factory_test.dart` for the common `click` field: GestureDetector wrap shape, end-to-end tap → action dispatch, tooltip + click coexistence, backward-compat no-click pass-through, non-Map click ignore, and `enabled:false` suppression via IgnorePointer.

### Deprecated
- Envelope `{success, result, message}` auto-unwrap — slated for removal in 0.6.0. Warning logged once per process.
- `tools.<tool>.result` namespaced mirror — slated for removal in 0.6.0. Warning logged once per process.

### Changed
- `runtime_engine.handleResourceNotification` / `handleMCPNotification` no longer apply `content[binding]` heuristic — raw content stored at binding per spec §4.5.
- Lifecycle `_renderContext` null short-circuit replaced with explicit error log.

### Fixed
- **Storage, one-shot reads and permissions did not scope to the origin
  either.** A `resource` read from an embedded subtree returned the embedder's
  resource under the embedded document's uri (a wrong answer, not a missing
  one); two devices on one screen shared a single storage key space, so the
  second to write a key silently overwrote the first and each read the other's
  value back as its own; and an embedded document could prompt for — and be
  granted — a permission the embedding app never held, which let any embedded
  server escalate through the screen it was given. Reads now route through
  `registerOriginResourceReader`, storage keys are prefixed by the scope's
  origin, and a scoped action is refused before any prompt when the embedder
  does not hold the permission.
- **An embedded subtree rendered against its origin but did not act against
  it.** `view` brought another origin's UI in; every `tool` action inside it
  still took the app's own path and landed on a session with no client for that
  device, so a composed screen looked finished and did nothing (observed as
  `session.tool.no_client` while both tiles rendered). `RenderContext` now
  carries an ambient `origin` — set on the embedded scope, inherited by every
  descendant, never read from the renderer because an origin scopes a subtree
  rather than a tree — and a scoped `tool` action routes through the host's
  `registerOriginToolCaller`. A scoped subtree with no bridge reports rather
  than redirecting: running one device's tool name against another server is
  worse than failing.
- **The resolver did not reach the context a page renders with.**
  `registerDefinitionResolver` stores it on the `Renderer`, and each
  `RenderContext` copied the field at construction — but two of the five
  construction sites did not, including the router's, which is the path a
  bundle takes. A host that had claimed the Composition Profile therefore saw
  `view` report that the runtime does not implement it. `RenderContext`
  now reads through to its renderer, so the profile reaches the tree by
  construction rather than by every construction site remembering; an
  explicitly-set resolver still wins.
- `ApplicationDefinition.fromUIDefinition` narrowed `routes` to
  `Map<String, String>`, so an application carrying a v1.4 route that names
  another origin (`{"$ref": ..., "from": {"connection": ...}}`) threw while
  parsing and the app could not open at all. The error named a type cast, not
  routes, so nothing pointed at composition. Routes now keep their declared
  shape.
- Tool responses arriving in MCP wire shape were merged as `content` / `isError` literal keys instead of unwrapped — now spec §3.10 compliant.
- `TemplateParamDefinition.validate` now skips declared-type and enum checks when the supplied argument is a binding expression (`"{{...}}"`). Mirrors the same fix in `flutter_mcp_ui_core`'s `TemplateDefinition.validate`; covers the extended-template (`resolveExtended`) path. Previously a template param declared `type: boolean` rejected every expression-bound argument (always a String at validate time), causing `use` invocations to surface the `Template not found:` placeholder. Spec §9.3.1 mandates only required / default / enum / validator and expressions resolve at runtime so cannot be compared against the enum list here either. Non-expression arguments still take the type / enum path unchanged. Regression: full templates test suite 88/88.
- `TemplateRegistry._substituteValue` now type-preserves whole-value placeholders. A param value shaped as a single `"{{name}}"` (with no surrounding literal text) was previously stringified by `_substituteString` via `value?.toString()` — a List param landed in the expanded template body as `"[a, b]"`, a Map as `"{x: 1}"`, an action Map (`{type:"tool",...}`) as `"{type: tool, ...}"`. Downstream factories receiving those props could no longer cast back to `List` / `Map<String, dynamic>?` (observed runtime: `'String' is not a subtype of type 'Map<String, dynamic>?'` from `inkWell.onTap` when a `template params.onActivate` action Map was forwarded into a nested `use`). The substitution now short-circuits whole-value placeholders to the raw param value; partial placeholders (`"Hello {{name}}"`) still take the string path unchanged.
- `ListViewWidgetFactory._ensureStableConstraints` is now orientation-aware. The defensive guard that wraps the ListView in a `SizedBox` when the parent supplies an unbounded constraint previously only checked `hasBoundedHeight`, so a `list` with `orientation: 'horizontal'` mounted inside a `Row` with a `Spacer` / `Expanded` sibling threw `Horizontal viewport was given unbounded width` at layout time (followed by a cascade of `RenderBox was not laid out` exceptions). The guard now branches on `scrollDirection`: horizontal lists check `hasBoundedWidth` and fall back to `SizedBox(width: MediaQuery.size.width)`; vertical lists keep the existing `hasBoundedHeight` / `SizedBox(height: ...)` path. Author intent is unchanged — explicit `shrinkWrap: true` or a parent-supplied size still short-circuits the guard.
- `text` widget pins `theme.color.onSurface` when `style.color` is unspecified. Spec §5.4.2 deliberately omits a `color` field on typography roles (Material 3 separates typography from colour), so `variant`-only / no-`style.color` text returned `TextStyle(color: null)` and Flutter fell through to the ambient `DefaultTextStyle.of(context).color` — which inherits from an ancestor `Theme` whose brightness can briefly diverge from the ThemeManager's effective mode during host tab transitions (an AppRendererScreen remount sees a stale `MediaQuery` / `Theme(brightness:)` frame before the host wrap re-applies its override). Visible in dark mode only — both ambient branches yield near-black under light, so the divergence is invisible there; in dark the same race surfaced as black-on-dark text frames after tab cycling. The factory now resolves `theme.color.onSurface` (the M3 canonical text colour) through ThemeManager at build time, breaking the ambient dependency. Author-supplied `style.color` still wins via the existing `merge` path. Regression: 2 new widget cases in `test/runtime/text_color_pin_test.dart` (onSurface pinned despite light-Theme ancestor / inline style.color overrides the pin).
- `ThemeManager.flutterThemeMode` now honours `_hostBrightnessOverride` unconditionally (in lockstep with `_resolveEffectiveMode`). Previously the override only applied when the bundle declared `mode: 'system'`, so a bundle with `mode: 'dark'` would resolve `theme.color.onSurface` to the host-pinned brightness via `getColorValue` while `MaterialApp.themeMode` still picked dark — the colour-token path and the ambient `ColorScheme` came from different brightnesses, producing the "ambient onSurface flips between frames" race the tab-cycle text fix above is the second half of. Regression: 5 new cases in `test/runtime/text_color_pin_test.dart::flutterThemeMode honours host override unconditionally`. Test `theme/theme_manager_test.dart::TC-TH-03 flutterThemeMode ignores host brightness ...` was inverted to lock the new contract (renamed to `... honours host brightness ...`) — policy change 2026-05-21, AppPlayer-class hosts are themselves "the system" for embedded bundles.
- `ThemeManager._resolveEffectiveMode` now treats a non-null `_hostBrightnessOverride` as the unconditional winner — previously the override only applied when `_themeMode == 'system'`, so a bundle that hard-declared `theme.mode: 'dark'` ignored the host's light/dark toggle entirely. Worse, the toggle's apparent effect depended on race-timing between `setTheme(appDef.theme)` (driven by the bundle's manifest at mount) and `setHostBrightness(...)` (driven by the host's chrome preview-mode pin) — whichever landed last won, producing an intermittent "text widget stays dark / surrounding chrome flips light" leak in `tools/builder/vibe_studio/vibe_studio_workspace`. `setHostBrightness` also now notifies unconditionally (the previous `if (_themeMode == 'system') notifyListeners()` guard would swallow the brightness change when a bundle declared an explicit mode). AppPlayer-class hosts are themselves "the system" for embedded bundles — when the host pins brightness, the bundle MUST follow. The identical-override early-return guard (`_hostBrightnessOverride == brightness`) is preserved, so no spurious rebuild. Regression: 6 new cases in `test/runtime/theme_host_override_priority_test.dart` (light flips dark bundle / dark flips light bundle / clear restores declared / always-notify / identical no-op / fingerprint changes for renderer cache invalidation).
- `RuntimeEngine.initialize` now forwards `ThemeManager` mutations to engine listeners. `setTheme` / `setThemeDefinition` / `setThemeMode` / `setHostBrightness` / `applyOverride` calls already invoked `ThemeManager.notifyListeners()` (six call sites), but the engine never `addListener`ed on `_themeManager`, so the notification stopped at the manager and widgets never rebuilt on a theme mutation. Hosts worked around this by bridging through `_stateManager` as a noop forward (sentinel: `tools/builder/vibe_studio/.../dsl_workspace_view.dart`). Spec `mcp_ui_dsl/spec/1.3/05_Theme.md` §L56 ("theme.mode … changes trigger theme recomputation and re-render") makes this re-render obligatory; the engine now satisfies it natively. The listener tear-off (`_themeListener = notifyListeners`) is held on the engine and detached in `destroy()` — ThemeManager is process-singleton, so an unreleased listener would outlive a destroyed engine and fire `notifyListeners` on a disposed receiver. Multi-host theme isolation (per-runtime ThemeManager) is unrelated to this fix and remains a separate refactor track. Regression: 3 new cases in `test/runtime/theme_forward_test.dart` (theme mutation forwards / destroy detaches cleanly / host bridge workaround is no longer necessary).

## [0.5.0] - 2026-05-03 - Spec ↔ implementation alignment (1.3.3)

- Channel callbacks: `onMessage` (canonical, `onData` retained as getter alias) + new `onConnect` / `onDisconnect` dispatch.
- `chart` adds donut / polar / bubble; `codeEditor` accepts 7 themes (vsLight/vsDark/monokai/solarizedLight/solarizedDark/github/dracula) + 14 languages.
- `lazy.trigger: visible` (spec rename from `viewport`); `manual` case recognised.
- `services.kind: polling` / `subscription` accepted (mapped to existing `periodic` / `continuous`).
- `template.styles` map field; `bottomBar` / `rail` navigation canonical (legacy `bottomNavigation` / `bottom` aliases retained).
- Bumps `flutter_mcp_ui_core` to `^0.4.0`.

### Fixed
- `ThemeManager.getColorValue(slot)` — falls back to the fromSeed-derived M3 28-role palette when the slot is absent from the bundle's raw `theme.color` map (spec §5.3 expects bundles to declare only `seed` plus a handful of overrides; the missing roles must derive). Previously the lookup only consulted `_themeData = definition.toJson()` (raw, no derive), so DSL bindings like `theme.color.surfaceContainerHigh` resolved to `null` for any bundle that omitted the role — even though `toFlutterTheme().colorScheme.surfaceContainerHigh` was filled correctly. The two paths now match. Light / dark schemes are cached; cache is invalidated on every `setTheme` / `setThemeDefinition` / `resetTheme` / `reset` / `applyOverride` restore. Semantic roles (`success` / `warning` / `info` and their `on*` variants) are not on Flutter's `ColorScheme`, so the fallback returns `null` for those — bundles must declare them explicitly.
- `box` (and the shared `BoxDecorationResolver`) — `decoration: {color: ...}` is no longer silently dropped when neither top-level `color` nor `backgroundColor` is supplied. The factory previously injected `color: null` into the flat property bag, and the resolver's flat-vs-nested override pass treated the `containsKey('color')` hit as an explicit erasure of the nested value. Now: (a) the factory only overlays `color` when the merged top-level value is non-null, and (b) the resolver ignores null entries during the override pass — they cannot shadow nested fields. Same null-tolerant treatment applies to `gradient` / `image` / `border` / `borderRadius` / `boxShadow` / `shape` / `backdropBlur`. Surface-toned boxes (e.g. `decoration: {color: "surfaceContainerHigh"}`) finally render against the M3 surface tonal scale rather than transparent.

## [0.4.4] - 2026-05-02 - M3 + Responsive consumption layer (bug fix)

0.3.0 announced "Material 3 + Responsive" but the runtime side was
never actually wired up. 0.4.4 delivers the consumption surface so
the previously advertised features finally work.

### Fixed
- M3 token shorthand on `text.variant`, `box.padding`, `card.shape`,
  `card.elevation`, `button.elevation`, `icon.size` / `sizeToken` —
  resolves through the corresponding `theme.<domain>.<token>`.
- `FormFactorScope` auto-wrap on the runtime root, so
  `AppSpacing.of(context)` / `AppTypography.of` / `AppIconSizes.of` /
  `AppDensity.of` actually track the form factor.
- Per-form-factor property override map (`{compact, medium, expanded,
  large, extraLarge, embedded, default}`) resolves on every property,
  per spec § 14.2.
- Linux: `event_listen_cb` / `event_cancel_cb` return type aligned
  with `FlMethodErrorResponse*` so the plugin compiles against the
  current `flutter_linux.h`.

### Notes
- Bumps `flutter_mcp_ui_core` to `^0.3.2` for the matching schema
  additions.

## [0.4.3] - 2026-05-01 - errorBoundary / errorRecovery onError spec violation fix

### Fixed
- `errorBoundary` (spec §2.13.11) — onError child context was registering `error` (string) instead of the canonical `event` variable. Now registers `event: {error, stack}` so `{{event.error}}` and `{{event.stack}}` resolve as the spec specifies.
- `errorRecovery` (spec §2.13.12) — same variable-name violation; now registers `event: {error, stack}`. Stack trace is captured (was previously lost).
- `errorBoundary` was re-firing `onError` on every rebuild while the boundary remained in the error state. The action now dispatches exactly once per captured exception (in the post-frame callback that flips `_hasError`).

## [0.4.2] - 2026-05-01 - Tool response spec violation fix (§3.10 + §4.4.2)

### Fixed
- `§3.10` auto-merge — `ToolActionExecutor` now calls `stateManager.mergeState(response)` when the tool response is a Map and `bindResult` is not specified, instead of leaving fold to host code. Top-level keys of the response land directly on page state.
- `§4.4.2` onSuccess/onError variable — child context now exposes the canonical `event` variable. `{{event.<key>}}` resolves to the response body inside `onSuccess`; inside `onError`, `event` is `{code, message, details}` per spec. Previously the runtime registered `response` / `error` (string), so the spec patterns silently failed.

### Migration
- DSL written against the previous (non-spec) `{{response.<key>}}` / `{{error.message}}` shapes must move to `{{event.<key>}}` to keep working.

## [0.4.1] - 2026-04-30 - Template auto-registration + theme system fixes + spec alignment

### Fixed
- `RuntimeEngine` now reads the `templates` block from the application / page definition during `initialize` and registers each entry into the `TemplateRegistry` (application scope for application roots, screen scope for standalone pages). Previously the block was silently ignored, so any `{ "type": "use", "template": "<name>" }` reference in the DSL failed to resolve and the widget went unrendered.
- `ThemeManager.flutterThemeMode` now honours `setHostBrightness` for `mode: 'system'` resolution: when the embedder injects a brightness override, it returns `ThemeMode.light` / `ThemeMode.dark` accordingly instead of always emitting `ThemeMode.system` (which Flutter resolves against OS brightness only). AppPlayer-class hosts are "the system" for embedded bundles, so launcher light/dark toggles now propagate into nested `MaterialApp` instances.
- `ThemeManager.toFlutterTheme(isDark: true)` no longer falls back to the active (light) `_definition` when the bundle declares no `dark` variant — it now returns `ThemeDefinition.defaultDark()` so the M3 default dark scheme is used. Previously bundles with an empty theme block could only render light, regardless of host brightness.
- **Template / `itemTemplate` instance state binding across close → reopen cycles.** The singleton `WidgetCache` was retaining widget instances whose event-handler closures captured the prior session's destroyed `RenderContext` (`StateManager`, `ActionHandler`). After a host-driven close → reopen, the rebuilt UI tree showed cached widgets whose `onTap` mutations targeted the dead engine, so visible state never updated even though buttons appeared responsive. Fix has three parts working together:
  - `Renderer._hasEventHandlers` now recurses through `child` / `children`, so an ancestor container holding event-bound descendants is also flagged non-cacheable. Previously a `linear` / `box` wrapping an `onTap` button could be cached even though its subtree's closures captured a stale context.
  - `'use'` is added to `nonCacheableTypes`. Each `use` site is an instance — its expansion MUST be a fresh widget subtree, not a shared cached widget across invocations or sessions.
  - `MCPUIRuntime.destroy()` now calls `WidgetCache.instance.clear()` to drop all cached entries from the dying session, so the next session starts with a clean cache and cannot inherit closures bound to a destroyed engine.
  - The same fix covers the `list.itemTemplate` (spec §9.6.1) instantiation path, since per-item expansions also produce fresh subtrees and the recursive event-handler check now catches buttons nested anywhere in the row template.

### Changed (breaking — pre-launch spec alignment)
- `ExtendedTemplateDefinition` widget tree wrapper field renamed `body` → `content` to align with MCP UI DSL 1.3 §9.2.2 (the canonical key for the template's widget tree). The use-site invocation key (`params:` on the `use` widget) is unchanged.
- `TemplateRegistry.isTemplateReference` now accepts only the canonical `type: "use"`. Legacy aliases (`type: "template"` / `type: "useTemplate"`) are removed in line with the spec's no-alias-accretion policy. Bundles using the legacy types must migrate to `type: "use"`.

## [0.4.0] - 2026-04-29 - Render inspector hook

- New `MCPUIRuntime.withInspector(...)` for editor tooling — pairs each rendered widget with its source JSON node. Standard constructor unchanged; no overhead when no inspector is supplied.

## [0.3.0] - 2026-04-28 - MCP UI DSL 1.3 (Material 3 + Responsive)

### Changed (breaking)
- **`ThemeManager` rewritten** on top of strongly-typed `ThemeDefinition` from `flutter_mcp_ui_core` — drops the 1.2-era 11-slot raw map and parallel default scheme.
- Theme bindings use the new path scheme (`theme.color.<slot>`, `theme.typography.<role>`, `theme.spacing.<token>`, `theme.shape.<family>`, `theme.elevation.<level>.shadow`, `theme.motion.duration.<key>`). Legacy `theme.colorScheme.*`, `theme.borderRadius.*`, `theme.spacing.medium`, `theme.elevation.small` are removed.
- `widget_factory` semantic color slots aligned to M3 28-role + semantic family (no `background` / `divider`).
- DSL version constant now sourced from `flutter_mcp_ui_core` `MCPUIDSLVersion` (runtime's own `DSLVersion` enum removed).
- License changed from Apache-2.0 to MIT.

### Added
- **`McpUiThemeBuilder`** — converts `ThemeDefinition` into Flutter `ThemeData` (`ColorScheme`, `TextTheme`, `VisualDensity`, `CardThemeData`, `DialogThemeData`).
- HCT-seed-derived default theme (`SeedPalette.lightFromSeed` / `darkFromSeed`).
- **Page-level theme override** — `applyOverride(Map)` deep-merges 14-domain JSON, returns restore callback (spec §5.7).
- **Responsive form factor scaffold** — `FormFactor` enum (compact / medium / expanded / large / embedded), `FormFactorScope`, `ViewModeResolver` priority chain.
- Four responsive token sets with `.of(context)` accessors — `AppSpacing`, `AppIconSizes`, `AppTypography`, `AppDensity`.
- **Auto-adaptive navigation** — drawer swaps to modal drawer (compact) / NavigationRail (medium) / permanent drawer (expanded+).
- New dependency: `mcp_bundle ^0.3.0`.

## 0.2.5

### Bug Fixes
- Fixed resource subscription cleanup on runtime destroy to properly unsubscribe from all active resources

## 0.2.4

## 0.2.3

### Documentation
- Added important build instructions for dynamic icons
- Documented the need for `--no-tree-shake-icons` flag when building apps with dynamic icons

## 0.2.2

### Bug Fixes
- Fixed navigation state persistence to properly save and restore tab/navigation positions
- Added SharedPreferences support to CacheManager for actual disk persistence
- Fixed setState during build error in ApplicationShell navigation initialization

## 0.2.1

### Bug Fixes
- Fixed state initialization issue where page states were not properly loaded
- Unified state management by removing duplicate StateService and using StateManager directly
- Fixed page state initialization in routing system

## 0.2.0

### Refactoring
- Major internal refactoring for improved maintainability
- Enhanced code organization and structure
- Improved type safety and validation
- Better separation of concerns

## 0.1.0

### Initial Release

- Comprehensive runtime for building dynamic, reactive UIs through JSON specifications
- Support for 77+ Flutter widgets across 9 categories
- Built-in state management with automatic UI updates
- Expression binding system with support for nested paths and transforms
- Action system (state, tool, batch, conditional, navigation)
- Multiple instance support for different MCP servers
- Tool executor injection for external API integration
- Custom widget registration support
- Custom transform registration
- Theme management with light/dark mode support
- Navigation and routing system
- Dialog and notification services
- Background service management
- Lifecycle management
- Service registry pattern
- Based on MCP UI DSL v1.0 specification