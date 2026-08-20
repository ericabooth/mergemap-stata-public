# mergemap

Map the merges, appends and joins across your do-files.

`mergemap` reads a sequence of do-files and reports every `merge`, `append`,
`joinby`, `cross`, `frlink` and `frget` in them, along with the reshaping and
filtering steps around them. By default it executes nothing: it reads your code
the way you would read it and prints a numbered receipt of what it found.

It answers one question. How did this dataset get built? That question comes up
when you inherit a project, when a merge has gone wrong and you need to find
where, and when you need a record of a data pipeline for an appendix.

## Start here

```stata
mergemap demo
```

That writes three small do-files into a new folder, scans them, and shows you the
output. The example is built only from `sysuse auto` and `sysuse census`, so
nothing is downloaded and nothing needs preparing, and the generated do-files
really run.

Then point it at your own work, in the order you run it:

```stata
mergemap 01_clean.do 02_merge.do 03_analyze.do
mergemap build/
mergemap 0*.do
```

## Install

From a local clone:

```stata
net install mergemap, from("/path/to/mergemap") replace
```

Once the repository is published, the usual form applies:

```stata
net install mergemap, from("https://raw.githubusercontent.com/ericabooth/mergemap-stata-public/main/") replace
```

The test battery is an ancillary file, so `net install` does not place it. Get it
with `net get mergemap` if you want to run it.

Requires Stata 16 or later. Nothing else: no Python, no LaTeX, no external
programs.

## Reading the receipt

Every run prints a numbered index of what was found, in the order the code
performs it.

```
1 of 2 joins flagged: 1 warn.
  # file        line command   keys        using/result          F flags
  1 01_build.do   12 use                   ../raw/cps_2019.dta
  2 01_build.do   15 append x3             ../raw/cps_`y'.dta    F !! force used
  3 01_build.do   22 merge m:1 county      ../raw/county_key.dta   keep(1 3): using-only
                                                                   will be dropped
  4 01_build.do   31 drop if               missing(hours)
  5 01_build.do   40 collapse  county year
  6 01_build.do   42 save                  ../out/co...panel.dta
```

`#` is the event number, and `file` and `line` say where to go and fix it. `F`
marks `force`, which lets Stata push past a type mismatch it would otherwise
refuse. `!!` marks anything worth a look. A stacked loop appears once, as `x3`,
rather than three near-identical rows.

Filters are in there for a reason. When a dataset ends up smaller than expected
the merge usually gets the blame and a `drop if` three lines later is usually the
culprit, so both are shown.

## Scan mode and run mode

**Scan mode is the default and it is safe.** `mergemap` reads your do-files as
text and never executes them, so it works on code that will not currently run, on
someone else's project, and on files whose data you do not have. What it cannot
know is anything that only exists at run time: there are no observation counts and
no match counts.

**Run mode executes your do-files** with instrumentation around each join and
records what actually happened.

```stata
mergemap run 01_clean.do 02_merge.do 03_analyze.do
```

```
mergemap: merge m:1 county using ../raw/county_key.dta   (01_build.do line 22)
    key: county   county: str5 vs str5
    master 1,936 | using 42 | matched 1,919 | result 1,936
    coverage: 99.1% of master matched, 95.2% of using used
    top unmatched keys: 48999 (17)
    2 using-only dropped by keep(1 3); 17 master-only kept
```

Coverage is reported as a share of each side because raw counts do not
scale-normalize, and a lookup table that goes mostly unused usually means the key
is wrong. The unmatched-keys line separates "500 rows failed to match" from "one
key failed to match 500 times".

Your results are unchanged. The wrappers call the real commands and pass your
options through untouched, and the test suite proves it: the pipeline is run
plainly and then under `mergemap run`, and every saved dataset must come out
identical on `datasignature`, `cf _all`, the sort flag, and `describe`.

Use scan when you want the shape. Use run when you want the truth.

## Commands

| command | what it does |
|---|---|
| `mergemap` *dofiles* | scan; the default, executes nothing |
| `mergemap demo` | write a worked example, scan it, show the output |
| `mergemap check` *dofiles* | print only the flagged events |
| `mergemap run` *dofiles* | execute with instrumentation and record what happened |
| `mergemap draw` | draw the last journal: Results window, HTML, PNG/SVG, mermaid, DOT |
| `mergemap sql` | teach any join form as a row-pairing picture |
| `mergemap receipt` *journal* | reprint a receipt from a saved journal |
| `mergemap list` | the journal as a table; `full` for every column |
| `mergemap detail` *#* | everything about one event; `teach` draws it with its counts |
| `mergemap export` | the journal as a `.dta` or `.csv`, counts arriving numeric |
| `mergemap clear` | forget the remembered journal; files are never touched |

## Drawing the map

```stata
mergemap draw
mergemap draw, export(html) saving(pipeline.html)
mergemap draw, export(png)  saving(figures/pipeline)
mergemap draw, export(mermaid) saving(pipeline)
```

With no options, `draw` renders the most recent journal in the Results window when
it fits, and writes a self-contained HTML page when it does not, printing a
clickable link. A PNG too dense for one readable image splits itself into one page
per do-file. For a webdoc or webdoc2 report, `export(html) ... embed` writes a
fragment whose stylesheet is scoped so it cannot restyle the report around it.
`export(mermaid)`, `export(dot)`, and `export(erdiagram)` write text that GitHub,
Quarto, VS Code, and online viewers render with nothing installed.

The gallery in `gallery/gallery.html` shows every medium side by side.

## Teaching the joins

```stata
mergemap sql            // the Stata / SQL / dplyr / pandas translation table
mergemap sql joinby     // one form, drawn as row pairings with its size rule
```

A join is a cartesian product with a filter, which is why a join can return more
rows than either input, and why the usual overlapping-circles picture cannot
explain the joins that go wrong. Each picture shows two small row stacks, the
operator, and the result, with dropped rows in parentheses and the size rule
underneath.

The pictures connect back to your own work: `mergemap detail 4, teach` draws
event 4 from the journal in the same style, with the toy rows replaced by that
join's observed counts — the teaching picture and your pipeline become the same
picture.

## Flags, and what to do about them

| flag | what it means |
|---|---|
| `!! m:m` | `merge m:m` is not a join. It pairs rows by position within the key, which depends on the order your data happen to be in. If you want all pairings use `joinby`; if you meant a lookup use `m:1`. |
| `!! force` | `force` let a type mismatch through. The merge succeeded and the values may be wrong. |
| `!! type` | The key is stored differently on the two sides, for example `id: str6 vs long`. This is the quietest way a merge fails. |
| `!! unmatched` | Rows found no partner. Often fine, sometimes the whole bug. |
| `!! also saved by` | Two do-files write the same file. Whichever runs last wins. |
| `!! stale` | A saved dataset is older than something it was built from. |

Severity has three levels, `note`, `warn` and `stop`, set with `warn()` and
`stop()`, which take either a count or a share. A `stop` makes `mergemap run` exit
with an error, so it can be used as a gate in a master do-file rather than only as
a report. Severity is never carried by colour alone.

## Limitations

These are boundaries of the approach, not bugs.

In scan mode, anything built at run time stays unresolved. A file name assembled
from a macro appears as it is written in your code, and a loop over a list built
from a directory listing cannot be counted. Both are flagged rather than guessed
at, and run mode resolves them.

A join performed inside a command you wrote yourself, or built up as text and then
executed, is invisible. That includes the merge wrappers on SSC: if your code uses
`mmerge`, `dmerge`, `mergeall` or `pullin`, `mergemap` sees the wrapper and not
the join inside it. It reads code, not intentions.

`mergemap run` rewrites your do-files into temporary copies with instrumented
command names, keeping your line numbers. It does not alter your files. If a
do-file uses `#delimit ;`, the scan is best-effort and says so, and run mode
leaves that region uninstrumented.

Do not nest `mergemap run` inside `webdoc do`. Both take control of how a do-file
is executed.

## Related commands

`mergemap` describes joins that have already been written. For neighbouring jobs:

- **Before you combine files**, `precombine` (Chatfield, *Stata Journal* 15(3))
  compares datasets you are about to combine, including whether their value-label
  code sets agree. That is a pre-flight check; `mergemap` is the map afterwards.
- **To manage a project's build**, `project` (Picard) tracks dependencies and
  re-runs what changed. `mergemap` reports when an output looks stale but never
  rebuilds anything.
- **To assert an exact number of dropped observations**, `iedropone` (DIME's
  `ietoolkit`) errors unless exactly the expected number went.
- **For participant-flow figures**, `flowchart` (Dodd) draws CONSORT and PRISMA
  diagrams. It needs LaTeX and it charts people, not datasets.

## Repository layout

| path | contents |
|---|---|
| `src/` | the package: `mergemap.ado`, the `_mm_*` helpers, and the help file |
| `tests/` | test data, 21 scenarios, a 3-file pipeline, and the regression battery |
| `tests/runmode/` | the run-mode transparency regression |
| `proto/` | renderer prototypes, the journal schema, and design notes |
| `gallery/` | every renderer's output assembled into one self-contained page |

Running the tests:

```stata
cd tests
do mergemap_pkgtest.do
```

## Documentation

`help mergemap` after installing. `PLAN.md` carries the design and the reasoning
behind it, `DECISIONS.md` the choices made and rejected, `CONCEPTMAP.md` a table
mapping every Stata combining verb to its SQL, dplyr and pandas equivalent, and
`CHANGELOG.md` what changed and when.

## Author

Eric Booth
eric.a.booth@gmail.com
