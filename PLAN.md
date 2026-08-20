# mergemap: a Stata package to visualize joins across a do-file pipeline

Design plan, 2026-08-19. Target: modern Stata only (frames era, Stata 16+; developed
against StataNow 19.5 MP). No LaTeX/TikZ, no external software, no Python required.

The working name is **mergemap** (SSC-checked as free; alternatives in section 12).
The goal: the user points the command at a sequence of do-files (or a folder of
numbered do-files); Stata records every merge/append/joinby/frlink and the
transformations around them, then draws a boxes-and-arrows diagram of what happened,
with diagnostics (key, declared vs. observed cardinality, duplicates, unmatched rows)
attached to each join. It visualizes what was already done; it does not build code or
perform joins.

## 1. Research digest

### 1.1 SQL-world conventions (jOOQ, MapForce, Simple Talk, SSMS, Power BI, dbt)

The jOOQ argument, which we adopt as the teaching frame: a JOIN is not a set
operation, so Venn diagrams are the wrong picture. "A JOIN is really a cartesian
product with a filter." The honest picture is two stacks of rows, the operator
between them, and the result as a stack of paired rows; unmatched rows in an outer
join appear with an empty partner slot; a many-to-many join visibly multiplies rows
(size rules: cross = |A|×|B|; inner ≤ |A|×|B|; left = inner ∪ unmatched-left padded
with missing).

Conventions worth borrowing from the tools surveyed:

1. Boxes = datasets; the join operator is a small separate node or an edge label
   (MapForce, dbt).
2. One consistent flow direction; sources enter from the side (MapForce is strictly
   left-to-right; dbt/targets lineage likewise).
3. Key variables named on the edge (`users.id = addresses.user_id`).
4. Cardinality spelled as text at line ends (`1`/`*` in Power BI; we use Stata's own
   `1:1  m:1  1:m  m:m` spelling).
5. Row counts in → out on edges; SSMS scales arrow thickness by row count (we keep a
   text count; thickness optional in HTML only).
6. Match breakdown per join: both / master-only / using-only (pandas `_merge`
   indicator ≈ Stata `_merge` 1/2/3).
7. Solid vs. dashed lines: dashed for dropped/unmatched paths and for alias/view
   links (Power BI active/inactive, IDEF1X non-identifying).
8. Self-merges as separately labeled instances (`Partner`, `Partner2`).
9. Detail on demand: list variables/keys inside boxes only when asked (DataHub, dm's
   `keys_only` default).
10. Subgraph grouping per do-file (Mermaid `subgraph`).

To avoid: Venn circles, icon vocabularies, color as the only encoder, per-column
spaghetti lines. Matches the boxes-and-arrows brief.

### 1.2 R/Python diagnostics (tidylog, dplyr 1.1, dm, targets, pandas)

tidylog's per-join ledger is the best textual convention found, and it maps
one-to-one onto Stata's `_merge`:

```
left_join: added one column (b)
           > rows only in x   0
           > rows only in y  (0)
           > matched rows     3    (includes duplicates)
           >                 ===
           > rows total       3
```

Parentheses mean "excluded from result"; `(includes duplicates)` flags fan-out.
dplyr 1.1's many-to-many warning contributes the *grammar* for our flags: one
headline, then bullets naming a concrete offending key, then the exact option that
asserts intent. pandas contributes declared-vs-observed cardinality
(`validate='m:1'` raising MergeError) — which Stata's `merge m:1` already declares,
so mergemap's job is to record the *observed* cardinality next to the declared one.
dm contributes the box style (table name as header, keys listed inside, `keys_only`
default) and the constraint message phrasing ("values of A$key not in B$key").
targets contributes status marking on nodes (we use text markers, not color).

The gap analysis: no surveyed tool in any language combines (a) cross-script,
after-the-fact lineage of dataset joins, (b) observed diagnostics attached to each
edge, and (c) loop collapsing. That combination is open territory; nothing to copy,
nothing to collide with.

### 1.3 Stata internals (verified by live probes on this machine, StataNow 19.5 MP)

Facts that determine the architecture (all tested, not assumed):

- `merge`, `append`, `joinby`, `cross`, `reshape`, `collapse`, `contract`, `xpose`,
  `frlink`, `frget`, `fralias`, `import`, `export`, `fillin`, `duplicates`, `isid`,
  `datasignature` are **ado-files**. `use`, `save`, `expand` are **built-ins** (not
  shadowable).
- An in-memory or earlier-adopath program named `merge` **does intercept** calls,
  and the wrapper receives **macro-expanded arguments** (a `merge ... using \`f'`
  arrived with the full expanded path). Abbreviation stubs (`mer.ado`, `app.ado`,
  ...) route through the full name, so intercepting the full name catches
  abbreviations too.
- Accepted abbreviations: `mer|merg|merge`, `app|appe|appen|append` (and `ap.ado`
  exists), `u|us|use`, `sa|sav|save`. `joinby`, `reshape`, `collapse`, `contract`,
  `frlink`, `frget` must be spelled in full. This keeps rewrite patterns small.
- `clear all` drops in-memory programs, frames, scalars, and open file handles, but
  **keeps globals** and **keeps adopath**. So instrumentation must live in ado-files
  on the adopath (reloaded lazily after `clear all`), state must live in globals plus
  a disk journal, and the journal must be opened-appended-closed per event.
- `merge` prints an exact, parseable result table (including `_merge==4/5` rows under
  `update`); it is not rclass and its r() is unreliable residue. `append` and
  `joinby` print nothing. `frlink` IS rclass (`r(unmatched)`); `frget` returns
  `r(k) r(srclist) r(newlist)`.
- `merge` physically sorts the master by key even when it does not set the sort flag.
  Worth a footnote in the help file; the diagram can annotate "result sorted by key."
- SMCL box drawing works: `{c TLC}{hline 5}{c TRC}` etc. render as lines in the
  Results window/Viewer and translate to ASCII `+---+` in logs. Unicode box chars
  also pass through. Clickable `{stata}`, `{view}`, `{browse}`, `{help}` all work.
- `view browse` fails under console/batch (rc 199); `!open file.html` is the macOS
  fallback.
- `file write` handles long lines and `<>"` inside compound quotes; a handwritten
  SVG validated with xmllint.
- `twoway pci`/`pcarrowi`/`scatteri`/`text()` produced a correct two-box-and-arrow
  diagram exported to PNG in batch. Gotchas: a box needs 4 `pci` segments; the user's
  scheme can draw grid lines through boxes (force `nogrid` + a clean scheme).
- `describe using f` gives `r(N) r(k)` (+ `varlist short` → `r(varlist) r(sortlist)`)
  without loading the file. `frame kf: use keyvars using f` loads only key variables
  of an external file into a scratch frame; `isid` fails with rc 459 on duplicates;
  `duplicates report` leaves `r(unique_value)` and `r(N)`.
- `datasignature` on 1M obs × 10 vars: 0.08 s. Cheap enough to fingerprint every
  result. `checksum` can fingerprint an on-disk file without loading it.
- There is **no general command hook** in Stata. `cmdlog` is interactive-only
  (verified empty in batch). Top-level do-file lines echo **unexpanded** under trace;
  expanded filenames only appear at tracedepth ≥ 2 inside version-specific internals.
  This rules out log/trace parsing as the primary capture mechanism.

## 2. Architecture: two capture modes, one journal, one renderer

The package has three layers: capture (two modes) → journal (one schema on disk) →
render (four output targets). Everything downstream of the journal is shared.

### 2.1 Mode 1: `mergemap scan` (static, no execution)

Reads the do-files as text and builds the DAG from the code alone: `use`/`import` →
source nodes, `save`/`export` → sink nodes, `merge`/`append`/`joinby`/`cross`/
`frlink` → join events, `reshape`/`collapse`/`contract`/`xpose`/`fillin`/`expand` →
transform events, and `keep if`/`drop if`/`drop`/`keep` → filter events. Nested
`do`/`run` calls are followed recursively.

Filter events were added after the competing-software pass (DECISIONS 16a) and they
matter more than their cost suggests. The diagram exists to explain how a dataset
reached its final size, and in practice most row loss happens in a `drop if`, not in
a merge. A map that draws only the joins hands the blame to the wrong step. Once
filters are events, run mode reports them tidylog-style ("removed 21 rows (66%), 11
remaining"), and the same machinery comes within reach of a sample-attrition figure
of the kind `flowchart` currently draws through LaTeX.

Properties: instant, zero interference, works on code that will not currently run.
Macros in filenames stay as placeholders (`` `year' ``), which is a feature: a
`foreach y ... { merge ... using cps_`y' }` loop is naturally a single ellipsis node.
No observed diagnostics (no counts, no duplicate checks) — structure only.

The scanner must be a real tokenizer, not a regex over raw lines (the webdoc
literal-scan trap): join `///` continuations, strip `/* */` and `//` comments, track
`#delimit ;` state, skip strings, and peel prefix chains (`quietly`, `capture`,
`noisily`, and abbreviations) before matching command words. Mata is the right home
for it.

### 2.2 Mode 2: `mergemap run` (instrumented execution)

The design problem: wrappers that shadow `merge` by name cannot call the real `merge`
(the in-memory wrapper wins the lookup → recursion), and `use`/`save` are built-ins
that cannot be shadowed at all. The solution is **source-to-source instrumentation**:
`mergemap run` rewrites each do-file into a temp copy where recognized commands are
substituted *on the same line* with differently-named wrappers:

```
merge 1:1 id using `f', nogen     →   _mm_merge 1:1 id using `f', nogen
use raw/cps2020, clear            →   _mm_use raw/cps2020, clear
save built/panel, replace         →   _mm_save built/panel, replace
do 02_merge.do                    →   _mm_do 02_merge.do        (recursive)
```

Because `_mm_merge` is not named `merge`, calling real `merge` inside it resolves
normally: no recursion, no copying or patching StataCorp code. Because `_mm_use` is
not named `use`, the built-in problem disappears. Because the wrappers are ado-files
on the adopath, `clear all` mid-pipeline is harmless (they reload lazily). Because
substitution is same-line token replacement and all bookkeeping happens *inside* the
wrapper, line numbers are preserved exactly; error messages are re-echoed against the
original file:line from the journal's line map.

Each `_mm_merge` call is a **recorder, not a rewriter**: measure before, run the
user's command verbatim, measure after. In order: record master identity
(`c(filename)`, N, k, sortedness); pre-check the using file cheaply
(`describe using` for N/k and key storage types); load the using file's key
variables into a scratch frame for the duplicate check and, in the same pass,
compute the match counts from the key sets under `preserve`/`restore`; run the
user's `merge` with every option untouched; post-record result N/k, observed
cardinality, coverage, and `datasignature`; append one line to the journal; print
the tidylog-style ledger (section 5).

Two earlier ideas were tested and discarded (evidence in
[RUNMODE_FINDINGS.md](proto/RUNMODE_FINDINGS.md)):

*Capturing merge's own result table through a nested named log* is out because
`texdoc` and `webdoc` open their own logs and Stata caps simultaneous logs at five;
a wrapper that opens a sixth breaks the report-writing tools this package is meant
to sit beside.

*Stripping `keep()` and applying the drop by hand* is out because it silently
changes the data's state. Content matched exactly — same `datasignature`, `cf _all`
clean, same variable order, `_merge` value label preserved — but the **sort flag
did not**: Stata sets it after a 1:1 merge that leaves no using-only observations,
and a manual `keep if` clears it. So `keep()` is passed through to the real `merge`
untouched and only `generate()` is substituted, which lets Stata set the flag
itself.

The subtler failure, and the one that actually broke the regression, is that
**instrumentation must not consume Stata's sort RNG**. With the data provably
identical at every step, the collapsed panel still differed: `cf` reported 56
mismatches in `wage` whose printed values were identical, meaning the means differed
in their last bits. `collapse` orders rows tied on its `by()` variables using the
sort RNG, floating-point addition is not associative, and so a different tie order
produces a different sum. Measurement confirmed that `merge` advances
`c(sortrngstate)` while `append`, `save`, and `collapse` do not — and that the
wrappers' own scratch merges and duplicate checks advanced it too, leaving the
instrumented session on a different tie-breaking sequence than the plain one.

Every helper that touches data therefore brackets its work: save `c(sortrngstate)`
and `c(rngstate)` on entry, restore them on every exit path including early ones.
The user's command may consume whatever it likes; the wrapper must consume nothing
observable. With that in place the regression passes 12 of 12. Any helper added
later without the bracket will reintroduce last-bit drift that no amount of staring
at the merge logic will explain.

A related consequence for testing: `.dta` files carry a minute-resolution timestamp
in their header, so byte-comparing them is not a valid transparency check. The
regression compares `datasignature`, `cf _all`, `: sortedby`, and `describe`.

### 2.3 The journal

One plain-text file (`_mergemap.jrn`, tab-separated, one line per event), appended
with open-write-close per event so `clear all` cannot orphan a handle; the path lives
in a global. Fields: run id, do-file, original line, event type, full command text,
keys, declared cardinality, observed cardinality, master path+N+k, using path+N+k,
result N+k, `_merge` counts (1–5), duplicates-on-key counts (each side), options
(nogen/keep/assert/update/generate), datasignature/checksum, timestamp, error code.
`mergemap draw` parses the journal into a frame and renders. The journal is itself a
deliverable: `mergemap list` prints it as a table; `mergemap export` can emit it as
.dta/.csv for the user's own auditing.

Dataset identity across steps: a `save` event and a later `use`/`merge ... using`
event with the same expanded path (tempfiles included, since tempfile paths are
stable within a session) connect into one node. A path re-saved later becomes
version 2 of that node (datasignature distinguishes). A tempfile never seen in a
`save` is labeled "temp file (external)".

### 2.4 Render targets (all verified feasible, no new software)

1. **SMCL** (default): vertical boxes-and-arrows in the Results window using
   `{c TLC}{hline}...` glyphs; translates to clean ASCII in logs; node headers are
   clickable (`{stata "mergemap detail 3":...}`) to print that event's full ledger.
   SMCL is inherently width-limited (linesize), so SMCL is always vertical.
2. **HTML with inline SVG** via `file write`; opened with `view browse` in GUI Stata,
   `!open` fallback. Detail-on-demand via pure-HTML `<details>` blocks (no JS, no
   CDN). This is the "more detailed features kick to HTML" tier: when the user asks
   for options SMCL cannot honor (horizontal layout beyond linesize, per-node
   variable lists, many nodes), mergemap says so and writes HTML.
3. **PNG/SVG/PDF via `twoway`** (`pci` boxes + `pcarrowi` arrows + `text()` labels,
   `graph export`): a native-graph diagram for slides and Word. Good to roughly a
   dozen nodes; beyond that, mergemap recommends the HTML/SVG writer (which has no
   node limit).
4. **Mermaid and DOT text export**: nearly free from the journal, and the highest
   interop value (paste into GitHub/Quarto). Also a plain-markdown table export.

## 3. Command design

One command, subcommand style:

```
mergemap scan  01_clean.do 02_merge.do 03_analyze.do [, options]
mergemap scan, folder(build/)                  // *.do in name order
mergemap run   01_clean.do 02_merge.do [, options nochecks]
mergemap draw  [, layout(vertical|horizontal) export(smcl|html|png|svg|dot|mermaid)
                 saving(fn) replace compact noellipsis notransforms nokeys nocounts
                 details wrap(#) title(str)]
mergemap list  [, full]                        // journal as a table
mergemap detail #                              // one event's full ledger
mergemap sql   [merge|append|joinby|cross ...] // teaching mode, section 7
mergemap export [, format(dta|csv)]            // journal itself
mergemap clear
```

Option semantics (the user's list, plus additions):

- `compact`: one line per node, no obs/var counts inside boxes.
- `noellipsis`: show every loop iteration instead of the collapsed stack.
- `notransforms`: hide reshape/collapse/contract/xpose annotation nodes.
- `nokeys` / `nocounts`: strip key names / row counts from edges.
- `layout(vertical)` default (documents); `layout(horizontal)` for slides (HTML,
  twoway, mermaid/dot only; SMCL refuses politely).
- `details`: per-node variable lists and full diagnostics (HTML `<details>`, or
  appended ledger in SMCL).
- `wrap(#)`: node-label wrap width; long paths get middle-ellipsis truncation.
- `maxnodes(#)`: SMCL auto-escalation threshold (default 8 join+transform events);
  past it, or on `layout(horizontal)`, mergemap prints the receipt + a notice and
  writes HTML instead; `forcesmcl` overrides.
- `noopen`: suppress the GUI auto-open of HTML output; a clickable
  `{browse "file:///…"}` link always prints in Results regardless.
- `examples(#)` (run mode): per join, list # sample rows showing key vars and
  `_merge` category only.

Decisions confirmed 2026-08-19 (see DECISIONS.md): scan is the default mode; Stata
16 floor; run-mode receipt adds obs counts; sxpose recognized and flagged as SSC;
teach mode deferred to v1.1; single muted-blue accent.
- Flags are text markers, not color: `!!` for observed-vs-declared cardinality
  mismatch, unexpected unmatched rows, `m:m` use, and assert() failures. One accent
  color allowed in HTML; the default is monochrome boxes and arrows per the brief.

## 4. Diagram conventions

Vertical layout: the master chain flows down a left spine; using files enter from the
right at each join node; saves branch off as sink boxes. Join type and keys label the
connector; the `_merge` breakdown sits under the join line; dropped categories are
parenthesized (tidylog convention); dashed connectors mark dropped/unmatched paths
and `fralias` view-links. SMCL mock (renders with line glyphs in the Results window):

```
  01_build.do ───────────────────────────────────────
  ┌───────────────────────────┐
  │ raw/cps_2019.dta          │  52,431 × 24
  └───────────────────────────┘
        │  append (×4: cps_2019 … cps_2022)          «loop collapsed»
        │  +157,203 obs from 3 files
        ▼
  ┌───────────────────────────┐    ┌──────────────────────────┐
  │ [pooled cps]              │    │ xwalk/county_key.dta     │
  │ 209,634 × 24              │    │ 254 × 3   key: county ✓  │
  └───────────────────────────┘    └──────────────────────────┘
        │                                   │
        │  merge m:1 county  ◄──────────────┘
        │  declared m:1, observed m:1
        │  matched 209,101 · master-only 533 · using-only (2 dropped)
        ▼
  ┌───────────────────────────┐
  │ collapse (mean) wage,     │   « transform: 209,634 → 3,048 rows »
  │ by(county year)           │
  └───────────────────────────┘
        │
        ▼
  ┌───────────────────────────┐
  │ built/county_panel.dta    │  3,048 × 6   [saved]
  └───────────────────────────┘
```

Horizontal layout mirrors this left-to-right with using files entering from the top
(HTML/twoway/mermaid only).

## 5. The per-event ledger (Results window, and `mergemap detail`)

Printed by `_mm_merge` as the pipeline runs, adapted from tidylog + dplyr grammar:

```
mergemap: merge m:1 county using xwalk/county_key.dta        (01_build.do line 44)
    key: county (str5)   declared m:1, observed m:1
    master 209,634 | using 254 | matched 209,101
    master-only 533 kept | using-only (2 dropped by keep(1 3))
```

and when something deserves a flag:

```
mergemap: !! observed cardinality m:m under declared merge 1:1 id
    3 duplicate values of id in master (e.g. id==10381, 4 obs)
    merge 1:1 would have failed; this ran under joinby — rows multiplied 4x
```

Concrete offending key values, per dplyr's convention, make flags actionable.

## 6. Loop and folder ellipsis

Runtime rule: consecutive journal events with an identical command template (same
command word, keys, options; only the filename token differs) collapse into one
stacked node labeled `×N files: first … last`, with summed row deltas. Static-scan
rule: a loop is already one template. `noellipsis` expands. Threshold: collapse at 3+
repeats; `mergemap draw, ellipsis(#)` to tune.

## 7. The learning-tool companion: `mergemap sql` and CONCEPTMAP.md

Two deliverables ride along. First, the concept map (drafted in
[CONCEPTMAP.md](CONCEPTMAP.md)): every Stata combining verb mapped to its SQL, dplyr,
and pandas equivalent, including the subtle ones (`keep(1)` = anti-join;
`merge m:m` = not a join at all, it pairs by row order within key; `joinby` = the
true many-to-many; `fralias` = a view; `update replace` = COALESCE/UPDATE-FROM;
`fillin` = cross join of key levels + left join back). This becomes a help-file
section and a chapter-ready table.

Second, `mergemap sql, type(left)` prints the jOOQ-style row-stack picture in SMCL
(two small stacks of keyed rows, the result stack with padded unmatched rows, the
size rule underneath) plus the equivalence line for that join. And the bridge
feature, which nothing surveyed does: `mergemap detail 3, teach` renders *that
captured merge* as a row-stack diagram using its actual counts, turning a real
pipeline step into the teaching picture.

## 8. What could break it (risk register)

1. **Dynamically built commands** (`` local c merge `` … `` `c' 1:1 ... ``) and
   user-written ados that call `merge` internally: invisible to the rewriter.
   Document as a limitation; a future `deep` option could add name-shadowing for
   these, accepting its fragility.
2. **Tokenizer traps**: `#delimit ;`, `///`, `/* */`, `merge` inside strings or
   comments, prefix chains (`cap noi qui merge`). Mitigation: real tokenizer in Mata
   plus a torture-test suite of nasty do-files; this is where the build effort
   concentrates.
3. **`clear all` / `discard` mid-pipeline**: solved structurally (ado wrappers on
   adopath, globals, per-event journal appends). Verified: globals and adopath
   survive `clear all`.
4. **Huge using files**: the duplicate-key pre-check loads key variables of the
   using file. `nochecks` skips it; `describe using` and `checksum` still give
   N/k/fingerprint without loading anything.
5. **Errors mid-pipeline**: the run stops as `do` would; the journal keeps everything
   up to the failure, and the diagram renders with an error marker on the last node.
   This turns a breakage into a feature ("where did it die").
6. **Tempfile labeling**: raw `/var/...` paths are meaningless; solved by linking
   save→use events by expanded path within the run.
7. **SMCL width**: long filenames and horizontal layouts overflow linesize; solved by
   wrap/truncation and by refusing horizontal in SMCL (pointing to HTML).
8. **twoway text sizing** at many nodes gets fussy; solved by capping the twoway
   renderer (~12 nodes) and routing bigger diagrams to the SVG writer.
9. **Semantics safety**: the wrappers must be provably transparent. Regression method
   (as in statplot): run a pipeline plain and under `mergemap run`, then
   `datasignature` and `cf` every saved output; assert byte-identical.
10. **Batch/console sessions**: no Viewer, `view browse` unavailable; everything
    falls back to files + `!open`, and SMCL output still logs as ASCII.

## 9. What we deliberately do NOT do

No Venn diagrams (except to explain why not, in the help file). No TikZ/LaTeX. No
Python/pystata (nothing in the design needs it; native graph + file write cover every
export). No live "join builder" interface. No icon language; no color-coded join
types; flags are text.

## 10. Package layout

```
mergemap/
  mergemap.ado          dispatcher + renderers (SMCL, twoway)
  _mm_scan.ado          static scanner (Mata core: lmergemap.mlib)
  _mm_run.ado           rewriter + executor
  _mm_merge.ado _mm_append.ado _mm_joinby.ado _mm_cross.ado
  _mm_use.ado _mm_save.ado _mm_import.ado _mm_export.ado
  _mm_frlink.ado _mm_frget.ado _mm_do.ado _mm_transform.ado
  _mm_html.ado          HTML/SVG writer     _mm_text.ado  mermaid/dot writer
  mergemap.sthlp        + mergemap_sql.sthlp (concept map)
  mergemap.pkg stata.toc README.md CHANGELOG.md
  mergemap_pkgtest.do   + tests/torture_*.do + tests/regress_transparency.do
```

## 11. Milestones

- **M1 — scan + SMCL + text exports.** Tokenizer, journal schema, `mergemap scan`,
  vertical SMCL renderer, mermaid/DOT export, `list`/`detail`. Immediately useful,
  zero execution risk.
- **M2 — instrumented run.** Rewriter, `_mm_*` wrappers, ledger output, diagnostics,
  transparency regression suite.
- **M3 — HTML/SVG + twoway PNG renderers**, ellipsis collapsing, horizontal layout,
  `!open`/`view browse` handling.
- **M4 — teach mode** (`mergemap sql`, `detail, teach`), help files, pkg/toc,
  torture tests, SSC-ready.

## 12. Name

`mergemap` (recommended: says what it does in Stata vocabulary), or `dtaflow`,
`joinviz`, `mergeviz`, `dataflow`, `linkmap` — all verified free at SSC (2026-08-19).
Existing diagram-adjacent packages (Naqvi's `sankey`/`arcplot`/`treemap`, Dodd's
TikZ-based `flowchart`, Corten's `netplot`) do not collide in name or function.
