*! version 0.5.6  10nov2026  Eric Booth
*! _mm_pfx -- run-mode stand-in for a recognised command behind a by:,
*! bysort: or frame: prefix.
*!
*! The wrappers (_mm_merge, _mm_keepif and the rest) are not byable, and a
*! frame: prefix would run them against a frame the run state does not
*! follow, so the rewriter does not swap the command word on such a line.
*! It puts this program in front of the prefix instead:
*!
*!     bysort grp: keep if _n == 1
*!  -> _mm_pfx #1:5:keep# bysort grp: keep if _n == 1
*!
*! _mm_pfx journals one note event for the line (class note, the command in
*! cmd, no counts) and then runs the rest of the line unchanged, under the
*! caller's version.  The note is posted first, so the r() left behind is
*! the user's command's own, and an error in the command stops the
*! pipeline exactly as it would in a plain run.  Prefixes that come before
*! the by: or frame: (capture, quietly, noisily) stay outside this program
*! and keep their meaning.

program define _mm_pfx
    version 16
    local vv = _caller()
    global MM_R_ARG : copy local 0
    _mm_tag
    local 0   : copy global MM_R_ARG
    local mml "$MM_R_TL"
    local mmf "$MM_R_TF"
    local cmd "$MM_R_TX"
    local dof "."
    if "`mmf'" != "." & "`mmf'" != "" local dof : copy global MM_R_B`mmf'
    if `"`dof'"' == "" local dof "."
    if "`cmd'" == "" local cmd "."

    * the prefix word, for the flag (by, bysort, frame, ...)
    local s : copy local 0
    gettoken pw : s, parse(" :,")
    if !inlist(`"`pw'"', "by", "frame", "frames") {
        if !(strpos("bysort", `"`pw'"') == 1 & strlen(`"`pw'"') >= 3) local pw "prefix"
    }

    local fl "not instrumented: `cmd' behind a `pw' prefix, run unchanged, no counts recorded"
    capture _return drop _mmret
    capture _return hold _mmret
    _mm_post , dofile(`"`dof'"') line(`mml') class(note) cmd(`cmd')         ///
        subtype(.) master(.) result(.) severity(note) flags(`"`fl'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: `cmd' behind a `pw' prefix   (`macval(dof)' line `mml')" ///
            _n "    " as res "not instrumented; it runs unchanged"
    }
    capture _return restore _mmret

    version `vv': `macval(0)'
end
