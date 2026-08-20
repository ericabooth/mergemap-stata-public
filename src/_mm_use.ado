*! version 0.2.0  19aug2026  Eric Booth
*! _mm_use -- run-mode wrapper around use.  Records the source node and its
*! dimensions and then runs the real use, verbatim.  use is a built-in and
*! cannot be shadowed, which is exactly why run mode rewrites the command
*! word to a differently named ado instead of intercepting the name.

program define _mm_use
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
    if `"`ufd'"' == "" {
        gettoken tok : body
        local ufd `"`tok'"'
        if substr(`"`ufd'"', 1, 1) == char(34) {
            local ufd = substr(`"`ufd'"', 2, strlen(`"`ufd'"') - 2)
        }
    }

    local nu "."
    local ku "."
    capture describe using `"`ufd'"'
    if !_rc {
        local nu = r(N)
        local ku = r(k)
    }

    capture noisily use `0'
    local rc = _rc
    _mm_lbl , path(`"`ufd'"')
    local lbl  : copy global MM_R_LBL
    local prov : copy global MM_R_PROV
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(source) cmd(use)      ///
            usingfile(`"`lbl'"') result(work) nusing(`nu') kusing(`ku')      ///
            opts(`"`opts'"') lifecycle(read) severity(stop)                  ///
            flags(`"!! use failed with r(`rc') -- pipeline stopped here"')
        capture _return restore _mmret
        exit `rc'
    }

    local nout = _N
    local kout = c(k)
    local flags ""
    local istmp = (strpos(`"`lbl'"', "tempfile:") == 1)
    if `"`prov'"' != "" {
        local flags `"produced by `prov'"'
        if `istmp' local flags `"tempfile from `prov'"'
    }
    else if `istmp' local flags "tempfile"

    _mm_post , dofile(`"`dof'"') line(`mml') class(source) cmd(use)          ///
        usingfile(`"`lbl'"') result(work) nusing(`nu') kusing(`ku')          ///
        nout(`nout') kout(`kout') opts(`"`opts'"') lifecycle(read)           ///
        flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: use " as res `"`lbl'"' as txt              ///
            "   (`dof' line `mml')" _n "    loaded " as res             ///
            trim(string(`nout', "%20.0fc")) as txt " obs, " as res      ///
            "`kout'" as txt " vars"
    }
    capture _return restore _mmret
end
