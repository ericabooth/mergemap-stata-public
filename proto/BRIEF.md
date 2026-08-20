# mergemap prototype build brief

Base directory: the repository root (call it BASE). All paths below are relative to it.
Read `PLAN.md` sections 3–7 for diagram conventions and `proto/JOURNAL_SCHEMA.md`
for the journal contract before writing any code.

## Common constraints (every agent)

- **Stata**: run headless with `cd <yourdir> && /usr/local/bin/stata-mp -b do <file>.do`;
  the `.log` lands in the cwd. Batch exit status is unreliable: grep the log for
  `^r([0-9]` to detect errors. An `.ado` file sitting in the cwd is found
  automatically (`.` is on the adopath); do NOT install anything or touch sysdirs.
- **Compatibility**: target Stata 16+ syntax where feasible (frames OK). Machine has
  StataNow 19.5 MP.
- **Attribution rule (hard)**: the only author this package ever names is `Eric Booth`.
  No tool, vendor, or assistant is credited in any file header, comment, commit, or doc.
- **Visual style**: boxes + arrows/connectors only. No icons, no emoji in diagrams.
  Monochrome default; at most ONE accent color in HTML/PNG. Vertical layout is the
  default (documents); horizontal is a variant for slides.
- **Scan mode is the default product**: renderers must look good with all counts `.`
  (see schema). Test against BOTH `proto/journal_scan.tsv` and `proto/journal_run.tsv`.
- **SMCL auto-escalation**: default `maxnodes(8)` join+transform events for the SMCL
  diagram; beyond that (or if horizontal requested) print receipt + notice deferring
  to HTML; `maxnodes(#)`/`forcesmcl` override. Prototype this behavior where relevant.
- Work ONLY inside your assigned directory. Contract files are read-only.
- Prototypes read the journal with `import delimited ... , delimiter(tab) varnames(1)
  stringcols(_all)` into a frame; do not hand-parse TSV.
- Return a concise report: files written (paths), what you verified (evidence), open
  issues.

## Agent A — `tests/`: synthetic data + scenario do-files

Write `tests/maketestdata.do` (set seed 20260819) creating small (200–2,000 obs)
datasets in `tests/raw/`: `participants.dta` (pid, county, staff, x-vars; a few
duplicate pids), `visits.dta` (pid, visitid, date, svc; many per pid; some pids
absent), `county_key.dta` (county, cname, region; 2 counties not in participants),
`cps_2019.dta`..`cps_2022.dta` (same vars, one year has an extra var and one has a
str-vs-numeric type clash for append force), `staff_assign.dta` (staff m:m
assignments), `corrections.dta` (pid+visitid subset, some conflicting values for
update replace), `schedules.dta` (staff with duplicate keys + a str var that clashes
byte for merge force), `scores_wide.dta` (id, score2019–score2022 for reshape),
`counties_frame.dta` (county, povrate, slots).

Then standalone scenario do-files in `tests/scenarios/`, each self-contained (loads
from `../raw/`, writes only to `../out/`), each exercising exactly what its name says:
`s01_merge11.do` (clean 1:1), `s02_mergem1_keep.do` (m:1, keep(1 3), unmatched both
sides), `s03_merge1m.do` (fan-out), `s04_mergemm_force.do` (m:m + force — expect it
to run, flags are the scanner's job), `s05_update.do` (1:1 update replace with
conflicts), `s06_joinby.do` (unmatched(both)), `s07_cross.do`, `s08_append_gen.do`
(generate(src) + force for the type clash), `s09_append_loop.do` (foreach f in
explicit list of 4 files), `s10_merge_loop.do` (forvalues y=2019/2022 merging
``cps_`y'``), `s11_frames.do` (frame create + frlink m:1 + frget + fralias add),
`s12_collapse_merge.do`, `s13_reshape_merge.do` (long, merge, back to wide),
`s14_contract_merge.do`, `s15_xpose.do` (+ sxpose only if `which sxpose` succeeds,
else display a skip note), `s16_fillin_expand.do`, `s17_dups_isid.do` (duplicates
drop, isid, then 1:1), `s18_tempfile_chain.do` (tempfile save then merge using it),
`s19_preserve.do` (merge inside preserve/restore), `s20_nested_do.do` (calls a small
child do-file that itself merges).

Also `tests/pipeline/01_build.do`, `02_panel.do`, `03_analyze.do`, `00_master.do`
(runs all three): reproduce the story told by `proto/journal_run.tsv` (same commands,
same line spirit; counts need not match the sample journal exactly). Include the
tempfile hand-off between 02 and 03 via a global path or by re-saving to
`../out/` — note in comments which you chose and why (real tempfiles die between
batch sessions; the pipeline runs inside ONE Stata session via 00_master.do, so true
`tempfile` is fine there).

Write `tests/runall.do` that runs every scenario + the pipeline; run it headless;
fix until the log shows zero unexpected `r(#)` errors (s04/s05/s08 may legitimately
need `force`/options to run clean — they should run clean WITH them).

## Agent B — `src/`: scanner prototype (`mergemap.ado`)

Prototype `mergemap.ado` with syntax:
`mergemap <do-files> [, out(journal.tsv) receipt noreceipt]` — bare call = SCAN mode
(nothing executed). Also accept `mergemap scan ...` explicitly. Implement:

1. **Reader**: load each do-file; join `///` continuations; strip `//` and `/* */`
   comments; detect `#delimit ;` regions and, inside them, split on `;` (best
   effort — emit a class=note event `#delimit region: best-effort parse` so honesty
   is preserved); skip strings when scanning for command words.
2. **Recognizer**: peel prefix chains (`quietly/qui/n/noisily/capture/cap` and
   combinations); then match first token against: use (u|us|use), import, merge
   (mer|merg|merge), append (ap|app|appe|appen|append), joinby, cross, frlink, frget,
   fralias, collapse, contract, reshape, xpose, sxpose, fillin, expand, duplicates,
   isid, save (sa|sav|save), saveold, export, tempfile, preserve, restore, do, run.
3. **Extractor**: per command pull subtype (1:1 etc.), keys, using filename, force
   flag, relevant options (keep/assert/nogenerate/generate/update/replace/frame/i()/
   j()/by()). Track `tempfile` declarations so a later `` `name' `` in a using/save
   position becomes `tempfile:<name>`.
4. **Loop resolution** (static): `foreach x in <literal list>`, `foreach x of numlist`,
   `forvalues i=a/b` and `a(s)b` — enumerate; when a loop body contains exactly one
   recognized join/save whose filename varies by the loop var, emit ONE collapsed
   event with loop_n/loop_first/loop_last resolved. Runtime lists (`of local`,
   `` `r(files)' ``, dir-built) → loop_n=`.`, using=template, flag
   `unresolved runtime list`. Nested `do`/`run` of a literal filename: recurse.
5. **Journal writer**: TSV per schema (scan mode: counts `.`; statically-derivable
   flags only: force, m:m, update replace, keep() drop note, tempfile provenance).
6. **Receipt renderer** (SMCL, printed by default after scan):
   header `mergemap receipt: <files> (scan mode - nothing executed)`, then a
   `{c TLC}`-ruled table with columns: `#  file  line  command  subtype  keys  using
   force  flags`; `#` clickable via `{stata "mergemap detail <#>":<#>}` is OPTIONAL
   for the prototype (plain number fine); truncate long paths middle-ellipsis.

Write 4–6 mini test do-files in `src/dev/` covering the ugly constructs
(continuations, block comments, prefixes, both loop kinds, #delimit region, tempfile
chain, nested do), run mergemap over them headless, and iterate until the emitted
TSV is correct (assert with a checking do-file or python diff). Do NOT depend on
Agent A's files (integration runs those later). Mata is allowed but plain ado string
functions are fine for the prototype.

## Agent C1 — `proto/render_smcl/`: SMCL diagram renderer

`rendersmcl.ado`: `rendersmcl using <journal.tsv> [, style(boxes|rail) wrap(#)
maxnodes(#) forcesmcl compact nocounts nokeys notransforms noellipsis]`.
Two styles, both vertical:
(a) **boxes** — PLAN §4 mock: `{c TLC}{hline}{c TRC}` boxes on a left spine, using
files as boxes to the right of the join annotation, `{c |}`/arrowhead `v` connectors,
`_merge` breakdown under each join line, transforms as slim single-line boxes,
saves as boxes marked `[saved]`, tempfiles marked `[tempfile]`, loop stacks as a
double-topped box (`{c TT}` row) labeled `x3: first ... last`;
(b) **rail** — compact: no boxes; node names on a vertical rail of `{c |}` with
`{c LT}{hline 2}` tick connectors, one line per join with keys+counts, transforms
indented dim (`{txt}`).
Auto-escalation per Common constraints. Render BOTH sample journals in BOTH styles;
capture output via a named `log using` in the driver do-file to `.smcl`, then
`translate` to `.txt` (ASCII) for the gallery; keep both. Check alignment at
linesize 80 AND 120 (`set linesize`). Deliver: gallery-ready `.txt`/`.smcl` files
named `smcl_<style>_<scan|run>.txt` etc., plus the driver `demo.do`.

## Agent C2 — `proto/render_html/`: HTML + inline-SVG renderer

`renderhtml.ado`: `renderhtml using <journal.tsv>, saving(x.html) [layout(vertical|
horizontal) accent(hex) details replace]`. Self-contained HTML (inline CSS + inline
SVG; NO external assets, JS, or CDN; must open offline as file://). Boxes with the
dataset name as header; keys/counts on connector labels; `!!` flags as bold text
markers; per-join `<details>` block containing the full ledger (PLAN §5) —
pure-HTML expansion, no JS. Vertical AND horizontal variants; scan and run journals.
Use at most one accent color (suggest a muted blue) on flags/arrowheads; everything
else grayscale. Middle-ellipsis long labels; page must not scroll horizontally in
vertical mode (SVG width <= 900px). Validate with `xmllint --noout` (wrap the SVG
check by extracting it or make the whole file XHTML-clean). Deliver: 4 html files
(`html_vert_scan.html`, `html_vert_run.html`, `html_horiz_run.html`,
`html_vert_run_details.html`) + driver `demo.do`.

## Agent C3 — `proto/render_twoway/`: native-graph renderer

`rendertw.ado`: `rendertw using <journal.tsv>, saving(stub) [layout(vertical|
horizontal) maxnodes(#)]`. Build ONE `twoway` call: boxes from 4 `pci` segments
each (or `function`/`scatteri` tricks if cleaner), arrows via `pcarrowi`, labels via
added `text()`; `yscale(off) xscale(off) ylabel(none, nogrid) xlabel(none, nogrid)
legend(off) graphregion(color(white)) plotregion(margin(zero) style(none))
scheme(s1color)` — the user's default scheme must not leak grid lines. Monochrome:
black boxes/arrows, one accent for `!!` flag text. Export PNG (width 1600) and SVG.
Cap at 12 join+transform nodes with a clear error pointing to the HTML renderer.
Render the run journal vertical AND horizontal, and the scan journal vertical.
VERIFY VISUALLY: Read the exported PNGs yourself and iterate until boxes don't
overlap, text fits inside boxes, arrows connect box edges (not centers), and nothing
is clipped. This renderer is fiddly; budget your iterations for label sizing
(`text(..., size(vsmall) justification(left) placement(east))` etc.).
Deliver: `tw_vert_run.png/.svg`, `tw_horiz_run.png`, `tw_vert_scan.png` + `demo.do`.

## Agent C4 — `proto/render_text/`: mermaid/DOT exports + teach-mode prototype

1. `rendertext.ado`: emits from a journal (i) `mermaid` flowchart — vertical `TD` and
   horizontal `LR` variants, `subgraph` per do-file, edge labels `merge m:1 county |
   matched 209,101`, loop stacks as a single node `x3: cps_2020 ... cps_2022`,
   dashed edges for dropped/unmatched annotation, `!!` in node text for flags; write
   `.mmd` plus a fenced ` ```mermaid ` `.md`; (ii) DOT digraph equivalents (`.dot`),
   `rankdir=TB|LR`, `shape=box`. No color beyond one accent class. Verify mermaid
   syntax by eye against the mermaid flowchart grammar (no renderer installed —
   that's the point); keep node ids sanitized (no dots/slashes in ids, labels
   quoted).
2. **Teach-mode prototype** (PLAN §7): `mmsql.do` producing SMCL row-stack pictures
   for `merge m:1 ... keep(1 3)` (left join) and `merge m:m` (the warning case):
   two small key-labeled row stacks, the operator, the result stack with padded/
   dropped rows in parentheses, the size rule underneath, and the equivalence line
   (`SQL: LEFT JOIN ... USING(county)  |  dplyr: left_join  |  pandas: how="left"`).
   Capture to `.txt` via log+translate as in C1.
3. `RENDERING.md`: zero-install rendering paths for the text exports on macOS AND
   Windows (GitHub/Quarto/VS Code/mermaid.live for mermaid; Graphviz OPTIONAL,
   online viewers otherwise), plus the `!open` / `winexec cmd /c start` / `xdg-open`
   OS-switch pattern for opening HTML from Stata, keyed off `c(os)`.

## Integration agent — `gallery/`

Preconditions: A–C4 done. Steps:
1. Run B's scanner over `tests/pipeline/*.do` and scenarios s02, s04, s09, s10, s18,
   s20. Diff the emitted journal against expectations (schema conformance; loop
   collapsing on s09/s10; tempfile labeling on s18; recursion on s20). Patch `src/`
   as needed (you may edit src/ and proto/render_*/; record every patch).
2. Run ALL renderers over (i) the contract journals and (ii) the scanner-emitted
   pipeline journal. Collect outputs into `gallery/`.
3. Assemble `gallery/gallery.html`: single self-contained page (embed PNGs as base64
   data URIs via `base64` in bash; inline the receipt/SMCL `.txt` in `<pre>`; inline
   the SVGs; mermaid/DOT as code blocks with a note they render on GitHub/Quarto/
   mermaid.live; link the standalone HTML variants as relative links). Sections:
   1. Receipt, 2. SMCL boxes, 3. SMCL rail, 4. HTML/SVG, 5. twoway PNG, 6. mermaid/
   DOT, 7. teach mode; each shown in scan vs run mode where applicable; a short
   caption per section saying what to evaluate.
4. `gallery/runall.do` + `gallery/README.md` to regenerate everything.

## Critics

**R1 (readability)**: judge every gallery output against the brief: boxes/arrows
only, minimal color, vertical-first, readable at a glance, receipt scannable,
scan-mode (no counts) still informative, loop stacks obvious, flags impossible to
miss. View the PNGs (Read tool) and read the txt/html sources. Rank the SMCL styles
(boxes vs rail), rank overall targets for (a) documents (b) slides (c) quick console
check. List concrete, file-specific fixes. Do not edit files.

**R2 (technical)**: from a clean state, re-run `tests/runall.do` and
`gallery/runall.do`; report any error the logs show. `xmllint` every SVG/HTML.
Grep the whole BASE for any authorship credit other than Eric Booth
(case-insensitive) — report hits. Portability scan: hardcoded absolute paths inside
emitted diagram FILES (bad) vs in demo drivers (acceptable, flag anyway), shell
usage, backslashes, non-{c} unicode in SMCL output. Do not edit files; report.
