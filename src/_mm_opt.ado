*! version 0.2.0  19aug2026  Eric Booth
*! _mm_opt -- split a command's arguments at the first top-level comma and
*! classify the option list, without disturbing anything it does not name.
*!
*! Input  : global MM_R_ARG   command arguments (already macro-expanded)
*! Output : global MM_R_BODY  everything before the first top-level comma
*!          global MM_R_OPTS  the option string, verbatim
*!          global MM_R_OREST the option string minus generate()/nogenerate/
*!                            noreport -- every other option, keep() included,
*!                            is passed through byte for byte
*!          global MM_R_OKEEP argument of keep(), or ""
*!          global MM_R_OGEN  argument of generate(), or ""
*!          global MM_R_ONOGEN 1 if nogenerate was specified
*!          global MM_R_OFORCE 1 if force was specified
*!          global MM_R_OUPD  1 if update was specified
*!          global MM_R_OREPL 1 if replace was specified
*!          global MM_R_OASRT argument of assert(), or ""

program define _mm_opt
    version 16
    local s : copy global MM_R_ARG
    local L = strlen(`"`s'"')

    * ---- split at the first comma that is outside quotes and parentheses ----
    local i   = 1
    local dq  = 0
    local dep = 0
    local cut = 0
    while `i' <= `L' {
        local c = substr(`"`s'"', `i', 1)
        if `"`c'"' == char(34) {
            local dq = 1 - `dq'
        }
        else if `dq' == 0 {
            if `"`c'"' == "(" {
                local ++dep
            }
            else if `"`c'"' == ")" {
                local dep = `dep' - 1
            }
            else if `"`c'"' == "," & `dep' <= 0 {
                local cut = `i'
                continue, break
            }
        }
        local ++i
    }
    if `cut' {
        local body = substr(`"`s'"', 1, `cut' - 1)
        local opts = substr(`"`s'"', `cut' + 1, .)
    }
    else {
        local body `"`s'"'
        local opts ""
    }
    local body = strtrim(`"`body'"')
    local opts = strtrim(`"`opts'"')

    * ---- walk the option string one option token at a time ----
    local rest   ""
    local okeep  ""
    local ogen   ""
    local onogen 0
    local oforce 0
    local oupd   0
    local orepl  0
    local oasrt  ""
    local M = strlen(`"`opts'"')
    local i = 1
    while `i' <= `M' {
        local c = substr(`"`opts'"', `i', 1)
        if `"`c'"' == " " | `"`c'"' == "," {
            local ++i
            continue
        }
        * token start
        local st  = `i'
        local dq  = 0
        local dep = 0
        while `i' <= `M' {
            local c = substr(`"`opts'"', `i', 1)
            if `"`c'"' == char(34) {
                local dq = 1 - `dq'
            }
            else if `dq' == 0 {
                if `"`c'"' == "(" {
                    local ++dep
                }
                else if `"`c'"' == ")" {
                    local dep = `dep' - 1
                    if `dep' <= 0 {
                        local ++i
                        continue, break
                    }
                }
                else if `dep' == 0 & (`"`c'"' == " " | `"`c'"' == ",") {
                    continue, break
                }
            }
            local ++i
        }
        local tok = substr(`"`opts'"', `st', `i' - `st')
        * name and argument of this option token
        local nm  `"`tok'"'
        local arg ""
        local p = strpos(`"`tok'"', "(")
        if `p' {
            local nm  = substr(`"`tok'"', 1, `p' - 1)
            local arg = substr(`"`tok'"', `p' + 1, .)
            if substr(`"`arg'"', -1, 1) == ")" {
                local arg = substr(`"`arg'"', 1, strlen(`"`arg'"') - 1)
            }
        }
        local nm = strtrim(`"`nm'"')
        local lnm = strlower(`"`nm'"')
        local drop = 0
        if "`lnm'" == "keep" & `p' {
            * recorded, but NOT removed: run mode lets the real merge apply
            * its own keep(), because dropping the rows afterwards changes
            * how the key sort breaks ties and therefore the row order
            local okeep `"`arg'"'
        }
        else if `p' & strpos("generate", "`lnm'") == 1 & strlen("`lnm'") >= 3 {
            local ogen `"`arg'"'
            local drop = 1
        }
        else if !`p' & strpos("nogenerate", "`lnm'") == 1 & strlen("`lnm'") >= 5 {
            local onogen 1
            local drop = 1
        }
        else if !`p' & strpos("noreport", "`lnm'") == 1 & strlen("`lnm'") >= 5 {
            local drop = 1
        }
        else if !`p' & strpos("force", "`lnm'") == 1 & strlen("`lnm'") >= 3 {
            local oforce 1
        }
        else if !`p' & strpos("update", "`lnm'") == 1 & strlen("`lnm'") >= 3 {
            local oupd 1
        }
        else if !`p' & strpos("replace", "`lnm'") == 1 & strlen("`lnm'") >= 3 {
            local orepl 1
        }
        else if `p' & strpos("assert", "`lnm'") == 1 & strlen("`lnm'") >= 3 {
            local oasrt `"`arg'"'
        }
        if !`drop' {
            local rest = strtrim(`"`rest' `tok'"')
        }
    }

    global MM_R_BODY   : copy local body
    global MM_R_OPTS   : copy local opts
    global MM_R_OREST  : copy local rest
    global MM_R_OKEEP  : copy local okeep
    global MM_R_OGEN   : copy local ogen
    global MM_R_ONOGEN "`onogen'"
    global MM_R_OFORCE "`oforce'"
    global MM_R_OUPD   "`oupd'"
    global MM_R_OREPL  "`orepl'"
    global MM_R_OASRT  : copy local oasrt
end
