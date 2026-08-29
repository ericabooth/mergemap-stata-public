# Changelog

All notable changes to mergemap. Dates are the day the work landed locally.

## 0.5.3 — 2026-08-29

### Fixed

- **A scan no longer dies on a dataset whose header holds a macro-hostile
  byte.** The staleness check reads the `<timestamp>` element of each `.dta`
  a do-file saves or reads, and the header's binary fields (the observation
  count, the variable count, the label and timestamp lengths) can hold any
  byte. A file with, say, 2,400 observations (0x960) plants a literal
  backtick, and v0.5.2 accumulated the header into a macro one byte at a
  time, so the scan died with a bare `invalid syntax` (r 198) whenever a
  do-file's outputs already sat on disk. That broke the natural loop on its
  third step: scan, run, scan again. The header now travels through Mata
  (`_mm_hdrts`, end of `mergemap.ado`), where binary bytes are inert; only
  the cleaned timestamp text ever reaches a macro. See
  `BUGREPORT_scan_after_run.md` for the full diagnosis.
- **Long dataset labels no longer switch staleness checking off.** The
  header read grew from 220 to 512 bytes, which reaches the timestamp in
  every dta format that has one; a label longer than 71 characters used to
  push `</timestamp>` out of the window and the file's timestamp silently
  read as unknown.

### Added

- Regression cover: `tests/mergemap_pkgtest.do` block 20 runs the
  scan-run-scan loop over a 2,400-row fixture (backtick byte) and a
  2,338-row fixture (double-quote byte).

## 0.5.2 — 2026-08-23

### Changed

- **The help file and README assume a reader who has never seen the
  package.** The words the documentation depends on are defined before they
  are used: the receipt (the numbered table on screen), the journal (the
  same record as a tab-separated file that every later command reads back),
  and the map (the drawing). The syntax section now says, correctly, that
  files, folders, and patterns mix freely in one call and that `folder()`
  is the same thing written as an option. Mermaid and DOT are introduced as
  plain-text diagram languages rather than assumed. The section on
  `mergemap sql` explains what the subcommand is for and why it is named
  for SQL; the worked-example wording replaces "teach mode" throughout, and
  `mergemap detail #, draw` is the documented spelling of what was
  `detail #, teach` (`teach` still works). The `!! also saved by` flag's
  entry now says what happened and what to do about it.
- **The gallery is a webdoc2 report built from a do-file.**
  `gallery/build_gallery.do` rebuilds `gallery/gallery.html`: one section
  per output, each with the generating Stata code in a collapsible panel,
  the HTML maps embedded live, and the mermaid export drawn on the page by
  the mermaid library so a reader sees the diagram, not just its text.
  Run mode's journal is prepared by `gallery_prep.do` outside the webdoc
  build, because run mode and `webdoc do` both need control of how a
  do-file executes.
- **The repository carries only what a user needs.** The design notes,
  prototypes, developer test fixtures, and the webdoc compatibility
  investigation moved out of the repository (kept locally under
  `_archive/`, which git ignores). The journal's column-by-column schema
  and its two example journals now live in `docs/`.

## 0.5.1 — 2026-08-23

### Changed

- **The HTML page spends one line per fact.** Read against four real maps
  (a 3,092-event run journal, its joins-only and scan versions), most of the
  height inside each box went to four things: the same scan-mode advisory
  repeated on every box it applied to ("path built from a macro" and "run
  mode resolves it" on 64 boxes, "unresolved runtime list" on 43), a
  three-line tempfile provenance, count lines that would have fit beside
  their label, and a file read and saved straight away drawn as two boxes
  and an arrow. Now: a read saved at once is one box with a
  `-> #k saved: <file>` line (and, in run mode, the saved counts when hidden
  filters changed them); provenance is one line, `[tempfile from line 412]`,
  naming the do-file only when it is another one; a filter's or reshape's
  row change sits on its command line when it fits and is one flagged line
  otherwise, `!! 209,634 -> 203,115 (-6,519, 3.1%)`; a duplicates drop is
  `!! a -> b (-d duplicates)`; a join that matched every row says
  `all N matched, 100% of both sides` once; the coverage line reads
  `cover: 99.7% of master . 99.2% of using` and no longer overflows; the
  result `-> N x k` and an append's `+N obs` sit on the command line; and the
  two scan-mode advisories are markers, `~` for a macro path and `x?` for a
  loop over a runtime list, explained once in the legend with their counts.
  Same information, fewer pixels: scan map 17,512 px to 13,220; joins-only
  scan 9,922 to 6,088; joins-only run 35,404 to 26,955; `filesonly` 14,144 to
  10,419. The hover text on every box keeps the full record.
- Lines that restated another line are gone: `opts: nogenerate` (and
  `generate()`, `noreport`, `nolabel`, `nonotes`, `sorted`, `force`, which
  change no row or are already on the command line); `types: key long vs
  long` when the types agree (a disagreement is still drawn, flagged);
  `[tempfile]` under a label that already reads `tempfile:<name>` in a dashed
  box; `N using-only dropped by keep()` when the breakdown already shows
  `(N dropped)`; and `row change unknown until run` on every scan-mode
  filter, which the legend now says once.
- A loop on the spine shows `xN` after the file name; a loop that ran once
  draws the one file it resolved to instead of the template with `x1`.
- The page title, the mermaid header and the graph footer name the journal
  you drew, not the tempfile copy that a hiding option or an `if` produced.

### Fixed

- **`mergemap run` rejected every one of its own options.** The dispatcher
  built the pass-through list with a leading comma and then placed it after
  `, out()`, so `_mm_run` received `, out(x) , noreceipt` and refused
  `noreceipt`, `examples()`, `warn()`, `stop()` and `nochecks` alike with
  "invalid 'noreceipt'". Calling `_mm_run` directly, which the transparency
  suite does, never hit it.

## 0.5.0 — 2026-08-23

### Added

- **Finer control over what a long map shows.** `norowfilters` hides only the
  row filters (`keep if`, `drop if`); `novarfilters` hides only the variable
  lists (`keep varlist`, `drop varlist`); `notempfiles` hides saves to, uses
  of, and joins against tempfiles; `filesonly` is `joinsonly` plus
  `notempfiles`, the joins between named files. All of them cut the journal
  before any renderer reads it, so they apply to every export, and `draw` now
  prints what it hid (`r(hidden)` holds the same line). Measured on a real
  3,092-event run journal: the default HTML map was 221,997 px tall,
  `nofilters` 51,756, `joinsonly` 35,404, `filesonly` 14,144.
- **An `if` on `mergemap draw`**, evaluated on the journal's own columns with
  the count columns as numbers: `mergemap draw if line < 400 & strpos(dofile,
  "build")` pages a long pipeline; `if class == "join" & n_out < n_in` keeps
  the joins that lost rows. The clause is read off the command line by a
  quote- and parenthesis-aware splitter, because `syntax [if]` validates an
  expression against the data in memory and the journal is not there.
- **Shorter file labels.** `paths(base)`, `paths(parent)` and `paths(#)` keep
  the last one, two or `#` components of each path; `root(folder)` makes every
  path relative to a folder you name, so a project copied between machines
  draws the same labels under any parent directory. Both work for `draw`,
  `receipt`, `list` and `export`. The shortened label is always a trailing
  substring of the original, so a Windows path keeps its backslashes.
- **`mergemap export` to `.xlsx`**: three sheets, `events` (every event,
  every column), `joins` (counts, `_merge` breakdown, coverage) and `filters`
  (each keep/drop with rows removed and percent removed), with count columns
  numeric so Excel sorts and filters them as numbers. The map can hide the
  filters while the workbook keeps all of them. `format()` follows the
  extension of `saving()` when omitted.
- **`compact`, `nocounts` and `nokeys` now reach the HTML page.** They were
  accepted and silently ignored there. `compact` and `nocounts` draw no
  count lines; `nokeys` draws no key varlists. For PNG/SVG, mermaid and DOT,
  which never took them, `draw` now says so instead of staying quiet.
- `_mm_jcut`, the one implementation behind every hide and shorten option.

### Changed

- **A standalone HTML page no longer caps the map in a 32rem scroll box.**
  The page is the page: the map runs full height and the browser scrolls it,
  which is also what a headless browser needs to rasterise the whole thing.
  The `embed` fragment keeps the bounded, resizable box, because it sits
  inside someone else's page.

### Fixed

- **Run mode's `merge` recorded a tempfile's raw path.** `use`, `append`,
  `joinby` and `cross` already journaled a tempfile as `tempfile:<name>`;
  `merge` wrote the resolved `/var/folders/.../St12345.000004`, so a run
  journal described the same tempfile two ways and anything looking for
  tempfile traffic missed the merges. `merge` now labels its using file the
  same way. For journals written by earlier versions, `notempfiles` also
  recognises a path under this machine's `c(tmpdir)`.

## 0.4.1 — 2026-08-21

### Fixed

- **Run mode failed outright on Stata 16.** `_mm_run` saved the sort seed with
  `c(sortseed)` and put it back before executing the pipeline, but that creturn
  came in after Stata 16. On 16 the save produced an empty macro and the restore
  ran as a bare `set sortseed`, which stopped run mode with `r(198) invalid
  syntax` before a single do-file executed. The package declares Stata 16 as its
  floor, so run mode was unusable at the floor it advertised. The seed is now
  probed for and used only where it exists. Verified on Stata 16.1 and 19.5:
  both produce 30 events and 11 joins on the test pipeline.
- **Bit-level reproducibility on Stata 16 is a limitation, and now says so.**
  Without `c(sortseed)` the instrumentation's own bookkeeping advances Stata's
  sort RNG with no way to put it back, so a later `sort` or `collapse` that
  breaks a tie at random can land a last bit away from a plain run. Run mode
  prints a note when it starts on such a Stata, and the help and README record
  it. Scan mode, the default, executes nothing and is unaffected. On a newer
  Stata the output stays identical to a plain run.
- **A UNC or root-relative Windows path was treated as relative.** The test for
  an absolute output path looked for a leading `/` or a drive letter, so
  `\\server\share\map.html` and `\project\map.html` were sent back through
  `c(pwd)` and came out as a path that opens nothing. Both forms are common on
  managed Windows machines, where research folders sit on a share. The test now
  lives in one place, `_mm_isabs`, used by `mergemap draw` and `_mm_open` alike.

### Added

- `_mm_isabs`, the absolute-path test, extracted so it can be checked directly.
  The battery covers all four absolute forms (unix, drive letter, UNC,
  root-relative) and three relative ones, and runs the same on every platform.
- The run-mode transparency suite reports SKIP rather than FAIL for the
  bit-level comparisons on a Stata without `c(sortseed)`, and counts them
  separately, so the suite reads honestly on both releases.

## 0.4.0 — 2026-08-21

### Added

- **`joinsonly`, `nofilters`, and a working `notransforms`.** Asked for from
  real use: a map of the joins alone, with the reshaping and the row filters
  left out. `notransforms` already existed but hid only the reshapes, left the
  filters in place, and worked for the Results-window drawing alone. The cut now
  happens on the journal before any renderer reads it, so `notransforms`,
  `nofilters` and `joinsonly` all apply to HTML, PNG, SVG, mermaid and DOT as
  well as SMCL, from one implementation.
- **A section in the help on naming files so they map well**: numbering do-files
  in run order, giving a loop a list that resolves without executing anything,
  varying one index against a common stub so a loop collapses to a single node,
  separating raw from built, and naming saved files for what they hold. The stub
  advice is the same habit that makes `reshape` work.
- The help's author block now carries the full affiliation and the license, in
  line with the other packages.

## 0.3.3 — 2026-08-21

### Fixed

- **Clicking the "open the diagram" link crashed Stata.** After `mergemap draw`
  wrote an HTML page it printed a `{browse "file://..."}` link. SMCL hands a
  `{browse}` target to the platform's URL machinery, and on macOS a `file://`
  URL passed that way throws an uncaught exception inside `NSURLComponents`
  and aborts the process: the crash report ends in
  `-[_NSURLComponentsBridge setScheme:]` and `abort()`. The same call was used
  for the automatic open, so both routes were affected.

  The link is now `{stata _mm_open:...}`, which runs a Stata command rather
  than handing a URL to the platform, and `_mm_open` shells to the operating
  system's own handler (`open` on macOS, `start` on Windows, `xdg-open`
  elsewhere). Paths containing spaces were checked explicitly and arrive as a
  single argument. `draw` also prints the path in plain text, so the file can
  be opened by hand.
- `draw` left a relative path in the link when the HTML file could not be
  confirmed, which was the one case where an absolute path mattered most.

### Changed

- The install line in the README is a single line again. Wrapping it with
  `///` made it impossible to paste into the Results window, which is where
  people install from.

## 0.3.2 — 2026-08-21

### Fixed

- **`mergemap demo` can be run more than once.** It refused on every call after
  the first, exiting `r(602)`, which stops any do-file that calls it without
  `capture`. The guard was meant to protect a folder the user owns, but the
  folder it refused was almost always the one the demo had written a minute
  earlier, so the first command a new user types failed the second time they
  typed it. The demo now recognises its own output and refreshes it in place. A
  folder holding anything else is still refused, and the user's files are still
  left alone.
- `mergemap list` collided the event number with the filename from event 10 on:
  a `%-4s` field holding `"  10"` fills exactly, leaving no separator.

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
