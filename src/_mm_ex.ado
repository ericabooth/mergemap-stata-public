*! version 0.2.0  19aug2026  Eric Booth
*! _mm_ex -- examples(#): list a few sample rows of a join, showing the key
*! variables and the _merge category only, never whole rows (DECISIONS 9).
*! The rows are copied into a scratch frame first, so the data in memory is
*! neither sorted nor altered.

program define _mm_ex
    version 16
    * mergemap must be invisible to Stata's sort tie-breaking: this helper's
    * own bookkeeping (sorts, scratch merges, duplicate checks) advances
    * c(sortrngstate), which would change how a later -collapse- or -sort-
    * breaks ties and so alter results in the last bits.  Save it here and
    * put it back on every exit path.
    local _mmsrng `"`c(sortrngstate)'"'
    local _mmrng  `"`c(rngstate)'"'
    syntax , [keys(string) n(integer 5)]
    if `n' <= 0 exit
    if `"`keys'"' == "" | `"`keys'"' == "." exit
    capture frame drop _mmex
    capture frame put `keys' _mm_merge_tmp, into(_mmex)
    if _rc exit
    frame _mmex {
        qui keep if _mm_merge_tmp != 3
        rename _mm_merge_tmp _merge
        if _N == 0 {
            di as txt "    examples: every row matched"
        }
        else {
            local top = min(`n', _N)
            di as txt "    examples (unmatched rows, key and category only):"
            list `keys' _merge in 1/`top', noobs abbreviate(16)
        }
    }
    capture frame drop _mmex
    capture set sortrngstate `_mmsrng'
    capture set rngstate `_mmrng'
end
