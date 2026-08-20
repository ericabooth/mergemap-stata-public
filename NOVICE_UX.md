# mergemap through a beginner's eyes

Findings from driving the prototype scanner the way a low-confidence Stata user
actually types, not the way the author intends. Tested 2026-08-19 against
`src/mergemap.ado` v0.1.0 in a scratch directory holding the pipeline do-files.

## A. What already works (do not break these)

The tokenizer survived every real-world file-shape trap thrown at it:

| Trap | Result |
|---|---|
| Windows CRLF line endings | parsed correctly, 3/3 events |
| `UPPER.DO` uppercase extension | parsed |
| `cd "subdir"` before the joins | parsed (but see B9) |
| UTF-8 accents in comments | parsed |
| Space inside a quoted `.dta` path | parsed, path kept intact |
| `merge` inside an `if { }` block | parsed, correct line numbers |
| Macro-built paths (`` use `path'/a.dta ``) | parsed, template preserved |

That is a solid foundation. Everything below is about the *doorway*, not the engine.

## B. Where a beginner hits a wall

Ranked by how likely the user is to give up.

**B1. Compound quotes crash the scanner — blocking.**
`mergemap 01_build.do 02_panel.do 03_analyze.do` → `too few quotes  r(132)`. The
first diagnosis (a multi-file bug) was wrong: bisecting showed `03_analyze.do` alone
fails, and the trigger is line 3, `if `"$MM_VISITS"' == "" {`.

Root cause, confirmed by minimal repro: the scanner protects backticks and dollar
signs by swapping them for `char(1)`/`char(2)` placeholders, but leaves the plain
single quote alone. A scanned line therefore still contains the two-character
sequence `"'`, which is exactly the *closing* delimiter of Stata's compound quote.
The moment the scanner references the line as `` `"`line'"' ``, that inner `"'`
closes the wrapper early and the rest of the line dangles. Verified:

```
local t : subinstr local line "\`" "@", all
display `"[`t']"'                        // -> [if @"invalid syntax   r(198)/r(132)
local u : subinstr local u "'" "#", all
display `"[`u']"'                        // -> [if @""# == "" {]      rc 0
```

Fix: add a third placeholder (`char(3)`) for the single quote alongside the existing
two, and mirror it everywhere `char(39)` is currently matched (the macro-reference
patterns) and at the two restore points (journal write, receipt re-encode).

This matters well beyond the test file: defensive `if `"`x'"' == ""` guards are
everywhere in careful Stata code, so without this fix mergemap fails on exactly the
well-written do-files it most wants to scan.

**B2. Wildcards are the first instinct and they fail.**
`mergemap *.do` → `file *.do not found  r(601)`. Stata does not glob, but the user
does not know that; they know shell and they know `ls *.do`. mergemap should expand
patterns itself via the `dir` extended macro function and sort the result, so
`mergemap *.do` and `mergemap 0*.do` just work.

**B3. A folder is a natural argument and it fails.**
`mergemap .` and `mergemap build/` → `file not found  r(601)`. PLAN documents
`folder()`, but a beginner will pass the folder positionally. Accept a directory in
the positional slot: detect it, expand to its `*.do` files in name order, and say so
("scanning 6 do-files in build/ in name order").

**B4. `folder()` is documented but not implemented.**
`mergemap, folder(.)` → `do-file list required  r(100)`. The prototype never
implemented it. Anyone reading PLAN or a draft help file will try it first.

**B5. Missing extension is not forgiven.**
`mergemap 01_build` → `file 01_build not found`. Append `.do` and retry before
erroring; Stata itself does this for `do`.

**B6. Bare call gives a dead end.**
`mergemap` → `do-file list required  r(100)`. That is Stata's generic syntax error.
A beginner needs a doorway here: a two-line usage hint plus a pointer to
`help mergemap` and to `mergemap demo`.

**B7. Typos produce no help.**
`mergemap 01_buidl.do` → `file 01_buidl.do not found`. Since we are already listing
the directory for B2/B3, offer the near-miss: "did you mean 01_build.do?"

**B8. Unresolved macros look like a bug, not a limitation.**
A scan of ``merge 1:1 id using `path'/b.dta`` prints `` `path'/b.dta `` in the using
column with no comment. The beginner reads that as mergemap being broken. It should
carry an explicit flag ("path built from a macro; values resolve under `mergemap
run`") so the limitation reads as a designed boundary.

**B9. `cd` silently invalidates later relative paths.**
`withcd.do` does `cd "subdir"` then merges `b.dta`. The scanner records `b.dta`
relative to the original directory, so any later file-existence checking or
save→use linking will mis-resolve. Track `cd` with a literal argument, resolve
subsequent relative paths against it, and flag `cd` with a macro argument as
unresolvable.

**B10. No help file exists yet.** Expected at this stage, but it is the single
biggest beginner deliverable, so it belongs on the list.

## C. Beginner-facing features worth building

**C1. `mergemap demo` — a self-demonstrating quickstart.**
Writes three tiny do-files into a folder (built from `sysuse auto` / `sysuse
census`, so no downloads and nothing to prepare), scans them, and shows the receipt
and diagram. A beginner can see the output in ten seconds without owning a pipeline
of their own, and the generated do-files double as a worked example of the join
vocabulary. This is the single highest-value novice feature.

**C2. Teach-on-flag messages.**
The receipt already flags `m:m` and `force`. For a beginner the flag should also say
what to do: `m:m` → "this pairs rows by position within key, it is not a join; see
`help mergemap##mm`"; `force` → "force lets a type mismatch through; check the
variable named". Short, one clause, with a help anchor.

**C3. Plain-language pipeline summary.**
Three sentences under the diagram: how many files feed the final dataset, which join
changed the row count most, and which flags need attention. This is the "explain it
to me" layer that makes the diagram legible to someone who cannot yet read it.

**C4. `mergemap check` — a diagnosis-only mode.**
Print only the flagged events. For a user whose merge "went wrong", the receipt of
everything is noise; the four suspicious lines are the answer.

**C5. Errors that name the fix.**
Every mergemap error should end with the command that would have worked. Not
"file not found" but "file not found: 01_buidl.do; did you mean 01_build.do?".

## D. Beginner-facing documentation plan (help file)

The help file should open with a runnable three-line quickstart, not a syntax
diagram. Order: (1) what it does in two sentences; (2) `mergemap demo`;
(3) the receipt explained column by column; (4) scan vs run, stated as "scan reads
your code, run executes it and adds counts"; (5) the diagram legend (what a box is,
what a dashed box is, what `×3` means, what `!!` means); (6) options grouped by
question the user is asking ("I want it shorter", "I want it in a document", "I want
to see loops expanded"); (7) the Stata↔SQL concept map as a learning section;
(8) limitations, stated plainly; (9) rendering/portability. Examples must run
against `mergemap demo` output so every one of them is copy-pasteable.

## E. Reviewer findings, and what was fixed

Two adversarial reviewers went over the gallery: one on readability against the
visual brief, one on technical correctness (clean-state re-runs, XML validity,
attribution, portability).

**Fixed already.**

- `gallery/runall.do` died `r(603)` from a fresh checkout because it never created
  its own `journals/` directory. The regeneration steps in its README therefore
  failed for anyone who cloned the repo. Added `capture mkdir journals`; a
  clean-state run is now green.
- The accent colour was not one colour. HTML used `#4a6d8c`, mermaid and DOT used
  `#39537d`, and the twoway renderer used Stata's named `navy` (`#1a476f`). All
  three now use `#4a6d8c`, expressed as the RGB triplet `74 109 140` in the twoway
  renderer so it stays valid at the Stata 16 floor.
- The regression battery (`tests/mergemap_pkgtest.do`) itself had two false
  passes worth recording, because both are traps a Stata author hits: a
  `` `=char(96)' `` written inside a quoted string is re-scanned by Stata's macro
  expander, so `` `hold' `` collapsed to nothing and the generated fixture did not
  contain what the test claimed to test; and a whole-line `strpos` match reported
  success because the filename `p4.do` happens to contain the digit the assertion
  was looking for. Fixtures are now built with `_char()` and numeric assertions
  read a named column. 27 checks pass, 0 fail.

**Still open, ranked.**

1. The receipt truncates flag text mid-word even at linesize 120
   (`!! m:m pairs rows by row ord..`). The flag is the most useful column and it is
   the one being cut. Give it the leftover width, or wrap it onto a continuation
   line.
2. There are two receipt layouts: the scanner's pipe-ruled table and the SMCL
   renderer's lighter aligned one. The lighter one scans faster. Pick it and delete
   the other.
3. Filename truncation is too eager: `03_analyze.do` became `03_an...e.do` when
   there was room to spare. Truncate only when the column genuinely overflows.
4. The twoway vertical diagram is one 1600x5745 image. For a printed page it should
   split per do-file, or offer a `page()` option.
5. The `rail` style loses the chain break between do-files and repeats a line when
   `opts` and `flags` carry the same text (`update replace` printed twice).
