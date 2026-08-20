*! version 0.2.0  19aug2026  Eric Booth
*! _mm_contract -- run-mode wrapper around contract.  Transform events carry the
*! row and variable counts on either side, so the diagram can show where the
*! shape of the data changed.  The real command is run verbatim.

program define _mm_contract
    version 16
    global MM_R_ARG : copy local 0
    _mm_tag
    local 0   : copy global MM_R_ARG
    local mmf  "$MM_R_TF"
    local mml  "$MM_R_TL"
    local dof "."
    if "`mmf'" != "." & "`mmf'" != "" local dof : copy global MM_R_B`mmf'
    if `"`dof'"' == "" local dof "."
    capture _return drop _mmret
    capture _return hold _mmret

    global MM_R_ARG : copy local 0
    _mm_opt
    local body : copy global MM_R_BODY
    local opts : copy global MM_R_OPTS
    local sub  "."
    local keys "."
    if `"`body'"' != "" local keys = strtrim(`"`body'"')

    local jopts = strtrim(`"`body', `opts'"')
    if `"`opts'"' == "" local jopts = strtrim(`"`body'"')
    if `"`jopts'"' == "" local jopts "."

    local nin = _N
    local kin = c(k)
    capture noisily contract `0'
    local rc = _rc
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(transform)             ///
            cmd(contract) subtype(`"`sub'"') keys(`"`keys'"') master(work)       ///
            result(work) nin(`nin') kin(`kin') opts(`"`jopts'"')              ///
            severity(stop)                                                    ///
            flags(`"!! contract failed with r(`rc') -- pipeline stopped here"')
        capture _return restore _mmret
        exit `rc'
    }
    local nout = _N
    local kout = c(k)
    local flags ""
    local sev "note"

    _mm_post , dofile(`"`dof'"') line(`mml') class(transform) cmd(contract)      ///
        subtype(`"`sub'"') keys(`"`keys'"') master(work) result(work)         ///
        nin(`nin') kin(`kin') nout(`nout') kout(`kout') opts(`"`jopts'"')     ///
        severity(`sev') flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: contract " as res `"`jopts'"' as txt                ///
            "   (`dof' line `mml')" _n "    " as res                          ///
            trim(string(`nin', "%20.0fc")) as txt " x " as res "`kin'"         ///
            as txt " -> " as res trim(string(`nout', "%20.0fc")) as txt " x "  ///
            as res "`kout'"
        if `"`flags'"' != "" di as txt "    " as res `"`flags'"'
    }
    capture _return restore _mmret
end
