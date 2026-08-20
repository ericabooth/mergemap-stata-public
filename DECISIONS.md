# mergemap: confirmed design decisions

Running log of decisions made with Eric. Newest last.

## 2026-08-19 (initial planning)

1. **Name**: `mergemap` (SSC-checked free).
2. **Default mode is scan**: bare `mergemap <do-files>` / `folder()` executes
   nothing and prints the receipt. `mergemap run` is the opt-in instrumented
   execution (source-to-source rewrite to `_mm_*` wrappers).
3. **Receipt** accompanies every diagram: # / file / line / command / subtype /
   keys / using / force? / flags. In run mode, add obs counts (n before, n using,
   n after). Scan-mode receipt keeps the same columns minus counts.
4. **Auto-escalation**: SMCL diagram is default up to `maxnodes(8)` join+transform
   events; beyond that, or when `layout(horizontal)` is requested, print receipt +
   notice and write HTML instead. Overrides: `maxnodes(#)`, `forcesmcl`.
5. **Loop handling**: static resolution of `forvalues`/literal `foreach`/numlists
   into one collapsed ellipsis node (×N: first … last). Runtime-built lists render
   as unresolved template stacks; `run` mode resolves everything. `noellipsis`
   expands.
6. **Intermediate steps**: every save/export/tempfile save-out is a marked sink box
   ([saved]/[tempfile]); tempfiles get provenance labels via save→use path linking.
   mergemap never ingests or alters use/save behavior in scan mode.
7. **No logs for capture**: wrappers never open logs (texdoc/webdoc/5-log-limit
   conflicts). `_mm_merge` strips `keep()`, counts `_merge` categories itself, then
   applies the drop; `assert()` passes through untouched. Compatibility scenario:
   run under an open user log + inside texdoc. Document: don't nest `mergemap run`
   inside `webdoc do`.
8. **Opening HTML**: print a clickable `{browse "file:///…":Open diagram}` link in
   Results; ALSO auto-open at end (GUI sessions only, never batch/console) unless
   `noopen`. Shell fallback (`!open` / `winexec cmd /c start` / `xdg-open` by
   `c(os)`) only where `{browse}`/GUI unavailable.
9. **`examples(#)`** (run mode): per join, `list` a few sample rows showing key
   vars + `_merge` category only — never full rows.
10. **Version floor: Stata 16** (frames). Avoid StataNow-only syntax; dev/test on
    StataNow 19.5 MP.
11. **sxpose**: recognized if seen; flag it as an SSC dependency in receipt/flags.
12. **Teach mode** (`mergemap sql`, jOOQ row stacks): deferred to v1.1. Concept map
    ships in the help file from v1.
13. **Color**: monochrome boxes/arrows; ONE accent, muted blue, for flags/arrowheads
    in HTML/PNG. No icons, no emoji. Venn diagrams never.
14. **Exports**: smcl (default), html (inline SVG, self-contained, no JS/CDN),
    png/svg via twoway (cap ~12 nodes), mermaid/.mmd + .md, dot. Mermaid/DOT need
    zero installs; rendering paths documented in help (GitHub/Quarto/VS Code/
    mermaid.live; Graphviz optional).
15. **Test data**: synthetic/system datasets only for now; no real pipeline target
    yet.

## 2026-08-19 (competing-software pass)

Research swept lineage tools (OpenLineage/dbt/Dagster/DataHub), data-quality
reporting (pointblank/Soda/Great Expectations/pandera), diagram-as-code
(mermaid/D2/Graphviz), report embedding (Quarto), and — most importantly — the
Stata package universe. Result: **no existing Stata package does what mergemap
does**, so the design stands. Decisions follow.

### 16. Adopted now (cheap, high value)

16a. **Track row filters as events.** `keep if`, `drop if`, and `drop`/`keep` of
     variables join the event vocabulary, reported tidylog-style: `removed 21
     rows (66%), 11 remaining`. Rationale: the plan tracked joins and reshapes
     but not filters, and filters are where most row loss actually happens. A
     pipeline diagram that omits them misattributes attrition to the merges.
     Side benefit: this brings mergemap within reach of a sample-attrition
     figure, the use case `flowchart` (SSC, TikZ-based) currently owns.
16b. **Severity tiers replace the single `!!`.** `warn()`/`stop()` accept a count
     or a 0-1 fraction (pointblank's `action_levels` pattern). 2% unmatched is a
     note; 40% is a crisis; one glyph cannot say which. `stop()` breaches also
     give mergemap a nonzero return code, which makes it usable in a master
     do-file as a gate.
16c. **Key type-drift check.** Compare each key's storage type across master and
     using and report `id: str6 vs long`. Near-free: `describe using` already
     supplies types without loading the file. This is the classic silent Stata
     merge failure.
16d. **Headline summary line + `r()` scalars.** `3 of 9 joins flagged. 1 stop, 2
     warn.` or `All 9 joins clean.` Plus `r(N_flags)`, `r(N_stop)`,
     `r(success_percent)`. One actionable line before the receipt.
16e. **Coverage percentages, not just counts.** Report match rate as a share of
     master keys matched and of using keys used: "94% of master matched, 61% of
     the crosswalk never used." Counts do not scale-normalize; shares do.
16f. **Clobber and staleness warnings.** Flag when two do-files `save` the same
     path (label writes CREATE vs OVERWRITE), and flag a saved output whose file
     date predates an input's or its producing do-file's. Both are pure
     filesystem checks that work in scan mode. mergemap *reports* staleness and
     never acts on it: rebuild orchestration belongs to `project` (Picard).
16g. **Provenance footer on every export.** Timestamp, Stata version and flavor,
     and the project's git branch/commit if there is one. Turns an exported
     figure into an auditable artifact rather than an undated picture.
16h. **Top-k unmatched keys with frequencies** (run mode), complementing
     `examples(#)`: shows whether 500 unmatched rows are 500 distinct keys or
     one key repeated 500 times.
16i. **Mermaid theming and accessibility instead of click-links.** Emit
     `%%{init: {'theme':'base','themeVariables':{...}}}%%`, `classDef`,
     `accTitle:`, and `accDescr{}`. These survive GitHub's renderer; see 18a.
16j. **`erDiagram` as a second mermaid export.** Mermaid's native cardinality
     glyphs (`||--o{` and friends) map more closely onto `1:1`/`m:1`/`1:m` than
     flowchart edge labels do.
16k. **SVG `<title>` tooltips plus overflow and print CSS.** Detail on demand
     with no JavaScript. The embedding CSS pattern is settled:
     `.mm-wrap { max-height: 32rem; overflow: auto; resize: vertical }` with the
     SVG carrying `viewBox` and no fixed width/height, and a print media query
     that removes the cap. Needed because `width:100%; height:auto` makes a tall
     diagram *taller* as the page widens.

### 17. Adopted later (v1.1+)

Structured-comment expectations (`*! mergemap: expect matchrate>=.95`, following
DIME's `iedropone`); variable-origin labels (which file introduced each
variable — `merge` and `frget` hand this over almost free); variable-list diffs
on each edge (`+12 vars from using`, `id: str6->long`); graph selectors
(`select(+built/panel.dta)`, dbt-style); terminal consumers so `graph export`
and `putexcel` outputs end the DAG; a `from`/`to`/`value` export feeding Naqvi's
SSC `sankey`; a long-format check ledger (one row per check, so users can filter
it themselves); node descriptions harvested from `* mergemap:` comments.

### 18. Rejected, with reasons

18a. **Mermaid `click ... href` deep-links to do-file lines.** GitHub renders
     mermaid inside an iframe under a `frame-src` CSP, so `click` is blocked
     there. It would be a headline feature that silently dies in the venue the
     mermaid export exists to serve. SMCL `{stata}`/`{view}` links already work
     in Stata, and SVG `<title>` tooltips cover HTML. (Also: GitHub's mermaid is
     pinned near 10.0.2, so avoid newer syntax and keep `-beta` suffixes.)
18b. **Auto-generated English prose summarizing the pipeline.** No surveyed tool
     does this deterministically; every one of them uses text a person wrote, or
     text a generator wrote for a person to edit. A
     template paragraph either restates the receipt at greater length or needs
     so much hedging it says nothing. Harvest user-written comments instead.
18c. **Any build-system behavior** (re-running stale steps, caching,
     dependency-driven execution). `project` owns this in Stata. Being correct
     about when *not* to run something is a harder problem than being
     transparent about what ran.
18d. **Full column-level lineage.** Would require tracking generate/replace/egen/
     rename/recode through macro-built names, and would produce exactly the
     per-column spaghetti the visual brief rules out. Take the cheap 80% instead
     (variable-origin labels, 17).
18e. **Per-variable profiling** (distributions, correlations, alert taxonomies).
     Scope creep away from joins; duplicates `codebook`, `mdesc`, `distinct`.

### 19. Neighbors to cite rather than compete with

- **`precombine`** (Chatfield, *Stata Journal* 15(3), cited in `[D] merge`) is the
  closest functional neighbor: a pre-flight comparison of files you are about to
  combine, including value-label code-set agreement. mergemap is post-hoc and
  pipeline-wide. Recommend `precombine` in the help file for the pre-flight case
  and do not re-implement its label comparison.
- **`project`** (Picard) is the build system; mergemap reports staleness only.
- **`vmerge`** (Canner) prints a per-variable update/replace summary for one
  merge; mergemap's `update replace` ledger should be at least as informative.
- **`mmerge`, `dmerge`, `mergeall`, `pullin`** replace or wrap `merge`. mergemap
  must never shadow them, and the help file should say plainly that joins
  performed inside such wrappers are invisible to the scanner.
- **`iedropone`** (DIME ietoolkit) asserts an exact dropped-observation count;
  prior art for the expectations feature in 17.
- **`flowchart`** (Dodd) draws CONSORT/PRISMA participant-disposition diagrams
  via TikZ. Different domain and needs LaTeX; state the boundary in the help.
- **`sankey`** (Naqvi) consumes `from`/`to`/`value` data; complement, not rival.
- **`cfout`/`cf2`** are the right tools for the run-mode transparency regression.

## 2026-08-19 (webdoc2 embedding pass)

Tested by building real webdoc2 reports that embed mergemap output four ways (PNG
via `wdimg`, iframe via `wdiframe`, inline SVG injected into the page body, and
`<pre>` text), plus a deliberate collision page. Full recipe and screenshots:
`tests/webdoc/WEBDOC2.md`.

### 20. What the test settled

20a. **Inline SVG fragment is the recommended default** for embedding in webdoc2.
     It flows with the page, prints, and needs no height guessing. The iframe is
     the fallback for very tall diagrams.
20b. **Stata's own SVG export already carries a `viewBox`** (checked on 19.5:
     `width="5.570in" height="20.000in" viewBox="0 0 4010 14400"`). The earlier
     worry was wrong. The actual problem is the **inch units**: dropping both
     `width` and `height` while keeping `viewBox` scales correctly (measured
     895x3214, aspect preserved, ~19px effective text).
20c. **CSS class names do not collide.** All 2,654 readable rules were walked
     (Bootstrap 5.3.2 = 1,297, webdoc2 theme = 52): zero matches against any
     mergemap class. The damage comes from somewhere else, so the `mm-` prefix is
     good hygiene rather than the fix.
20d. **Element selectors are what break the host page.** mergemap's
     `body{max-width:920px;margin:24px}` capped the whole report at 920px inside a
     1265px viewport, and its `h1`/`h2` rules shrank the report's headings from
     29.6px to 19px and 21.6px to 15px. In embed mode mergemap must never emit
     `body`, `h1`, `h2`, `details`, `summary`, `pre`, or bare `svg` selectors.
20e. **Duplicate SVG ids are a live bug, not a theoretical one.** Every mergemap
     HTML file uses the same arrowhead marker ids (`ag`, `aa`); with two diagrams
     on one page, recolouring the first diagram's `#ag` changed the *second*
     diagram's arrowheads. Ids must be namespaced per diagram (`mm1-ag`).
20f. **`wdiframe`'s `height()` writes an HTML attribute**, so CSS units are
     silently dropped and the frame collapses to the 150px default. A `class()`
     plus a stylesheet rule works (measured 702px for `78vh`). There is no
     pure-CSS auto-height for an iframe, and at `file://` the iframe's
     `contentDocument` is `null`, so the JavaScript auto-height trick is
     unavailable in the double-click case. This is why 20a prefers inline SVG.
20g. **`<details>` works unmodified** inside Bootstrap 5 and webdoc2, with no
     JavaScript. Keep it.
20h. **Horizontal layout needs a sideways scroller.** Stretched to a text column
     the 6802x439 horizontal diagram rendered at 928x60 with 1.4-1.8px text.
     Keeping native width inside `overflow-x:auto` preserves 13px text.
20i. **`wdimg`/`wdiframe` link files, they do not copy them**, so exported
     diagrams must live where the report can reach them.

### 21. mergemap-side changes this requires

An `embed` option that emits a fragment rather than a page: a scoped `<style>`, a
`<div class="mm-embed">` wrapper, and an `<svg>` carrying `viewBox` with no
`width`/`height`; every class prefixed `mm-`; every id namespaced per diagram; no
element selectors; presentation attributes emitted on shapes so the fragment
degrades legibly if its stylesheet is stripped; `overflow-x:auto` by default on
horizontal layouts. The help file documents the `wdiframe` `class()` trick and
notes that `height()` cannot take `vh`.

Also confirmed for the help file's rendering section: webdoc2 emits a bare `<body>`
with no `.container`, so text runs edge-to-edge unless the author supplies a
wrapper, and `header.html` is an ancillary file that `net install` does not place.
