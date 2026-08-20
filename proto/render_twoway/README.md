# twoway renderer (`rendertw`)

Draws a mergemap journal as a native Stata twoway diagram: `pci` segments for
boxes, `pcarrowi` for arrows, `text()` for labels, one `twoway` call per page.
Exports `<stub>.png` (width 1600) and `<stub>.svg`. Needs nothing but Stata 16.

```
rendertw using <journal.tsv>, saving(stub)
    [ layout(vertical | horizontal)
      page(none | dofile)
      maxnodes(#)
      noprovenance ]
```

| option | meaning |
|---|---|
| `layout()` | `vertical` (default) is the reading order; `horizontal` is the slide/banner form, wrapped into bands of at most 7 columns |
| `page()` | `none` (default) is one image; `dofile` writes one image per do-file, `stub_01_build.png`, `stub_02_panel.png`, … A do-file the journal returns to later gets `_2`, `_3` so no page overwrites another |
| `maxnodes()` | refuse to draw a page denser than # join+transform+filter events (default 12) and point at the HTML renderer, rc 134. With `page(dofile)` the cap applies per page |
| `noprovenance` | suppress the footer, which is the only nondeterministic part of the output |

## What the diagram shows

- The spine is the dataset in memory; boxes to the right are files, frames, or
  tempfiles feeding a join. Dashed box and dashed arrow = a frame link.
- A `filter` event (`keep if`, `drop if`, `drop`/`keep` of variables) is a slim
  inset node with a thin grey rule: the condition, then the row change.
- Loop rows are one stacked node, `x3: cps_2020 … cps_2022`.
- Counts appear only when the journal has them, so a scan-mode journal (all
  counts `.`) draws clean.
- Coverage (v2 `cover_master` / `cover_using`) prints as
  `cover 99.7% master / 99.2% using`; key type drift (v2 `keytypes`) prints as
  `types id: str6 vs long`, and only when the two sides actually differ and no
  flag already names that key.
- Severity is never colour-only. `warn` and `stop` both print `!!`; `stop` is
  bolded as well. The accent `#4a6d8c` (RGB `74 109 140`) is used for nothing
  else.
- The footer is the provenance line (16g): timestamp, Stata version and
  flavour, the git branch and short commit of the nearest ancestor directory
  holding a `.git`, and the journal's file name. Git is read straight out of
  `.git/HEAD` and `refs/` or `packed-refs`, so there is no shell call.

## Reading the journal

Columns are read **by name** from the header row, never by position; column 9
is `usingfile`. A v1 journal (column 9 named `using`) is refused with rc 459
rather than silently misread. Unknown trailing columns are ignored, and the
five v2 columns are filled with `.` if an older producer omitted them.

## Regenerating the gallery outputs

```
cd proto/render_twoway && /usr/local/bin/stata-mp -b do demo.do
```

`demo.do` writes every image below and asserts the option checks, the node cap,
the v1 refusal, and that a refused call leaves no partial output. Batch exit
status is unreliable: check `demo.log` for `^r([0-9]`.

| file | journal | layout |
|---|---|---|
| `tw_vert_scan.png/.svg` | scan | vertical (the default product) |
| `tw_horiz_scan.png/.svg` | scan | horizontal |
| `tw_vert_run.png/.svg` | run | vertical |
| `tw_horiz_run.png/.svg` | run | horizontal |
| `tw_page_scan_01_build` … `_03_analyze` | scan | vertical, `page(dofile)` |
| `tw_page_run_01_build` … `_03_analyze` | run | vertical, `page(dofile)` |
