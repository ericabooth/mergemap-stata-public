*! version 0.2.0  19aug2026  Eric Booth
*! _mm_filter -- shared body of _mm_dropif and _mm_keepif.  Runs the real
*! drop/keep verbatim and records the row (or variable) change.
*! Input globals: MM_R_FCMD MM_R_FLINE MM_R_FDOF MM_R_FARG

program define _mm_filter
    version 16
    local cmd  "$MM_R_FCMD"
    local mml  "$MM_R_FLINE"
    local dof  "$MM_R_FDOF"
    local 0    : copy global MM_R_FARG
    local 0 = strtrim(`"`0'"')
    if `"`dof'"' == "" local dof "."
    if `"`mml'"' == "" local mml "."

    local sub "."
    gettoken w1 : 0
    if strlower(`"`w1'"') == "if" | strlower(`"`w1'"') == "in" local sub "if"

    local nin = _N
    local kin = c(k)
    capture noisily `cmd' `0'
    local rc = _rc
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(filter) cmd(`cmd')    ///
            subtype(`sub') master(work) result(work) nin(`nin') kin(`kin')   ///
            opts(`"`0'"') severity(stop)                                     ///
            flags(`"!! `cmd' failed with r(`rc') -- pipeline stopped here"')
        exit `rc'
    }
    local nout = _N
    local kout = c(k)

    if "`sub'" == "if" {
        local gone = `nin' - `nout'
        local pct = 0
        if `nin' > 0 local pct = 100 * `gone' / `nin'
        local flags = "removed " + trim(string(`gone', "%20.0fc")) + " rows ("  ///
            + string(`pct', "%3.1f") + "%), "                                  ///
            + trim(string(`nout', "%20.0fc")) + " remaining"
        _mm_sev `gone' `nin'
    }
    else {
        local gone = `kin' - `kout'
        local flags = "removed " + trim(string(abs(`gone'), "%20.0fc"))        ///
            + " variables, " + trim(string(`kout', "%20.0fc")) + " remaining"
        global MM_R_SEV "note"
    }
    local sev "$MM_R_SEV"

    _mm_post , dofile(`"`dof'"') line(`mml') class(filter) cmd(`cmd')        ///
        subtype(`sub') master(work) result(work) nin(`nin') kin(`kin')       ///
        nout(`nout') kout(`kout') opts(`"`0'"') severity(`sev')              ///
        flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: `cmd' " as res `"`0'"' as txt                   ///
            "   (`dof' line `mml')" _n "    " as res `"`flags'"'
    }
end
