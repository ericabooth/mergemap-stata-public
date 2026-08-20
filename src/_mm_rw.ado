*! version 0.2.0  19aug2026  Eric Booth
*! _mm_rw -- source-to-source rewriter for mergemap run.
*!
*! The tokenizer is NOT re-implemented here.  The scanner is called first and
*! its journal supplies every (dofile, line, command) triple; this program
*! then rewrites exactly those lines in a temporary copy of the do-file,
*! replacing the command-word token in place so that prefixes survive
*! (capture noisily merge -> capture noisily _mm_merge) and line numbers are
*! preserved exactly.  A marker "#file:line#" is inserted immediately after
*! the new command word, on the same physical line, so that every wrapper can
*! name its own do-file and line in the journal without guessing.
*!
*! Lines inside a "#delimit ;" region are left alone; a single warning is
*! issued.  do/run of a literal file name is followed recursively: the child
*! is registered and rewritten too, and its index is stamped into the marker.
*!
*! Backticks, dollar signs, and right quotes are swapped for char(1)/(2)/(3)
*! the moment a line is read and swapped back at write time, so that a
*! macro-built path in the user's code can never be expanded by the rewriter
*! itself and a source-level `"..."' pair can never close the rewriter's own
*! compound quotes early.

program define _mm_rw
    version 16
    args idx
    local src  : copy global MM_R_O`idx'
    local dst  : copy global MM_R_R`idx'
    local base : copy global MM_R_B`idx'
    local p = max(strrpos(`"`src'"', "/"), strrpos(`"`src'"', char(92)))
    local sdir ""
    if `p' local sdir = substr(`"`src'"', 1, `p')

    * ---------------- 1. scan the file for (line, command) triples ----------
    tempfile sj
    capture quietly mergemap scan `"`src'"', out(`"`sj'"') noreceipt
    if _rc {
        di as err `"mergemap run: could not scan `src' (r(`=_rc'))"'
        exit 198
    }
    _mm_rwread , journal(`"`sj'"') base(`"`base'"') sdir(`"`sdir'"') idx(`idx')

    * ---------------- 2. #delimit ; regions in this file --------------------
    local ph1 = char(1)
    local ph2 = char(2)
    local ph3 = char(3)
    tempname rh wh
    file open `rh' using `"`src'"', read text
    local lineno = 0
    local indel  = 0
    local delrng ""
    file read `rh' line
    while r(eof) == 0 {
        local ++lineno
        local tl = strtrim(`"`line'"')
        if substr(`"`tl'"', 1, 2) == "#d" {
            if strpos(`"`tl'"', ";") local indel = 1
            else local indel = 0
        }
        if `indel' local delrng "`delrng' `lineno'"
        file read `rh' line
    }
    file close `rh'

    * ---------------- 3. write the instrumented copy ------------------------
    file open `rh' using `"`src'"', read text
    quietly file open `wh' using `"`dst'"', write text replace
    local lineno = 0
    local nskip  = 0
    local nrw    = 0
    file read `rh' line
    while r(eof) == 0 {
        local ++lineno
        local line : subinstr local line "\`" "`ph1'", all
        local line : subinstr local line "\$" "`ph2'", all
        local line : subinstr local line "'" "`ph3'", all
        local hit = 0
        forvalues e = 1/$MM_RW_N {
            local evln : copy global MM_RW_L`e'
            if "`evln'" == "`lineno'" & `hit' == 0 {
                local w : copy global MM_RW_W`e'
                if "`w'" != "" {
                    if strpos(" `delrng' ", " `lineno' ") {
                        local ++nskip
                    }
                    else {
                        local x : copy global MM_RW_X`e'
                        local c : copy global MM_RW_C`e'
                        global MM_R_LINE : copy local line
                        _mm_rwtok `"`c'"' `"`w'"' `"#`idx':`lineno'`x'#"'
                        local line : copy global MM_R_LINE
                        if "$MM_R_HIT" == "1" {
                            local hit = 1
                            local ++nrw
                        }
                        else {
                            di as txt "mergemap run: could not locate the " ///
                                "`c' command word at `base' line `lineno'; " ///
                                "left uninstrumented"
                        }
                    }
                }
            }
        }
        file write `wh' (subinstr(subinstr(subinstr(`"`line'"',    ///
            char(1), char(96), .), char(2), char(36), .),          ///
            char(3), char(39), .)) _n
        file read `rh' line
    }
    file close `rh'
    file close `wh'
    if `nskip' > 0 & "$MM_R_DELWARN" == "" {
        di as txt "mergemap run: `nskip' command(s) inside a #delimit ; " ///
            "region were left uninstrumented"
        global MM_R_DELWARN "1"
    }
    global MM_R_D`idx' = 1
end

* ------------------------------------------------------------------ helpers

* read the scan journal, keep the rows belonging to this do-file, and decide
* for each one which wrapper (if any) it maps to; register do/run children
program define _mm_rwread
    version 16
    syntax , journal(string) base(string) idx(integer) [sdir(string)]
    local T = char(9)
    global MM_RW_N = 0
    tempname jh
    file open `jh' using `"`journal'"', read text
    file read `jh' hline
    local hline : subinstr local hline "\`" "`=char(1)'", all
    local hline : subinstr local hline "\$" "`=char(2)'", all
    local hline : subinstr local hline "'" "`=char(3)'", all
    * column positions, by name, tolerating a trailing schema addition
    local nc = 0
    local s `"`hline'"'
    while 1 {
        local q = strpos(`"`s'"', "`T'")
        local ++nc
        if `q' {
            local f = substr(`"`s'"', 1, `q' - 1)
            local s = substr(`"`s'"', `q' + 1, .)
        }
        else {
            local f `"`s'"'
        }
        local f = strtrim(`"`f'"')
        if "`f'" == "dofile"    local cdof = `nc'
        if "`f'" == "line"      local clin = `nc'
        if "`f'" == "class"     local ccls = `nc'
        if "`f'" == "cmd"       local ccmd = `nc'
        if "`f'" == "usingfile" local cuf  = `nc'
        if "`f'" == "using"     local cuf  = `nc'
        if !`q' continue, break
    }
    if "`cdof'" == "" local cdof = 2
    if "`clin'" == "" local clin = 3
    if "`ccls'" == "" local ccls = 4
    if "`ccmd'" == "" local ccmd = 5
    if "`cuf'"  == "" local cuf  = 9

    file read `jh' line
    while r(eof) == 0 {
        local line : subinstr local line "\`" "`=char(1)'", all
        local line : subinstr local line "\$" "`=char(2)'", all
        local line : subinstr local line "'" "`=char(3)'", all
        local s `"`line'"'
        local nc = 0
        local vdof ""
        local vlin ""
        local vcls ""
        local vcmd ""
        local vuf  ""
        while 1 {
            local q = strpos(`"`s'"', "`T'")
            local ++nc
            if `q' {
                local f = substr(`"`s'"', 1, `q' - 1)
                local s = substr(`"`s'"', `q' + 1, .)
            }
            else {
                local f `"`s'"'
            }
            if `nc' == `cdof' local vdof `"`f'"'
            if `nc' == `clin' local vlin `"`f'"'
            if `nc' == `ccls' local vcls `"`f'"'
            if `nc' == `ccmd' local vcmd `"`f'"'
            if `nc' == `cuf'  local vuf  `"`f'"'
            if !`q' continue, break
        }
        if `"`vdof'"' == `"`base'"' {
            _mm_rwmap `"`vcmd'"' `"`vcls'"'
            local w "$MM_R_WRAP"
            local x ""
            if "`w'" == "_mm_do" {
                local x "d"
                if `"`vcmd'"' == "run" local x "r"
                _mm_rwkid `"`vuf'"' `"`sdir'"'
                local x "`x'$MM_R_KID"
                local x ":`x'"
            }
            if "`w'" != "" {
                local n = $MM_RW_N + 1
                global MM_RW_N = `n'
                global MM_RW_L`n' : copy local vlin
                global MM_RW_C`n' : copy local vcmd
                global MM_RW_W`n' : copy local w
                global MM_RW_X`n' : copy local x
            }
        }
        file read `jh' line
    }
    file close `jh'
end

* map a journal command word onto its wrapper; empty means "leave alone"
program define _mm_rwmap
    version 16
    args cmd cls
    local w ""
    if "`cmd'" == "use"        local w "_mm_use"
    if "`cmd'" == "import"     local w "_mm_import"
    if "`cmd'" == "merge"      local w "_mm_merge"
    if "`cmd'" == "append"     local w "_mm_append"
    if "`cmd'" == "joinby"     local w "_mm_joinby"
    if "`cmd'" == "cross"      local w "_mm_cross"
    if "`cmd'" == "frlink"     local w "_mm_frlink"
    if "`cmd'" == "frget"      local w "_mm_frget"
    if "`cmd'" == "save"       local w "_mm_save"
    if "`cmd'" == "export"     local w "_mm_export"
    if "`cmd'" == "do"         local w "_mm_do"
    if "`cmd'" == "run"        local w "_mm_do"
    if "`cmd'" == "collapse"   local w "_mm_collapse"
    if "`cmd'" == "contract"   local w "_mm_contract"
    if "`cmd'" == "reshape"    local w "_mm_reshape"
    if "`cmd'" == "duplicates" local w "_mm_duplicates"
    if "`cmd'" == "expand"     local w "_mm_expand"
    if "`cmd'" == "fillin"     local w "_mm_fillin"
    if "`cmd'" == "xpose"      local w "_mm_xpose"
    if "`cmd'" == "isid"       local w "_mm_isid"
    if "`cls'" == "filter" {
        if "`cmd'" == "drop" local w "_mm_dropif"
        if "`cmd'" == "keep" local w "_mm_keepif"
    }
    global MM_R_WRAP "`w'"
end

* register a do/run child so that it is rewritten too; sets global MM_R_KID
program define _mm_rwkid
    version 16
    args tgt sdir
    global MM_R_KID "."
    if strpos(`"`tgt'"', char(1)) | strpos(`"`tgt'"', char(2)) exit
    if `"`tgt'"' == "" | `"`tgt'"' == "." exit
    local t `"`tgt'"'
    local q = strrpos(`"`t'"', ".")
    local r = max(strrpos(`"`t'"', "/"), strrpos(`"`t'"', char(92)))
    if `q' <= `r' local t `"`t'.do"'
    local path ""
    capture confirm file `"`t'"'
    if !_rc local path `"`t'"'
    else {
        capture confirm file `"`sdir'`t'"'
        if !_rc local path `"`sdir'`t'"'
    }
    if `"`path'"' == "" exit
    if $MM_R_NF >= 32 exit
    _mm_reg , path(`"`path'"')
    global MM_R_KID "$MM_R_IDX"
end

* replace the command-word token in global MM_R_LINE, in place
program define _mm_rwtok
    version 16
    args cmd wrap tag
    global MM_R_HIT "0"
    local line : copy global MM_R_LINE
    local alt "`cmd'"
    if "`cmd'" == "use"    local alt "u us use"
    if "`cmd'" == "merge"  local alt "mer merg merge"
    if "`cmd'" == "append" local alt "ap app appe appen append"
    if "`cmd'" == "save"   local alt "sa sav save"

    local L = strlen(`"`line'"')
    local i  = 1
    local dq = 0
    local st = 0
    while `i' <= `L' + 1 {
        local c = cond(`i' <= `L', substr(`"`line'"', `i', 1), " ")
        if `"`c'"' == char(34) local dq = 1 - `dq'
        if `dq' == 0 & (`"`c'"' == " " | `"`c'"' == char(9) | `"`c'"' == ",") {
            if `st' {
                local tok = substr(`"`line'"', `st', `i' - `st')
                local ok = 0
                foreach a of local alt {
                    if `"`tok'"' == "`a'" local ok = 1
                }
                if `ok' {
                    local new = substr(`"`line'"', 1, `st' - 1) + "`wrap' `tag'" ///
                        + substr(`"`line'"', `i', .)
                    global MM_R_LINE : copy local new
                    global MM_R_HIT "1"
                    exit
                }
                local st = 0
            }
        }
        else if `st' == 0 & `"`c'"' != " " & `"`c'"' != char(9) {
            local st = `i'
        }
        local ++i
    }
end
