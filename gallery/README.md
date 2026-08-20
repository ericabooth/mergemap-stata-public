# mergemap gallery

Review gallery for the mergemap prototypes: the static scanner
(`../src/mergemap.ado`) plus the four renderer prototypes
(`../proto/render_smcl`, `render_html`, `render_twoway`, `render_text`),
all driven from the same 29-column journal contract
(`../proto/JOURNAL_SCHEMA.md`).

Open **`gallery.html`** — a single self-contained page (PNGs embedded as
base64 data URIs, text renders inlined, one SVG inlined). The six
standalone HTML renderer outputs are linked from it as relative files, so
keep them next to it.

## Regenerating everything

```
cd gallery
/usr/local/bin/stata-mp -b do runall.do
grep '^r([0-9]' runall.log     # should print nothing
```

`runall.do` does three things:

1. **Scan.** Runs the scanner over the six integration scenarios
   (s02, s04, s09, s10, s18, s20 in `../tests/scenarios/`) and over the
   pipeline in `../tests/pipeline/` — once through `00_master.do`
   (exercises nested-`do` recursion; keeps the `class=flow` rows) and once
   as the three numbered files directly (the shape the renders below use).
   Journals land in `journals/`; the pipeline scan's receipt is captured
   to `receipt_pipeline.smcl/.txt`.
2. **Render.** Runs every renderer over the two contract journals
   (`../proto/journal_scan.tsv`, `../proto/journal_run.tsv`) and the
   scanner-emitted `journals/journal_pipeline.tsv`. SMCL output is
   captured via named logs and translated to ASCII `.txt`; the teach-mode
   pictures come from `../proto/render_text/mmsql.do`.
3. **Assemble.** Shells out to `make_gallery.sh` (bash; uses `base64`,
   `sed`) to build `gallery.html`.

Requirements: StataNow/Stata 16+ at `/usr/local/bin/stata-mp`, macOS
`bash`/`base64`/`sed`. No package installation: the ado files are picked
up by session-local `adopath +` lines. No datasets are needed — scanning
is static and the sample journals carry their own counts. (The scenario
do-files themselves run against `../tests/raw/`, built by
`../tests/runall.do`, but this gallery only *scans* them.)

## Files

| group | files |
|---|---|
| journals (emitted here) | `journals/journal_pipeline.tsv` (render input), `journals/journal_master.tsv` (recursion variant with flow rows), `journals/s*.tsv` (six scenarios) |
| receipt | `receipt_pipeline.smcl/.txt`, `smcl_escalation.smcl/.txt` |
| SMCL diagrams | `smcl_{boxes,rail}_{scan,run,pipe}.smcl/.txt` |
| HTML | `html_vert_{scan,run,pipe}.html`, `html_horiz_run.html`, `html_vert_{run,pipe}_details.html` |
| twoway | `tw_vert_{scan,run,pipe}.png/.svg`, `tw_horiz_run.png/.svg` |
| mermaid/DOT | `text_{scan,run,pipe}_{td,lr}.mmd/.md`, `text_{scan,run,pipe}_{tb,lr}.dot` |
| teach mode | `teach_merge_m1.smcl/.txt`, `teach_merge_mm.smcl/.txt` |
| build | `runall.do`, `make_gallery.sh`, `gallery.html`, `runall.log` |

`scan` / `run` = the contract journals; `pipe` = the journal the scanner
emitted from `tests/pipeline/01-03`. The pipeline journal differs from the
contract run journal where the real test files deviate on purpose: the
CPS append needs `force` (str3 `hours` in `cps_2022`), `duplicates drop
pid, force`, the corrections merge is `m:1`, and the 02→03 hand-off goes
through the master-declared tempfile published as `$MM_VISITS` — a static
scan reports that global name literally, not the tempfile it points to.

## Integration notes

- Scanner patch (recorded): `src/mergemap.ado` originally crashed
  (r 132, "too few quotes") on source lines containing compound quotes,
  e.g. ``if `"$MM_VISITS"' == "" {`` in `03_analyze.do`. The scanner
  placeholders backtick/`$` at read time, which left the raw `"'` closer
  behind to terminate the scanner's own compound-quote wrappers early.
  Fix: `'` is now placeholdered too (char(3)) and swapped back at journal
  write/receipt display time. All `src/dev/` fixture journals were
  re-verified byte-identical after the patch.
- No renderer *ado* needed patching: all four handled the scanner-emitted
  pipeline journal, the `class=flow` rows in `journal_master.tsv`, and
  the `$MM_VISITS` literal without errors (macro-injection guards held).
- Teach-mode driver patches (recorded): `proto/render_text/mmsql.do`
  (a) added `nomsg` to both `log using` calls — without it the Stata log
  banner leaked absolute workstation paths into the captured `.txt` and
  from there into `gallery.html`; (b) switched the translator from
  `smcl2txt` to `smcl2log` — `smcl2txt` prepends the Stata logo and
  numbers every line. `proto/render_text/teach_merge_*.smcl/.txt` were
  regenerated in place with the patched driver.
- Known cosmetic limits, left as is: flow rows render as a bare `(do)`
  annotation in the SMCL boxes style (no target filename), and the
  scanner receipt's *title* line wraps at linesize 120 when three long
  do-file paths are passed (the table itself fits).
