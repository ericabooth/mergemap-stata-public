# Bug: `mergemap <folder>` fails with a bare "invalid syntax" after a run

> **Fixed in v0.5.3 (2026-08-29).** `_mm_ftime` now reads the header through Mata
> (`_mm_hdrts`, end of `mergemap.ado`): the timestamp element is located and
> filtered there, and only the cleaned text ever reaches a macro. The read also
> grew from 220 to 512 bytes, so a dataset label longer than 71 characters no
> longer silently pushes `</timestamp>` out of reach and switches staleness
> checking off for that file. Regression cover: `tests/mergemap_pkgtest.do`,
> block 20. The two surveymap items at the bottom remain open.

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

## Root cause

`_mm_ftime` (in `mergemap.ado`) reads the first 220 bytes of a `.dta` to pull the
`<timestamp>` element out of the header, accumulating them one byte at a time:

```stata
forvalues i = 1/220 {
    file read `fh' %1s ch1
    if r(eof) continue, break
    local hdr `"`hdr'`ch1'"'          // <- raw binary into a macro
}
```

A `.dta` header interleaves ASCII tags with **raw binary counts**, so `ch1` is
sometimes a byte that Stata's macro parser cannot survive. The observation count is
the usual source. In the failing example, `raw/roster.dta` holds 2,400 rows, and
2,400 = 0x960, so the little-endian count begins with byte `0x60`, which is a
literal backtick:

```
offset 76..84:  3c 4e 3e | 60 09 00 00 00 00 00 00
                 <  N  > | `
```

Appending a backtick opens a macro reference Stata cannot close, and the scan exits
r(198) naming no file. Any dataset with `N mod 256 == 96` carries this byte, so about
one file in 256 triggers it on the observation count alone, plus more from the
variable count and the label.

This also explains the run-then-scan trigger. The staleness check only reaches the
input files when the output already exists on disk, so a scan before the run never
reads `roster.dta`'s header and a scan after it does.

## Why the one-line fixes do not hold

Two minimal patches were tried and neither is sufficient:

1. `local hdr `"`macval(hdr)'`macval(ch1)'"'` gets past the backtick, and the scan
   then fails further down at r(132), because `hdr` is expanded again without
   `macval` in the `strpos` and `substr` calls that follow.
2. Filtering to safe characters at read time fails earlier still: testing the byte
   requires expanding it, and a `0x22` byte (a double quote) breaks the test
   expression itself with "too few quotes".

Defending each byte class inside macro syntax is whack-a-mole. The underlying problem
is routing arbitrary binary through Stata macros at all.

## Suggested fix

Read and filter the header in Mata, which handles binary strings safely, and hand
Stata only characters that can appear in the tag:

```stata
mata:
void mm_hdrscan(string scalar fn) {
    real scalar fh, i
    string scalar s, c, out, keep
    keep = "<>/0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz: "
    fh  = fopen(fn, "r")
    s   = fread(fh, 220)
    fclose(fh)
    out = ""
    for (i = 1; i <= strlen(s); i++) {
        c = substr(s, i, 1)
        if (strpos(keep, c)) out = out + c
    }
    st_local("hdr", out)
}
end
```

Everything downstream of `local hdr` then works unchanged, because `hdr` can no
longer contain a character that breaks a macro.

*(The shipped v0.5.3 fix goes one step further than this sketch: `_mm_hdrts`
finds and cleans the timestamp inside Mata and hands Stata only that text, so
no header macro remains at all.)*

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
