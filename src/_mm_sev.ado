*! version 0.2.0  19aug2026  Eric Booth
*! _mm_sev -- turn a breach count into a severity tier.
*!
*! Thresholds live in globals MM_R_WARN and MM_R_STOP and accept either a
*! count (a number >= 1) or a share of the total (strictly between 0 and 1),
*! following DECISIONS 16b; the default is warn(.05) unmatched.  Severity is
*! never colour-only downstream: warn and stop both print "!!".
*!
*! Usage : _mm_sev <count> <total>      Output: global MM_R_SEV

program define _mm_sev
    version 16
    args count total
    local sev "note"
    if "`count'" == "" | "`total'" == "" | "`count'" == "." | "`total'" == "." {
        global MM_R_SEV "`sev'"
        exit
    }
    if `total' <= 0 {
        global MM_R_SEV "`sev'"
        exit
    }
    foreach tier in warn stop {
        local thr "${MM_R_`=strupper("`tier'")'}"
        if "`thr'" == "" continue
        capture confirm number `thr'
        if _rc continue
        local breach = 0
        if `thr' >= 1 {
            if `count' >= `thr' local breach = 1
        }
        else if `thr' > 0 {
            if `count' / `total' >= `thr' local breach = 1
        }
        if `breach' local sev "`tier'"
    }
    global MM_R_SEV "`sev'"
end
