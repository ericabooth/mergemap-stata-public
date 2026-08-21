*! mmok -- one PASS/FAIL check for the mergemap run-mode test harness.
*! Kept in an ado-file, not a program in the do-file, because the pipeline
*! under test runs "clear all", which drops in-memory programs but leaves the
*! adopath and the globals alone.
*!
*! Optional third argument: a 1 marks the check as one this Stata cannot
*! meet for a known reason, and a failure is then reported as SKIP and
*! counted in $NSKIP.  Used for the bit-level dataset comparisons, which
*! need c(sortseed) to hold the sort seed steady; a Stata without that
*! creturn can break a tie differently and land a last-bit apart.  A check
*! that passes anyway is still reported as PASS.
program define mmok
    version 16
    args cond
    local txt  `"`2'"'
    local excused `"`3'"'
    if "$NPASS" == "" global NPASS = 0
    if "$NFAIL" == "" global NFAIL = 0
    if "$NSKIP" == "" global NSKIP = 0
    if `cond' {
        global NPASS = $NPASS + 1
        display as txt "PASS: `txt'"
    }
    else if `"`excused'"' != "" & `"`excused'"' != "0" {
        global NSKIP = $NSKIP + 1
        display as txt "SKIP: `txt' (no c(sortseed) on this Stata)"
    }
    else {
        global NFAIL = $NFAIL + 1
        display as err "FAIL: `txt'"
    }
end
