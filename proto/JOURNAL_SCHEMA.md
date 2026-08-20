# mergemap journal schema, v2

One tab-separated line per event, **34 columns**, header row present. Missing value
is a single period `.`. Contract files: `journal_run.tsv` (run mode, counts
observed) and `journal_scan.tsv` (scan mode, counts unknown). **Scan mode is the
package default**, so every renderer must produce a clean diagram when all count
fields are `.`.

| # | name | meaning |
|---|---|---|
| 1 | seq | event number within the run, 1..N |
| 2 | dofile | original do-file name |
| 3 | line | original line number |
| 4 | class | `source` `join` `link` `transform` `filter` `save` `flow` `note` |
| 5 | cmd | command word, full spelling |
| 6 | subtype | merge/joinby `1:1 m:1 1:m m:m`; reshape `long/wide`; duplicates `drop/report`; save `tempfile`; filter `if` |
| 7 | keys | key varlist, space separated |
| 8 | master | data in memory before the event (`work`, `frame:<name>`) |
| 9 | **usingfile** | file path, `tempfile:<name>`, or `frame:<name>`; for collapsed loops the unexpanded template |
| 10 | result | label after the event (`work`, or the saved path when class=save) |
| 11-16 | n_in k_in n_using k_using n_out k_out | obs/var counts (`.` in scan mode) |
| 17-21 | m1 m2 m3 m4 m5 | `_merge` counts: master-only, using-only, matched, missing-updated, conflict-updated |
| 22-23 | dup_master dup_using | obs minus distinct key values per side (0 = key unique) |
| 24 | force | 1 if `force` was on the command |
| 25 | opts | verbatim relevant options; for class=filter, the condition |
| 26-28 | loop_n loop_first loop_last | collapsed-loop stack: iterations and first/last resolved names |
| 29 | severity | `note` `warn` `stop` |
| 30 | keytypes | storage type of each key on each side, `id: str6 vs long` |
| 31 | cover_master | percent of master rows that matched |
| 32 | cover_using | percent of using rows that were used |
| 33 | lifecycle | on save/source events: `create` `overwrite` `read` |
| 34 | flags | human-readable diagnostics; `!!` marks a warning; multiple separated by `; ` |

## Reading the journal back

`using` is a **reserved word** in Stata. Column 9 is therefore named `usingfile`,
not `using`: with the old name, `import delimited ... varnames(1)` silently
produced a positional variable (`v9`) and `levelsof using` failed with a bare
r(100). Never reintroduce a reserved word as a column name.

Read by **name** from the header row, and tolerate unknown trailing columns so a
later schema addition does not break an older renderer.

## Rendering rules every renderer shares

- Dropped categories print in parentheses: `using-only (2 dropped)`.
- `severity` drives emphasis, but the text marker is what carries the meaning:
  `warn` and `stop` both print `!!` so the signal survives a log file, a
  monochrome printout, and a reader who does not distinguish colours. `stop` may
  additionally be bolded. Never encode severity in colour alone.
- The single accent colour is `#4a6d8c` (RGB `74 109 140`). Used for flags and
  arrowheads only; everything else is greyscale.
- Loop rows render as ONE stacked node: `x3: raw/cps_2020.dta ... raw/cps_2022.dta`.
- Labels longer than the wrap width get middle-ellipsis, but only when the column
  genuinely overflows.
- Scan mode: omit count lines entirely rather than printing `.`.
- `class=filter` renders as a slim node on the spine showing the condition and the
  row change: `drop if missing(wage)  |  removed 6,519 rows (3.1%), 203,115 left`.
  Filters matter because most row loss happens in them, not in the joins.
- SMCL auto-escalation: past `maxnodes` (default 8) join+transform+filter events,
  or when horizontal layout is requested, print the receipt plus a one-line notice
  and defer the diagram to HTML. `maxnodes(#)` and `forcesmcl` override.
- Default SMCL style is `boxes`; `rail` is the compact alternative.

## Embed mode (HTML)

A fragment, not a page. Scoped `<style>`, a `<div class="mm-embed">` wrapper, an
`<svg>` carrying `viewBox` and **no** `width`/`height`. Every class prefixed `mm-`,
every id namespaced per diagram (`mm1-arrow`), and **no element selectors at all**
(`body`, `h1`, `h2`, `pre`, `details`, bare `svg`) because those restyle the host
page. Horizontal layouts keep their natural width inside `overflow-x:auto`.
