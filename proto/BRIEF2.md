# mergemap round 2 build brief

BASE = the repository root. All paths below are relative to it.

Read first: `proto/JOURNAL_SCHEMA.md` (**v2, 34 columns — the contract changed**),
`DECISIONS.md`, `NOVICE_UX.md`, `PLAN.md` §3-§7. The v2 contract journals
`proto/journal_run.tsv` and `proto/journal_scan.tsv` are READ-ONLY and already
regenerated; build against them.

## What changed in the contract since round 1

- Column 9 renamed `using` → **`usingfile`** (`using` is a reserved word, so
  `import delimited` silently produced `v9` and `levelsof using` died r(100)).
  Delete any positional workaround and read it by name.
- Five new columns: **severity** (`note|warn|stop`), **keytypes**
  (`id: str6 vs long`), **cover_master**, **cover_using** (percentages),
  **lifecycle** (`create|overwrite|read`). All before `flags`, which stays last.
- New event class **`filter`** for `keep if` / `drop if` / `drop` / `keep`.
  `opts` holds the condition; `flags` holds the tidylog phrasing
  (`removed 6,519 rows (3.1%), 203,115 remaining`).
- Accent colour is **`#4a6d8c`** (RGB `74 109 140`) everywhere. Default SMCL style
  is **boxes** (confirmed by the user); `rail` is the compact alternative.

## Common constraints (every agent)

- Stata headless: `cd <yourdir> && /usr/local/bin/stata-mp -b do <file>.do`; the
  `.log` lands in the cwd. **Batch exit status is unreliable — grep the log for
  `^r([0-9]`.** An `.ado` in the cwd is found automatically.
- Target **Stata 16** syntax (frames OK). Machine is StataNow 19.5 MP.
- **Attribution rule (hard):** the only author this package ever names is `Eric Booth`.
  No tool, vendor, or assistant is credited in any file, comment, header, or commit.
- Visual style: boxes and arrows only. No icons, no emoji. Greyscale plus the one
  accent. Vertical default; horizontal is a variant.
- Scan mode is the default product: every renderer must look right with all counts
  `.`. Test against BOTH contract journals.
- **Severity is never colour-only.** `warn` and `stop` both print `!!`.
- **Work ONLY in the files your section names.** Another agent owns every other
  file. Do not edit `proto/journal_*.tsv` or `proto/JOURNAL_SCHEMA.md`.
- Verify your own work by running Stata and inspecting output; report evidence.

### Known Stata traps (do not rediscover these)

- A `` `=char(96)' `` written inside a quoted string is **re-scanned** by the macro
  expander, so `` `hold' `` collapses to empty. Build such fixtures with
  `file write fh "save " _char(96) "hold" _char(39) _n`.
- `args a b` splits a parenthesized expression across arguments.
- A literal `|` inside a SMCL `{synopt}` breaks rendering — use `{c |}`.
- An unclosed `{p}` or `{synopt}` silently swallows every following directive.
- `help` is ignored in batch; validate `.sthlp` with
  `translate "x.sthlp" "x.txt", translator(smcl2txt) replace`.
- Compound quotes `` `"..."' `` in scanned text need the char(3) placeholder that
  `mergemap.ado` already applies — do not remove it.

---

## Agent A — scanner, receipt, demo, beginner gaps

**Owns:** `src/mergemap.ado`, `src/dev/*`, `tests/scenarios/s21_filters.do`,
`tests/pipeline/*.do`, `tests/runall.do`. Nothing else.

1. **Emit the v2 journal**: rename the header `using` → `usingfile`; add the five
   new columns in schema order; fill `severity` (`warn` for m:m, force, duplicates
   dropped, update-replace; `stop` reserved for run mode; `note` otherwise) and
   `lifecycle` (`read` on use/import, `create` on first save of a path, `overwrite`
   when a path is saved again anywhere in the scanned set). Leave `keytypes`,
   `cover_master`, `cover_using` as `.` in scan mode.
2. **New `filter` events**: recognise `keep if`, `drop if`, and variable-list
   `keep`/`drop`. Record the condition in `opts`. Scan mode cannot know row counts,
   so `flags` stays `.`; run mode fills it.
3. **Clobber + staleness (DECISIONS 16f)**: flag when two do-files save the same
   path (`!! also saved by 02_panel.do line 26`), and flag a saved output whose
   file mtime predates an input's or its producing do-file's. Both are pure
   filesystem checks. Report only, never rebuild.
4. **Beginner gaps** (NOVICE_UX B2-B9), all with tests:
   - wildcards: `mergemap *.do`, `mergemap 0*.do` — expand via the `dir` extended
     macro function, sort by name;
   - a folder positionally: `mergemap build/` and `mergemap .` — detect a directory,
     expand to its `.do` files in name order, and say so in one line;
   - implement `folder(path)` as documented;
   - forgive a missing `.do` extension (append and retry before erroring);
   - bare call: print a short usage hint pointing at `help mergemap` and
     `mergemap demo`, not Stata's generic syntax error;
   - typo: on a not-found file, list near-misses from the same directory
     ("did you mean 01_build.do?"). A simple prefix/edit-distance-1 match is fine;
   - flag an unresolved macro in a path as a designed boundary
     ("path built from a macro; run mode resolves it"), not silent;
   - track `cd` with a literal argument so later relative paths resolve against it;
     flag `cd` with a macro argument as unresolvable.
5. **`mergemap demo`** (NOVICE_UX C1): create a folder (default `mergemap_demo/`,
   refuse politely if it exists unless `replace`), write three small do-files built
   **only from `sysuse auto` / `sysuse census`** so nothing is downloaded, scan
   them, and show receipt + diagram. The generated do-files must themselves be a
   worked example: a 1:1 merge, an m:1 lookup, an append, a collapse, a `drop if`,
   and one deliberate `m:m` so a flag appears. They must actually run.
6. **Receipt overhaul** (reviewer findings):
   - adopt the *lighter aligned* layout (the one `rendersmcl` used), not the
     pipe-ruled table; there must be exactly ONE receipt style in the package;
   - stop truncating flag text mid-word — flags are the most useful column; give
     them the leftover width and wrap onto a continuation line when needed;
   - truncate a filename only when the column genuinely overflows (`03_analyze.do`
     must not become `03_an...e.do` when there is room);
   - add obs-count columns in run mode (n before → n after), absent in scan mode;
   - add a **headline line** before the receipt (DECISIONS 16d):
     `3 of 9 joins flagged: 1 stop, 2 warn.` or `All 9 joins clean.`
   - `mergemap check` prints ONLY flagged events.
7. **`r()` returns**: `r(N_events)`, `r(N_joins)`, `r(N_flags)`, `r(N_stop)`,
   `r(journal)`, `r(files)`.
8. **Dispatch `mergemap run`** to `_mm_run` (Agent F owns that file). Exact
   interface, do not deviate: `_mm_run `"`files'"', out(`"`out'"') `runopts'`.
   Do not implement run mode yourself; if `_mm_run.ado` is missing, fail with a
   clear message.
9. **Test fixtures**: add `tests/scenarios/s21_filters.do` (keep if / drop if /
   drop varlist), add a `drop if` to `tests/pipeline/01_build.do` and a `keep if`
   to `03_analyze.do` so the pipeline exercises filters, and extend
   `tests/runall.do`. Keep every scenario runnable.
10. Re-run `src/runtests.do` and `tests/runall.do` until clean.

## Agent B — SMCL renderer

**Owns:** `proto/render_smcl/*`.

Update `rendersmcl.ado` for the v2 schema (`usingfile`, severity, filter events,
keytypes/coverage when present). Fix the reviewer's `rail` defects: the chain break
between do-files is invisible, and a line is duplicated when `opts` and `flags`
carry the same text (`update replace` printed twice). Keep **boxes as the default
style**. Render filter events as slim spine nodes showing condition and row change.
Show coverage percentages when present. Regenerate every `.smcl`/`.txt` gallery
output for both contract journals, both styles, at linesize 80 and 120. The
receipt now lives in `mergemap.ado` (Agent A) — **remove any receipt rendering from
this file** and leave a comment saying where it went.

## Agent C — HTML renderer and embed mode

**Owns:** `proto/render_html/*`.

1. v2 schema support (as B), including filter nodes and coverage.
2. **`embed` option** (DECISIONS 21, `tests/webdoc/WEBDOC2.md`): emit a fragment,
   not a page — scoped `<style>`, `<div class="mm-embed">`, `<svg>` with `viewBox`
   and **no** `width`/`height`. Prefix every class `mm-`. Namespace every id per
   diagram (`mm1-arrow`), because two diagrams on one page currently share
   arrowhead ids and recolouring the first changed the second. Emit **no element
   selectors** (`body`, `h1`, `h2`, `pre`, `details`, bare `svg`) in embed mode —
   those restyled the host report in testing. Emit presentation attributes on
   shapes so the fragment degrades legibly without its stylesheet.
3. **SVG `<title>` tooltips** per node (DECISIONS 16k): key, counts, coverage,
   flags. No JavaScript.
4. **Overflow and print CSS**: `.mm-wrap{max-height:32rem;overflow:auto;resize:
   vertical}` plus a print media query removing the cap; horizontal layouts keep
   natural width inside `overflow-x:auto` (squeezed into a column their labels fell
   below 2px).
5. **Provenance footer** (16g): timestamp, Stata version and flavour, git
   branch/commit of the project directory if there is one.
6. Regenerate the gallery HTML variants plus a new `html_embed_fragment.html`
   demonstrating the fragment inside a mock host page with its own `h1`/`body`
   rules — prove the host is not restyled. Validate everything with `xmllint`.

## Agent D — twoway renderer

**Owns:** `proto/render_twoway/*`.

v2 schema support including filter nodes. Add **`page(dofile|none)`**: with
`page(dofile)` export one image per do-file (`stub_01_build.png`, ...) so a printed
page is usable — the current vertical diagram is a single 1600x5745 image. Keep the
accent as the RGB triplet `74 109 140` (already fixed; do not reintroduce `navy`).
Add the provenance footer as a small caption. Regenerate all gallery PNG/SVG
outputs, **view the PNGs yourself with the Read tool**, and iterate until boxes do
not overlap, text fits, arrows meet box edges, and nothing is clipped.

## Agent E — mermaid and DOT renderer

**Owns:** `proto/render_text/*`.

1. v2 schema support including filter nodes.
2. **Mermaid theming and accessibility** (16i): emit
   `%%{init: {'theme':'base','themeVariables':{...}}}%%` carrying `#4a6d8c`, plus
   `classDef`, `accTitle:`, and `accDescr{}`. **Do not emit `click ... href`** —
   GitHub renders mermaid under a frame CSP that blocks it (DECISIONS 18a). Keep to
   syntax that renders on GitHub's pinned ~10.0.2: no `block-beta`, keep `-beta`
   suffixes where required.
3. **`erDiagram` export** (16j): a second mermaid flavour where keys are attributes
   and Stata cardinality maps onto mermaid glyphs (`||--o{` and friends).
4. Provenance comment line in every emitted file.
5. Regenerate all `.mmd`/`.md`/`.dot` outputs for both journals, and update
   `RENDERING.md` for the new exports.
6. Keep `mmsql.do` (teach-mode prototype) working; it stays a prototype.

## Agent F — run mode

**Owns:** `src/_mm_run.ado` and `src/_mm_*.ado` (all NEW files), plus
`tests/runmode/*` (new directory). **Do not edit `src/mergemap.ado`** — Agent A
dispatches to you with exactly:
`_mm_run `"`files'"', out(`"`out'"') [examples(#) nochecks warn(#) stop(#)]`.

Implement PLAN §2.2:

1. **Rewriter.** Do not re-implement the tokenizer. Call the scanner first
   (`mergemap scan ... , out(<temp>) noreceipt`) to get every (dofile, line, cmd)
   triple, then rewrite exactly those lines in a temporary copy of each do-file,
   replacing the *command-word token* in place — preserving prefixes
   (`capture noisily merge` → `capture noisily _mm_merge`) and preserving line
   numbers exactly. Recurse into `do`/`run` of literal filenames. If a do-file
   contains a `#delimit ;` region, do not instrument inside it: warn once and leave
   those lines alone.
2. **Wrappers**, one file each: `_mm_merge` `_mm_append` `_mm_joinby` `_mm_cross`
   `_mm_use` `_mm_save` `_mm_import` `_mm_export` `_mm_frlink` `_mm_frget`
   `_mm_do` `_mm_keepif` `_mm_dropif` and a shared `_mm_post.ado` that appends one
   journal line (open-write-close per event so `clear all` cannot orphan a handle).
3. **No logs anywhere.** `texdoc`/`webdoc` open their own logs and Stata caps
   simultaneous logs at five. `_mm_merge` must instead: strip `keep()` from the
   user's options, always run the real merge with `generate(_mm_merge_tmp)`,
   tabulate that variable to get m1..m5, then apply the `keep()` drop itself, then
   either drop the temp variable (if the user said `nogenerate`) or rename it to
   `_merge` / their `generate()` name. Pass `assert()` through untouched so Stata's
   own error behaviour is preserved. Never alter `keepusing()`, `update`,
   `replace`, `sorted`, or `force`.
4. **Diagnostics**: `describe using` for the using file's N/k and key storage types
   (fills `keytypes`); key variables into a scratch frame for duplicate counts
   (`nochecks` skips this); coverage percentages (`cover_master`, `cover_using`);
   `severity` from `warn()`/`stop()` thresholds accepting a count or a 0-1 fraction
   (DECISIONS 16b), defaulting to `warn(.05)` unmatched; a `stop` breach makes
   `mergemap run` exit nonzero.
5. **`examples(#)`**: list # sample rows per join showing key variables and the
   `_merge` category only — never full rows.
6. **Top-k unmatched keys** (16h): the most frequent unmatched key values with
   counts, so the user can tell 500 distinct keys from one key repeated 500 times.
7. **The tidylog ledger** printed per join as it runs (PLAN §5).
8. **Transparency regression — the most important test.** `tests/runmode/`:
   run `tests/pipeline/00_master.do` plainly, save every output; run it again under
   `mergemap run`; assert every saved dataset is byte-identical using
   `datasignature` and `cf _all`. If they differ, run mode is wrong. Also assert
   line numbers in the journal match the original files, and that a deliberate
   error mid-pipeline leaves a usable partial journal.
9. Test `mergemap run` **with a user log already open** and confirm no log
   conflict, since that was the original reason for the no-logs design.

---

## Integration (after A-F)

**Owns:** `gallery/*`, `tests/mergemap_pkgtest.do`, `README.md`.

Regenerate every journal from the real scenarios, run every renderer over both
contract journals and the scanner-emitted pipeline journal, rebuild
`gallery/gallery.html` (self-contained, base64 PNGs, no scripts, no external refs),
and add sections for the new material: filter events, embed fragment, per-do-file
paging, erDiagram, `mergemap demo` output, the new receipt, and run mode. Extend
`tests/mergemap_pkgtest.do` with blocks covering every beginner gap (they should
now PASS, not OPEN), demo, filters, clobber/staleness, the v2 schema, embed-mode
scoping, and run-mode transparency. `gallery/runall.do` must work from a clean
checkout (it needs its own `capture mkdir journals`). Patch other agents' files
where needed and record every patch.

## Critics

**R1 readability**: judge every gallery output against the brief. View PNGs. Rank
targets for documents / slides / console. Check the new receipt is scannable and
that flags are never cut mid-word. Confirm scan mode still reads well with no
counts. Do not edit files.

**R2 technical**: clean-state re-runs of `tests/runall.do`, `gallery/runall.do`,
`tests/mergemap_pkgtest.do`, and the run-mode transparency suite. `xmllint` every
SVG/HTML. Grep the whole BASE for any authorship credit other than Eric Booth. Verify the embed fragment
does not restyle a host page (build a host page with its own `body`/`h1` rules and
measure). Verify no renderer reads column 9 positionally any more. Portability scan
(absolute paths in emitted artifacts, shell usage, backslashes). Do not edit files;
report.
