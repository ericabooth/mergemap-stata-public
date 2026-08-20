*! version 0.2.0  19aug2026  Eric Booth
*! _mm_cross -- run-mode wrapper around cross, the unconditional cartesian
*! product.  Row counts before and after make the multiplication explicit.

program define _mm_cross
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
    if `"`opts'"' == "" local opts "."
    global MM_R_ARG : copy local body
    _mm_using
    local ufd : copy global MM_R_UFD

    local nu "."
    local ku "."
    capture describe using `"`ufd'"'
    if !_rc {
        local nu = r(N)
        local ku = r(k)
    }
    local nin = _N
    local kin = c(k)
    capture noisily cross `0'
    local rc = _rc
    _mm_lbl , path(`"`ufd'"')
    local lbl : copy global MM_R_LBL
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(join) cmd(cross)      ///
            master(work) usingfile(`"`lbl'"') result(work) nin(`nin')        ///
            kin(`kin') nusing(`nu') kusing(`ku') opts(`"`opts'"')            ///
            severity(stop)                                                   ///
            flags(`"!! cross failed with r(`rc') -- pipeline stopped here"')
        capture _return restore _mmret
        exit `rc'
    }
    local nout = _N
    local kout = c(k)
    local flags ""
    if `nin' > 0 {
        local flags = "cartesian product x" + string(`nout' / `nin', "%4.2f")
    }
    _mm_post , dofile(`"`dof'"') line(`mml') class(join) cmd(cross)          ///
        master(work) usingfile(`"`lbl'"') result(work) nin(`nin') kin(`kin') ///
        nusing(`nu') kusing(`ku') nout(`nout') kout(`kout')                  ///
        opts(`"`opts'"') severity(warn) flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: cross using " as res `"`lbl'"' as txt           ///
            "   (`dof' line `mml')" _n "    " as res                         ///
            trim(string(`nin', "%20.0fc")) as txt " x " as res               ///
            trim(string(`nu', "%20.0fc")) as txt " = " as res                ///
            trim(string(`nout', "%20.0fc")) as txt " obs"
    }
    capture _return restore _mmret
end
