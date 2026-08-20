*! version 0.2.0  19aug2026  Eric Booth
*! _mm_using -- split "keyvars using filename" at the top-level word "using".
*!
*! Input  : global MM_R_ARG
*! Output : global MM_R_KEYS  text before "using" (the key varlist)
*!          global MM_R_UF    the filename exactly as written, so that it can
*!                            be handed straight back to the real command
*!          global MM_R_UFD   the same path with surrounding quotes removed,
*!                            for the journal and the ledger

program define _mm_using
    version 16
    local s : copy global MM_R_ARG
    local L = strlen(`"`s'"')
    local i  = 1
    local dq = 0
    local st = 0
    local cut = 0
    local cutend = 0
    while `i' <= `L' + 1 {
        local c = cond(`i' <= `L', substr(`"`s'"', `i', 1), " ")
        if `"`c'"' == char(34) local dq = 1 - `dq'
        if `dq' == 0 & (`"`c'"' == " " | `"`c'"' == char(9)) {
            if `st' {
                local tok = substr(`"`s'"', `st', `i' - `st')
                if strlower(`"`tok'"') == "using" {
                    local cut    = `st'
                    local cutend = `i'
                    continue, break
                }
                local st = 0
            }
        }
        else if `st' == 0 & `"`c'"' != " " & `"`c'"' != char(9) {
            local st = `i'
        }
        local ++i
    }
    if `cut' {
        local keys = strtrim(substr(`"`s'"', 1, `cut' - 1))
        local uf   = strtrim(substr(`"`s'"', `cutend', .))
    }
    else {
        local keys = strtrim(`"`s'"')
        local uf   ""
    }
    local ufd `"`uf'"'
    if substr(`"`ufd'"', 1, 1) == char(34) & substr(`"`ufd'"', -1, 1) == char(34) {
        local ufd = substr(`"`ufd'"', 2, strlen(`"`ufd'"') - 2)
    }
    if `"`keys'"' == "" local keys "."
    global MM_R_KEYS : copy local keys
    global MM_R_UF   : copy local uf
    global MM_R_UFD  : copy local ufd
end
