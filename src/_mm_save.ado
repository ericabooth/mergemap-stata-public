*! version 0.2.0  19aug2026  Eric Booth
*! _mm_save -- run-mode wrapper around save.  Records the sink node, whether
*! the path is being created or overwritten (lifecycle, DECISIONS 16f), and
*! registers the path so that a later use of the same file -- a tempfile in
*! particular -- can name its producer.

program define _mm_save
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

    gettoken tok : body
    local path `"`tok'"'
    if substr(`"`path'"', 1, 1) == char(34) {
        local path = substr(`"`path'"', 2, strlen(`"`path'"') - 2)
    }
    if `"`path'"' == "" local path `"`c(filename)'"'
    local pdta `"`path'"'
    if !strpos(`"`pdta'"', ".") local pdta `"`path'.dta"'

    local life "create"
    capture confirm file `"`pdta'"'
    if !_rc local life "overwrite"

    local nin = _N
    local kin = c(k)
    capture noisily save `0'
    local rc = _rc
    _mm_lbl , path(`"`pdta'"')
    local lbl : copy global MM_R_LBL
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(save) cmd(save)       ///
            master(work) result(`"`lbl'"') nin(`nin') kin(`kin')             ///
            opts(`"`opts'"') lifecycle(`life') severity(stop)                ///
            flags(`"!! save failed with r(`rc') -- pipeline stopped here"')
        capture _return restore _mmret
        exit `rc'
    }
    _mm_lbl , path(`"`pdta'"') register(`"`dof' line `mml'"')

    local sub ""
    local flags ""
    if strpos(`"`lbl'"', "tempfile:") == 1 {
        local sub "tempfile"
        local flags "tempfile"
    }
    _mm_post , dofile(`"`dof'"') line(`mml') class(save) cmd(save)           ///
        subtype(`"`sub'"') master(work) result(`"`lbl'"')                    ///
        nin(`nin') kin(`kin') nout(`nin') kout(`kin') opts(`"`opts'"')       ///
        lifecycle(`life') flags(`"`flags'"')
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: save " as res `"`lbl'"' as txt                  ///
            "   (`dof' line `mml')" _n "    `life', " as res                 ///
            trim(string(`nin', "%20.0fc")) as txt " obs, " as res            ///
            "`kin'" as txt " vars"
    }
    capture _return restore _mmret
end
