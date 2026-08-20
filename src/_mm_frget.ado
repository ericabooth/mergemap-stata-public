*! version 0.2.0  19aug2026  Eric Booth
*! _mm_frget -- run-mode wrapper around frget.  frget IS rclass (r(k),
*! r(srclist), r(newlist)); those results are captured with "return add"
*! straight after the real command and passed back untouched.

program define _mm_frget, rclass
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
    local opts : copy global MM_R_OPTS
    local body : copy global MM_R_BODY
    local all = strtrim(`"`body', `opts'"')
    if `"`opts'"' == "" local all `"`body'"'
    if `"`all'"' == "" local all "."

    local fname ""
    if regexm(`"`opts'"', "from\(([^)]*)\)") {
        local lv = regexs(1)
        capture local fname : copy global MM_R_LINK_`lv'
    }

    local nin = _N
    local kin = c(k)
    capture noisily frget `0'
    local rc = _rc
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(link) cmd(frget)      ///
            master(work) usingfile(`"frame:`fname'"') result(work)           ///
            nin(`nin') kin(`kin') opts(`"`all'"') severity(stop)             ///
            flags(`"!! frget failed with r(`rc') -- pipeline stopped here"')
        exit `rc'
    }
    local nk = .
    capture local nk = r(k)
    return add
    local nout = _N
    local kout = c(k)
    local flags ""
    if `nk' < . local flags = trim(string(`nk', "%20.0fc")) + " variables brought over"

    _mm_post , dofile(`"`dof'"') line(`mml') class(link) cmd(frget)          ///
        master(work) usingfile(`"frame:`fname'"') result(work)               ///
        nin(`nin') kin(`kin') nout(`nout') kout(`kout') opts(`"`all'"')      ///
        flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: frget " as res `"`all'"' as txt                 ///
            "   (`dof' line `mml')" _n "    " as res "`kin'" as txt          ///
            " -> " as res "`kout'" as txt " variables"
    }
end
