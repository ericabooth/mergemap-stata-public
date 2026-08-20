*! version 0.2.0  19aug2026  Eric Booth
*! _mm_duplicates -- run-mode wrapper around duplicates.  Transform events carry the
*! row and variable counts on either side, so the diagram can show where the
*! shape of the data changed.  The real command is run verbatim.

program define _mm_duplicates, rclass
    version 16
    global MM_R_ARG : copy local 0
    _mm_tag
    local 0   : copy global MM_R_ARG
    local mmf  "$MM_R_TF"
    local mml  "$MM_R_TL"
    local dof "."
    if "`mmf'" != "." & "`mmf'" != "" local dof : copy global MM_R_B`mmf'
    if `"`dof'"' == "" local dof "."

    global MM_R_ARG : copy local 0
    _mm_opt
    local body : copy global MM_R_BODY
    local opts : copy global MM_R_OPTS
    local sub  "."
    local keys "."
    gettoken w1 b2 : body
    if `"`w1'"' != "" local sub `"`w1'"'
    if strtrim(`"`b2'"') != "" local keys = strtrim(`"`b2'"')

    local jopts = strtrim(`"`body', `opts'"')
    if `"`opts'"' == "" local jopts = strtrim(`"`body'"')
    if `"`jopts'"' == "" local jopts "."

    local nin = _N
    local kin = c(k)
    capture noisily duplicates `0'
    local rc = _rc
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(transform)             ///
            cmd(duplicates) subtype(`"`sub'"') keys(`"`keys'"') master(work)       ///
            result(work) nin(`nin') kin(`kin') opts(`"`jopts'"')              ///
            severity(stop)                                                    ///
            flags(`"!! duplicates failed with r(`rc') -- pipeline stopped here"')
        exit `rc'
    }
    return add
    local nout = _N
    local kout = c(k)
    local flags ""
    local sev "note"
    if `nout' < `nin' {
        local flags = trim(string(`nin' - `nout', "%20.0fc")) + " duplicate "  ///
            + cond(`"`keys'"' == ".", "", `"`keys' "') + "obs dropped"
        local sev "warn"
    }

    _mm_post , dofile(`"`dof'"') line(`mml') class(transform) cmd(duplicates)      ///
        subtype(`"`sub'"') keys(`"`keys'"') master(work) result(work)         ///
        nin(`nin') kin(`kin') nout(`nout') kout(`kout') opts(`"`jopts'"')     ///
        severity(`sev') flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: duplicates " as res `"`jopts'"' as txt                ///
            "   (`dof' line `mml')" _n "    " as res                          ///
            trim(string(`nin', "%20.0fc")) as txt " x " as res "`kin'"         ///
            as txt " -> " as res trim(string(`nout', "%20.0fc")) as txt " x "  ///
            as res "`kout'"
        if `"`flags'"' != "" di as txt "    " as res `"`flags'"'
    }
end
