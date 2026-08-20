*! version 0.2.0  19aug2026  Eric Booth
*! _mm_joinby -- run-mode wrapper around joinby, the true many-to-many join.
*! joinby prints nothing, so coverage is computed from key-only scratch
*! frames (skipped under nochecks) and the fan-out is read from the row
*! counts on either side.

program define _mm_joinby
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
    local keys : copy global MM_R_KEYS
    local ufd  : copy global MM_R_UFD

    local nin = _N
    local kin = c(k)
    _mm_pre , keys(`keys') usingfile(`"`ufd'"') $MM_R_NOCHK
    local nu     "$MM_R_NU"
    local ku     "$MM_R_KU"
    local dupm   "$MM_R_DUPM"
    local dupu   "$MM_R_DUPU"
    local ktype  : copy global MM_R_KTYPE
    local kdrift "$MM_R_KDRIFT"
    local covm "$MM_R_COVM"
    local covu "$MM_R_COVU"

    capture noisily joinby `0'
    local rc = _rc
    _mm_lbl , path(`"`ufd'"')
    local lbl : copy global MM_R_LBL
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(join) cmd(joinby)     ///
            subtype(m:m) keys(`"`keys'"') master(work) usingfile(`"`lbl'"')  ///
            result(work) nin(`nin') kin(`kin') nusing(`nu') kusing(`ku')     ///
            dupmaster(`dupm') dupusing(`dupu') opts(`"`opts'"')              ///
            severity(stop) keytypes(`"`ktype'"')                             ///
            flags(`"!! joinby failed with r(`rc') -- pipeline stopped here"')
        capture _return restore _mmret
        exit `rc'
    }
    local nout = _N
    local kout = c(k)

    local flags ""
    if `nin' > 0 {
        if `nout' > `nin' * 1.005 {
            local flags = "row multiplication x" + string(`nout' / `nin', "%4.2f")
        }
    }
    if "`kdrift'" == "1" {
        local flags = cond("`flags'" == "", "!! key type drift: `ktype'", ///
            "`flags'; !! key type drift: `ktype'")
    }
    local sev "note"
    if `"`flags'"' != "" local sev "warn"

    _mm_post , dofile(`"`dof'"') line(`mml') class(join) cmd(joinby)         ///
        subtype(m:m) keys(`"`keys'"') master(work) usingfile(`"`lbl'"')      ///
        result(work) nin(`nin') kin(`kin') nusing(`nu') kusing(`ku')         ///
        nout(`nout') kout(`kout') dupmaster(`dupm') dupusing(`dupu')         ///
        opts(`"`opts'"') severity(`sev') keytypes(`"`ktype'"')               ///
        covermaster(`covm') coverusing(`covu') flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: joinby " as res `"`keys'"' as txt " using "     ///
            as res `"`lbl'"' as txt "   (`dof' line `mml')"
        di as txt "    master " as res trim(string(`nin', "%20.0fc"))        ///
            as txt " {c |} using " as res trim(string(`nu', "%20.0fc"))      ///
            as txt " {c |} result " as res trim(string(`nout', "%20.0fc"))
        if "`covm'" != "." {
            di as txt "    coverage: " as res "`covm'%" as txt              ///
                " of master matched, " as res "`covu'%" as txt " of using used"
        }
        if `"`flags'"' != "" di as txt "    " as res `"`flags'"'
    }
    capture _return restore _mmret
end
