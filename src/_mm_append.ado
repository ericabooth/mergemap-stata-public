*! version 0.2.0  19aug2026  Eric Booth
*! _mm_append -- run-mode wrapper around append.  append prints nothing, so
*! the row counts on each side are read before and after and every option is
*! passed through unchanged.

program define _mm_append
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
    local body   : copy global MM_R_BODY
    local opts   : copy global MM_R_OPTS
    local oforce  "$MM_R_OFORCE"
    if `"`opts'"' == "" local opts "."

    global MM_R_ARG : copy local body
    _mm_using
    local uf : copy global MM_R_UF

    local nu = 0
    local ku "."
    local lbls ""
    local nf = 0
    foreach f of local uf {
        local ff `"`f'"'
        if substr(`"`ff'"', 1, 1) == char(34) {
            local ff = substr(`"`ff'"', 2, strlen(`"`ff'"') - 2)
        }
        capture describe using `"`ff'"'
        if !_rc {
            local nu = `nu' + r(N)
            local ku = r(k)
        }
        _mm_lbl , path(`"`ff'"')
        local lbls = trim(`"`lbls' $MM_R_LBL"')
        local ++nf
    }
    if `nf' == 0 local nu "."

    local nin = _N
    local kin = c(k)
    capture noisily append `0'
    local rc = _rc
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(join) cmd(append)     ///
            master(work) usingfile(`"`lbls'"') result(work) nin(`nin')       ///
            kin(`kin') nusing(`nu') kusing(`ku') force(`oforce')             ///
            opts(`"`opts'"') severity(stop)                                  ///
            flags(`"!! append failed with r(`rc') -- pipeline stopped here"')
        capture _return restore _mmret
        exit `rc'
    }
    local nout = _N
    local kout = c(k)

    local flags ""
    if "`oforce'" == "1" local flags "!! force used"
    local sev "note"
    if "`oforce'" == "1" local sev "warn"

    _mm_post , dofile(`"`dof'"') line(`mml') class(join) cmd(append)         ///
        master(work) usingfile(`"`lbls'"') result(work)                      ///
        nin(`nin') kin(`kin') nusing(`nu') kusing(`ku')                      ///
        nout(`nout') kout(`kout') force(`oforce') opts(`"`opts'"')           ///
        severity(`sev') flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: append using " as res `"`lbls'"' as txt         ///
            "   (`dof' line `mml')" _n "    " as res                         ///
            trim(string(`nin', "%20.0fc")) as txt " + " as res               ///
            trim(string(`nout' - `nin', "%20.0fc")) as txt " = " as res      ///
            trim(string(`nout', "%20.0fc")) as txt " obs"
        if `"`flags'"' != "" di as txt "    " as res `"`flags'"'
    }
    capture _return restore _mmret
end
