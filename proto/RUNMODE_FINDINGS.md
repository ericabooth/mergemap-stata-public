# Run-mode transparency: what actually broke it

Verified on StataNow 19.5 while round 2 was building. The transparency regression
went from **6 failed** to **12 passed, 0 failed** on the strength of finding 3.

## 1. Byte-comparing `.dta` files is not a valid transparency test

A `.dta` header carries `<timestamp>19 Aug 2026 23:28</timestamp>` at minute
resolution. Two saves of identical data inside the same minute *are* byte-identical,
so a quick check looks sound and then fails whenever the plain run and the
instrumented run straddle a minute boundary.

Compare `datasignature` (content and row order), `cf _all`, `: sortedby` (neither of
the first two looks at the sort flag), and `describe` for variable order and types.

## 2. The sort flag is real, and it is easy to lose

An early design stripped `keep()`, ran the merge with a temporary `generate()`,
counted, then applied the drop by hand. Content matched exactly — same
`datasignature`, `cf _all` clean, same variable order, `_merge` value label
preserved — but `: sortedby` did not: reference `id`, candidate empty. Stata's
`merge` sets the sort flag when the merge is 1:1 and no using-only observations
survive, and a manual `keep if` clears it.

The shipped wrapper avoids the whole question by passing `keep()` through to the
real `merge` untouched and substituting only `generate()`, so Stata sets the flag
itself. Keep it that way.

## 3. The root cause: instrumentation consumed Stata's sort RNG

With the data provably identical at every step, `county_panel.dta` still differed
after `collapse (mean) wage hours, by(county year)`. `cf` reported 56 mismatches in
`wage` whose printed values were **identical** — differences below display
precision, i.e. in the last bits of the floating-point mean.

The chain:

- `collapse` sorts by its `by()` variables. Rows tied on those are ordered using
  Stata's sort RNG.
- A different tie order means the group means are summed in a different order, and
  floating-point addition is not associative, so the means differ in their last
  bits.
- Measured directly: `merge` **does** advance `c(sortrngstate)`;
  `append`, `save`, and `collapse` do **not**.
- The wrappers' own bookkeeping — scratch merges for the coverage counts, duplicate
  checks, sorts — also advances it. So by the time `collapse` ran, the instrumented
  session was at a different RNG state than the plain one, and broke ties
  differently.

Nothing about the data was wrong. The instrumentation was leaking through a channel
nobody thinks about.

**The fix** is to make every measurement helper restore the state it consumed.
`c(sortrngstate)` and `c(rngstate)` are both readable and settable, and the restore
is exact:

```stata
program define _mm_pre
    local _mmsrng `"`c(sortrngstate)'"'
    local _mmrng  `"`c(rngstate)'"'
    ...measurement work...
    capture set sortrngstate `_mmsrng'
    capture set rngstate `_mmrng'
end
```

Applied to `_mm_pre`, `_mm_cov`, `_mm_topk`, and `_mm_ex` — every helper that
touches data — including before each early `exit`, not only before `end`. After
that, the sort RNG state matched the plain run at every step of the pipeline and all
three saved datasets became bit-identical.

**The rule for any future wrapper:** measurement must restore `c(sortrngstate)` and
`c(rngstate)` on every exit path. The user's own command may consume whatever it
likes; the wrapper must consume nothing observable. A helper added later without
this bracket will reintroduce last-bit drift that no amount of staring at the merge
logic will explain.
