*! version 0.2.0  19aug2026  Eric Booth
*! _mm_do -- run-mode wrapper around do/run of a literal file name.  The
*! rewriter has already produced an instrumented copy of the child do-file
*! and stamped its index into this call's marker, so the child is run from
*! that copy.  Nothing else changes: the child keeps its own local and
*! tempfile scope exactly as a plain "do" would give it, and relative data
*! paths still resolve against the user's working directory because "do"
*! never changes it.

program define _mm_do
    version 16
    global MM_R_ARG : copy local 0
    _mm_tag
    local 0   : copy global MM_R_ARG
    local mmf  "$MM_R_TF"
    local mml  "$MM_R_TL"
    local mmx  "$MM_R_TX"
    local dof "."
    if "`mmf'" != "." & "`mmf'" != "" local dof : copy global MM_R_B`mmf'
    if `"`dof'"' == "" local dof "."

    * marker extra field: d<child index> for do, r<child index> for run,
    * with "." in place of the index when the child could not be rewritten
    local flav = substr("`mmx'", 1, 1)
    local kid  = substr("`mmx'", 2, .)
    local cmd  = cond("`flav'" == "r", "run", "do")

    local 0 = strtrim(`"`0'"')
    gettoken tgt args : 0
    local tgtd `"`tgt'"'
    if substr(`"`tgtd'"', 1, 1) == char(34) {
        local tgtd = substr(`"`tgtd'"', 2, strlen(`"`tgtd'"') - 2)
    }

    local exec `"`tgt'"'
    local flags ""
    if "`kid'" != "" & "`kid'" != "." {
        local rw : copy global MM_R_R`kid'
        if `"`rw'"' != "" local exec `"`rw'"'
    }
    if `"`exec'"' == `"`tgt'"' local flags "child not instrumented"

    _mm_post , dofile(`"`dof'"') line(`mml') class(flow) cmd(`cmd')          ///
        master(work) usingfile(`"`tgtd'"') result(work) flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: `cmd' " as res `"`tgtd'"' as txt                ///
            "   (`dof' line `mml')"
    }
    if "`cmd'" == "run" {
        run `"`exec'"' `args'
    }
    else {
        do `"`exec'"' `args'
    }
end
