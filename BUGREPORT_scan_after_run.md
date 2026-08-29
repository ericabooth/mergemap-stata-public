# Bug: `mergemap <folder>` fails with a bare "invalid syntax" after a run

Found 2026-08-29 while building the book's Chapter 6 example. Reproducible from a
clean directory in three commands.

## Repro

Given `build/` holding three do-files where `20_link.do` saves `build/analysis.dta`
and `30_analyze.do` reads it back:

```stata
mergemap build/            // A: rc = 0, receipt prints
mergemap run build/        // B: rc = 0, runs and instruments correctly
mergemap build/            // C: rc = 198, prints only "invalid syntax"
```

Step C fails **after** printing `mergemap: build/ is a folder; scanning 3 do-file(s)
in name order`, so the folder and file discovery are fine.

## What it is not

- Not session state. A fresh Stata session scanning the same directory fails the same way.
- `mergemap clear` does not fix it (it reports "nothing was remembered").
- Not the `.dta` files in general: scanning a folder containing `analysis.dta` alone
  succeeds.
- Not a relative path, and not a doubled path separator. Both scan cleanly elsewhere.

## What it is

The artefact that `mergemap run` writes is what breaks the next scan:

```stata
erase build/estimation.dta   // still fails
erase build/analysis.dta     // now rc = 0
```

`build/analysis.dta` is both an output of `20_link.do` and an input of
`30_analyze.do`. The failure appears while processing `20_link.do`, which is also
the file that saves it. Scanning that same file on its own
(`mergemap build/20_link.do`) succeeds, so the folder path and the `dir()` argument
are implicated rather than the file's contents.

## Where it fails

`set trace on, tracedepth(2)` puts the last successful call at:

```
_mm_process, frame(_mm_l1) from(1) to(4) dofile(20_link.do) dir(build/)
invalid syntax
```

`_mm_process` is defined in `mergemap.ado` and takes
`dofile(string asis)` and `dir(string asis)`.

## Why it matters

Scan-then-run-then-scan is the natural working loop: read the pipeline, run it for the
counts, come back and re-read after an edit. The second scan fails on a build that
worked minutes earlier, and the message names neither a file nor a line.

## Two smaller items found in the same session

1. `surveymap draw, layout(vertical) export(png)` silently ignores `layout()`.
   `_sm_rendertw` accepts only `saving() maxnodes() name() noprovenance replace`, and
   `_sm_draw` does not pass `layout` to it, so the PNG and SVG always come out
   horizontal. The HTML and mermaid renderers honour it. Either pass it through or
   refuse the combination.
2. `surveymap band, saving("x")` exits with "output file suffix not recognized"
   because the stub reaches `graph export` without an extension. `surveymap draw`
   accepts a bare stub and adds the extension itself, so the two subcommands disagree.
