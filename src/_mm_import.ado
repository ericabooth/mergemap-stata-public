*! version 0.2.0  19aug2026  Eric Booth
*! _mm_import -- run-mode wrapper around import.  A source node whose file is
*! not a .dta, so its dimensions are read from memory after the import rather
*! than from "describe using".

program define _mm_import
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
    gettoken sub b2 : body
    if `"`sub'"' == "" local sub "."
    global MM_R_ARG : copy local b2
    _mm_using
    local ufd : copy global MM_R_UFD
    if `"`ufd'"' == "" {
        gettoken tok : b2
        local ufd `"`tok'"'
        if substr(`"`ufd'"', 1, 1) == char(34) {
            local ufd = substr(`"`ufd'"', 2, strlen(`"`ufd'"') - 2)
        }
    }

    capture noisily import `0'
    local rc = _rc
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(source) cmd(import)   ///
            subtype(`"`sub'"') usingfile(`"`ufd'"') result(work)             ///
            opts(`"`opts'"') lifecycle(read) severity(stop)                  ///
            flags(`"!! import failed with r(`rc') -- pipeline stopped here"')
        capture _return restore _mmret
        exit `rc'
    }
    local nout = _N
    local kout = c(k)
    _mm_post , dofile(`"`dof'"') line(`mml') class(source) cmd(import)       ///
        subtype(`"`sub'"') usingfile(`"`ufd'"') result(work)                 ///
        nusing(`nout') kusing(`kout') nout(`nout') kout(`kout')              ///
        opts(`"`opts'"') lifecycle(read)
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: import `sub' " as res `"`ufd'"' as txt          ///
            "   (`dof' line `mml')" _n "    loaded " as res                  ///
            trim(string(`nout', "%20.0fc")) as txt " obs, " as res           ///
            "`kout'" as txt " vars"
    }
    capture _return restore _mmret
end
