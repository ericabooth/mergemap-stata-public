*! mmok -- one PASS/FAIL check for the mergemap run-mode test harness.
*! Kept in an ado-file, not a program in the do-file, because the pipeline
*! under test runs "clear all", which drops in-memory programs but leaves the
*! adopath and the globals alone.
program define mmok
    version 16
    args cond
    local txt `"`2'"'
    if "$NPASS" == "" global NPASS = 0
    if "$NFAIL" == "" global NFAIL = 0
    if `cond' {
        global NPASS = $NPASS + 1
        display as txt "PASS: `txt'"
    }
    else {
        global NFAIL = $NFAIL + 1
        display as err "FAIL: `txt'"
    }
end
