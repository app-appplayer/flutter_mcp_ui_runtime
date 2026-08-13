## [0.7.6] - 2026-08-12

### Fixed
- `onSuccess` / `onError` take one action or a list of them, as every other
  action slot does; a list runs in order (`sequence`, §4.6). A list used to be
  dropped without running and without an error, so the tool succeeded and the
  state it was meant to write stayed at its initial value.
- An embedded `application` renders `dashboard.content` (§11.9) before falling
  back to its initial route. Only `routes` was read, so an application that
  presented itself the way §2.13.1 embeds it showed "Unavailable".

### Changed
- A widget that cannot be built is reported (log + plugin `onError` hook, with
  the widget type) and drawn only in a debug build. Release builds collapse the
  slot instead of painting the message. Spec §18.2.1.
- `sliverList` / `sliverGrid` / `sliverFixedExtentList`: `items` holding widget
  nodes renders them, as `children` does. Items that are not widget nodes and
  have no `itemTemplate` render nothing and log why.

## [0.7.5] - 2026-08-11

### Every accepted spelling is now drawn, not just every canonical one

The conformance matrix walked canonical widget names only. Four layers each
held an opinion of which spellings a document may carry — the registry's
`aliases:`, `17_Naming.md` §17.3.1, the generated JSON Schema (which
`initialize` runs as a **load gate**), and this package's factory
registrations — and nothing compared them. They had drifted in both
directions, and line coverage could not see it: `registry.register('decoratedBox', …)`
runs at boot whether or not any document with that spelling was ever opened.

- `decoratedBox` — registered here, registered as an alias of `box` by the
  spec, and **rejected by the schema**, so a document using the spelling the
  spec promises did not open at all. §18.2.10 says a runtime MUST accept every
  registered alias.
- `circularProgressIndicator` — added in 0.7.4 and named by §2.5.14, but the
  registry never learned it, so the same load gate refused it. The 2026-08-10
  `progressBar` change had landed in the runtime and the prose and nowhere
  else; its other half, `indicatorType` defaulting to `circular`, is now
  declared too.
- `constrainedBox` — registered here and named by nothing. Declared as a `box`
  alias rather than dropped: widening costs nothing and the registration was
  already shipping.
- `text-form-field` — declared by the registry and accepted by the schema, and
  **not registered here**, so the document loaded and the field drew an
  unknown-type box. Registered.

The matrix gained the axis that finds these: every spelling any layer calls
legal is rendered as its canonical's own document, with the canonical render
as the control. Two harness defects surfaced while building it — a constant
frame key was letting pixels leak between renders in one test (an unknown
widget type produced no error box at all), and the paint assertion was being
demanded of synthesized documents that have nothing to draw.

### `scrollView.slivers` draws as slivers

**Acceptance was never the problem.** The schema has carried `scrollView.slivers`
and the five `Sliver` shapes since 1.4, and a sliver document loads on 0.7.4 as
well as on this release — measured on both. What it did not do was *lay out* as
slivers: this package had no sliver support, so the entries were placed as
ordinary children and `sliverAppBar` reached the widget registry, found no
factory, and drew an unknown-type box in the middle of the page.

(Worth stating plainly because the other changes here are load-gate changes.
Reading this one as "documents that were rejected now load" sends a consumer
looking for a validation failure that never happened.)

Sliver mode now builds a `CustomScrollView` — `sliverAppBar` (collapsing,
pinned/floating/snap/stretch, `flexibleSpace` or a `background` wrapped for
it), `sliverPersistentHeader` (held between its declared extents),
`sliverList`, `sliverGrid`, `sliverFixedExtentList`, the latter three taking
the same `children` / `items` + `itemTemplate` pair the list widgets take. A
shape the spec does not define is reported in place rather than skipped.

### `sliverAppBar` can name the surface the reader is left with

A collapsing bar shows two surfaces in turn: the hero (`background` /
`flexibleSpace`) while expanded, and the bar itself once the hero has faded
out. A `title` colour chosen to read against the hero stops reading at exactly
the moment the bar collapses — and the document had no way to say otherwise.
Measured on a real screen: white on navy while open, the same white on the
theme surface once collapsed.

`backgroundColor` and `foregroundColor` are declared on `sliverAppBar` and read
by the factory. Declaring `backgroundColor` before this did nothing and said
nothing — the registry did not accept the key on the route that reaches the
screen, and the factory never read it.

### Sliver mode stopped differing from linear mode in silence

Reported from a real screen, all three found by measuring rather than reading:

- **A `scrollView` with `slivers` drew nothing in an unbounded parent** — the
  same widget with `children`, in the same slot, drew. No error, no log. Linear
  mode had carried an unbounded-parent fallback all along; sliver mode did not,
  and the difference reached the author as a blank area. Sliver mode now takes
  the same fallback.
- **`items` accepted only a binding string** on `sliverList` / `sliverGrid` /
  `sliverFixedExtentList`, while `list` and `grid` take an array or a binding.
  The ordinary inline form was refused **at load** in slivers and nowhere else.
  Widened to the same contract the list widgets use; the factory already read
  both.
- **`TableRow.cells` carried a `minItems: 1`** — left behind when the narrowing
  that file describes was reverted — so `rows: [{"cells": []}]` was refused at
  load while `rows: [{}]` opened. The description one line below said the
  refusal must not happen. Removed.

### Shapes that cannot be drawn still open

Three documents passed the load gate and were then refused on screen: a
`conditional` with neither `condition` nor `switch`, a `tabBar` whose tab named
no label and no icon, a `table` whose row carried no cells. Declaring the
missing key required in the schema is the obvious repair and the wrong one —
validation runs when a document loads, so a narrowed schema does not deprecate
a field, it stops the whole document opening and takes a page of good widgets
with it (spec §1.7.5).

So the runtime absorbs them instead:

- a conditional with nothing to test is not true — it shows its `else` /
  `default` branch, or nothing, and never `then`;
- a tab naming neither label nor icon draws as an empty tab instead of tripping
  Flutter's assertion;
- a table drops the rows it cannot lay out and draws the rest.

### Also

- `HostPlatform` and the `client.platform` family, `signature`'s `data:` URI
  contract and the `progressBar` shape rules are now what the spec says they
  are — the three prose sections were written on 2026-08-10 against this
  behaviour and are part of this cut.
- Coverage 99.35% (8,750 → 8,816 tests). The tail of that push is in the
  entries above: most of these defects were found by rewriting a test that
  asserted nothing into one that reads the result.

### Silences, every one of them measured by someone else

### A list slot reads empty rather than painting a stack trace

Measured on the published 0.7.4, in the shape that happens during
ordinary editing: a list property bound to a path whose state holds a scalar —
a response still loading, a value half-typed. `resolve<List<dynamic>?>` threw,
and the renderer answers a throw by painting a red
`Error rendering …: 'String' is not a subtype of 'List<dynamic>?'` box over the
widget's own area.

Four widgets did that (`tabBar`, `dataTable`, `bottomNavigation`,
`resizable.handles`); two others (`kenBurnsImage`, `visibility`) already
degraded quietly, which is the behaviour the other four now share. The scalar
slots were fixed in 0.7.3 — the list slots were the same defect one type over,
and they were found because a consumer kept measuring after the first report
was closed.

- `readList` / `listOf` joins the tolerant readers (`readBool`, `readNumber`,
  `readDimension`, `readActions`), and the 25 factories that read a list slot
  now go through it. A wrong-shaped value reads as EMPTY — what the widget
  draws for no data anyway — so the mistake stays visible as an empty widget
  rather than as an exception on screen.
- `bottomNavigation` draws nothing at all below two items: Flutter asserts on a
  shorter list, so tolerating the shape without that would have traded a cast
  error for an assertion.

### Collection properties on a state path

`rows.isEmpty` / `.isNotEmpty` / `.first` / `.last`.
`rows.length` answered from the start and the others answered null, so a
document that hid an empty section with `{{rows.isEmpty}}` never hid it, with
nothing said. (The parenthesised method spellings always worked, which is what
made the property spellings look supported.)


Every item here rendered as *nothing* — or as a stack trace where a widget
belonged — rather than as an error a document could act on. That is the shape
that costs a day: the screen looks finished, or broken in a way that reads like
the runtime is broken, and no channel says which.

One more, found while covering `client.*` with tests: `client.theme` reported
the OS preference while every other `client.theme.*` path read the host theme,
so an app running dark on a light OS answered `mode: light` beside dark colours
and a document choosing an asset by mode chose the wrong one.

### A predicate written the ordinary way

`filter(rows, (r) => r.ok)` answered with an empty list. Only the bare
`r => …` spelling parsed as a lambda; the parenthesised one fell through to the
operator branch, came back as a value, and `filter` read that value as a
property NAME — so the shorthand added in 0.7.3 turned a null into an empty
list. Both were wrong. `(r) => …` now parses, the way `(acc, i) => …` already
did.

### A chain of more than one call resolved to nothing

`filter(rows, 'done').map('name')` read correctly; adding one more link —
`.join(', ')`, or `.length` — did not. The receiver test insisted the whole
receiver be a *single* balanced call, so a receiver that was itself a chain was
rejected, the expression fell through to a path lookup, and the whole thing
resolved to null: a blank where a joined list or a count belonged.

The test now accepts a close-paren followed by `.` as the chain continuing,
which is the only thing it can be. Anything else after the close is still two
terms with an operator between them, and is still refused.

### A call's result can be read like a path

`rows.length` answered 3 and `filter(rows, 'ok').length` answered nothing —
the same reading of the same list, one through a path and one through a call.
§3.6.4 makes the method form equivalent to the function form, so the receiver
is now an expression rather than only a path. Two consumers wrote the "N of M"
form and both read a blank; the first attributed it to their own chain, which
is what a silent answer earns.

### A child in a slot its parent never reads

`{"type": "box", "content": {...}}` — `box` reads `child`, so the node was
never mounted: no widget, no error, no pixels. Every downstream reading was
consistent with it ("the surface is never called" → "the capability must be
absent" → "the shared byte path is broken"), and a colleague walked that whole
chain before finding the slot name. The runtime cannot render what it does not
know about, but it can say that something was declared and dropped — §6.13's
rule applied to a slot rather than to a capability.

Reported through the log, never drawn: an error box here would change screens
that carry harmless extra keys. Once per (widget, key) per renderer — a host
that opens a second document still hears about that document's own.

### The error boundary could not recover, and six more

None of these came from a consumer — they came from replacing tests that
asserted nothing with tests that read the result. Each one is the same shape as
the rest of this release: the runtime returned success for something it had not
done.

`ErrorBoundary` / `ErrorRecovery` were the worst of it. They were 49% covered
and the uncovered half was every path that runs when a document actually
fails, so six defects sat in the widget whose entire job is to be correct on
the worst day:

- **The retry strategy could never retry.** `ErrorRecovery` wraps an
  `ErrorBoundary`, and the boundary holds the error it caught. Clearing the
  recovery's own error rebuilt the same boundary element, which went straight
  back to its error surface — so retry, reset, ignore and the dialog's OK were
  all no-ops on screen. The boundary is now keyed per recovery attempt, so the
  child is genuinely built again.
- **One failure was handled twice.** A failed build arrives through
  `ErrorWidget.builder` AND through `FlutterError.onError`. The host's
  `onError` fired twice per failure, two dialogs stacked, and the error route
  was pushed twice.
- **`setState` was called during build.** That is where a build failure
  arrives; marking the element dirty mid-build trips an assertion in debug and,
  in release, lands on a frame the framework has already walked past — so a
  failed build could leave the old content on screen with no error shown at
  all. The state is recorded synchronously and repainted after the frame.
- **`dialog` and `navigate` never ran.** `showDialog` / `Navigator.push` from
  inside build is illegal, so both strategies asserted instead of acting. They
  now run after the frame that raised the error.
- **The boundary took the host's error channel and did not give it back.** It
  replaced `FlutterError.onError` and then called `FlutterError.presentError`
  rather than the handler it displaced — so a host's crash reporter received
  nothing while any boundary was mounted. `ErrorWidget.builder` had the same
  shape of bug across a rekey: the replacement saved the outgoing boundary's
  override as "the original", leaving the global pointing at a defunct State.
  Both are now restored properly, the builder through a stack that survives
  nesting and out-of-order disposal.

### The app cache was write-only, and what it did load was thrown away

Two faults, one behind the other.

- The cache LOOKUP reads `domain`/`id`/`version` from the top level of an
  application — the v1.0 shape every bundle uses. The cache WRITE read them
  only from an `mcpRuntime` block, and filed everything else under
  `unknown:unknown`. The reader never looked there, so nothing written was
  ever found.
- Behind that, the cached *state* was applied before the definition was
  initialised, and initialising a definition replaces the whole state map. So
  every cached value was discarded a moment after being loaded, with a debug
  line saying it had been loaded.

A host priming the cache to resume where the user left off got a fresh start
and no way to tell. The write now files an application under the identity it
declares, and the cached state is applied *after* initialisation: the
definition's `initialState` is where a first run begins, the cache is where
this user actually was.

### A cached widget belonged to whoever built it first

Found by writing the input-widget tests: the widget cache was one process-wide
map, and a cached widget is **not** a pure function of its definition — the
closures inside it hold the `RenderContext` that built it, its state manager
and its action handler. Two documents that render the same widget definition
therefore shared one widget, and the second document's `binding` writes landed
in the FIRST document's state. Nothing on screen said so: the field accepted
the text and the second document simply never saw it.

`MCPUIRuntime.destroy` already cleared the singleton to stop closures leaking
into the *next* session — the comment there names the hazard. Two runtimes
alive at once, which is a dashboard tile beside an open app, had no such
protection.

Each renderer now owns its cache (`WidgetCache.isolated`); the enable/disable
switch stays global, because that is a host policy rather than a property of a
document. `WidgetCache.instance` is unchanged for hosts reading statistics.

### `{{sync.*}}` never resolved

§3 lists `sync.` as a read-only namespace for offline sync status, and the
runtime carries a `SyncBindingResolver` that answers every path in it. Nothing
ever handed that resolver a `SyncManager` — `setSyncManager` is called nowhere
in the package — so it took the "not configured" branch every time and answered
null. Because the resolver intercepts `{{sync.…}}` *before* the binding
engine's own path handling, the engine-backed fallback further down was
unreachable dead code.

A badge bound to `{{sync.pendingCount}}` therefore rendered empty, which reads
as "nothing pending" — the opposite of what it is there to say. The engine now
wires the resolver when it builds the sync manager.

### `{{sync.status}}` in a sentence still said nothing

The same binding takes two different paths depending on whether text sits
beside it: alone it goes through `SyncBindingResolver`, interpolated it goes
through the binding engine's own `sync.` handling. The second one read the
status as `syncManager.status.name` — and `.name` is an *extension* getter on
`Enum`, which does not resolve on a dynamic receiver. The engine is held as
`dynamic` there to break an import cycle, so that call threw
`NoSuchMethodError` on every read, the surrounding catch swallowed it, and
`'Sync: {{sync.status}}'` rendered as `Sync: ` while the badge beside it read
`idle`.

`lastSyncTime` had the mirror-image gap: the interpolated path answered it, the
resolver knew only `lastSyncAt`. Both spellings now answer from both paths, and
the status name is read without depending on static extension resolution.

### Every state read built the whole state into a string, and threw it away

`debug` takes a `String`, so its argument is built at the call site whether or
not logging is on. Three of those arguments interpolated the ENTIRE state map —
one on every `get`, one on every `set`, one on every simple binding — and a
fourth called `toString()` on every value written, to fill a map whose values
are never read.

Reads are the hottest path there is: every binding, every frame. So the size of
a document's data became the speed of its screens, and quadratically: a list in
state was re-serialised once per binding that touched anything. Measured on an
accumulator `reduce`, which reads once per row — 5,000 rows did not finish
inside a **ten-second** budget before; the same 5,000 rows take about **30ms**
now, and the cost is linear in the list again.

Two smaller things fell out with it: a host object whose `toString` throws no
longer takes a state write down with it (`set` is not in the business of
printing what it stores), and a document with no computed properties does no
invalidation work at all.

Found by asking whether an unreachable `catch` could be driven from a test.

### A trust level granted after startup was kept where nobody reads it

`setTrustLevel` applies the level to the permission manager, and when there is
none — a host that supplied its own implementations for every client action,
which `registerExecutor` is public in order to allow — it stored the level in
the field that `initialize` consumes. `initialize` has already run by then, so
the field is never read again: the host believed it had granted `full`, and the
runtime went on refusing at whatever level it had. It now says the grant was
not applied instead of filing it somewhere nothing looks.

### A pinned view mode changed the layout but not the numbers

The widgets read their form factor through `FormFactor.of(context)`, which
honours a `FormFactorScope` — that scope is how a host pins a view mode, and
how a derivative player flags `embedded`. The picker for responsive VALUES
(`{compact: 8, expanded: 24}`) read `MediaQuery` width directly instead, so
the two disagreed: a window pinned to `expanded` laid out wide and took its
spacing, columns and sizes from `compact`. And `embedded` could not be picked
at all — width alone never says it — so every `embedded:` variant in every
document was dead text.

Both now come from the same answer.

### A live region bound to a changing id kept announcing the old one

`LiveRegion` subscribed in `initState` and never again, so a `regionId` that
changes — one status line serving several forms, the ordinary way to write it —
left the widget listening to the region it was created with: the new id was
never registered, `announce` on it warned "live region not found", and the
screen reader kept being handed the previous region's last announcement. The
old region also stayed registered for the life of the process, because only
`dispose` removes one.

The third widget in this release with the same shape, and the second found by
writing a test rather than by a report.

### A terminal went quiet the moment it mattered

`terminal` copied its `lines` once in `initState` and never read them again, so
a console bound to state — a build log, a device session, anything filled by a
tool response or a channel, which is to say filled AFTER the widget is on
screen — showed whatever happened to be there at mount and nothing after it.
The same shape as `networkGraph`'s late nodes in 0.7.4, and the third time this
class of defect has been found: state that arrives after the first frame.

Bound lines are now read on every change, trimmed to `maxLines` as before. A
rebuild carrying the same lines is left alone, so a command the user just typed
keeps its echo until the document's own state catches up.

Found while asking whether an unreachable `addLine` was dead code. It was not
dead — it was the imperative half of an output path that had no working half.

### `MCPUIRuntimeHelper.render` built a new runtime on every rebuild

The future was created inside `build`, so a theme change, a rotation or a
parent's `setState` constructed and initialised a whole new `MCPUIRuntime`
while the previous one was dropped without ever being destroyed — each keeping
its channels, its state and its subscriptions for the life of the process. And
a dropped future that then fails has nobody listening: the refusal arrived as
an uncaught zone error rather than as the error screen the builder beside it is
written to draw, so a document the runtime could not parse took the app down
instead of showing what was wrong with it.

The runtime is now created once per document and destroyed when its host goes
away, including when the host is torn down while `initialize` is still in
flight. A different document gets a fresh host — a teardown followed by a
setup, in that order — because `destroy` resets process-wide state (the theme
manager, the navigation service, the binding caches) that an overlapping
successor has just set up.

### And elsewhere

- **`numberField`'s stepper could not read its own field.** It parsed the
  displayed text with `num.tryParse`, which answers null for anything carrying
  a thousand separator or a `format` wrapper — so stepping a formatted `1,000`
  landed on `1`. The value is now recovered from the text before stepping.
- **`numberField`'s `onChange` could not see `{{event.value}}`.** The
  substitution was hand-rolled and only reached keys inside `params`, so the
  ordinary spelling — a `state` action whose `value` is `{{event.value}}` —
  received the literal string. It now publishes the event through a child
  context like every other input widget, and the `params` substitution is kept
  for documents already written against it.
- **`combobox`: arrow-up from a fresh field skipped the last option.** The
  modular wrap ran from "nothing highlighted" (`-1`) to the second-to-last
  match instead of the last.
- **`inkWell` built only the first of its `children`.** The slot is declared
  in the schema and every entry after the first was accepted and dropped —
  no error, nothing on screen. They are now stacked, the way `renderPage`
  stacks a list of children.
- **`simpleDialog.onSelect` could not see what was picked.** The chosen value
  was written into the action map as `selectedValue` and never published as
  `event`, so the ordinary spelling — `value: "{{event.value}}"` — resolved to
  nothing: the document learned that a choice had been made but not which one.
  (`selectedValue` still arrives, for documents written against it.)
- **A one-item bottom bar took the whole application down.** Material's
  `BottomNavigationBar` asserts on fewer than two destinations, and the
  application shell handed it whatever the document declared — so an
  `application` with a single navigation item rendered a red screen instead of
  its page. That is a legal document, and it is the shape a bundle has while
  it is still being written. A single destination needs no switcher, so the bar
  is now omitted and the page opens. (The `bottomNavigation` WIDGET was
  hardened for this earlier in this release; the shell was not.)
- **`textInput`'s reveal toggle and phone prefix reached almost nobody.**
  There are two field builders in the factory — one for a debounced field, one
  for every other field — and `showToggle` (§2.6.5) plus `defaultCountry`
  (1.4) were implemented only in the first. A password field asking for a
  reveal control got none, and a phone field naming a country got no dialling
  prefix, on the path almost every document takes.
- **Two notifications raised in the same millisecond collapsed into one.**
  `showInfo` / `showSuccess` / `showError` / `showWarning` derive their id from
  `DateTime.now().millisecondsSinceEpoch`, so an error and the warning
  explaining it — or a batch reporting each item — shared an id and the manager
  kept only the last. A sequence number now distinguishes them.
- **A one-off background service could never retry.** It cleared its own
  running flag before the tool returned, and every retry checks that flag — so
  `retryOnError` on a one-off was accepted and silently dropped.
- **`AccessibleFormField` never announced that an error was fixed.** The clear
  branch tested the error state *after* `setState` had already replaced it, so
  it was null exactly when the branch needed it not to be. A screen-reader
  user heard about every mistake and never about the correction.
- **One plugin failing to unload stranded the rest.** `unloadAllPlugins` let
  a `PluginException` out of its loop, so a plugin whose `dispose()` threw
  stopped the shutdown where it stood and every plugin below it in the load
  order stayed loaded — widgets, actions, services and timers still attached.
  On a host tearing documents down that is a leak per document. Each failure
  is now logged and the loop continues.
- **`client.exec` could answer with empty output.** `stdout` and `stderr` were
  collected on stream subscriptions that were never awaited, and `exitCode`
  resolves while the last chunk is still in the pipe. A command whose whole
  output is one short line hit this routinely, and the document was handed
  `stdout: ""` for a command that printed. Both streams are now drained before
  the result is built.
- **A second dialog reported success without opening.** `DialogService.show`
  declines while another dialog is up and answers `null`; the `alert` and
  `simple` branches set their result to `true` regardless. Two taps in quick
  succession, or a batch declaring two dialogs, told the document the user had
  been asked. The executor now checks first and reports (§6.13).
- **`cacheFirst` served an expired entry forever.** The strategy tested
  `isUsable`, which is true for `stale` as well as `ready`, so a resource past
  its `ttlSeconds` was returned from cache on every subsequent read and the
  fetcher was never asked again. A document declaring a 60-second ttl could
  show an hour-old value for the life of the process. Only a fresh entry
  short-circuits now; a stale one goes back to the source, and
  `fallback.useLastKnown` still hands the old value back if that fails.
  (Serving stale data on purpose remains `staleWhileRevalidate`.)
- **"Remember this decision" did nothing for `client.exec`.** The shell prompt
  raised its dialog with no scope, so the decision was stored under a null
  scope while `PermissionManager` looks one up by the executable name. The
  stored grant was never found and the user was asked again on every run — the
  checkbox they had ticked did nothing. The prompt now carries the executable
  as its scope, matching the lookup. (`file.*` and `http` already passed their
  path and host.)
- **`channel` backpressure `latest` kept everything.** The collapse was
  scheduled on a microtask, which always runs between two stream events, so
  the strategy behaved exactly like `buffer` — a document asking for "only the
  current reading" got every reading. It now defers to the next event-loop
  turn, which is where a burst actually collapses.

### `errorRecovery` could not recover

The widget exists to catch a child that will not build and put something
usable in its place — a `fallback`, a type-specific `handler`, an `onError`
report to the document's own server. None of it could ever run. The renderer
answers a failed build by returning its inline error card, so by the time
control came back to `errorRecovery` there was no exception left to catch: the
child had already been replaced, and every branch below the `try` was
unreachable. A document could declare all three and get the runtime's red box.

- The renderer gained a rethrowing entry point, and `errorRecovery` uses it —
  a depth counter rather than a parameter, because the failure is usually not
  in the immediate child but somewhere below it, and the nested render calls
  run on the same renderer.
- `onError` is now deferred to after the frame. It runs inside `build()`, and
  almost every useful `onError` writes state — which marks a listening
  ancestor dirty mid-build and throws. Reporting the failure must not itself
  be a second failure.

### A tab whose route failed reported it at the top of the app, not on the tab

The shell called the page loader from inside `build`, which runs again on
every state change — so a route that fails produced a fresh rejected future on
every frame, and `TabBarView` mounts only the tabs near the current index, so
most of those futures had nobody listening. The failure surfaced as an
unhandled async error (a red frame in a test run, a `FlutterError` in the
field) instead of as the error page the `FutureBuilder` draws when that tab is
actually opened.

Each route now has ONE future for the life of the shell, marked handled so an
unopened tab's failure waits for the tab rather than escaping. As a
side-effect the loader is no longer re-entered on every frame for a page it
has already loaded.

### A route with a parameter could not be opened

`/users/:id` is declared as a pattern and pushed with the parameter filled in.
Flutter's `routes:` table is keyed by exact string, so `/users/42` matched
nothing: the substitution in `_buildRouteWithParams` and the extraction in
`parseRoute` both existed with no path between them, and every parameterised
page in a document was unreachable. `RouteManager.onGenerateRoute` resolves a
pushed name against the declared patterns, and the four shells that build a
`MaterialApp` now wire it beside `routes`.

### A page heard `onPause` twice, or never

`onPause` / `onResume` were fired from two places: the page widget, which
subscribes to the navigator through `RouteAware`, and `RouteManager`, from its
own page stack. The launch route is never pushed, so it was never on that
stack — the first page's hooks came only from the widget. Every page after it
got both. A hook that runs twice runs its teardown twice, which is how a
subscription is released out from under its second subscriber. `RouteManager`
now only moves the Navigator; the widget that can see the route change owns
the report. (The same double-fire was already recorded, and fixed, for the
replace branch.)

### And elsewhere, in the same pass

- **A `list` bound to a value that is not a list painted a stack trace.** The
  same defect as the list slots at the top of this release, one layer down:
  `items` was cast rather than read, so a binding that had not resolved yet —
  or an object where the document expected a collection — replaced the list
  with a red box. It now reads as empty, which is what the `emptyMessage`
  branch is for.
- **…and that `emptyMessage` could not draw either.** It coloured itself from
  `Theme.of(context.buildContext!)`, asserting a field that is nullable, so
  the empty-list branch threw wherever the render context had no build
  context. The theme is now read through a `Builder`, at the list's own place
  in the tree.
- **A `tooltip` with a `richMessage` did not build at all.** `Tooltip` asserts
  that at most one of `message` / `richMessage` is given, and the factory
  passed an empty string for the first — which is still given. Declaring the
  rich form replaced the whole tooltip, and its child, with an error box.
- **A `chip`'s avatar icon was always a ✕.** The factory resolved it through a
  local switch that knew three names and answered `Icons.close` for everything
  else, while the delete icon in the same file already went through the shared
  resolver. `avatar: {"icon": "home"}` drew a close glyph.
- **A `simpleDialog` option's icon was dropped unless it was one of 25.** Same
  shape, other direction: the local switch answered null for any other name,
  so a declared icon rendered nothing and said nothing. Both now use the
  shared resolver, which draws the missing-icon cue for a name it does not
  know.
- **`dateRangePicker` opened its dialog from a context it should not have
  asserted.** `context.buildContext!` is nullable and belongs to the render
  context, not to the widget — where it was set at all, it could point at a
  different subtree than the one the user tapped, which is the Navigator the
  dialog would have been pushed onto. The picker now opens from its own build
  context.

### `reduce`'s accumulator form never accumulated

`items.reduce((acc, item) => acc + item.price, 0)` — the spelling §3.6.3 and
the spec's own example use — answered its seed, unchanged, for every list. The
loop passed each ITEM as the lambda's first parameter, so `acc` inside the body
resolved to the item, `acc + item.price` was not a number, and nothing was
added. `_evaluateLambdaBody` could already bind both parameter names; nothing
ever called it that way. A total that silently equals its seed reads as "no
data", which is the one interpretation that stops an author looking at the
expression.

The single-parameter form (`(item) => item.price`, mapped then summed) is
unchanged, and a non-numeric seed — a string, a list — now survives the
accumulator form.

### A property on an object answered null; the same property on a list answered

`{{rows.isEmpty}}` on a list reads a boolean. `{{form.isEmpty}}` on an object
read NOTHING — and so did `.length` and `.isNotEmpty`. The Map cases were
written, but they sat below a branch that matches any Map and indexes it by
key, so they could never run: an object has no key called `isEmpty`, the index
answered null, and a section hidden on "no data" stayed visible with nothing
said. This is the collection-property defect fixed at the top of this release,
one type over. A real key still wins over the property.

### And elsewhere, again

- **`mode: "horizontal"` on `menu` took the page down.** The entries are
  `ListTile`s and a Row gives its children unbounded width, which is the one
  thing a `ListTile` asserts on. A declared, spec'd mode (§2.8.9) was a layout
  assertion, not a menu. Each entry is now sized to its own content.
- **A literal `selectedKey` could never match.** §2.8.9 declares
  `string | binding`, and a bare string is indistinguishable from a state
  path — so the path was read, found nothing, and the branch written for the
  literal was unreachable. The path is still read first; the literal is what is
  left.
- **`format.number(v, "decimal")` printed 1,234.50 for 1,234.5.** `0` after
  the decimal point is a required digit and `#` an optional one — the whole
  difference between a price and a quantity — and the formatter counted
  characters, so `#,##0.##` behaved as `#,##0.00`.
- **A markdown heading deeper than six levels kept one of its hashes.** The
  level was clamped to six and then used to slice the marker off, so
  `####### deep` rendered as "# deep".
- **`ServiceLocator.get(optional: true)` threw instead of answering null.**
  `null as T` is a cast error for every non-nullable T, which is every type a
  caller writes — so the degrade path a widget uses to survive a service its
  host did not wire raised `type 'Null' is not a subtype of T`. An optional
  lookup now answers null when the type argument can hold it, and otherwise
  says, in the exception, what to write instead.

### A tab's icon came out as the wrong glyph

`tabBar` resolved a tab's `icon` through a local switch that knew three names
and answered `Icons.tab` for everything else — so a declared icon drew a
plausible WRONG glyph rather than the missing-icon cue, which is the harder of
the two to notice. It now goes through the shared resolver, like the chip
avatar and the simpleDialog option earlier in this release. That is four
copies of the same private icon table found in one pass — `chip`'s avatar,
`simpleDialog`'s option, `tabBar`'s tab and `textFormField`'s prefix — and the
shared resolver is the only one that carries the whole vocabulary. (The one in
`segmentedControl` stays: it answers null for an unknown name and the control
falls back to the segment's LABEL, which is more use than a missing-icon
glyph.)

### A signature could not be submitted

§10.19 says the binding holds "base64 PNG or SVG path", and its own
`onSignatureEnd` example writes `{{event.value}}`. Neither existed.

- The binding received an internal stroke dump — `{strokes, strokeCount,
  timestamp}` — which no document can render and no server stores as a
  signature.
- The event carried no `value` at all, so the spec's own example wrote NULL:
  the user signed and the form submitted nothing.
- `toImage`, which produces exactly the PNG the spec describes, was written
  and called from nowhere.

A finished stroke now encodes the pad and hands the document a
`data:image/png;base64,…` string, on the binding and on `event.value`.
Clearing puts the binding back to null. The stroke coordinates stay reachable
as `event.strokes` for a document that wants the vector rather than the
picture.

**Behaviour change**: a document that was reading `strokeCount` or `strokes`
off the *binding* must read them off the event instead. The binding now holds
the picture.

### A dragged Gantt bar reported where it started

`gantt` with `editable: true` moves a bar under the finger and reports the new
dates through `onTaskChange` — and it reported the dates from the bar's last
BUILD, not from the last drag update. The frame after the final update has not
been built when the gesture ends, so the tail of every drag was lost, and a
quick drag reported the task as unmoved: the server was told nothing had
changed, and the next refresh put the bar back.

### A plugin's services were registered under the wrong name, and never removed

`MCPPlugin.services` is a `Map<Type, Service>`, and the manager registered each
entry with `register<T>(service)` — which takes its key from the STATIC type of
its argument. That type is `Service`, so every plugin's services landed on one
key: the first plugin's service answered every lookup, the second overwrote it,
and `get<MyService>()` found neither. Unloading called `unregister()` with no
type argument at all, which infers `dynamic` and removed nothing, so a service
outlived the plugin that answered through it.

`ServiceLocator` gained `registerByType` / `unregisterByType` for the case
where the type travels as data, and the plugin manager uses them.

### One row without the sort field took the whole resource down

A `client://` resource can declare a `sort` step. The comparator substituted an
empty STRING for a missing field and handed it to `Comparable.compare` beside a
number, which throws — so a single row missing the field threw out of the
comparator and took the list, and the fetch around it, with it. A missing field
now sorts to one end, and mixed types compare as text.

### A poll channel's and a system monitor's first event reached nobody

`SystemMonitorChannel.start` created its broadcast controller and then emitted
the first reading synchronously — before any consumer could listen, because
`stream` answers `Stream.empty()` until `start` has run. Every consumer does
`await start(); stream.listen(...)`, and a broadcast controller drops what it
emits with no listeners, so that reading was thrown away every time. A
dashboard bound to the channel sat empty for a full interval and then filled
in, which reads as a slow backend rather than as a dropped sample.

`PollChannel` had the same shape and the same fault: a document refreshing on
a thirty-second poll waited the whole interval for its first update, which
reads as a slow server rather than as a dropped event.

Both now emit the first event on the next turn of the event loop, and `stop`
cancels it along with the interval timer.

### A `deep` watcher fired on every write

`state.watchers` with `deep: true` exists to fire only when the CONTENTS of a
map or list change. It fired on every write of an identical collection: the
baseline it compares against is a clone, cloning re-types (`{'a': 1}` is a
`Map<String, int>`, its clone a `Map<String, dynamic>`), and the comparison
rejected on `runtimeType` before it looked at a single key. A document
watching a fetched object deeply ran its actions once per poll.

### `errorBoundary` could not catch either

The same defect as `errorRecovery`, in its sibling: the renderer answers a
failed build with its own inline card, so the boundary's `catch` never ran —
its `fallback`, its default surface and its `onError` were all unreachable
from any document. Both now render their child through the rethrowing form.
(The fallback path too: a fallback that itself failed used to draw the
renderer's card rather than the boundary's default surface.)

### Every directed graph rendered as an undirected one

Three faults on the same edge, each of which alone would have hidden the
others.

- `directed` was read only per edge. §10.13's own example declares it on the
  graph — "topology-oriented defaults (hierarchical layout, directed edges)" —
  so the documented form drew plain lines. A graph-level `directed` is now the
  default for every edge, and an edge may still say otherwise.
- The arrowhead's direction vector was divided by the *square* of the edge
  length, so its size was `10/|d|` rather than `10`: sub-pixel for any edge
  longer than ten logical pixels, which is every real edge.
- The arrowhead's tip sat at the target node's centre, and nodes are painted
  after the edges — so what did get drawn was covered by the very node it
  pointed at. The tip now sits on the node's rim.

The result was a dependency graph that shows what is connected but never which
way anything points, with nothing said. Verified by counting the pixels in the
edge colour: a directed edge now paints more than a plain one.

### A radar series ignored `borderColor`

Every other series type takes `borderColor` as the line colour, which is what
§10 says it is. The radar polygon read only `backgroundColor`, so a document
that coloured its series the documented way got the palette default on that
one chart type — with a legend beside it in the colour it asked for.

### `timeField` opened its picker from a context it should not have asserted

`context.buildContext!` is the render context's stored context, and it is
nullable: asserting it made the tap throw wherever it was unset, and where it
was set it could belong to a different subtree than the one the user tapped —
which is the Navigator the dialog would have been pushed onto. Same fix as
`dateRangePicker` earlier in this release: the picker opens from the widget's
own build context. `dateField` had it too — all three date/time pickers
asserted the same nullable field.

### A refused `client://` URI said the wrong thing

`ClientResourceSchemes.parse` returns null for two unrelated reasons — a
malformed URI, and a path traversal segment (§8.3.3) — and the resolver
reported both as "Failed to parse URI". An author who wrote
`client://file/data/../secrets` was told their URI would not parse, which it
would; what happened is that the runtime refused to follow it. The two are now
distinguished, in the same words the per-scheme checks already use.

### A faded-out transport still took the tap

`mediaPlayer` hides its controls after a few seconds of playback by animating
them to zero opacity — and an `AnimatedOpacity` at zero still hit-tests. So the
tap meant to bring the transport back landed on the invisible play button
underneath and paused the media instead. The overlay is now ignored for hits
while it is hidden.

### The time picker opened at the wall clock, not at the time already chosen

`datePicker` opens on the date the binding holds; `timePicker` opened on
`TimeOfDay.now()` regardless. Correcting 09:30 to 09:35 meant spinning the dial
back from whatever the current time happened to be, every time.

### A navigation rail replaced the selected destination's icon with a house

`selectedIcon` is optional, and an absent one means "the same icon" — Material
resolves it that way from a null. The factory substituted `Icons.home` instead,
so the one destination the user is looking at showed something the document
never declared.

### A navigation rail could not report which destination was chosen

The index was substituted into an `index` KEY of the action map, which no
action reads. The standard spelling — `state.set` with
`value: "{{event.index}}"` — therefore wrote null. The handler now publishes
`event.index` into a child context, so the placeholder resolves wherever the
action puts it.

### The bar form of `progressBar` skipped the common wrappers

`visible`, `tooltip` and `click` (§2.2) apply to every widget, and the linear
branch applied none of them; it also never read `minHeight`, so a declared bar
thickness left every bar at the 4dp default. Both shapes are now built by the
per-shape factories that already existed in the file and had never been wired
to anything.

### The progress shape can now be named by the widget type

§2.5.14 gives `progressBar` a `type` property with `linear` and `circular` in
it, and that property is unreachable: the widget type and the property share
the key, and `extractProperties` strips it. `indicatorType` was the only way
to say it. The widget types now carry the shape as well —
`linearProgressIndicator` defaults to linear and `circularProgressIndicator`
(new) to circular, with `indicatorType` still overriding either. Before this,
`linearProgressIndicator` drew a spinner: a name that stated the shape and
then drew the other one. `progressBar` / `progress` / `loadingIndicator` are
unchanged.

### A doubly-parenthesised expression resolved to nothing

`((a + b))` — what a generator produces when it parenthesises something that
was already parenthesised — had only its outer pair stripped, leaving
`(a + b)` to be read as a state PATH. The path does not exist, so the binding
answered null and the label went blank. The strip now repeats while the
remaining pair still wraps the whole expression.

### `flow` showed one enormous child and nothing else

The delegate never overrode `getConstraintsForChild`, so every child inherited
the flow's own constraints — TIGHT whenever the flow sits in a sized box,
which is the ordinary case. Each child was forced to the full size of the
flow, so the first one filled it and every other one was placed off the bottom
edge. A tag list rendered as a single enormous tag, with nothing to say why.

Children size themselves now; the flow only places them, which is what a flow
layout is.

### `mediaQuery` breakpoints were not responsive at all

The widget matched against `xs` / `sm` / `md` / `lg` / `xl`, and the
breakpoint system answers with the §14.1.1 classes — `compact`, `medium`,
`expanded`, `large`, `extraLarge`. Nothing ever matched, so the exact-match
branch never ran and the fallback loop returned whichever key came first in
that obsolete list, at every window width: a phone layout on a desktop, or the
reverse, depending only on declaration order. The classes are now the spec's,
the old spellings are accepted as aliases so shipped documents keep choosing
the same layout, and a `default` key is honoured per §14.2.1.

### A `listTile` icon name outside four words drew an arrow

The tile carried its own icon table with `arrow_forward`, `arrow_back`,
`check` and `close` in it, and answered a forward chevron for anything else —
so `leading: "home"` drew an arrow. Same shape as the four tables already
folded into the shared resolver this release, one widget over: a plausible
wrong icon, which is harder to notice than a missing one.

### `expanded` / `flexible` with any wrapper asserted instead of laying out

Both are `ParentDataWidget`s: the surrounding `Row`/`Column` reads them by
looking at its own direct child. The factories applied the common wrappers
(`visible`, `tooltip`, `click`) *around* the widget, which hid it from the row
— so a document that declared `flex` and `tooltip` on the same node got a
Flutter parent-data assertion, a red rectangle, rather than a layout.

The wrappers now go inside, which is where the renderer already puts its own.

### Every `drawer` threw before it drew anything

The default header read the colour scheme through `context.buildContext!` —
outside any `if`, so it ran for every drawer, including the ones that supply
their own children and never reach the default. A render context with no
stored build context made that a null assertion, and the drawer became an
error card. The theme now comes from the drawer's own build context, and the
default header is built only when there is nothing else to show.

### A `radio` declared with only a `binding` would not select

The change callback was installed only when `onChange` was also declared, and
the label's tap handler read the legacy `bindTo` alone. So the shortest
correct form — a radio, a value, a binding — rendered and did nothing, and a
labelled radio ignored taps on its label. Both paths now go through the one
handler, which writes the binding first and dispatches `onChange` after.

### Forty-six dimension slots dropped a bound value

§3 says every value may be written as a literal, as `{value, unit}`, or as a
binding. `parseDimension` reads the first two and answers null for the third,
so any slot using it silently reverted to its default the moment a document
bound it — and a size that changes is *only* ever bound. `animatedContainer`
was the sharpest case: its `width`/`height` came back null, so the box had
nothing to animate between, which is the one thing the widget exists to do.

The tolerant reader (`dimensionOf`) already existed — a note above it records
nine such slots being fixed "so the next slot inherits it instead of repeating
the defect". Forty-six had not. They now all read through it: same answers for
a number and for `{value, unit}`, and a binding resolves.

### One stray keystroke emptied a `numberField`

`FilteringTextInputFormatter.allow` takes a pattern matching allowed
*characters*. This passed it anchored whole-string patterns (`^-?\d*$`), and a
string that does not match in full produces no matches at all — so the filter
kept **nothing**. A letter, or the thousand separator the field itself
displays, wiped the digits the user had already typed and took the binding to
null with them.

`thousandSeparator` was unusable for the same reason: the field renders
`1,234,567` and `onChanged` strips the separator before parsing, but the
formatter deleted the whole text the moment one was typed. The two halves of
the widget contradicted each other.

The filter is now a character class, and it includes the declared separator.

### The runtime asked the operating system directly, in three places

`client.platform`, `client.getSystemInfo` and the system-monitor channel each
ran their own ladder of `Platform.isAndroid` / `isIOS` / `isMacOS` / … and each
carried its own `kIsWeb` guard in front of it. Three independent readings of
one fact, which can disagree; a guard that has to be remembered at every new
call site; and no way for the embedder — which is the layer that actually knows
— to say otherwise.

The `client://` resolver's own web guards went the same way, so a document on
a browser now gets a named refusal from every filesystem scheme — and the
cache, which is not a filesystem, keeps working.

`dart:io` is now read in one file, which the web build never compiles, and
everything above reads `HostPlatform`. A host that knows better than the
process does (a kiosk shell, a remote session) states it with
`HostPlatform.override`, and the derived answers (`category`, `isWeb`) come
from the same value rather than being read again.

### The platform-split widgets could not be tested at all

`voiceInput` and `pdfViewer` reach the browser through a conditional import
that resolves to a no-op stub everywhere else. Off the web their factories
could only ever take the "not available here" branch — so everything below it
went unverified on *every* platform, not just off the web: the transcript
reaching its binding, the live-capture indicator, the maximum-duration
cut-off, and the whole §10.25 open-parameter fragment that decides which page
a PDF opens on.

Neither of those is browser code. Both factories now read their platform
entry points through a `@visibleForTesting` seam, so the logic that is not
browser-specific is exercised on any platform. Production still reads the
platform; nothing about the browser path changed.

### A debounced field lost its debounce as soon as it was wrapped

The debounced path built the field, then took the result apart and rebuilt a
`TextField` around its own handler and controller. That recognised exactly two
shapes — a bare `TextField`, or a `Focus` around one. A document that also
declared `visible`, `tooltip` or `click` got a wrapper back, the rebuild did
not recognise it, and the built field was returned untouched: no debounce, and
driven by a different controller than the one holding the debounced value.

The builder now takes the controller and the change handler as arguments, so
the debouncer owns both and everything the document wrapped around the field
comes back intact.

### A phone field showed its dialling code twice

`defaultCountry` set `prefixText` — which is what draws the code — and *also*
seeded the controller with the same string. So the code appeared twice
(`+82+82…` the moment anything was typed), and the seeding wrote into the
field without writing to the binding, so what was on screen and what the
document held disagreed from the first frame. Only the debounced path ever
showed it, because that path threw the seeded controller away.

The prefix is decoration now, and only decoration.

### A pasted one-time code landed entirely in the first cell

`otpInput` exists because a row of text inputs cannot distribute a pasted or
autofilled code across its cells — and the field carried `maxLength: 1`, whose
formatter truncates the arriving string to one character before `onChanged`
runs. So the distribution code never saw more than one digit, and the widget
behaved exactly like the composed version it replaces. The cells are kept to
one character by the distribution itself, which is what it was written to do.

### A page given as `{appBar, body}` could not draw its bar

`Scaffold` needs a preferred size and the `headerBar` factory hands back a
`Builder` around the bar — so the cast to `AppBar` threw, and the whole page
became an error surface. The rendered bar is now given a preferred size when
it does not carry its own.

### A `webView` given inline HTML showed nothing at all

The engine-absent path reported "no web view capability" for every case,
including the one that needs no engine: markup the document supplied itself.
The preview that shows it — labelled as source, with a badge when scripts are
off — sat in the file unreachable, and the document got a blank box plus an
`onError` for content it had already provided. Inline HTML now renders; a URL
with no engine still reports the absence, unchanged.

### `dialog` could not reach its own `alert` and `simple` forms

The widget type and the dialog's kind are both spelled `type`, and
`extractProperties` strips that key before the factory sees it — so the
property was always absent and every `dialog` was the custom form. `dialogType`
is the reachable spelling, matching `mediaType` on `mediaPlayer` and
`indicatorType` on `progressBar`. Additive: nothing that renders today changes.

## [0.7.4] - 2026-08-08 — a topology that arrives late is still drawn

`networkGraph` copied its node list once, in `initState`, and never again. A
bound `nodes` resolves from state, and in an app that state arrives after the
first frame — so the layout kept the empty list it was born with and the panel
stayed empty for good. `edges` looked fine the whole time because the painter
reads those on every paint: the two halves of the same widget disagreed about
whether late data counts.

Now the node list is re-read (and re-laid-out) when the declaration changes,
compared by what the document declares rather than by object identity — the
resolver hands back a fresh list every rebuild, and comparing references would
relayout every frame and throw away a drag.

### How it survived the previous cut

0.7.3 typed `nodes` / `edges` as bindable and shipped a test that passed, and
the note that went out said the runtime had always drawn a bound topology. Both
were measured wrong:

- the first probe returned the *same* pixel count for literal and bound. An
  identical number is a reason to distrust the measurement, and it was read as
  proof instead;
- the unit harness puts state in place before the first build. An app puts it
  there after. That difference is the whole defect, so the harness could not
  see it.

A five-way control (state visible as text · literal/literal ·
literal+bound edges · bound nodes+literal edges · both bound) is what
separated them. The regression here reproduces the ordering — empty state,
first frame, then the data — and fails without the fix.

## [0.7.3] - 2026-08-07 — the runtime answers for the spec's own examples

Six binding defects, all of them written down in the specification as its own
examples, all of them present in every release back to 0.5.1. None of them was
found by this package's 5,600 tests, because no test read the spec: the schema
says a document is well formed and the widget suites cover the paths their
author thought of. The first person to execute §3.6.1's own line was an author
following the document, after upload.

### The gate that ends this class

`test/spec/spec_expressions_test.dart` runs the forms §3 documents against the
engine, and `test/spec/input_binding_readback_test.dart` asks every input
widget the §2.6.0 question. Both are backed by a mechanical inventory: every
`{{ … }}` in the 1.4 prose is extracted (`tools/spec_codegen/bin/spec_examples.dart`)
and an expression that appears in NO bucket fails the suite — so a new example
cannot land unanswered, and nothing lands in "skip" without a written reason.
Its live half (`tool/capability_probe/run_corpus.py` in appplayer_core) reads
the same corpus off a painted screen.

The previous cut fixed two holes in the same argument parser (commas inside
quoted arguments, nested calls) and walked past the third, because nothing
enumerated the forms.

### Fixed

- **A function argument may be an operation.** §3.2.1's grammar makes an
  argument an `Expression`, and §3.6.1's example is `round(price * quantity, 2)`.
  Arguments that were not literals, paths or nested calls fell through to the
  path branch, so `floor(9 / 2)` became a lookup for a variable *named*
  `9 / 2` → null → an empty string on screen. Silent: an author sees `2:5`
  render as `:`.
- **A leading sign is not a binary operator.** `-1.57 + (value / max) * 6.28`
  (§10's gauge needle) split at index 0 and answered with the right-hand term
  alone — a needle drawn at the wrong angle, reported by nothing.
- **`filter(list, 'prop')`** — §3.6.2's truthy shorthand. Only the 3-argument
  and lambda forms existed, so §3.6.1's `length(filter(items, 'completed'))`
  answered 0 for every input, which reads like real data.
- **`reduce(list, (acc, item) => …, initial)`** — §3.6.3's accumulator form.
  Only single-parameter lambdas parsed, so the spec's own example returned its
  initial value: a total of 0 that reads like an empty cart.
- **`page.` and `state.` prefixes** — §3.5 makes `page.` the explicit alias of
  the bare resolution target (v1.0) and §17.2.5 lists `state.` as its synonym;
  §16.1.1 writes `{{state.isActive ? 1.0 : 0.3}}` as its own example. Neither
  resolved: the store was asked for a key literally called `page.count`.
- **`slider` read its binding back.** §2.6.0 is normative that `binding` is
  two-way — "the runtime reads the current value from the path and writes user
  input back". Only the write half was wired, so a bound slider sat at its
  minimum while the value beside it was right. The read-back matrix now covers
  the input widgets; `slider` was the one that failed it.

From documents written by following the spec.

### The matrix now asks whether anything was drawn

`widget_render_matrix_test` enumerated every declared widget and passed each
one that built without an error widget. A heatmap clamping every cell to one
colour, a chart plotting nothing, a player over a source that will not open —
all of those build cleanly and leave the page empty, which is the shape of
every defect an author reported from a screen. The matrix now screenshots the
frame and requires pixels on top of the page background, with host
capabilities wired (so `mediaPlayer` is exercised rather than reporting an
absent host) and state seeded from the bindings each spec example reads.

Turning it on immediately found: `heatmap` (below), `spreadsheet` reading
nothing, and six widgets that threw a **cast error** when a bound path held an
unexpected shape — `bottomNavigation`, `dataTable`, `kenBurnsImage`,
`resizable`, `tabBar`, `visibility` painted a red error box over the page
instead of ignoring the value. A mistyped binding is an authoring mistake, not
a reason to take the screen down; all six now read through the tolerant
helpers.

### heatmap

- **The scale comes from the data when none is declared.** `minValue` /
  `maxValue` are optional, and defaulted to 0..1 — so a heatmap of anything
  larger (a defect rate of 1.5..6.2, a temperature, a count) clamped every cell
  to the top colour: one flat block that looks finished and says nothing.
- **A fractional value is no longer printed as an integer.** Cells were rounded
  to whole numbers always, so 1.8 and 2.4 both read `2` — on a heatmap of rates
  or averages, where the first decimal is the signal, that is a wrong screen.
- **`showLabels` is documented for what it does.** The registry said "draw the
  numeric value inside each cell", which is `showValues`; it actually turns on
  the row and column labels. An author who declared `rowLabels` and saw nothing
  read the blank axis as their own mistake.

Measured on a built app before this cut went anywhere.

### A note on what these fixes change for documents already in the field

Four of them make a binding that read `null` read a value. That is the spec's
answer, and a document cannot have depended on the correct one — but it can
have been written around the wrong one, and some of those documents belong to
other people (a marketplace bundle is not ours to re-author). Specifically:
`page.` / `state.` prefixes now resolve, `filter(list, 'prop')` returns rows
where it returned none, a function argument that is an operation produces a
number where it produced an empty string, and `slider` follows its `binding`.
Where a `binding` sits beside a declared `value`, §2.6.0's precedence decides
and the declared value still stands while the path is unset — so a document
that never populates that path looks exactly as it did.

Reported as a live path by mark (Cloud's launcher model stacks renderers) and
(bundles that declare both on a slider, where the `value`
turned out to be a binding to the same unset path — no visible change there).

### Two documents can be on screen at once

Found by running the two live gates back to back instead of one at a time: the
second one opened its bundle, was told `ok`, and read the launcher. A gate that
reports on the wrong screen is worse than no gate.

- **The navigator key is the engine's, not the process's.** Every document that
  declares routes builds a `MaterialApp`, and its key came from the
  `NavigationService` singleton — so a second mounted document put the same
  `GlobalKey` in two places, Flutter truncated the tree at the second, and the
  first was torn out of its parent. One `Duplicate GlobalKey` line in the log
  was the only trace. `NavigationService.attach` now points at the front app's
  navigator, so navigation actions still act on what the user is looking at.
- **The route observer is the engine's too.** A `RouteObserver` may be attached
  to one navigator at a time (`observer.navigator == null` is asserted), so the
  shared instance failed the moment a second document mounted — which is what
  `onPause` / `onResume` hang from.


## [0.7.2] - 2026-08-07 — the alias is inferred from too

`mediaPlayer` opens `src ?? source` and 0.7.1 inferred the kind from `source`
alone, so a document written with the legacy spelling pointed at an `.mp3`,
inferred nothing, and fell back to video — the host was asked for the video
capability and an audio-only one reported it absent. Both now read the same
value. Reported against the published cut.

## [0.7.1] - 2026-08-07 — the spec states the standard, the runtime keeps reading the legacy

Backward compatibility is measured here, not asserted: `compat_probe_test`
runs 577 documents from this workspace through the last pre-1.4 registry, the
published one, and this tree. **A document the published registry accepts and
this one does not now fails the suite** — widening is free, taking a form away
closes bundles that are already in the field.

Result of that gate today: **0 documents lost**, 57 gained (forms that were
rejected at load and are accepted again).

### Legacy values are declared, not advertised

The registry gained `legacyValues:`. Those spellings go into the schema — so a
bundle carrying one still opens — and stay out of the prose, the generated
tables and anything that offers an author a choice:

- `linear.distribution` — `space-between` / `space-around` / `space-evenly`
- `qrCode.errorCorrection` — `L` / `M` / `Q` / `H`
- `codeEditor.theme` — `light` / `dark`
- `Color` — the pre-M3 slot names (`divider`, `foreground`, `textOnSurface`,
  `textOnPrimary`, `textOnSecondary`, `textOnBackground`, `textOnError`).
  These now *resolve* as well as validate: each maps onto the M3 role it meant,
  so a document that used to load and paint nothing paints the right colour.

A new audit section (`drift_audit` §L) reports any spelling the runtime renders
that the schema refuses, so this class cannot come back silently.

### Declared defaults now say what the runtime does

`drift_audit` §M compares each registry `default:` against the literal the
factory falls back to. Ten disagreed; in every case the implementation was
left alone and the documentation corrected, because the default is what a
document that says nothing already gets:

`gauge.strokeWidth` 20→10 · `gauge.labelFormat` `{value}`→`{value}%` ·
`gauge.startAngle` 135→-220 · `gauge.sweepAngle` 270→260 ·
`heatmap.showValues` false→true · `signature.showGuide` false→true ·
`codeEditor.theme` vsLight→dark · `terminal.prompt` `$`→`$ ` ·
`timeField.use24HourFormat` true→false · `timePicker.use24HourFormat`
false→true. (The last two disagree with each other; both are documented as
implemented rather than unified, because unifying them would change screens
that never named the property.)

### Visible without declaring anything

Four changes alter what an existing document draws even if it declares none of
the properties involved:

- **chart** — the entry reveal declared by `options.animation.duration`
  (default 1000 ms) now runs. `options.animation.duration: 0` restores the
  instant draw.
- **calendar** — the month fits the box it is given instead of scrolling, and
  a month that begins on the week's first day no longer carries a leading week
  of the previous month.
- **networkGraph** — the graph is fitted to its box (placements were built
  around a fixed centre of 200,200) and each `layout` draws its own shape.
- **codeEditor** — Tab indents by `tabSize` instead of moving focus.

`colorPicker` keeps its preset swatches: the registry said `pickerType: wheel`
while no implementation ever drew one, so the default is now `palette` — what
every picker has always shown — and `wheel` / `both` are opt-in.

### Also in 0.7.1 — validation that was declared but never applied

**Additive only.** A schema narrowing is a bundle break, not an authoring
hint: the runtime validates documents *at load*, so a slot that stops
accepting a value stops the bundles carrying it from opening. Nothing here
narrows anything — measured, not assumed (see below).

**A `validation` block written to `07_Security.md` §7.2.1 produced no rules at
all.** The section publishes two shapes and says a runtime MUST support both.
Shape B is an array keyed `rule`; this engine only ever read `type`, and its
switch had no default, so an array in the published spelling parsed to an
empty rule set — and an empty rule set validates everything. Shape A, the
constraint object, was answered with "legacy validation format detected" and
discarded. The workspace corpus holds **117 Shape B blocks, every one of them
already in the `rule` spelling**, so every declared constraint in it was
inert: the field accepted anything, quietly, and nothing anywhere said so.

- `rule` is read, and `type` still is. Documents authored against the shipped
  engine keep validating; documents authored against the published spec start.
- Shape A parses. `kind` becomes the matching rule, `maxLength` and `pattern`
  become their own, and they compose — `{kind: email, maxLength: 12}` now
  rejects on either.
- `phone`, `number`, `integer` and `date` are implemented. §7.2.1 published
  them; the enum had no entry, so they parsed to nothing even under the right
  key. Each checks shape only: an empty value is `required`'s business, so
  "optional, but must look like a phone number" stays expressible.
- An unrecognised rule or kind is now reported. A constraint nobody parses is
  one the author believes is running, and a typo used to be indistinguishable
  from a field with no rules.

**This changes behaviour for existing bundles, deliberately.** A form whose
`required` rule was inert will start refusing empty input. The author declared
that constraint; applying it is the fix, not a regression — but a bundle that
had come to depend on the constraint *not* running will behave differently.

**`box.margin` now takes the M3 spacing token, like `padding`.** Both slots
have always resolved it through the same helper; only the declaration was
narrower, which made the token unauthorable rather than unrenderable. A token
the theme does not declare produces no inset and is now reported once per
distinct value — `"16px"` in a padding slot has always resolved to nothing,
and saying so is the whole of the fix. The registry still accepts it:
tightening that pattern would stop published bundles from opening.

Verified additive by differential: 20 value shapes × 2 slots run against the
published registry and this one — **0 narrowed, 7 widened, 33 identical**
(`test/spec_compliance/box_spacing_widening_probe.dart`).

## [0.7.0] - 2026-08-05 — vector assets, and the ink that was painted under the page

**SVG draws, in both the image and the icon slot, on every platform including
the web.** `IconRef` has named `data:image/svg+xml` as an ordinary form since
1.4 and `icon`'s own example in the registry is `assets/icons/heart.svg`, so a
runtime that could not draw them made the spec's shipped example false. Vectors
take a picture widget rather than an `ImageProvider`, so the scheme dispatch
lives in `AssetResolver.vectorWidgetFor` beside the raster one — §6.12 requires
one resolution path for every `AssetRef` slot, and two dispatches would drift.
All five forms resolve: `data:`, `assets/`, `bundle://`, `client://` / origin
(asynchronous, with the slot's loading state while the read is in flight), and
network. Icons tint through a colour filter, which is what makes §2.5's "`color`
applies to the SVG form" true rather than aspirational. Adds `flutter_svg`.

**A tile reading `SVG not supported` was removed — it violated §6.12.4.** That
section forbids rendering the runtime's limitation in place of the asset, with
`Base64 not supported` as its example; an undecodable payload takes the slot's
declared fallback and the reason goes to the diagnostic channel. It was shipped
for one round, verified as correct by a live check, and was wrong the whole
time.

**Ink is painted where the document can see it.** `ListTile.tileColor`,
`selectedTileColor` and the splash / focus / hover overlays are painted into the
nearest `Material`, which is normally the app's — below every background the
document paints on the way down. A page with its own background therefore
covered them completely: the properties validated, rendered no error, and drew
nothing. Both widgets now own a transparent `Material`, which is the fix
Flutter's own assertion names. Measured live: 0 → 7,054 splash pixels with the
page background in place.

**Union-typed slots read every branch they declare.** `Dimension` slots were
read as `as num?` in 40 places, so the `{value, unit}` object and the binding
form threw on sight; `Action` slots were cast to `Map<String, dynamic>?` in 120
places, so a list of actions rendered a cast error, and the common `click` slot
accepted a list, rendered without complaint, and did nothing when tapped. Enum
slots resolve their binding before matching. `EdgeInsets` accepts a binding, per
entry as well as whole — `{left: "{{sidebar.width}}", top: 8}` is the shape
documents actually write.

**Properties the registry declared and the factory ignored, implemented:**
`dataTable.filterable` / `resizableColumns` / `virtualScroll`,
`tree.checkable` / `checkedKeys`, `textInput.showToggle` / `defaultCountry`,
`numberField.showStepper`, `codeEditor.copyable`, `list.overscan`.

### Also in 0.7.0 — expressions the spec's own examples use

**A `validation` block does something.** The rules were parsed, `validate` was
called on every keystroke, and the result was dropped — under a comment saying
it would be used "later if needed". A field declaring `required` or
`minLength` therefore accepted anything, which reads as input that was always
valid. The message now shows on the field; an explicit `error` still wins.

**§3.8 computed properties and §3.9 state watchers reach a document.** Both
were implemented and wired only to a runtime `services.state` block, so a page
or application that declared them the way the spec writes them — inside its own
`state` — got nothing at all: a computed value that never appeared and a
watcher whose actions never ran, neither of which reports anything. They are
read from the definition's `state` now, in the spec's own shape
(`"total": "{{a + b}}"`, dependencies detected from the expression) as well as
the older `{expression, dependencies}` wrap.

**`debounce` on a text field took the page down.** The debounced field looked
its own factory up as `TextField` while the registry key is `textInput`, so
the lookup returned null and the `!` threw during `initState` — every document
that declared `debounce`, which is the property a search box exists to use,
replaced its page with a null-check error. Both lookups use the canonical key
now, and the window itself is pinned: held until it closes, only the last
value in a burst delivered, and the caret never waits on it.

**A bound `selectedDate` moves the calendar.** The date was read once in
`initState`, so a calendar bound to state kept showing the month it first
rendered — a server push or a date picked elsewhere on the page changed
nothing, with no sign that anything had been asked of it. Its day-select event
also reports `event.value` now, alongside the `event.date` it already sent:
every other input reports `value`, and that is what a document binds by habit.

**`channel.send` on an inbound-only channel is reported.** It logged one debug
line and returned, so a document sending on an `mcpStream` got a success it
could not tell apart from a delivered message.

**A comma inside a quoted argument ended the argument.** `format(price,
'#,##0.00')` — §3.6.1's own example — arrived as three arguments, so the
pattern lost its grouping and its decimals and `1234.5` came back as `1235`.
`split(text, ',')` had the same shape. The splitter respects quotes now, as it
already respected parentheses.

**A nested call was read as a variable name.** An argument that was itself a
call fell through to the path branch, so `length(filter(items, 'completed'))`
— again the spec's example — looked up a variable literally named
`filter(items, 'completed')`, found nothing, and answered 0 for every input.

**`min` / `max` take the arguments they are documented with.** §3.6.1 writes
`max(a, b, ...)`; the implementation handled exactly two, and a third made the
whole call resolve to null — which a document shows as an empty value rather
than as an error.

**`map` accepts a lambda.** `filter` and `reduce` both read one; `map` went
straight to the property-name branch, stringified the lambda into a property no
item carries, and returned every item unchanged — the input list, which reads
as a mapping that did nothing rather than one that never ran.

**`{{runtime.version}}` reports the version this package implements.** It
answered a hardcoded `1.1`, two cuts stale and a number nothing else in the
system used; it reads `MCPUIDSLVersion.current` now.

**Client resources**: a workspace or temp file could be written and then not
read back. The containment check resolved the *target* through symlinks and
compared it against an unresolved root, so any workspace reached through a
link — `/var/folders/…` on macOS, and anything under it — rejected its own
files as escaping. Both sides are resolved now. A custom resource provider
that throws is reported as a result rather than escaping to the caller, and an
unknown file extension is treated as binary, which is what its own
`application/octet-stream` content type already said.

**Channels**: stopping a channel moves its state. The subscription was
cancelled but `_channelStates` stayed on `connected`, so `getChannelState` and
every binding reading it reported a live channel that would never deliver
again — and `toggleChannel`, reading the same stale picture, refused to turn it
back on. A channel action naming a channel that was never declared is reported
(`NOT_FOUND`) instead of returning success, which left a page waiting for data
with `onError` never firing.

**Dialogs**: `showOverlay` never worked — it looked for an `Overlay` *above*
the overlay's own context and threw every time; it reads the navigator's
overlay now. `showInput` disposed its controller while the dialog was still
animating out, tripping a framework assertion in debug and leaving a listener
on a dead object in release.

**Batch**: an empty `actions` list is a batch with nothing to do rather than an
authoring error — a document that builds its actions from a filtered list
produces one legitimately. A *missing* list is still an error.

**Error boundary**: the global `FlutterError.onError` and `ErrorWidget.builder`
are restored when the boundary is disposed. Both were taken over and never
given back — and `ErrorWidget.builder` was assigned from `build`, so the last
boundary to build owned the application's error surface for the rest of the
process, including after it was gone.

### Also in 0.7.0 — a shell app can reach its own pages

**A route declared in `routes` was unreachable inside a navigation shell.**
Four things had to line up and none of them did. The shell's `MaterialApp` was
built with `home:` and no `routes:` table, so no named route resolved there.
The shell registers a handler that maps a route to a tab index and returns
`false` for anything else — its own comment says "let other handlers process
this" — but the executor read that `false` as a refusal and stopped, so the
fall-through to the navigator never ran. The tab strip itself was placed with
`DefaultTabController(initialIndex:)`, which only applies at creation, so a
route-driven switch moved `_currentIndex` and the navigation state while the
screen stayed where it was. And that controller's listener was attached inside
`build`, stacking a new one on every rebuild.

Now: the document's routes are registered in both branches; a declining
handler hands the route on instead of ending it; a programmatic index change
drives the controller (a user tap still moves the controller first, and the
shell follows it — pushing back in that direction fought the gesture); the
listener attaches once.

**A launch route is honoured wherever there is a shell.** The shell picked its
tab from `appDefinition.initialRoute` and never consulted `RouteManager`, so
three stations opening the same application at `/kiosk`, `/pos` and `/kds` all
drew the first tab (reported 2026-08-03; present since 0.1.0). It
reads `RouteManager.initialRoute` now, which is the requested route when the
document declares it and the document's own otherwise. A launch route that
names a declared page with no tab of its own — the usual shape of a scanned
code — opens over the shell once the first frame exists, so back returns to
the tab the document names.

**`ComputedManager`**: every computed property threw. `_recompute` hands
`BindingEngine` a `SimpleComputedContext`, and the engine's resolution chain
asks for `themeManager` before it knows whether the path is a theme path — the
context was written to refuse, so nothing resolved. Watchers primed their
baseline only when `immediate: true`, so the first change reported `null` as
the old value and setting an unchanged value counted as a change. And
`dispose` cleared its own maps while leaving its closures on the shared
`StateManager`, so a discarded manager kept delivering for the life of the
state object.

### Also in 0.7.0 — one reading of `Color`

**Four color parsers became one.** The warning below was added to
`WidgetFactory.parseColor` and then the axis was measured properly: three more
parsers answered the same question differently, so whether a document was legal
depended on which property it landed in. The page renderer took `pink` and
`transparent` — neither is in §5.3.4 — knew no scheme slot at all, so a page
`backgroundColor: "primary"` was silently dropped, and read `#fff` as
`0xFF000FFF`, a near-black blue, where the spec says white. The theme took
`rgb()` and nothing else: no three-digit hex, none of the ten names. A dialog
parsed `#RRGGBB` without an alpha channel, producing `0x00RRGGBB` — fully
transparent, for a background that had been asked for explicitly. All four now
call `DslColor.parse`, which is §5.3.4 and nothing else: scheme slot, hex in
three lengths, the ten basic names, and `rgb()`/`rgba()` (accepted here for the
first time — the spec rated it SHOULD and the runtime rejected it).

**Three holes in the warning itself.** A malformed hex (`#12345`) returned null
without a word, which is the failure the warning exists to stop. A valid scheme
slot read on a surface with no theme was reported as *not a color*, sending an
author to fix a correct line. And the warn-once set was an unbounded
process-wide `Set` — colors arrive from state, so it grew for the life of the
process; it is capped at 128 distinct values and says when it stops.

An unresolved binding reaching the parser stays silent: it is the binding
layer's failure, and naming it a color error points at the wrong line.

### Also in 0.7.0 — `lazy` implements what it declares, and an unknown colour says so

**An unrecognised colour name is reported.** `parseColor` returned null and
the widget drew with no colour at all. Found on a live marketplace shelf: two
bundles used `color: "tomato"` and went through publish, approval, purchase
and install, then drew an uncoloured box on the buyer's screen with nothing
anywhere to read. `Color` takes hex, the ten basic names and the Material 3
scheme slots — §5.3.4 says CSS keyword colours are not canonical — so the
document is wrong, and the schema says so wherever a document is validated. An
installed bundle is not, which is why the screen had to. Once per distinct
value: a colour is read on every rebuild.


Found after 0.6.1 shipped, by fixing a harness rather than by a report.

**`lazy.content` accepts the source form.** §10.22 gives it two — an inline
widget, and `{ source: "ui://..." }` naming a fragment to fetch. Only the
first was implemented: a source went to the renderer as-is, which answered
`Widget type is required`, because a source is not a widget. Resolution is
delegated to `view` rather than rebuilt — `lazy` decides *when* a subtree is
built, `view` decides *what* a source resolves to — which also carries
`placeholder` and `onError` through to surfaces that already implement them.

**`onLoad` and `onError` fire.** Both were read into locals and silenced with
an `unused_local_variable` ignore, so a document that declared them waited for
something that never came.

Prose §10.22 named the `trigger` values `viewport` / `immediate` / `manual`
while the registry and the runtime have always used `visible`; a document
written from the prose failed schema validation. The prose now matches.

**Why it took this long to see.** Every spec-compliance suite judged a frame
after a single fixed 50 ms pump. `lazy` materializes from a post-frame
callback, so its failure arrived after the assertion had already passed — the
harness reported clean on a widget that drew an error box. The suites now
settle (capped at one second, because an indeterminate progress indicator
never settles and the default budget grinds for ten minutes before saying so).
Re-run across all five axes, `lazy` was the only thing hiding there.

## [0.6.1] - 2026-08-03 — documents the schema accepts now draw

**Every branch of every declared union now draws.** A property typed
`number | binding` was read as `properties['x'] as String?` in seven widgets:
the cast throws the moment an author writes the number the schema plainly
allows. `resizable.width` and `.height`, `pdfViewer.page` and `.zoom`,
`popover.open`, `stepper.currentStep`, `mediaQuery.condition`, `grid.columns`
and `chart.data` all took the page down on a document that validates.

Nothing caught it because nothing asked. The render matrix draws the examples
the spec ships, and those examples happen to use the *other* branch — so the
number form of `resizable.width` had never been rendered once.
`widget_union_branch_test` closes that: 141 branches, one document per branch,
built by overriding a single property on a document already known to draw.

**Two-way properties wrote to the wrong place.** The path was taken raw, so a
document written the documented way — `"width": "{{panel.width}}"` — read
through the resolver from `panel.width` and wrote back to a key literally
named `{{panel.width}}`. The read worked, the drag persisted nowhere, and no
frame ever looked wrong. `twoWayPath` unwraps the braces and rejects an
expression, which has no single target to write to.

**`IconRef` means all three of its forms, everywhere.** The primitive says a
name, a `{codepoint}` object and a `{uri}` object are accepted anywhere an
icon is taken; seven slots accepted only the string, and two of those carried
private icon tables that had drifted from the shared resolver. Fixing the
crash surfaced two slots that were not drawing the author's icon at all —
`accordion.icon` was read and never used, and `link.icon` drew `Icons.link`
whatever the document said.

**`grid.columns` accepts the responsive object the spec documents.** It never
did; the property was read as `int?`. The registry described that object with
a `{default, sm, md, lg}` vocabulary that appears nowhere else in the spec —
it now names the §14.1.1 form-factor labels the picker actually resolves, and
`pdfViewer`'s page and zoom are described as the one-way values they are,
because an embedded viewer reports nothing back.

An out-of-range `selectedIndex` on `bottomNavigation` now clamps instead of
tripping a framework assertion and taking the page with it.

**A definition-level `onInit` can call a tool again.** The hook runs inside
`initialize` (§1.5.2 puts it before the first render) and the tool executor was
registered from `buildUI`, so an application whose `onInit` loaded its first
data reached nothing at all — no error to the author, and the server never saw
the call. `initialize` now takes `onToolCall` too. A host that passes it only
to `buildUI` keeps working and is told what happened: the "no executor
registered *at all*" case is reported apart from "that tool is not registered",
because the two send the reader to different places.

**`kanban` joined §2.15.** It grew per-column scrolling in this cut, which is
what makes a widget need a bounded parent, and the hand-written list did not
follow. `bounded_parent_axis_test` now pins that list against what actually
happens under a scrolling page — including that the `sizedBox` remedy the
section prescribes works.

**A tab bar no longer rebuilds the page you came back to.** Every branch of
the application shell built its body from a `FutureBuilder` keyed on the
current route, so switching destroyed the outgoing page and built the incoming
one from nothing — `onInit` → `onMount` → `onReady` again, tools called again,
images fetched and decoded again, on every tap. A page that loads its data in
`onInit`, which is the shape §1.5.3 shows, re-fetched on every visit.

Pages now stay mounted: leaving one fires `onPause`, returning fires
`onResume`, and it is the same instance in between. A page is built on its
first visit, so six tabs do not run five `onInit`s before anyone has opened
them.

`onPause` / `onResume` had in fact never fired for a routed page at all. A
page covered by a pushed route is not disposed either — `dispose` never runs
and nothing else reports the change — so it heard nothing on the way out and
nothing on the way back. Both paths now report: the pushed-over case through
`RouteAware`'s `didPushNext` / `didPopNext`, which is the framework's own
answer to that question, and the shell case through the shell that owns the
selection. A `resume` with no `pause` before it no longer fires — §1.5.2 draws
them as a pair, and a page built already-selected was reporting `onReady` and
then immediately `onResume`.

What a paused page contains is paused too. An instance-level `lifecycle`
block heard `onInit` → `onMount` → `onReady` when its page opened and then
nothing ever again — leaving the page paused the page, not the widget inside
it, so a timer or a subscription started on mount kept running behind a tab
nobody was looking at. Embedded `view` definitions follow the same way.

Each page hook is now dispatched under its own event name. All seven were
labelled `mount`, so a host listening for `pause` would have heard nothing and
one listening for `mount` would have heard every hook. Nothing registers such
a listener today, which is why it was invisible.

**A destroyed page no longer fires `onPause`.** §6.8.3 said the unmount
sequence opened with it; §1.5.1 defines the same hook as losing focus *without*
being destroyed, and §1.5.2 draws it as half of `(onPause ↔ onResume)*`. The
spec contradicted itself — its own back-navigation line resumed a page the
line above had destroyed — and the runtime followed the wrong half. On a
routed page that made `onPause` fire *only* on the way to destruction while
`onResume` never fired at all, so a draft save or a timer stop written there
appeared to run and was discarded with the instance. §6.8.3 now splits on the
one question that decides it: does the outgoing instance survive?

§6.12.8 says what was previously nowhere: an asset carried as bytes through
state gives up its identity, so it is re-sent and re-parsed on every delivery
and the host never sees a reference it could apply a size policy to. §1.5.2
says the other thing that was nowhere: returning to a page is a new instance,
not a resume, so a fetch in a page's `onInit` runs on every visit.


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