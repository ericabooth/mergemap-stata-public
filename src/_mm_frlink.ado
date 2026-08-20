*! version 0.2.0  19aug2026  Eric Booth
*! _mm_frlink -- run-mode wrapper around frlink.  frlink IS rclass, so the
*! real command's r() is captured with "return add" immediately and handed
*! back to the caller unchanged; r(unmatched) also feeds master coverage.

program define _mm_frlink, rclass
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
    if `"`opts'"' == "" local opts "."
    gettoken sub keys : body
    local keys = strtrim(`"`keys'"')
    if `"`keys'"' == "" local keys "."

    local fname ""
    if regexm(`"`opts'"', "frame\(([^)]*)\)") {
        local fspec = regexs(1)
        gettoken fname : fspec, parse(" ")
    }

    local nin = _N
    local kin = c(k)
    _mm_pre , keys(`keys') fframe(`fname') $MM_R_NOCHK
    local nu     "$MM_R_NU"
    local ku     "$MM_R_KU"
    local dupm   "$MM_R_DUPM"
    local dupu   "$MM_R_DUPU"
    local ktype  : copy global MM_R_KTYPE
    local kdrift "$MM_R_KDRIFT"
    local covu "$MM_R_COVU"

    capture noisily frlink `0'
    local rc = _rc
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(link) cmd(frlink)     ///
            subtype(`"`sub'"') keys(`"`keys'"') master(work)                 ///
            usingfile(`"frame:`fname'"') result(work) nin(`nin') kin(`kin')  ///
            nusing(`nu') kusing(`ku') opts(`"`opts'"') severity(stop)        ///
            keytypes(`"`ktype'"')                                            ///
            flags(`"!! frlink failed with r(`rc') -- pipeline stopped here"')
        exit `rc'
    }
    local unm = .
    capture local unm = r(unmatched)
    return add
    * remember which frame this link variable points at, so that a later
    * frget from(lvar) can name the frame it pulled variables out of
    local lvar "`fname'"
    if regexm(`"`opts'"', "gen[a-z]*\(([^)]*)\)") local lvar = regexs(1)
    if "`lvar'" != "" global MM_R_LINK_`lvar' "`fname'"

    local nout = _N
    local kout = c(k)
    local covm "."
    local flags ""
    if `nin' > 0 & `unm' < . {
        local covm = string(100 * (`nin' - `unm') / `nin', "%4.1f")
        if `unm' > 0 {
            local flags = trim(string(`unm', "%20.0fc")) + " obs unmatched to frame"
        }
    }
    if "`kdrift'" == "1" {
        local flags = cond("`flags'" == "", "!! key type drift: `ktype'", ///
            "`flags'; !! key type drift: `ktype'")
    }
    _mm_sev `=cond(`unm' < ., `unm', 0)' `nin'
    local sev "$MM_R_SEV"
    if "`kdrift'" == "1" & "`sev'" == "note" local sev "warn"

    _mm_post , dofile(`"`dof'"') line(`mml') class(link) cmd(frlink)         ///
        subtype(`"`sub'"') keys(`"`keys'"') master(work)                     ///
        usingfile(`"frame:`fname'"') result(work) nin(`nin') kin(`kin')      ///
        nusing(`nu') kusing(`ku') nout(`nout') kout(`kout')                  ///
        dupmaster(`dupm') dupusing(`dupu') opts(`"`opts'"')                  ///
        severity(`sev') keytypes(`"`ktype'"') covermaster(`covm')            ///
        coverusing(`covu') flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: frlink `sub' " as res `"`keys'"' as txt         ///
            " to frame " as res "`fname'" as txt "   (`dof' line `mml')"
        if "`covm'" != "." {
            di as txt "    coverage: " as res "`covm'%" as txt               ///
                " of master linked"
        }
        if `"`flags'"' != "" di as txt "    " as res `"`flags'"'
    }
end
