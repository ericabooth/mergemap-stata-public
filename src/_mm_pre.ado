*! version 0.2.0  20aug2026  Eric Booth
*! _mm_pre -- pre-join diagnostics that touch neither the data in memory nor
*! Stata's sort state.
*!
*! The using side's N and k come from "describe using", which never loads the
*! file.  Its key variables are read into scratch frame _mmuk with a plain
*! "use varlist using", which does not sort.  Duplicate counts, coverage, and
*! the top-k unmatched keys are then computed in Mata by _mm_keys, because
*! every sorting route to them (duplicates, contract, merge, egen tag) would
*! advance the sort seed and change how the user's own later sorts break
*! ties.  With nochecks only one observation of the using file is read, which
*! still gives the key storage types.
*!
*! Output globals: MM_R_NU MM_R_KU      using N and k
*!                 MM_R_KTYPE           "id: str6 vs long"
*!                 MM_R_KDRIFT          1 if any key type differs
*!                 plus everything _mm_keys sets

program define _mm_pre
    version 16
    syntax , [keys(string) usingfile(string) fframe(string) nochecks]
    * syntax treats an option spelled noXXX as the negation of XXX, so the
    * local it fills in is called checks, not nochecks
    local nochecks "`checks'"

    global MM_R_NU     "."
    global MM_R_KU     "."
    global MM_R_KTYPE  "."
    global MM_R_KDRIFT "0"
    foreach g in DUPM DUPU COVM COVU COVMN COVMD COVUN COVUD {
        global MM_R_`g' "."
    }
    global MM_R_TOPK ""
    capture frame drop _mmuk

    * ---------- using-side N and k, without loading the file ----------
    if `"`fframe'"' != "" {
        capture frame `fframe' {
            global MM_R_NU = _N
            global MM_R_KU = c(k)
        }
    }
    else if `"`usingfile'"' != "" {
        capture describe using `"`usingfile'"'
        if !_rc {
            global MM_R_NU = r(N)
            global MM_R_KU = r(k)
        }
    }
    if `"`keys'"' == "" | `"`keys'"' == "." exit

    * ---------- master-side key storage types ----------
    local mt ""
    foreach k of local keys {
        capture confirm variable `k'
        if _rc {
            local mt `"`mt' ?"'
        }
        else {
            local t : type `k'
            local mt `"`mt' `t'"'
        }
    }

    * ---------- using-side key variables into a scratch frame ----------
    local ok = 0
    if `"`fframe'"' != "" {
        capture frame `fframe' {
            frame put `keys', into(_mmuk)
        }
        if !_rc local ok = 1
    }
    else {
        local inopt ""
        if "`nochecks'" != "" local inopt "in 1"
        capture frame create _mmuk
        capture frame _mmuk: use `keys' `inopt' using `"`usingfile'"', clear
        if !_rc local ok = 1
    }

    local ut ""
    if `ok' {
        frame _mmuk {
            foreach k of local keys {
                capture confirm variable `k'
                if _rc {
                    local ut `"`ut' ?"'
                }
                else {
                    local t : type `k'
                    local ut `"`ut' `t'"'
                }
            }
        }
    }

    * ---------- assemble the type ledger ----------
    local kt ""
    local drift 0
    local j = 0
    foreach k of local keys {
        local ++j
        local a : word `j' of `mt'
        local b : word `j' of `ut'
        if "`a'" == "" local a "?"
        if "`b'" == "" local b "?"
        local kt = cond("`kt'" == "", "`k': `a' vs `b'", "`kt'; `k': `a' vs `b'")
        if "`a'" != "`b'" & "`a'" != "?" & "`b'" != "?" local drift = 1
    }
    if "`kt'" != "" global MM_R_KTYPE "`kt'"
    global MM_R_KDRIFT "`drift'"

    * ---------- key-set arithmetic, in Mata, without sorting ----------
    if "`nochecks'" == "" & `ok' {
        _mm_keys , keys(`"`keys'"')
    }
    capture frame drop _mmuk
end
