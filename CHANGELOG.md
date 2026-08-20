# Changelog

All notable changes to mergemap. Dates are the day the work landed locally.

## 0.3.1 — 2026-08-20

The subcommand set is complete: nothing in the help file is a promise any more.

### Added

- **`mergemap list`** — the journal as a table: one line per event with the
  counts run mode fills, and `full` for every column when auditing the record.
- **`mergemap detail #`** — everything the journal knows about one event, as a
  ledger. **`detail #, teach`** is the bridge the teach mode was built toward:
  the event is drawn as a row-pairing picture with the toy rows replaced by its
  observed counts, so the teaching picture and your own pipeline become the same
  picture. Categories a `keep()` dropped are parenthesized so the box's
  arithmetic agrees with the result count it sits under. A scanned event has no
  counts, so teach falls back to the generic picture for its form and says why.
- **`mergemap export`** — the journal as a `.dta` or `.csv`, count and
  percentage columns arriving numeric. The record of your joins is data like any
  other: keep the flagged rows, append journals across runs, graph coverage.
- **`mergemap clear`** — forget the remembered journal and the scanner's session
  state. Journal files are never touched; deleting records is not this
  package's job.
- The battery grows to 66 checks.

### Removed

- The help file's "Not in this release" section, because there is nothing left
  to put in it.

## 0.3.0 — 2026-08-20

The release that draws.

### Added

- **`mergemap draw`.** The four renderers now ship, renamed `_mm_rendersmcl`,
  `_mm_renderhtml`, `_mm_rendertw`, and `_mm_rendertext` so nothing generic lands
  on the adopath, and dispatched through one subcommand. With no argument it
  draws the most recent journal — remembered across `clear all` and across
  sessions in the same directory — in the Results window when it fits.
  `export()` picks the medium: `smcl`, `html`, `png`, `svg`, `mermaid`, `dot`,
  or `erdiagram`.
- **Auto-escalation is now an action, not a notice.** Past `maxnodes()` events,
  or under `layout(horizontal)`, the SMCL renderer used to print advice; `draw`
  now writes the HTML page it was advising, prints a clickable link, and opens
  it in GUI sessions unless `noopen`. A PNG too dense for one readable image
  splits itself into one page per do-file.
- **`mergemap sql`** — teach mode, no longer a prototype. Alone it prints the
  Stata / SQL / dplyr / pandas translation table with each picture linked; with
  a form (`full`, `left`, `inner`, `fanout`, `joinby`, `append`, `cross`, `mm`)
  it draws that join as two small row stacks, the operator, and the result, with
  dropped rows in parentheses and the size rule underneath. A join is a
  cartesian product with a filter; the pictures show exactly the things the
  overlapping-circles diagram cannot, and they leave the data in memory
  untouched.
- The battery grows to 54 checks, including: draw renders every medium, the
  embed fragment carries no element selectors, a dense PNG pages itself, an
  unknown journal is refused with advice, and every sql picture prints without
  touching the loaded data.

### Changed

- The gallery's teach-mode section now captures the shipped `mergemap sql`
  rather than the prototype script.
- The help file's diagram material returns, documenting the shipped behavior:
  a "Drawing the map" section with the legend and the escalation rule, the
  "Putting a map in a document" section, draw examples, and `r(output)`.
  "Not in this release" shrinks to `list`, `detail`, `export`, and `clear`.
- `mergemap demo` finishes by drawing the example and printing the draw commands
  to try next.

## 0.2.0 — 2026-08-19

The round that made the package usable by someone who did not write it.

### Added

- **`mergemap demo`** — writes three small do-files built only from `sysuse auto`
  and `sysuse census`, scans them, and shows the output. Nothing to download and
  nothing to prepare, so a new user sees the tool work before pointing it at their
  own project. The generated do-files double as a worked example of the join
  vocabulary, including one deliberate `m:m` so a flag appears.
- **`mergemap check`** — prints only the flagged events. When a merge has gone
  wrong, a receipt of everything is noise.
- **Filter events.** `keep if`, `drop if`, and variable-list `keep`/`drop` are now
  part of the event vocabulary, reported as `removed 6,519 rows (3.1%), 203,115
  remaining`. Most row loss happens in a filter, not in a merge, so a diagram that
  drew only the joins was handing the blame to the wrong step.
- **Severity tiers.** `warn()` and `stop()` accept a count or a share; events sort
  into `note`, `warn`, and `stop`. A `stop` makes `mergemap run` exit with an
  error, so it can be used as a gate in a master do-file rather than only as a
  report. Severity is never encoded in colour alone.
- **Coverage percentages** alongside raw counts: what share of the master matched,
  and what share of the using file was ever used. A lookup table that goes mostly
  unused usually means the key is wrong.
- **Key type-drift check** (`id: str6 vs long`), read from `describe using` without
  loading the file. This is the quietest way a Stata merge fails.
- **Clobber and staleness warnings** — two do-files writing the same path, and a
  saved output older than its inputs. Reported, never acted on: rebuilding is
  `project`'s job.
- **Top-k unmatched keys**, so 500 unmatched rows across 500 keys can be told apart
  from one key repeated 500 times.
- **`embed` option** for HTML: a fragment to drop into another page rather than a
  standalone document.
- **`page(dofile)`** for PNG export: one image per do-file instead of one very tall
  one.
- **`erDiagram` mermaid export**, whose native cardinality glyphs fit Stata's
  `1:1`/`m:1`/`1:m` more closely than flowchart edge labels.
- **Mermaid theming and accessibility** (`accTitle`, `accDescr`, theme variables).
- **Provenance footer** on exports: timestamp, Stata version and flavour, and the
  project's git commit if there is one.
- **Run mode** (`mergemap run`): instrumented execution recording observed
  cardinality, duplicate keys, `_merge` breakdown, and coverage, with
  `examples(#)` listing sample rows by key and `_merge` category.
- Help file, and a regression battery in `tests/mergemap_pkgtest.do`.
- **Package files.** `mergemap.pkg` and `stata.toc`, so the command installs with
  `net install`. Verified into a sandboxed adopath: all 37 ado-files and the help
  file install, and the test battery stays ancillary as it should, since Stata
  decides that by file extension rather than by the letter on the line.
- **README.md**, with the receipt and the run-mode ledger shown rather than
  described.

### Changed

- **Beginner-facing invocation.** Wildcards (`mergemap *.do`), a folder passed
  positionally (`mergemap build/`), the documented `folder()` option, and a missing
  `.do` extension all work now; a bare call prints a usage hint instead of Stata's
  generic syntax error; a mistyped filename offers near-misses from the same
  directory.
- **One receipt, not two.** The lighter aligned layout replaced the pipe-ruled
  table. Flag text is no longer cut mid-word — flags are the most useful column and
  were the one being truncated — and a filename is shortened only when its column
  genuinely overflows.
- A headline line precedes the receipt: `3 of 9 joins flagged: 1 stop, 2 warn.`
- **The `rail` style's two defects are fixed.** A second chain inside one do-file
  was separated only by a blank line and read as a continuation of the first; it
  now carries a labelled half-width rule, against the full-width rule that opens a
  do-file, so the hierarchy is visible at a glance. And an option line that a flag
  already restated (`force` above `!! force used`) is now suppressed, but only when
  the flag genuinely covers it: `force keepusing(pay)` still prints, because the
  flag does not mention `keepusing`. `boxes`, the default, is byte-identical.
- The help file documents only what this release actually does. The options for
  drawing, exporting and embedding are described in one section as not yet
  available rather than listed as if they worked.
- The accent colour is one colour everywhere: `#4a6d8c`. It had drifted to three
  different blues across the renderers.
- Journal schema v2: 34 columns, with `severity`, `keytypes`, `cover_master`,
  `cover_using`, and `lifecycle` added.

### Fixed

- **Compound quotes crashed the scanner** (`r(132)`, "too few quotes"). The scanner
  protected backticks and dollar signs with placeholder characters but left the
  plain single quote alone, so a scanned line still contained `"'` — the closing
  delimiter of Stata's own compound quote — which terminated the scanner's wrapper
  early. Defensive `if `"`x'"' == ""` guards are common in careful code, so the
  scanner was failing on exactly the well-written do-files it most wants to read.
- **Journal column `using` renamed `usingfile`.** `using` is a reserved word, so
  reading the journal back with `import delimited` silently produced a positional
  variable and `levelsof using` failed with a bare `r(100)`.
- `gallery/runall.do` failed from a clean checkout because it never created its own
  `journals/` directory, and its relative adopath stopped resolving once a step
  changed directory, so run mode reported `_mm_run` as unrecognized.
- Emitted artifacts no longer carry this machine's absolute paths: `cd` echoes the
  directory it lands in, so the run-mode capture now changes directory outside the
  log rather than inside it.

### Notes for the next round

- `.dta` headers carry a minute-resolution timestamp, so byte-comparing them is not
  a valid transparency test; compare `datasignature`, `cf _all`, `: sortedby`, and
  `describe` instead.
- Run mode records rather than rewrites. An earlier design that stripped `keep()`
  and applied the drop by hand matched on content but silently cleared the sort
  flag. See `proto/RUNMODE_FINDINGS.md`.

## 0.1.0 — 2026-08-19

Prototype: static scanner, journal contract, and four renderers (SMCL, HTML with
inline SVG, native `twoway` graphs, mermaid/DOT), with a gallery assembling all of
them.
