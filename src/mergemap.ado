*! version 0.3.2  21aug2026  Eric Booth
*! mergemap: static scanner for join pipelines in do-files
*! scans do-files for source/join/link/transform/filter/save/flow events and
*! writes a tab-separated journal (schema v2, 34 columns; see
*! proto/JOURNAL_SCHEMA.md). Scan mode executes nothing.

program define mergemap, rclass
    version 16

    * ---- subcommand handling -------------------------------------------
    * bare call = scan; "scan", "check", "receipt", "demo", "run" recognised
    gettoken sub rest : 0, parse(" ,")
    local onlyflagged ""
    if `"`sub'"' == "scan" {
        local 0 `"`rest'"'
    }
    else if `"`sub'"' == "check" {
        local onlyflagged "onlyflagged"
        local 0 `"`rest'"'
    }
    else if `"`sub'"' == "receipt" {
        * render the receipt for an existing journal file
        local 0 `"`rest'"'
        syntax anything(name=jfile id="journal file") [, CHECK]
        gettoken jfile : jfile
        confirm file `"`jfile'"'
        local of ""
        if "`check'" != "" local of "onlyflagged"
        _mm_receipt using `"`jfile'"', files(`jfile') mode(existing journal) `of'
        _mm_stats using `"`jfile'"'
        return local files `"`jfile'"'
        return local journal `"`jfile'"'
        return scalar N_stop   = `s_nstop'
        return scalar N_flags  = `s_nflag'
        return scalar N_joins  = `s_njoin'
        return scalar N_events = `s_nev'
        exit
    }
    else if `"`sub'"' == "demo" {
        local 0 `"`rest'"'
        _mm_demo `0'
        if `"`demojournal'"' != "" {
            _mm_stats using `"`demojournal'"'
            return local journal `"`demojournal'"'
            return scalar N_stop   = `s_nstop'
            return scalar N_flags  = `s_nflag'
            return scalar N_joins  = `s_njoin'
            return scalar N_events = `s_nev'
        }
        exit
    }
    else if `"`sub'"' == "run" {
        local 0 `"`rest'"'
        syntax [anything(name=files id="do-file list")] [, out(string)      ///
            FOLDer(string asis) EXamples(integer 0) noCHecks               ///
            warn(string) stop(string) * ]
        _mm_expand `"`files'"' `"`folder'"'
        local files `"`flist'"'
        if `"`files'"' == "" {
            _mm_usage
            exit 198
        }
        if `"`out'"' == "" local out "journal.tsv"
        capture which _mm_run
        if _rc {
            di as err "mergemap run needs _mm_run.ado, which is not installed."
            di as err "    Reinstall the package to get run mode, or use"
            di as err "    mergemap <do-files>  to scan without executing."
            exit 601
        }
        local runopts ""
        if `examples' > 0 local runopts `"`runopts' examples(`examples')"'
        if "`checks'" == "nochecks" local runopts `"`runopts' nochecks"'
        if `"`warn'"' != "" local runopts `"`runopts' warn(`warn')"'
        if `"`stop'"' != "" local runopts `"`runopts' stop(`stop')"'
        if `"`options'"' != "" local runopts `"`runopts' `options'"'
        local runopts = strtrim(`"`runopts'"')
        if `"`runopts'"' != "" local runopts `", `runopts'"'
        global MM_LASTJ `"`out'"'
        _mm_run `"`files'"', out(`"`out'"') `runopts'
        exit
    }
    else if `"`sub'"' == "draw" {
        _mm_draw `rest'
        return add
        exit
    }
    else if `"`sub'"' == "sql" {
        _mm_sql `rest'
        exit
    }
    else if `"`sub'"' == "list" {
        _mm_list `rest'
        return add
        exit
    }
    else if `"`sub'"' == "detail" {
        _mm_detail `rest'
        return add
        exit
    }
    else if `"`sub'"' == "export" {
        _mm_export `rest'
        return add
        exit
    }
    else if `"`sub'"' == "clear" {
        _mm_clear
        exit
    }

    * ---- scan / check ---------------------------------------------------
    * noRECEIPT declaration accepts both "receipt" and "noreceipt" tokens;
    * local receipt=="noreceipt" only when the user negated it
    syntax [anything(name=files id="do-file list")] [, out(string)          ///
        noRECEIPT FOLDer(string asis)]
    _mm_expand `"`files'"' `"`folder'"'
    local files `"`flist'"'
    if `"`files'"' == "" {
        _mm_usage
        exit 198
    }
    if `"`out'"' == "" local out "journal.tsv"

    * ---- reset scan state ----
    global MM_SEQ = 0
    global MM_TMPF ""
    global MM_DEPTH = 0
    global MM_CD ""
    global MM_CDBAD = 0
    global MM_NSV = 0
    global MM_INP ""
    capture macro drop MM_TFO_*
    capture macro drop MM_LINK_*
    capture macro drop MM_SVP*
    capture macro drop MM_SVW*

    * ---- open journal, write the v2 header (34 columns) ----
    tempname jh
    quietly file open `jh' using `"`out'"', write text replace
    global MM_JH `jh'
    file write `jh' "seq" _tab "dofile" _tab "line" _tab "class" _tab "cmd" _tab   ///
        "subtype" _tab "keys" _tab "master" _tab "usingfile" _tab "result" _tab    ///
        "n_in" _tab "k_in" _tab "n_using" _tab "k_using" _tab "n_out" _tab "k_out" _tab ///
        "m1" _tab "m2" _tab "m3" _tab "m4" _tab "m5" _tab                          ///
        "dup_master" _tab "dup_using" _tab "force" _tab "opts" _tab                ///
        "loop_n" _tab "loop_first" _tab "loop_last" _tab                           ///
        "severity" _tab "keytypes" _tab "cover_master" _tab "cover_using" _tab     ///
        "lifecycle" _tab "flags" _n

    * ---- scan each file ----
    foreach f of local files {
        _mm_scanfile `"`f'"'
    }
    file close `jh'
    macro drop MM_JH

    * ---- receipt (default on; noreceipt arrives in local receipt) ----
    if "`receipt'" != "noreceipt" {
        _mm_receipt using `"`out'"', files(`files') `onlyflagged'
    }
    di as txt "mergemap: $MM_SEQ events written to " as res `"`out'"'

    _mm_stats using `"`out'"'
    * remembered (in a global, so it survives -clear all-) for -mergemap draw-
    global MM_LASTJ `"`out'"'
    return local files   `"`files'"'
    return local journal `"`out'"'
    return scalar N_stop   = `s_nstop'
    return scalar N_flags  = `s_nflag'
    return scalar N_joins  = `s_njoin'
    return scalar N_events = `s_nev'
end

* ------------------------------------------------------- usage hint (B6)
program define _mm_usage
    di as txt ""
    di as txt "mergemap draws the join pipeline hidden in your do-files."
    di as txt "It reads the code; in scan mode it executes nothing."
    di as txt ""
    di as txt "    mergemap 01_build.do 02_panel.do   scan these do-files"
    di as txt "    mergemap *.do                      scan every do-file here"
    di as txt "    mergemap .                         scan this folder"
    di as txt "    mergemap , folder(build)           scan another folder"
    di as txt "    mergemap check *.do                show only the flagged events"
    di as txt "    mergemap demo                      write and scan a worked example"
    di as txt ""
    di as txt "See {help mergemap} for the full syntax, or run {stata mergemap demo}."
    di as txt ""
end

* ------------------------------------------- expand a do-file list (B2-B7)
* accepts explicit names, shell-style wildcards, and directories; forgives a
* missing .do extension; suggests near misses on a typo. -> c_local flist
program define _mm_expand
    args spec fold
    local out ""
    if `"`fold'"' != "" {
        _mm_dirfiles `"`fold'"' "*.do"
        if `"`dflist'"' == "" {
            di as err `"mergemap: no .do files in folder `fold'"'
            exit 601
        }
        di as txt `"mergemap: scanning `ndf' do-file(s) in `fold' in name order"'
        local out `"`out' `dflist'"'
    }
    foreach tok of local spec {
        if `"`tok'"' == "" continue
        * ---- wildcard pattern ----
        if strpos(`"`tok'"', "*") | strpos(`"`tok'"', "?") {
            _mm_splitpath `"`tok'"'
            _mm_dirfiles `"`pdir'"' `"`pbase'"'
            if `"`dflist'"' == "" {
                di as err `"mergemap: no files match `tok'"'
                exit 601
            }
            di as txt `"mergemap: `tok' matched `ndf' file(s), scanned in name order"'
            local out `"`out' `dflist'"'
            continue
        }
        * ---- a directory in the positional slot ----
        local isdir = 0
        mata: st_local("isdir", strofreal(direxists(st_local("tok"))))
        if `isdir' {
            _mm_dirfiles `"`tok'"' "*.do"
            if `"`dflist'"' == "" {
                di as err `"mergemap: no .do files in folder `tok'"'
                exit 601
            }
            di as txt `"mergemap: `tok' is a folder; scanning `ndf' do-file(s) in name order"'
            local out `"`out' `dflist'"'
            continue
        }
        * ---- plain file ----
        capture confirm file `"`tok'"'
        if !_rc {
            _mm_qpath `"`tok'"'
            local out `"`out' `qp'"'
            continue
        }
        * ---- missing .do extension ----
        _mm_extfix `"`tok'"'
        if !`hasext' {
            capture confirm file `"`tok'.do"'
            if !_rc {
                di as txt `"mergemap: reading `tok'.do"'
                _mm_qpath `"`tok'.do"'
                local out `"`out' `qp'"'
                continue
            }
        }
        * ---- not found: offer near misses ----
        di as err `"mergemap: file `tok' not found"'
        _mm_suggest `"`tok'"'
        if `"`sugg'"' != "" {
            di as err `"          did you mean `sugg'?"'
        }
        else {
            di as err `"          check the spelling, or run mergemap with no"'
            di as err `"          arguments for the usage hint"'
        }
        exit 601
    }
    c_local flist = strtrim(`"`out'"')
end

* wrap a path in quotes only when it contains a space, so a do-file list stays
* a plain token list: -syntax anything- re-wraps a list that already carries
* embedded quotes into a single element, which breaks -foreach- downstream
program define _mm_qpath
    args p
    if strpos(`"`p'"', " ") {
        c_local qp `""`p'""'
        exit
    }
    c_local qp `"`p'"'
end

* split a path into directory (with trailing separator) and last component
program define _mm_splitpath
    args p
    local q = max(strrpos(`"`p'"', "/"), strrpos(`"`p'"', char(92)))
    if `q' {
        c_local pdir  = substr(`"`p'"', 1, `q')
        c_local pbase = substr(`"`p'"', `q' + 1, .)
    }
    else {
        c_local pdir  ""
        c_local pbase `"`p'"'
    }
end

* list a directory, sorted by name -> c_local dflist (quoted, dir-prefixed), ndf
program define _mm_dirfiles
    args d pat
    local dd `"`d'"'
    if `"`dd'"' == "" local dd "."
    * trailing separator is optional on input; normalise for the prefix
    local pfx `"`dd'"'
    if `"`pfx'"' == "." | `"`pfx'"' == "./" local pfx ""
    else if !inlist(substr(`"`pfx'"', -1, 1), "/", char(92)) local pfx `"`pfx'/"'
    local raw ""
    capture local raw : dir `"`dd'"' files `"`pat'"'
    * insertion sort by lowercased name (the dir macro function does not sort)
    local sorted ""
    foreach n of local raw {
        local placed = 0
        local newl ""
        foreach s of local sorted {
            if !`placed' {
                if lower(`"`n'"') < lower(`"`s'"') {
                    local newl `"`newl' "`n'""'
                    local placed = 1
                }
            }
            local newl `"`newl' "`s'""'
        }
        if !`placed' local newl `"`newl' "`n'""'
        local sorted `"`newl'"'
    }
    local outl ""
    local k = 0
    foreach n of local sorted {
        local ++k
        _mm_qpath `"`pfx'`n'"'
        local outl `"`outl' `qp'"'
    }
    c_local dflist = strtrim(`"`outl'"')
    c_local ndf `k'
end

* near-miss suggestions for a not-found file (B7) -> c_local sugg
program define _mm_suggest
    args tok
    _mm_splitpath `"`tok'"'
    local d `"`pdir'"'
    local b `"`pbase'"'
    _mm_dirfiles `"`d'"' "*.do"
    local hits ""
    local nh = 0
    foreach f of local dflist {
        _mm_splitpath `"`f'"'
        _mm_near `"`b'"' `"`pbase'"'
        if `isnear' {
            local ++nh
            if `nh' <= 3 local hits `"`hits' `f'"'
        }
    }
    if `nh' == 0 {
        * try again ignoring a missing extension on the typed name
        foreach f of local dflist {
            _mm_splitpath `"`f'"'
            _mm_near `"`b'"' `"`pbase'.do"'
            if `isnear' {
                local ++nh
                if `nh' <= 3 local hits `"`hits' `f'"'
            }
        }
    }
    local s = strtrim(`"`hits'"')
    local s : subinstr local s " " " or ", all
    c_local sugg `"`s'"'
end

* is b a plausible typo of a? (case, prefix, one edit, one transposition)
program define _mm_near
    args a b
    local A = lower(`"`a'"')
    local B = lower(`"`b'"')
    local n = 0
    if `"`A'"' == `"`B'"' local n = 1
    if !`n' {
        local la = strlen(`"`A'"')
        local lb = strlen(`"`B'"')
        if `la' < `lb' & `la' >= 3 {
            if substr(`"`B'"', 1, `la') == `"`A'"' local n = 1
        }
        if `lb' < `la' & `lb' >= 3 {
            if substr(`"`A'"', 1, `lb') == `"`B'"' local n = 1
        }
        if !`n' & `la' == `lb' {
            local d    = 0
            local pos  = 0
            local pos2 = 0
            forvalues i = 1/`la' {
                if substr(`"`A'"', `i', 1) != substr(`"`B'"', `i', 1) {
                    local ++d
                    if `d' == 1 local pos  = `i'
                    if `d' == 2 local pos2 = `i'
                }
            }
            if `d' <= 1 local n = 1
            if `d' == 2 & `pos2' == `pos' + 1 {
                if substr(`"`A'"', `pos', 1) == substr(`"`B'"', `pos2', 1) {
                    if substr(`"`A'"', `pos2', 1) == substr(`"`B'"', `pos', 1) local n = 1
                }
            }
        }
        if !`n' & abs(`la' - `lb') == 1 {
            if `la' > `lb' {
                local L `"`A'"'
                local S `"`B'"'
            }
            else {
                local L `"`B'"'
                local S `"`A'"'
            }
            local LL = strlen(`"`L'"')
            forvalues i = 1/`LL' {
                local cand = substr(`"`L'"', 1, `i' - 1) + substr(`"`L'"', `i' + 1, .)
                if `"`cand'"' == `"`S'"' {
                    local n = 1
                    continue, break
                }
            }
        }
    }
    c_local isnear `n'
end

* ---------------------------------------------------------------- scan one file
program define _mm_scanfile
    args path
    capture confirm file `"`path'"'
    if _rc {
        di as err `"mergemap: file `path' not found"'
        exit 601
    }
    global MM_DEPTH = $MM_DEPTH + 1
    local fr "_mm_l$MM_DEPTH"
    capture frame drop `fr'
    frame create `fr'
    frame `fr' {
        qui gen long ln = .
        qui gen strL st = ""
    }
    * basename and directory of this file
    local base `"`path'"'
    local p = max(strrpos(`"`path'"', "/"), strrpos(`"`path'"', char(92)))
    local dir ""
    if `p' {
        local base = substr(`"`path'"', `p' + 1, .)
        local dir  = substr(`"`path'"', 1, `p')
    }
    * staleness inputs are tracked per do-file; nested files get their own list
    local saveinp : copy global MM_INP
    global MM_INP ""
    _mm_prep `"`path'"' `fr'
    frame `fr': local N = _N
    if `N' {
        _mm_process, frame(`fr') from(1) to(`N') dofile(`base') dir(`dir')
    }
    capture frame drop `fr'
    global MM_INP `"`saveinp'"'
    global MM_DEPTH = $MM_DEPTH - 1
end

* ------------------------------------------- preprocess file into logical stmts
* joins /// continuations, strips // and /* */ comments (nesting tracked),
* skips strings, handles #delimit ; regions (best effort, split on ;)
* NOTE: backtick, dollar, and right quote are replaced by placeholder chars
* char(1)/char(2)/char(3) immediately after each read so that later macro
* references to the text can never re-expand code the scanner is only
* supposed to look at, and so that a source-level `"..."' pair cannot
* close the scanner's own compound-quote wrappers early (the backtick is
* placeholdered, so the raw "' would otherwise dangle); the journal writer
* swaps them back at output time.
program define _mm_prep
    args path fr
    local ph1 = char(1)
    local ph2 = char(2)
    local ph3 = char(3)
    tempname rh
    file open `rh' using `"`path'"', read text
    local lineno  = 0
    local acc     ""
    local accln   = 0
    local indelim = 0
    local blockd  = 0
    file read `rh' line
    while r(eof) == 0 {
        local ++lineno
        local line : subinstr local line "\`" "`ph1'", all
        local line : subinstr local line "\$" "`ph2'", all
        local line : subinstr local line "'" "`ph3'", all
        * ---- #delimit directive line (outside block comments) ----
        if `blockd' == 0 {
            local tl = strtrim(`"`line'"')
            local w1 ""
            if substr(`"`tl'"', 1, 2) == "#d" {
                local tl : subinstr local tl ";" " ;", all
                gettoken w1 arg : tl
            }
            local isdel = 0
            if `"`w1'"' != "" {
                if strpos("#delimit", `"`w1'"') == 1 & strlen(`"`w1'"') >= 2 local isdel = 1
            }
            if `isdel' {
                local arg = strtrim(`"`arg'"')
                if `"`arg'"' == ";" {
                    local indelim = 1
                    frame post `fr' (`lineno') ("#delimit ;")
                }
                else {
                    if strtrim(`"`acc'"') != "" {
                        frame post `fr' (`accln') (`"`acc'"')
                    }
                    local acc ""
                    local accln = 0
                    local indelim = 0
                }
                file read `rh' line
                continue
            }
        }
        * ---- whole-line star comment (cr mode, no pending statement) ----
        if `blockd' == 0 & `indelim' == 0 & `"`acc'"' == "" {
            local tl = strltrim(`"`line'"')
            if substr(`"`tl'"', 1, 1) == "*" {
                file read `rh' line
                continue
            }
        }
        * ---- character scan ----
        local L = strlen(`"`line'"')
        local i     = 1
        local segst = 1
        local cont  = 0
        local dq    = 0
        local cqd   = 0
        while `i' <= `L' {
            if `blockd' > 0 {
                if substr(`"`line'"', `i', 2) == "*/" {
                    local blockd = `blockd' - 1
                    local i = `i' + 2
                    if `blockd' == 0 local segst = `i'
                    continue
                }
                if substr(`"`line'"', `i', 2) == "/*" {
                    local blockd = `blockd' + 1
                    local i = `i' + 2
                    continue
                }
                local ++i
                continue
            }
            if `dq' {
                if substr(`"`line'"', `i', 1) == char(34) local dq = 0
                local ++i
                continue
            }
            if `cqd' > 0 {
                if substr(`"`line'"', `i', 2) == char(1) + char(34) {
                    local cqd = `cqd' + 1
                    local i = `i' + 2
                    continue
                }
                if substr(`"`line'"', `i', 2) == char(34) + char(3) {
                    local cqd = `cqd' - 1
                    local i = `i' + 2
                    continue
                }
                local ++i
                continue
            }
            * top level
            if substr(`"`line'"', `i', 2) == char(1) + char(34) {
                local cqd = 1
                local i = `i' + 2
                continue
            }
            if substr(`"`line'"', `i', 1) == char(34) {
                local dq = 1
                local ++i
                continue
            }
            if substr(`"`line'"', `i', 2) == "//" {
                local isblank = 0
                if `i' == 1 local isblank = 1
                else if inlist(substr(`"`line'"', `i' - 1, 1), " ", char(9)) local isblank = 1
                if `isblank' {
                    if substr(`"`line'"', `i', 3) == "///" local cont = 1
                    if `i' > `segst' local acc = `"`acc'"' + substr(`"`line'"', `segst', `i' - `segst')
                    local segst = `L' + 1
                    local i = `L' + 1
                    continue
                }
            }
            if substr(`"`line'"', `i', 2) == "/*" {
                if `i' > `segst' local acc = `"`acc'"' + substr(`"`line'"', `segst', `i' - `segst')
                local acc = `"`acc'"' + " "
                local blockd = 1
                local i = `i' + 2
                continue
            }
            if `indelim' & substr(`"`line'"', `i', 1) == ";" {
                if `i' > `segst' local acc = `"`acc'"' + substr(`"`line'"', `segst', `i' - `segst')
                local stmt = strtrim(`"`acc'"')
                if `"`stmt'"' != "" & substr(`"`stmt'"', 1, 1) != "*" {
                    if `accln' == 0 local accln = `lineno'
                    frame post `fr' (`accln') (`"`stmt'"')
                }
                local acc ""
                local accln = 0
                local ++i
                local segst = `i'
                continue
            }
            local ++i
        }
        * end of line: flush kept segment
        if `blockd' == 0 & `segst' <= `L' {
            local acc = `"`acc'"' + substr(`"`line'"', `segst', `L' - `segst' + 1)
        }
        if strtrim(`"`acc'"') != "" & `accln' == 0 local accln = `lineno'
        * statement termination
        if `blockd' == 0 & `indelim' == 0 & `cont' == 0 {
            local stmt = strtrim(`"`acc'"')
            if `"`stmt'"' != "" & substr(`"`stmt'"', 1, 1) != "*" {
                frame post `fr' (`accln') (`"`stmt'"')
            }
            local acc ""
            local accln = 0
        }
        else if `"`acc'"' != "" {
            local acc = `"`acc'"' + " "
        }
        file read `rh' line
    }
    local stmt = strtrim(`"`acc'"')
    if `"`stmt'"' != "" & substr(`"`stmt'"', 1, 1) != "*" {
        frame post `fr' (`accln') (`"`stmt'"')
    }
    file close `rh'
end

* ------------------------------------------------- walk statements, find loops
program define _mm_process
    syntax, frame(name) from(integer) to(integer) dofile(string asis)  ///
        [dir(string asis) lv(string) lkind(string) lln(string)         ///
         lfirst(string asis) llast(string asis)]
    local i = `from'
    while `i' <= `to' {
        frame `frame' {
            local st = st[`i']
            local ln = ln[`i']
        }
        local sst = strtrim(`"`st'"')
        if `"`sst'"' == "}" {
            local ++i
            continue
        }
        global MM_STMT `"`sst'"'
        _mm_peel
        local s : copy global MM_STMT
        gettoken w : s, parse(" ,")
        local isloop = 0
        if `"`w'"' == "foreach" local isloop = 1
        if `"`w'"' != "" {
            if strpos("forvalues", `"`w'"') == 1 & strlen(`"`w'"') >= 4 local isloop = 1
        }
        if `isloop' {
            * find matching closing brace
            global MM_STMT `"`s'"'
            _mm_nbraces
            local depth = `nb'
            if `depth' <= 0 local depth = 1
            local j = `i'
            while `depth' > 0 & `j' < `to' {
                local ++j
                frame `frame': local s2 = st[`j']
                global MM_STMT `"`s2'"'
                _mm_nbraces
                local depth = `depth' + `nb'
            }
            local bend = `j' - 1
            if `depth' > 0 local bend = `to'
            * parse loop header
            global MM_STMT `"`s'"'
            _mm_loophdr
            if `i' + 1 <= `bend' {
                _mm_process, frame(`frame') from(`=`i'+1') to(`bend')       ///
                    dofile(`dofile') dir(`dir') lv(`hlv') lkind(`hkind')    ///
                    lln(`hn') lfirst(`hfirst') llast(`hlast')
            }
            local i = `j' + 1
            continue
        }
        global MM_STMT `"`s'"'
        _mm_stmt, dofile(`dofile') line(`ln') dir(`dir') lv(`lv')           ///
            lkind(`lkind') lln(`lln') lfirst(`lfirst') llast(`llast')
        local ++i
    }
end

* ------------------------------------------------ peel prefix chains off $MM_STMT
program define _mm_peel
    local s : copy global MM_STMT
    local go = 1
    while `go' {
        local s = strltrim(`"`s'"')
        if `"`s'"' == "" continue, break
        gettoken tok rest : s, parse(" :,")
        if `"`tok'"' == ":" {
            local s `"`rest'"'
            continue
        }
        if `"`tok'"' == "version" {
            gettoken v rest2 : rest, parse(" :,")
            local s `"`rest2'"'
            continue
        }
        local peel = 0
        if `"`tok'"' != "" {
            if strpos("quietly", `"`tok'"') == 1 & strlen(`"`tok'"') >= 3 local peel = 1
            if strpos("noisily", `"`tok'"') == 1 & strlen(`"`tok'"') >= 1 local peel = 1
            if strpos("capture", `"`tok'"') == 1 & strlen(`"`tok'"') >= 3 local peel = 1
        }
        if `peel' local s `"`rest'"'
        else local go = 0
    }
    global MM_STMT `"`s'"'
end

* -------------------------------------- net brace count of $MM_STMT (skip strings)
program define _mm_nbraces
    local s : copy global MM_STMT
    local L = strlen(`"`s'"')
    local i   = 1
    local dq  = 0
    local cqd = 0
    local n   = 0
    while `i' <= `L' {
        if `dq' {
            if substr(`"`s'"', `i', 1) == char(34) local dq = 0
            local ++i
            continue
        }
        if `cqd' > 0 {
            if substr(`"`s'"', `i', 2) == char(1) + char(34) {
                local cqd = `cqd' + 1
                local i = `i' + 2
                continue
            }
            if substr(`"`s'"', `i', 2) == char(34) + char(3) {
                local cqd = `cqd' - 1
                local i = `i' + 2
                continue
            }
            local ++i
            continue
        }
        if substr(`"`s'"', `i', 2) == char(1) + char(34) {
            local cqd = 1
            local i = `i' + 2
            continue
        }
        if substr(`"`s'"', `i', 1) == char(34) {
            local dq = 1
            local ++i
            continue
        }
        if substr(`"`s'"', `i', 1) == "{" local ++n
        if substr(`"`s'"', `i', 1) == "}" local --n
        local ++i
    }
    c_local nb `n'
end

* --------------------------------------------- parse loop header in $MM_STMT
* returns c_local: hlv hkind (static|runtime) hn hfirst hlast
program define _mm_loophdr
    local s : copy global MM_STMT
    local hlv ""
    local hkind "runtime"
    local hn "."
    local hfirst ""
    local hlast ""
    gettoken w rest : s, parse(" ")
    if `"`w'"' == "foreach" {
        gettoken hlv rest : rest, parse(" ")
        gettoken kw rest : rest, parse(" ")
        if `"`kw'"' == "in" {
            local list = strtrim(`"`rest'"')
            if substr(`"`list'"', -1, 1) == "{" {
                local list = strtrim(substr(`"`list'"', 1, strlen(`"`list'"') - 1))
            }
            if strpos(`"`list'"', char(1)) | strpos(`"`list'"', char(2)) {
                local hkind "runtime"
            }
            else {
                local hkind "static"
                local hn : word count `list'
                local hfirst : word 1 of `list'
                local hlast : word `hn' of `list'
            }
        }
        else if `"`kw'"' == "of" {
            gettoken typ rest : rest, parse(" ")
            if `"`typ'"' == "numlist" {
                local spec = strtrim(`"`rest'"')
                if substr(`"`spec'"', -1, 1) == "{" {
                    local spec = strtrim(substr(`"`spec'"', 1, strlen(`"`spec'"') - 1))
                }
                _mm_numlist `"`spec'"'
                if `nok' {
                    local hkind "static"
                    local hn `nn'
                    local hfirst `nfirst'
                    local hlast `nlast'
                }
            }
        }
    }
    else {
        * forvalues i = spec {
        gettoken hlv rest : rest, parse(" =")
        gettoken eq rest : rest, parse(" =")
        while `"`eq'"' == " " {
            gettoken eq rest : rest, parse(" =")
        }
        local spec = strtrim(`"`rest'"')
        if substr(`"`spec'"', -1, 1) == "{" {
            local spec = strtrim(substr(`"`spec'"', 1, strlen(`"`spec'"') - 1))
        }
        _mm_numlist `"`spec'"'
        if `nok' {
            local hkind "static"
            local hn `nn'
            local hfirst `nfirst'
            local hlast `nlast'
        }
    }
    c_local hlv `hlv'
    c_local hkind `hkind'
    c_local hn `hn'
    c_local hfirst `"`hfirst'"'
    c_local hlast `"`hlast'"'
end

* ------------------------------------------ expand a simple numlist spec
* forms: a/b   a(s)b   plain space list of numbers
program define _mm_numlist
    args spec
    local nok = 0
    local spec = strtrim(`"`spec'"')
    if regexm(`"`spec'"', "^(-?[0-9]+)[ ]*/[ ]*(-?[0-9]+)$") {
        local a = real(regexs(1))
        local b = real(regexs(2))
        local s = 1
        local nok = 1
    }
    else if regexm(`"`spec'"', "^(-?[0-9]+)\((-?[0-9]+)\)(-?[0-9]+)$") {
        local a = real(regexs(1))
        local s = real(regexs(2))
        local b = real(regexs(3))
        local nok = 1
    }
    else if regexm(`"`spec'"', "^[-0-9 ]+$") {
        local nn : word count `spec'
        local nfirst : word 1 of `spec'
        local nlast : word `nn' of `spec'
        c_local nok 1
        c_local nn `nn'
        c_local nfirst `nfirst'
        c_local nlast `nlast'
        exit
    }
    if `nok' & "`s'" != "0" {
        local nn = floor((`b' - `a') / `s') + 1
        if `nn' < 1 local nok = 0
        else {
            c_local nok 1
            c_local nn `nn'
            c_local nfirst `a'
            c_local nlast = `a' + (`nn' - 1) * `s'
            exit
        }
    }
    c_local nok 0
    c_local nn "."
    c_local nfirst ""
    c_local nlast ""
end

* --------------------------------- recognize one statement ($MM_STMT), emit event
program define _mm_stmt
    syntax, dofile(string asis) line(string) [dir(string asis) lv(string)   ///
        lkind(string) lln(string) lfirst(string asis) llast(string asis)]
    local s : copy global MM_STMT
    if `"`s'"' == "" exit
    * normalize whitespace (tabs -> spaces, collapse runs) for clean journal text
    local s = stritrim(subinstr(`"`s'"', char(9), " ", .))
    gettoken tok rest : s, parse(" ,")
    _mm_cmdmatch `"`tok'"'
    if "`cmd'" == "" exit

    * defaults
    local class ""
    local subtype "."
    local keys "."
    local master "work"
    local ufile "."
    local result "work"
    local force "0"
    local opts "."
    local flags ""
    local sev "note"
    local life "."
    local xtra ""
    local xflags ""
    local recurse ""

    * split remainder at first top-level comma
    global MM_SPLIT `"`rest'"'
    _mm_split
    local body = strtrim(`"`body'"')
    local optstr = strtrim(`"`optstr'"')

    * ---------------- per-command extraction ----------------
    if "`cmd'" == "use" {
        local class "source"
        local master "."
        local life "read"
        _mm_findusing `"`body'"'
        if `"`uf'"' == "" gettoken uf : body, parse(" ,")
        _mm_norm `"`uf'"'
        local ufile `"`nfile'"'
        if "`ntf'" != "" {
            _mm_tfoflag `ntf'
            local flags = cond(`"`flags'"' == "", `"`tfflag'"', `"`flags'; `tfflag'"')
        }
        if `"`optstr'"' != "" local opts `"`optstr'"'
        _mm_noteinput `"`ufile'"' `"`dir'"'
    }
    else if "`cmd'" == "sysuse" | "`cmd'" == "webuse" {
        * a dataset that ships with Stata (or with a package); still a source
        local class "source"
        local master "."
        local life "read"
        gettoken f : body, parse(" ,")
        _mm_norm `"`f'"'
        local ufile `"`nfile'"'
        if `"`optstr'"' != "" local opts `"`optstr'"'
    }
    else if "`cmd'" == "import" {
        local class "source"
        local master "."
        local life "read"
        gettoken flav body2 : body, parse(" ,")
        local subtype `"`flav'"'
        _mm_findusing `"`body2'"'
        if `"`uf'"' == "" gettoken uf : body2, parse(" ,")
        _mm_normraw `"`uf'"'
        local ufile `"`nfile'"'
        if `"`optstr'"' != "" local opts `"`optstr'"'
        _mm_noteinput `"`ufile'"' `"`dir'"'
    }
    else if "`cmd'" == "merge" {
        local class "join"
        gettoken sub body2 : body, parse(" ,")
        local subtype `"`sub'"'
        local keys ""
        _mm_findusing `"`body2'"'
        local keys = strtrim(`"`pre'"')
        _mm_norm `"`uf'"'
        local ufile `"`nfile'"'
        if `"`optstr'"' != "" local opts `"`optstr'"'
        if "`subtype'" == "m:m" {
            local flags "!! m:m pairs rows by row order within key (not a join)"
            local sev "warn"
        }
        _mm_hasopt `"`optstr'"' force
        if `has' {
            local force "1"
            local flags = cond(`"`flags'"' == "", "!! force used", `"`flags'; !! force used"')
            local sev "warn"
        }
        _mm_hasopt `"`optstr'"' update
        local hasupd = `has'
        _mm_hasopt `"`optstr'"' replace
        if `hasupd' & `has' {
            local flags = cond(`"`flags'"' == "", "update replace", `"`flags'; update replace"')
            local sev "warn"
        }
        if regexm(`"`optstr'"', "keep\(([^)]*)\)") {
            local kc = regexs(1)
            _mm_keepnote `"`kc'"'
            if `"`knote'"' != "" {
                local flags = cond(`"`flags'"' == "", `"`knote'"', `"`flags'; `knote'"')
            }
        }
        if "`ntf'" != "" {
            _mm_tfoflag `ntf'
            local flags = cond(`"`flags'"' == "", `"`tfflag'"', `"`flags'; `tfflag'"')
        }
        _mm_noteinput `"`ufile'"' `"`dir'"'
    }
    else if "`cmd'" == "append" {
        local class "join"
        _mm_findusing `"`body'"'
        _mm_norm `"`uf'"'
        local ufile `"`nfile'"'
        * additional files on the same append line
        local xtra `"`post'"'
        if `"`optstr'"' != "" local opts `"`optstr'"'
        _mm_hasopt `"`optstr'"' force
        if `has' {
            local force "1"
            local flags "!! force used"
            local sev "warn"
        }
        local xflags `"`flags'"'
        local xsev "`sev'"
        if "`ntf'" != "" {
            _mm_tfoflag `ntf'
            local flags = cond(`"`flags'"' == "", `"`tfflag'"', `"`flags'; `tfflag'"')
        }
        _mm_noteinput `"`ufile'"' `"`dir'"'
    }
    else if "`cmd'" == "joinby" {
        local class "join"
        local subtype "m:m"
        _mm_findusing `"`body'"'
        local keys = strtrim(`"`pre'"')
        if `"`keys'"' == "" local keys "."
        _mm_norm `"`uf'"'
        local ufile `"`nfile'"'
        if "`ntf'" != "" {
            _mm_tfoflag `ntf'
            local flags = cond(`"`flags'"' == "", `"`tfflag'"', `"`flags'; `tfflag'"')
        }
        if `"`optstr'"' != "" local opts `"`optstr'"'
        _mm_noteinput `"`ufile'"' `"`dir'"'
    }
    else if "`cmd'" == "cross" {
        local class "join"
        _mm_findusing `"`body'"'
        _mm_norm `"`uf'"'
        local ufile `"`nfile'"'
        if "`ntf'" != "" {
            _mm_tfoflag `ntf'
            local flags = cond(`"`flags'"' == "", `"`tfflag'"', `"`flags'; `tfflag'"')
        }
        if `"`optstr'"' != "" local opts `"`optstr'"'
        _mm_noteinput `"`ufile'"' `"`dir'"'
    }
    else if "`cmd'" == "frlink" {
        local class "link"
        gettoken sub body2 : body, parse(" ,")
        local subtype `"`sub'"'
        local keys = strtrim(`"`body2'"')
        if `"`keys'"' == "" local keys "."
        local fname ""
        if regexm(`"`optstr'"', "frame\(([^)]*)\)") {
            local fspec = regexs(1)
            gettoken fname : fspec, parse(" ")
        }
        local lvar `"`fname'"'
        if regexm(`"`optstr'"', "gen[a-z]*\(([^)]*)\)") local lvar = regexs(1)
        if `"`fname'"' != "" {
            global MM_LINK_`lvar' `"`fname'"'
            local ufile "frame:`fname'"
        }
        if `"`optstr'"' != "" local opts `"`optstr'"'
    }
    else if "`cmd'" == "frget" | "`cmd'" == "fralias" {
        local class "link"
        local opts = strtrim(`"`rest'"')
        if substr(`"`opts'"', 1, 1) == "," local opts = strtrim(substr(`"`opts'"', 2, .))
        if `"`opts'"' == "" local opts "."
        if regexm(`"`opts'"', "from\(([^)]*)\)") {
            local lvar = regexs(1)
            local fname ""
            capture local fname : copy global MM_LINK_`lvar'
            if `"`fname'"' != "" local ufile "frame:`fname'"
        }
    }
    else if "`cmd'" == "collapse" {
        local class "transform"
        local opts = strtrim(`"`rest'"')
        if `"`opts'"' == "" local opts "."
        if regexm(`"`optstr'"', "by\(([^)]*)\)") local keys = regexs(1)
    }
    else if "`cmd'" == "contract" {
        local class "transform"
        local keys = strtrim(`"`body'"')
        if `"`keys'"' == "" local keys "."
        if `"`optstr'"' != "" local opts `"`optstr'"'
    }
    else if "`cmd'" == "reshape" {
        local class "transform"
        gettoken sub body2 : body, parse(" ,")
        local subtype `"`sub'"'
        local opts = strtrim(`"`body2'"')
        if `"`optstr'"' != "" local opts `"`opts', `optstr'"'
        if `"`opts'"' == "" local opts "."
        local keys ""
        if regexm(`"`optstr'"', "i\(([^)]*)\)") local keys = regexs(1)
        if regexm(`"`optstr'"', "j\(([^)]*)\)") {
            local jspec = regexs(1)
            gettoken jv : jspec, parse(" ")
            local keys = strtrim(`"`keys' `jv'"')
        }
        if `"`keys'"' == "" local keys "."
    }
    else if "`cmd'" == "xpose" | "`cmd'" == "sxpose" {
        local class "transform"
        if `"`optstr'"' != "" local opts `"`optstr'"'
        if "`cmd'" == "sxpose" {
            local flags "sxpose is an SSC package, not official Stata"
        }
    }
    else if "`cmd'" == "fillin" {
        local class "transform"
        local keys = strtrim(`"`body'"')
        if `"`keys'"' == "" local keys "."
    }
    else if "`cmd'" == "expand" {
        local class "transform"
        local opts = strtrim(`"`rest'"')
        if `"`opts'"' == "" local opts "."
    }
    else if "`cmd'" == "duplicates" {
        local class "transform"
        gettoken sub body2 : body, parse(" ,")
        local subtype `"`sub'"'
        local keys = strtrim(`"`body2'"')
        if `"`keys'"' == "" local keys "."
        if `"`optstr'"' != "" local opts `"`optstr'"'
        _mm_hasopt `"`optstr'"' force
        if `has' local force "1"
        if `"`subtype'"' == "drop" {
            local flags "duplicate rows on the key will be dropped"
            local sev "warn"
        }
    }
    else if "`cmd'" == "isid" {
        local class "transform"
        local keys = strtrim(`"`body'"')
        if `"`keys'"' == "" local keys "."
        if `"`optstr'"' != "" local opts `"`optstr'"'
    }
    else if "`cmd'" == "keep" | "`cmd'" == "drop" {
        * row filters and variable-list filters (DECISIONS 16a)
        local class "filter"
        local ufile "."
        local cond = strtrim(`"`rest'"')
        gettoken w1 : cond, parse(" ")
        if `"`w1'"' == "if" local subtype "if"
        else if `"`w1'"' == "in" local subtype "in"
        else local subtype "vars"
        if `"`cond'"' == "" local cond "."
        local opts `"`cond'"'
        * scan mode cannot know how many rows a condition removes; run mode
        * fills flags with the tidylog phrasing
    }
    else if "`cmd'" == "save" | "`cmd'" == "saveold" {
        local class "save"
        local ufile "."
        gettoken f : body, parse(" ,")
        if `"`f'"' == "" {
            local result "."
        }
        else {
            _mm_norm `"`f'"'
            if "`ntf'" != "" {
                local subtype "tempfile"
                local result `"`nfile'"'
                global MM_TFO_`ntf' "`dofile' line `line'"
                local flags "tempfile"
            }
            else local result `"`nfile'"'
        }
        if `"`optstr'"' != "" local opts `"`optstr'"'
        _mm_lifecycle `"`result'"' `"`dofile'"' `"`line'"' `"`dir'"'
        local life "`lcyc'"
        if `"`lflag'"' != "" {
            local flags = cond(`"`flags'"' == "", `"`lflag'"', `"`flags'; `lflag'"')
            local sev "warn"
        }
        if `"`sflag'"' != "" {
            local flags = cond(`"`flags'"' == "", `"`sflag'"', `"`flags'; `sflag'"')
            local sev "warn"
        }
    }
    else if "`cmd'" == "export" {
        local class "save"
        local ufile "."
        gettoken flav body2 : body, parse(" ,")
        local subtype `"`flav'"'
        _mm_findusing `"`body2'"'
        if `"`uf'"' == "" gettoken uf : body2, parse(" ,")
        _mm_normraw `"`uf'"'
        local result `"`nfile'"'
        if `"`optstr'"' != "" local opts `"`optstr'"'
        _mm_lifecycle `"`result'"' `"`dofile'"' `"`line'"' `"`dir'"'
        local life "`lcyc'"
        if `"`lflag'"' != "" {
            local flags = cond(`"`flags'"' == "", `"`lflag'"', `"`flags'; `lflag'"')
            local sev "warn"
        }
    }
    else if "`cmd'" == "tempfile" {
        * declaration only: track names, no event
        local b2 `"`body'"'
        while `"`b2'"' != "" {
            gettoken t b2 : b2, parse(" ,")
            if `"`t'"' != "," & `"`t'"' != "" {
                global MM_TMPF "$MM_TMPF `t'"
            }
        }
        exit
    }
    else if "`cmd'" == "cd" {
        * track the working directory so later relative paths resolve (B9)
        local class "flow"
        local master "."
        local result "."
        local tgt = strtrim(`"`rest'"')
        _mm_stripq `"`tgt'"'
        local tgt `"`sq'"'
        local ufile `"`tgt'"'
        if `"`tgt'"' == "" local ufile "."
        if strpos(`"`tgt'"', char(1)) | strpos(`"`tgt'"', char(2)) {
            global MM_CDBAD = 1
            global MM_CD ""
            local flags "cd path built from a macro; later relative paths cannot be resolved"
        }
        else {
            _mm_cdapply `"`tgt'"'
            local flags "working directory now $MM_CD ; later relative paths resolve there"
            if "$MM_CD" == "" local flags "working directory reset; later relative paths resolve as written"
        }
    }
    else if "`cmd'" == "preserve" | "`cmd'" == "restore" {
        local class "flow"
    }
    else if "`cmd'" == "do" | "`cmd'" == "run" {
        local class "flow"
        gettoken f : body, parse(" ,")
        _mm_normraw `"`f'"'
        local child `"`nfile'"'
        if strpos(`"`child'"', char(1)) | strpos(`"`child'"', char(2)) {
            local ufile `"`child'"'
            local flags "unresolved do target"
        }
        else {
            _mm_extfix `"`child'"'
            if !`hasext' local child `"`child'.do"'
            local ufile `"`child'"'
            * resolve for recursion: as written (cwd-relative), then
            * relative to the directory of the current do-file
            capture confirm file `"`child'"'
            if !_rc local recurse `"`child'"'
            else {
                capture confirm file `"`dir'`child'"'
                if !_rc local recurse `"`dir'`child'"'
            }
            if `"`recurse'"' == "" local flags "do target not found; not scanned"
            if $MM_DEPTH >= 8 {
                local recurse ""
                local flags "nesting depth limit reached; not scanned"
            }
        }
    }
    else if "`cmd'" == "#delimit" {
        local class "note"
        local master "."
        local result "."
        local flags "#delimit region: best-effort parse"
    }

    if "`class'" == "" exit

    * ---------------- loop collapse ----------------
    local loopn "."
    local loopfirst "."
    local looplast "."
    local resolved = 0
    if "`lv'" != "" {
        local needle = char(1) + "`lv'" + char(3)
        local tgt ""
        if strpos(`"`ufile'"', "`needle'") local tgt "ufile"
        else if strpos(`"`result'"', "`needle'") local tgt "result"
        if "`tgt'" != "" {
            if "`lkind'" == "static" {
                local loopn "`lln'"
                local rf : subinstr local `tgt' "`needle'" `"`lfirst'"', all
                local rl : subinstr local `tgt' "`needle'" `"`llast'"', all
                _mm_extfix `"`rf'"'
                if !`hasext' {
                    local rf `"`rf'.dta"'
                    local rl `"`rl'.dta"'
                    local `tgt' `"``tgt''.dta"'
                }
                local loopfirst `"`rf'"'
                local looplast `"`rl'"'
                local resolved = 1
            }
            else {
                local flags = cond(`"`flags'"' == "", "unresolved runtime list", ///
                    `"`flags'; unresolved runtime list"')
            }
        }
    }

    * ------- unresolved macro in a path is a designed boundary, not a bug (B8)
    if !`resolved' {
        local mflag = 0
        if strpos(`"`ufile'"', char(1)) | strpos(`"`ufile'"', char(2)) local mflag = 1
        if strpos(`"`result'"', char(1)) | strpos(`"`result'"', char(2)) local mflag = 1
        if `mflag' & !strpos(`"`flags'"', "unresolved runtime list") {
            if !strpos(`"`flags'"', "path built from a macro") {
                local pf "path built from a macro; run mode resolves it"
                local flags = cond(`"`flags'"' == "", `"`pf'"', `"`flags'; `pf'"')
            }
        }
    }

    if `"`flags'"' == "" local flags "."
    if `"`subtype'"' == "" local subtype "."
    if `"`keys'"' == "" local keys "."
    if `"`master'"' == "" local master "."
    if `"`ufile'"' == "" local ufile "."
    if `"`result'"' == "" local result "."
    if `"`opts'"' == "" local opts "."

    * ---------------- write event ----------------
    _mm_emit `"`dofile'"' `"`line'"' `"`class'"' `"`cmd'"' `"`subtype'"'   ///
        `"`keys'"' `"`master'"' `"`ufile'"' `"`result'"' `"`force'"'       ///
        `"`opts'"' `"`loopn'"' `"`loopfirst'"' `"`looplast'"'              ///
        `"`sev'"' `"`life'"' `"`flags'"'

    * extra files on a multi-file append: one event per file
    if `"`xtra'"' != "" {
        local b2 `"`xtra'"'
        while `"`b2'"' != "" {
            gettoken t b2 : b2, parse(" ,")
            if `"`t'"' == "" continue, break
            if `"`t'"' == "," continue
            _mm_norm `"`t'"'
            local f2 `"`xflags'"'
            if "`ntf'" != "" {
                _mm_tfoflag `ntf'
                local f2 = cond(`"`f2'"' == "", `"`tfflag'"', `"`f2'; `tfflag'"')
            }
            if `"`f2'"' == "" local f2 "."
            _mm_noteinput `"`nfile'"' `"`dir'"'
            _mm_emit `"`dofile'"' `"`line'"' `"`class'"' `"`cmd'"' `"`subtype'"' ///
                `"`keys'"' `"`master'"' `"`nfile'"' `"`result'"' `"`force'"'     ///
                `"`opts'"' "." "." "." `"`xsev'"' "." `"`f2'"'
        }
    }

    * recurse into a nested do-file after its flow event
    if `"`recurse'"' != "" {
        _mm_scanfile `"`recurse'"'
    }
end

* append one journal line (34 tab-separated fields; counts and run-mode
* diagnostics stay missing in scan mode)
program define _mm_emit
    args dofile line class cmd subtype keys master ufile result force ///
        opts loopn loopfirst looplast sev life flags
    global MM_SEQ = $MM_SEQ + 1
    local T = char(9)
    if `"`sev'"' == "" local sev "note"
    if `"`life'"' == "" local life "."
    local o `"$MM_SEQ`T'`dofile'`T'`line'`T'`class'`T'`cmd'`T'`subtype'`T'`keys'`T'`master'`T'`ufile'`T'`result'"'
    local o `"`o'`T'.`T'.`T'.`T'.`T'.`T'.`T'.`T'.`T'.`T'.`T'.`T'.`T'."'
    local o `"`o'`T'`force'`T'`opts'`T'`loopn'`T'`loopfirst'`T'`looplast'"'
    local o `"`o'`T'`sev'`T'.`T'.`T'.`T'`life'`T'`flags'"'
    * swap placeholder chars back to backtick/dollar/right quote at output time
    file write $MM_JH (subinstr(subinstr(subinstr(`"`o'"', char(1), char(96), .), char(2), char(36), .), char(3), char(39), .)) _n
end

* ---------------------------------------------------------------- helpers

* command word match (abbreviations per design brief)
program define _mm_cmdmatch
    args tok
    local cmd ""
    if inlist(`"`tok'"', "u", "us", "use") local cmd "use"
    else if inlist(`"`tok'"', "sysuse", "webuse") local cmd `"`tok'"'
    else if `"`tok'"' == "import" local cmd "import"
    else if inlist(`"`tok'"', "mer", "merg", "merge") local cmd "merge"
    else if inlist(`"`tok'"', "ap", "app", "appe", "appen", "append") local cmd "append"
    else if inlist(`"`tok'"', "sa", "sav", "save") local cmd "save"
    else if inlist(`"`tok'"', "joinby", "cross", "frlink", "frget", "fralias") local cmd `"`tok'"'
    else if inlist(`"`tok'"', "collapse", "contract", "reshape", "xpose", "sxpose") local cmd `"`tok'"'
    else if inlist(`"`tok'"', "fillin", "expand", "duplicates", "isid") local cmd `"`tok'"'
    else if inlist(`"`tok'"', "saveold", "export", "tempfile", "preserve", "restore") local cmd `"`tok'"'
    else if inlist(`"`tok'"', "keep", "drop") local cmd `"`tok'"'
    else if inlist(`"`tok'"', "cd", "chdir") local cmd "cd"
    else if inlist(`"`tok'"', "do", "run") local cmd `"`tok'"'
    else if `"`tok'"' == "#delimit" local cmd "#delimit"
    c_local cmd `cmd'
end

* split $MM_SPLIT at first comma outside strings -> c_local body, optstr
program define _mm_split
    local s : copy global MM_SPLIT
    local L = strlen(`"`s'"')
    local i   = 1
    local dq  = 0
    local cqd = 0
    local cut = 0
    while `i' <= `L' {
        if `dq' {
            if substr(`"`s'"', `i', 1) == char(34) local dq = 0
            local ++i
            continue
        }
        if `cqd' > 0 {
            if substr(`"`s'"', `i', 2) == char(1) + char(34) {
                local cqd = `cqd' + 1
                local i = `i' + 2
                continue
            }
            if substr(`"`s'"', `i', 2) == char(34) + char(3) {
                local cqd = `cqd' - 1
                local i = `i' + 2
                continue
            }
            local ++i
            continue
        }
        if substr(`"`s'"', `i', 2) == char(1) + char(34) {
            local cqd = 1
            local i = `i' + 2
            continue
        }
        if substr(`"`s'"', `i', 1) == char(34) {
            local dq = 1
            local ++i
            continue
        }
        if substr(`"`s'"', `i', 1) == "," {
            local cut = `i'
            continue, break
        }
        local ++i
    }
    if `cut' {
        c_local body = substr(`"`s'"', 1, `cut' - 1)
        c_local optstr = substr(`"`s'"', `cut' + 1, .)
    }
    else {
        c_local body `"`s'"'
        c_local optstr ""
    }
end

* find "using" in a token stream -> c_local uf (file token), pre (tokens before),
* post (tokens after the file, e.g. extra append files)
program define _mm_findusing
    args b
    local uf ""
    local pre ""
    local post ""
    local b2 `"`b'"'
    local found = 0
    while `"`b2'"' != "" {
        gettoken t b2 : b2, parse(" ,")
        if `"`t'"' == "" continue, break
        if `"`t'"' == "," continue
        if `found' == 0 & `"`t'"' == "using" {
            gettoken uf b2 : b2, parse(" ,")
            local found = 1
            continue
        }
        if `found' local post `"`post' `t'"'
        else local pre `"`pre' `t'"'
    }
    c_local uf `"`uf'"'
    c_local pre = strtrim(`"`pre'"')
    c_local post = strtrim(`"`post'"')
end

* normalize a dataset filename token -> c_local nfile, ntf (tempfile name or "")
* strips quotes; tempfile macro -> tempfile:name; template left alone;
* plain names get .dta appended when the last component has no extension
program define _mm_norm
    args f
    _mm_stripq `"`f'"'
    local f `"`sq'"'
    local ntf ""
    local pat = "^" + char(1) + "([A-Za-z0-9_]+)" + char(3) + "$"
    if regexm(`"`f'"', `"`pat'"') {
        local nm = regexs(1)
        local tl "$MM_TMPF"
        if `: list posof `"`nm'"' in tl' > 0 {
            c_local nfile "tempfile:`nm'"
            c_local ntf "`nm'"
            exit
        }
    }
    if strpos(`"`f'"', char(1)) | strpos(`"`f'"', char(2)) {
        c_local nfile `"`f'"'
        c_local ntf ""
        exit
    }
    _mm_extfix `"`f'"'
    if !`hasext' & `"`f'"' != "" local f `"`f'.dta"'
    c_local nfile `"`f'"'
    c_local ntf ""
end

* normalize without extension logic (import/export/do keep names as written)
program define _mm_normraw
    args f
    _mm_stripq `"`f'"'
    c_local nfile `"`sq'"'
end

* strip one layer of surrounding quotes -> c_local sq
program define _mm_stripq
    args f
    local f = strtrim(`"`f'"')
    local L = strlen(`"`f'"')
    if `L' >= 4 {
        if substr(`"`f'"', 1, 2) == char(1) + char(34) & substr(`"`f'"', -2, 2) == char(34) + char(3) {
            c_local sq = substr(`"`f'"', 3, `L' - 4)
            exit
        }
    }
    if `L' >= 2 {
        if substr(`"`f'"', 1, 1) == char(34) & substr(`"`f'"', -1, 1) == char(34) {
            c_local sq = substr(`"`f'"', 2, `L' - 2)
            exit
        }
    }
    c_local sq `"`f'"'
end

* does last path component contain an extension dot -> c_local hasext (0/1)
program define _mm_extfix
    args f
    local slash = max(strrpos(`"`f'"', "/"), strrpos(`"`f'"', char(92)))
    local lastc = substr(`"`f'"', `slash' + 1, .)
    local h = (strpos(`"`lastc'"', ".") > 0)
    c_local hasext `h'
end

* is a word present as a token in an option string -> c_local has (0/1)
program define _mm_hasopt
    args ostr word
    local has = 0
    local b2 `"`ostr'"'
    while `"`b2'"' != "" {
        gettoken t b2 : b2, parse(" ,()")
        if `"`t'"' == "" continue, break
        if `"`t'"' == "(" {
            * skip to matching )
            local d = 1
            while `d' > 0 & `"`b2'"' != "" {
                gettoken t2 b2 : b2, parse("()")
                if `"`t2'"' == "(" local ++d
                if `"`t2'"' == ")" local --d
            }
            continue
        }
        if `"`t'"' == "`word'" {
            local has = 1
            continue, break
        }
    }
    c_local has `has'
end

* keep() analysis -> c_local knote
program define _mm_keepnote
    args kc
    local have1 = 0
    local have2 = 0
    local have3 = 0
    local b2 `"`kc'"'
    while `"`b2'"' != "" {
        gettoken t b2 : b2, parse(" ,")
        if `"`t'"' == "" continue, break
        if `"`t'"' == "," continue
        if `"`t'"' == "1" | `"`t'"' == "master" local have1 = 1
        if `"`t'"' == "2" | `"`t'"' == "using" local have2 = 1
        if inlist(`"`t'"', "3", "match", "matched") local have3 = 1
        if inlist(`"`t'"', "4", "5", "match_update", "match_conflict") local have3 = 1
    }
    local drop ""
    if !`have1' local drop "master-only"
    if !`have2' {
        if `"`drop'"' != "" local drop "`drop' and using-only"
        else local drop "using-only"
    }
    if !`have3' {
        if `"`drop'"' != "" local drop "`drop' and matched"
        else local drop "matched"
    }
    if `"`drop'"' != "" c_local knote `"keep(`kc'): `drop' will be dropped"'
    else c_local knote ""
end

* tempfile-provenance flag for a using-side tempfile -> c_local tfflag
program define _mm_tfoflag
    args nm
    local o ""
    capture local o : copy global MM_TFO_`nm'
    if `"`o'"' != "" c_local tfflag `"tempfile from `o'"'
    else c_local tfflag "tempfile"
end

* ------------------------------------------- working directory tracking (B9)
* apply a literal cd argument to the tracked prefix in $MM_CD
program define _mm_cdapply
    args t
    local t = strtrim(`"`t'"')
    if `"`t'"' == "" exit
    * absolute path replaces the prefix entirely
    local abs = 0
    if substr(`"`t'"', 1, 1) == "/" local abs = 1
    if substr(`"`t'"', 1, 1) == char(92) local abs = 1
    if substr(`"`t'"', 2, 1) == ":" local abs = 1
    if `abs' {
        if !inlist(substr(`"`t'"', -1, 1), "/", char(92)) local t `"`t'/"'
        global MM_CD `"`t'"'
        global MM_CDBAD = 0
        exit
    }
    local cur : copy global MM_CD
    if `"`t'"' == "." exit
    if `"`t'"' == ".." {
        if `"`cur'"' == "" {
            global MM_CD "../"
            exit
        }
        local cur = substr(`"`cur'"', 1, strlen(`"`cur'"') - 1)
        local q = max(strrpos(`"`cur'"', "/"), strrpos(`"`cur'"', char(92)))
        if `q' global MM_CD = substr(`"`cur'"', 1, `q')
        else global MM_CD ""
        exit
    }
    if !inlist(substr(`"`t'"', -1, 1), "/", char(92)) local t `"`t'/"'
    global MM_CD `"`cur'`t'"'
end

* canonical key for a path: apply the tracked cd prefix, drop a leading ./
program define _mm_canon
    args p
    local q `"`p'"'
    local abs = 0
    if substr(`"`q'"', 1, 1) == "/" local abs = 1
    if substr(`"`q'"', 1, 1) == char(92) local abs = 1
    if substr(`"`q'"', 2, 1) == ":" local abs = 1
    if !`abs' {
        local cd : copy global MM_CD
        if `"`cd'"' != "" local q `"`cd'`q'"'
    }
    if substr(`"`q'"', 1, 2) == "./" local q = substr(`"`q'"', 3, .)
    local q : subinstr local q "/./" "/", all
    c_local cpath `"`q'"'
end

* first existing candidate for a path as written -> c_local rpath ("" if none)
program define _mm_resolve
    args p d
    if `"`p'"' == "" | `"`p'"' == "." {
        c_local rpath ""
        exit
    }
    if strpos(`"`p'"', char(1)) | strpos(`"`p'"', char(2)) {
        c_local rpath ""
        exit
    }
    if substr(`"`p'"', 1, 9) == "tempfile:" | substr(`"`p'"', 1, 6) == "frame:" {
        c_local rpath ""
        exit
    }
    _mm_canon `"`p'"'
    * checked one at a time rather than with a foreach list, so a path
    * containing a space is still a single candidate
    capture confirm file `"`p'"'
    if !_rc {
        c_local rpath `"`p'"'
        exit
    }
    if `"`cpath'"' != `"`p'"' {
        capture confirm file `"`cpath'"'
        if !_rc {
            c_local rpath `"`cpath'"'
            exit
        }
    }
    if `"`d'"' != "" {
        capture confirm file `"`d'`p'"'
        if !_rc {
            c_local rpath `"`d'`p'"'
            exit
        }
        if `"`cpath'"' != `"`p'"' {
            capture confirm file `"`d'`cpath'"'
            if !_rc {
                c_local rpath `"`d'`cpath'"'
                exit
            }
        }
    }
    c_local rpath ""
end

* remember an existing input file of the current do-file (staleness inputs)
program define _mm_noteinput
    args p d
    _mm_resolve `"`p'"' `"`d'"'
    if `"`rpath'"' == "" exit
    global MM_INP `"$MM_INP "`rpath'""'
end

* lifecycle + clobber + staleness for a save target (DECISIONS 16f)
* -> c_local lcyc (create|overwrite|.), lflag (clobber), sflag (staleness)
program define _mm_lifecycle
    args p dof ln d
    c_local lcyc "."
    c_local lflag ""
    c_local sflag ""
    if `"`p'"' == "" | `"`p'"' == "." exit
    _mm_canon `"`p'"'
    local key `"`cpath'"'
    * ---- clobber: has any earlier event in this scan saved the same path? ----
    local n = $MM_NSV
    local prev ""
    forvalues i = 1/`n' {
        local pp : copy global MM_SVP`i'
        if `"`pp'"' == `"`key'"' {
            local prev : copy global MM_SVW`i'
            continue, break
        }
    }
    local nn = `n' + 1
    global MM_NSV = `nn'
    global MM_SVP`nn' `"`key'"'
    global MM_SVW`nn' `"`dof' line `ln'"'
    if `"`prev'"' != "" {
        c_local lcyc "overwrite"
        c_local lflag `"!! also saved by `prev'"'
    }
    else {
        c_local lcyc "create"
    }
    * ---- staleness: is the file on disk older than an input it was built from? ----
    * Stata has no file-modification-time function, so the comparison uses the
    * timestamp -save- writes into a .dta header. That covers data inputs; the
    * producing do-file is plain text and carries no timestamp Stata can read
    * without shelling out, so it is not compared. Reported, never acted on:
    * rebuild orchestration belongs to -project- (DECISIONS 16f, 18c).
    _mm_resolve `"`p'"' `"`d'"'
    if `"`rpath'"' == "" exit
    _mm_ftime `"`rpath'"'
    local tout = `ftime'
    if `tout' >= . exit
    local worst ""
    local wt = .
    local ins : copy global MM_INP
    foreach f of local ins {
        _mm_ftime `"`f'"'
        if `ftime' < . & `ftime' > `tout' {
            if `wt' >= . | `ftime' > `wt' {
                local wt = `ftime'
                local worst `"`f'"'
            }
        }
    }
    if `"`worst'"' != "" {
        c_local sflag `"!! stale: `p' is older than `worst'"'
    }
end

* saved timestamp of a .dta file -> c_local ftime (Stata datetime, . if unknown)
* Stata offers no file-modification-time function, so this reads the
* <timestamp> element that -save- writes into the .dta header. Files that are
* not .dta (including do-files) report missing and are skipped by callers.
program define _mm_ftime
    args p
    local t = .
    capture confirm file `"`p'"'
    if _rc {
        c_local ftime .
        exit
    }
    if lower(substr(`"`p'"', -4, 4)) != ".dta" {
        c_local ftime .
        exit
    }
    tempname fh
    capture file open `fh' using `"`p'"', read binary
    if _rc {
        c_local ftime .
        exit
    }
    local hdr ""
    forvalues i = 1/220 {
        file read `fh' %1s ch1
        if r(eof) continue, break
        local hdr `"`hdr'`ch1'"'
    }
    capture file close `fh'
    local p1 = strpos(`"`hdr'"', "<timestamp>")
    local p2 = strpos(`"`hdr'"', "</timestamp>")
    if `p1' & `p2' > `p1' {
        local ts = substr(`"`hdr'"', `p1' + 11, `p2' - `p1' - 11)
        local ok "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz: "
        local clean ""
        local L = strlen(`"`ts'"')
        forvalues i = 1/`L' {
            local c1 = substr(`"`ts'"', `i', 1)
            if `"`c1'"' != "" {
                if strpos(`"`ok'"', `"`c1'"') local clean `"`clean'`c1'"'
            }
        }
        local clean = strtrim(`"`clean'"')
        if `"`clean'"' != "" local t = clock(`"`clean'"', "DMYhm")
    }
    c_local ftime = `t'
end

* ---------------------------------------------------------------- statistics
* journal summary -> c_local s_nev s_njoin s_nflag s_nstop
program define _mm_stats
    syntax using/
    capture frame drop _mm_st
    frame create _mm_st
    local nev = 0
    local njoin = 0
    local nflag = 0
    local nstop = 0
    frame _mm_st {
        qui import delimited using `"`using'"', delimiter(tab) varnames(1) ///
            stringcols(_all) bindquote(nobind) clear
        local nev = _N
        capture confirm variable class
        if !_rc {
            qui count if strtrim(class) == "join"
            local njoin = r(N)
        }
        capture confirm variable severity
        if !_rc {
            qui count if inlist(strtrim(severity), "warn", "stop")
            local nflag = r(N)
            qui count if strtrim(severity) == "stop"
            local nstop = r(N)
        }
    }
    capture frame drop _mm_st
    c_local s_nev   `nev'
    c_local s_njoin `njoin'
    c_local s_nflag `nflag'
    c_local s_nstop `nstop'
end

* ---------------------------------------------------------------- receipt
* One receipt style for the whole package: a light aligned table with a
* headline above it. Flags get every column the layout can spare and wrap
* onto continuation lines rather than being cut mid-word.
program define _mm_receipt
    syntax using/, [files(string asis) mode(string) ONLYflagged]
    if `"`mode'"' == "" local mode "scan mode - nothing executed"
    capture frame drop _mm_rcpt
    frame create _mm_rcpt
    frame _mm_rcpt {
        qui import delimited using `"`using'"', delimiter(tab) varnames(1) ///
            stringcols(_all) bindquote(nobind) clear
        capture confirm variable usingfile
        local notv2 = (_rc != 0)
    }
    if `notv2' {
        capture frame drop _mm_rcpt
        di as err `"mergemap: `using' is not a v2 journal (no usingfile column)"'
        di as err `"          rebuild it with: mergemap <do-files>, out(`using')"'
        exit 459
    }
    frame _mm_rcpt {
        foreach v in severity lifecycle n_in n_out loop_n {
            capture confirm variable `v'
            if _rc qui gen str1 `v' = "."
        }
        * derived display columns
        qui gen strL _cm = strtrim(cmd)
        qui replace _cm = _cm + " " + strtrim(subtype) if strtrim(subtype) != "."
        qui replace _cm = _cm + " x" + strtrim(loop_n) if strtrim(loop_n) != "."
        qui gen strL _us = strtrim(usingfile)
        qui replace _us = strtrim(result) if _us == "." & strtrim(class) == "save"
        qui replace _us = "" if _us == "."
        * a filter's payload is its condition, so show that in the target slot
        capture confirm variable opts
        if !_rc {
            qui gen strL _op = strtrim(opts)
            qui replace _op = "" if _op == "."
            qui replace _us = _op if strtrim(class) == "filter" & _op != ""
            qui replace _us = strtrim(substr(_us, 4, .)) if strtrim(class) == "filter" ///
                & (substr(_us, 1, 3) == "if " | substr(_us, 1, 3) == "in ")
        }
        qui gen strL _ky = strtrim(keys)
        qui replace _ky = "" if _ky == "."
        qui gen strL _fl = strtrim(flags)
        qui replace _fl = "" if _fl == "."
        qui gen byte _fg = inlist(strtrim(severity), "warn", "stop") | _fl != ""
        * headline counts
        local Nall = _N
        qui count if strtrim(class) == "join"
        local njoin = r(N)
        qui count if strtrim(class) == "join" & inlist(strtrim(severity), "warn", "stop")
        local njflag = r(N)
        qui count if strtrim(class) == "join" & strtrim(severity) == "stop"
        local njstop = r(N)
        qui count if inlist(strtrim(severity), "warn", "stop") & strtrim(class) != "join"
        local nother = r(N)
        qui count if strtrim(n_out) != "."
        local isrun = (r(N) > 0)
        if "`onlyflagged'" != "" {
            qui keep if _fg
        }
        local N = _N
        * natural widths
        local wsq = 3
        local wfi = 4
        local wln = 4
        local wcm = 7
        local wky = 4
        local wus = 12
        local wni = 0
        local wno = 0
        forvalues i = 1/`N' {
            local wsq = max(`wsq', strlen(strtrim(seq[`i'])))
            local wfi = max(`wfi', strlen(strtrim(dofile[`i'])))
            local wln = max(`wln', strlen(strtrim(line[`i'])))
            local wcm = max(`wcm', strlen(_cm[`i']))
            local wky = max(`wky', strlen(_ky[`i']))
            local wus = max(`wus', strlen(_us[`i']))
            if `isrun' {
                local vni = n_in[`i']
                local vno = n_out[`i']
                _mm_num `"`vni'"'
                local wni = max(`wni', strlen(`"`numf'"'))
                _mm_num `"`vno'"'
                local wno = max(`wno', strlen(`"`numf'"'))
            }
        }
    }
    local wfi = min(`wfi', 22)
    local wcm = min(`wcm', 20)
    local wky = min(`wky', 16)
    local wus = min(`wus', 32)
    if `isrun' {
        local wni = max(`wni', 5)
        local wno = max(`wno', 5)
    }
    local W = c(linesize) - 1
    if `W' < 79 local W 79
    if `W' > 199 local W 199

    * Flags get whatever the other columns leave over, and wrap rather than
    * being cut. The file name is the LAST thing shortened, so 03_analyze.do
    * keeps its name whenever the line can carry it: the count columns go
    * first, then the key column, and only then the file name.
    local shownin = `isrun'
    local showkey = 1
    local ktot  = cond(`showkey', 1 + `wky', 0)
    local extra = cond(`shownin', 1 + `wni', 0) + cond(`isrun', 1 + `wno', 0)
    local fixed = `wsq' + 1 + `wfi' + 1 + `wln' + 1 + `wcm' + `ktot' + 1 + `wus' + `extra' + 2 + 1
    local wfl   = `W' - `fixed'
    if `wfl' < 22 {
        local cut = 22 - `wfl'
        local room = `wus' - 14
        if `room' > 0 {
            local take = min(`cut', `room')
            local wus = `wus' - `take'
            local cut = `cut' - `take'
        }
        local room = `wky' - 6
        if `cut' > 0 & `room' > 0 {
            local take = min(`cut', `room')
            local wky = `wky' - `take'
            local cut = `cut' - `take'
        }
        local room = `wcm' - 10
        if `cut' > 0 & `room' > 0 {
            local take = min(`cut', `room')
            local wcm = `wcm' - `take'
            local cut = `cut' - `take'
        }
        local ktot  = cond(`showkey', 1 + `wky', 0)
        local extra = cond(`shownin', 1 + `wni', 0) + cond(`isrun', 1 + `wno', 0)
        local fixed = `wsq' + 1 + `wfi' + 1 + `wln' + 1 + `wcm' + `ktot' + 1 + `wus' + `extra' + 2 + 1
        local wfl   = `W' - `fixed'
    }
    if `wfl' < 18 & `shownin' {
        local shownin = 0
        local extra = cond(`isrun', 1 + `wno', 0)
        local fixed = `wsq' + 1 + `wfi' + 1 + `wln' + 1 + `wcm' + `ktot' + 1 + `wus' + `extra' + 2 + 1
        local wfl   = `W' - `fixed'
    }
    if `wfl' < 18 & `showkey' {
        local showkey = 0
        local ktot = 0
        local fixed = `wsq' + 1 + `wfi' + 1 + `wln' + 1 + `wcm' + `ktot' + 1 + `wus' + `extra' + 2 + 1
        local wfl   = `W' - `fixed'
    }
    if `wfl' < 14 {
        local room = `wfi' - 10
        if `room' > 0 {
            local wfi = `wfi' - min(14 - `wfl', `room')
            local fixed = `wsq' + 1 + `wfi' + 1 + `wln' + 1 + `wcm' + `ktot' + 1 + `wus' + `extra' + 2 + 1
            local wfl   = `W' - `fixed'
        }
    }
    if `wfl' < 10 local wfl 10
    local tw = `fixed' + `wfl'

    * ---- headline (DECISIONS 16d) ----
    di as txt ""
    if `njoin' == 0 {
        di as res "mergemap: no joins found in `Nall' events."
    }
    else if `njflag' == 0 {
        if `njoin' == 1 di as res "The 1 join is clean."
        else di as res "All `njoin' joins clean."
    }
    else {
        local nw = `njflag' - `njstop'
        local bits ""
        if `njstop' > 0 local bits "`njstop' stop"
        if `nw' > 0 {
            if `"`bits'"' != "" local bits "`bits', `nw' warn"
            else local bits "`nw' warn"
        }
        di as res "`njflag' of `njoin' joins flagged: `bits'."
    }
    if `nother' > 0 {
        di as txt "plus `nother' flagged event(s) outside the joins."
    }

    * ---- title ----
    * Naming three or more files in the title leaves so little room that the
    * middle-ellipsis eats the names it is meant to show ("01_cars.do mer....do").
    * Past two files, count them instead; the receipt's own file column says
    * which is which anyway.
    local fshow = subinstr(`"`files'"', char(34), "", .)
    local nfiles : word count `fshow'
    if `nfiles' > 2 {
        local fshow `"`nfiles' do-files"'
    }
    else if `nfiles' == 2 {
        local a : word 1 of `fshow'
        local b : word 2 of `fshow'
        local fshow `"`=substr("`a'", strrpos("`a'", "/") + 1, .)' `=substr("`b'", strrpos("`b'", "/") + 1, .)'"'
    }
    else if `nfiles' == 1 {
        local fshow = substr(`"`fshow'"', strrpos(`"`fshow'"', "/") + 1, .)
    }
    local ttl `"mergemap receipt: `fshow'  (`Nall' events, `mode')"'
    if "`onlyflagged'" != "" {
        local ttl `"mergemap check: `fshow'  (`N' flagged of `Nall' events)"'
    }
    _mm_mell `"`ttl'"' `=`tw'-4'
    _mm_padl `"`melled'"' `=`tw'-4'
    di as txt "{c TLC}{hline `=`tw'-2'}{c TRC}"
    di as txt `"{c |} `padded' {c |}"'
    di as txt "{c BLC}{hline `=`tw'-2'}{c BRC}"
    if `N' == 0 {
        di as txt "nothing to show"
        capture frame drop _mm_rcpt
        exit
    }

    * ---- header row ----
    _mm_padr "#" `wsq'
    local hdr "`padded'"
    _mm_padl "file" `wfi'
    local hdr "`hdr' `padded'"
    _mm_padr "line" `wln'
    local hdr "`hdr' `padded'"
    _mm_padl "command" `wcm'
    local hdr "`hdr' `padded'"
    if `showkey' {
        _mm_padl "keys" `wky'
        local hdr "`hdr' `padded'"
    }
    _mm_padl "using/result" `wus'
    local hdr "`hdr' `padded'"
    if `shownin' {
        _mm_padr "n in" `wni'
        local hdr "`hdr' `padded'"
    }
    if `isrun' {
        _mm_padr "n out" `wno'
        local hdr "`hdr' `padded'"
    }
    local hdr "`hdr' F flags"
    di as txt "`hdr'"
    di as txt "{hline `tw'}"

    * ---- rows ----
    forvalues r = 1/`N' {
        frame _mm_rcpt {
            local c1 = strtrim(seq[`r'])
            local c2 = subinstr(subinstr(subinstr(strtrim(dofile[`r']), char(96), char(1), .), char(36), char(2), .), char(39), char(3), .)
            local c3 = strtrim(line[`r'])
            local c4 = subinstr(subinstr(subinstr(_cm[`r'], char(96), char(1), .), char(36), char(2), .), char(39), char(3), .)
            local c5 = subinstr(subinstr(subinstr(_ky[`r'], char(96), char(1), .), char(36), char(2), .), char(39), char(3), .)
            local c6 = subinstr(subinstr(subinstr(_us[`r'], char(96), char(1), .), char(36), char(2), .), char(39), char(3), .)
            local c8 = strtrim(force[`r'])
            local c9 = subinstr(subinstr(subinstr(_fl[`r'], char(96), char(1), .), char(36), char(2), .), char(39), char(3), .)
            local ni = ""
            local no = ""
            if `isrun' {
                local ni = n_in[`r']
                local no = n_out[`r']
            }
        }
        _mm_padr `"`c1'"' `wsq'
        local row "`padded'"
        _mm_mell `"`c2'"' `wfi'
        _mm_padl `"`melled'"' `wfi'
        local row `"`row' `padded'"'
        _mm_padr `"`c3'"' `wln'
        local row `"`row' `padded'"'
        _mm_mell `"`c4'"' `wcm'
        _mm_padl `"`melled'"' `wcm'
        local row `"`row' `padded'"'
        if `showkey' {
            _mm_mell `"`c5'"' `wky'
            _mm_padl `"`melled'"' `wky'
            local row `"`row' `padded'"'
        }
        _mm_mell `"`c6'"' `wus'
        _mm_padl `"`melled'"' `wus'
        local row `"`row' `padded'"'
        if `shownin' {
            _mm_num `"`ni'"'
            _mm_padr `"`numf'"' `wni'
            local row `"`row' `padded'"'
        }
        if `isrun' {
            _mm_num `"`no'"'
            _mm_padr `"`numf'"' `wno'
            local row `"`row' `padded'"'
        }
        local fr = cond(`"`c8'"' == "1", "F", " ")
        local row `"`row' `fr'"'
        * flags: wrap on word boundaries onto continuation lines
        local restf `"`c9'"'
        local pad = strlen(`"`row'"') + 1
        local ind = `pad' * " "
        local first = 1
        while `first' | `"`restf'"' != "" {
            _mm_takew `"`restf'"' `wfl'
            local restf `"`rest2'"'
            if `first' {
                local outl `"`row' `chunk'"'
                local first = 0
            }
            else local outl `"`ind'`chunk'"'
            di as txt (strrtrim(subinstr(subinstr(subinstr(`"`outl'"', char(1), char(96), .), char(2), char(36), .), char(3), char(39), .)))
            if `"`restf'"' == "" continue, break
        }
    }
    di as txt "{hline `tw'}"
    if "`onlyflagged'" == "" & `Nall' > 0 {
        di as txt "`Nall' events. Severity: !! marks warn and stop."
    }
    capture frame drop _mm_rcpt
end

* take up to w chars of s, breaking at a space -> c_local chunk, rest2
program define _mm_takew
    args s w
    local s = strtrim(`"`s'"')
    if `"`s'"' == "" {
        c_local chunk ""
        c_local rest2 ""
        exit
    }
    if strlen(`"`s'"') <= `w' {
        c_local chunk `"`s'"'
        c_local rest2 ""
        exit
    }
    local cut = 0
    forvalues i = 1/`w' {
        if substr(`"`s'"', `i', 1) == " " local cut = `i'
    }
    * a single word longer than the column: hard cut, nothing better exists
    if `cut' == 0 local cut = `w' + 1
    c_local chunk = strtrim(substr(`"`s'"', 1, `cut' - 1))
    c_local rest2 = strtrim(substr(`"`s'"', `cut', .))
end

* format a count string with thousands separators -> c_local numf
program define _mm_num
    args s
    local s = strtrim(`"`s'"')
    if `"`s'"' == "." | `"`s'"' == "" {
        c_local numf ""
        exit
    }
    local v = real(`"`s'"')
    if `v' >= . {
        c_local numf `"`s'"'
        exit
    }
    local x : display %20.0fc `v'
    c_local numf = strtrim(`"`x'"')
end

* pad-left-justify (truncate with ..) -> c_local padded
program define _mm_padl
    args s w
    if strlen(`"`s'"') > `w' {
        c_local padded = substr(`"`s'"', 1, `w' - 2) + ".."
        exit
    }
    c_local padded = substr(`"`s'"' + `w' * " ", 1, `w')
end

* pad-right-justify (truncate with ..) -> c_local padded
program define _mm_padr
    args s w
    if strlen(`"`s'"') > `w' {
        c_local padded = substr(`"`s'"', 1, `w' - 2) + ".."
        exit
    }
    c_local padded = substr(`w' * " " + `"`s'"', -`w', `w')
end

* middle-ellipsis truncation, applied only when the column overflows
program define _mm_mell
    args s w
    local L = strlen(`"`s'"')
    if `L' <= `w' {
        c_local melled `"`s'"'
        exit
    }
    local keep = `w' - 3
    local lft = ceil(`keep' / 2)
    local rgt = `keep' - `lft'
    c_local melled = substr(`"`s'"', 1, `lft') + "..." + substr(`"`s'"', `L' - `rgt' + 1, `rgt')
end

* ---------------------------------------------------------------- demo (C1)
program define _mm_demo
    syntax [anything(name=dname)] [, FOLDer(string asis) replace]
    local d `"`folder'"'
    if `"`d'"' == "" & `"`dname'"' != "" {
        gettoken d : dname
    }
    if `"`d'"' == "" local d "mergemap_demo"
    local isdir = 0
    mata: st_local("isdir", strofreal(direxists(st_local("d"))))
    if `isdir' & "`replace'" == "" {
        * A folder holding a previous demo is ours to refresh.  The demo is
        * the first command a new user types and the one they retype while
        * finding their footing, so refusing on the second call turns the
        * introduction into an error.  A folder with anything else in it is
        * the user's, and that one is still refused.
        local mine = 1
        foreach f in 01_cars.do 02_join.do 03_report.do {
            capture confirm file `"`d'/`f'"'
            if _rc local mine = 0
        }
        if !`mine' {
            di as err `"mergemap: folder `d' already exists and was not written by mergemap demo."'
            di as err `"          mergemap demo, replace          write the example into it anyway"'
            di as err `"          mergemap demo, folder(name)     write somewhere else"'
            exit 602
        }
        di as txt `"mergemap demo: refreshing the example already in `d'"'
    }
    if !`isdir' {
        capture mkdir `"`d'"'
        mata: st_local("isdir", strofreal(direxists(st_local("d"))))
        if !`isdir' {
            di as err `"mergemap: could not create folder `d'"'
            exit 693
        }
    }
    _mm_demofiles `"`d'"'
    c_local demojournal `"`d'/demo_journal.tsv"'
    di as txt ""
    di as txt `"mergemap demo: wrote 3 do-files to `d'"'
    di as txt "  01_cars.do    sysuse auto -> two halves, a lookup, a 1:1 partner"
    di as txt "  02_join.do    append, an m:1 lookup, a 1:1 merge, a row filter"
    di as txt "  03_report.do  sysuse census regions, then a deliberate m:m"
    di as txt "They read and write only inside that folder, and they run."
    mergemap `"`d'/01_cars.do"' `"`d'/02_join.do"' `"`d'/03_report.do"',   ///
        out(`"`d'/demo_journal.tsv"')
    di as txt ""
    di as txt "To run the example for real:"
    di as txt `"    cd "`d'""'
    di as txt "    do 01_cars.do"
    di as txt "    do 02_join.do"
    di as txt "    do 03_report.do"
    di as txt "    cd .."
    * draw it too, and leave the journal as the draw default
    global MM_LASTJ `"`d'/demo_journal.tsv"'
    capture which _mm_rendersmcl
    if !_rc {
        _mm_rendersmcl using `"`d'/demo_journal.tsv"'
        di as txt ""
        di as txt "Redraw it any time, in other shapes:"
        di as txt `"    {stata mergemap draw:. mergemap draw}"'
        di as txt `"    . mergemap draw, export(html) saving(demo_map.html)"'
        di as txt `"    . mergemap draw, export(png) saving(demo_map)"'
    }
    else {
        di as txt ""
        di as txt "To see the receipt again without rescanning:"
        di as txt `"    mergemap receipt "`d'/demo_journal.tsv""'
    }
end

* write the three demo do-files (no macros inside them, so nothing in the
* generated text can be re-expanded by the writer)
program define _mm_demofiles
    args d
    tempname fh

    quietly file open `fh' using `"`d'/01_cars.do"', write text replace
    file write `fh' "* 01_cars.do -- build the pieces of the demo pipeline." _n
    file write `fh' "* Written by mergemap demo. Run from this folder, in order:" _n
    file write `fh' "*     do 01_cars.do" _n
    file write `fh' "*     do 02_join.do" _n
    file write `fh' "*     do 03_report.do" _n
    file write `fh' "* Everything comes from sysuse auto and sysuse census, so" _n
    file write `fh' "* nothing is downloaded and nothing outside this folder is touched." _n
    file write `fh' _n
    file write `fh' "sysuse auto, clear" _n
    file write `fh' "gen int carid = _n" _n
    file write `fh' "* a synthetic key the census file can also carry" _n
    file write `fh' "gen byte region = 1 + mod(carid, 4)" _n
    file write `fh' "save cars_all.dta, replace" _n
    file write `fh' _n
    file write `fh' "* split the file in two so 02_join.do has something to append" _n
    file write `fh' "use cars_all.dta, clear" _n
    file write `fh' "keep if carid <= 37" _n
    file write `fh' "save cars_early.dta, replace" _n
    file write `fh' _n
    file write `fh' "use cars_all.dta, clear" _n
    file write `fh' "keep if carid > 37" _n
    file write `fh' "save cars_late.dta, replace" _n
    file write `fh' _n
    file write `fh' "* one row per repair record: the m:1 lookup table" _n
    file write `fh' "use cars_all.dta, clear" _n
    file write `fh' "drop if missing(rep78)" _n
    file write `fh' "collapse (mean) rep_mpg = mpg, by(rep78)" _n
    file write `fh' "save rep_lookup.dta, replace" _n
    file write `fh' _n
    file write `fh' "* one row per car: the 1:1 partner" _n
    file write `fh' "use cars_all.dta, clear" _n
    file write `fh' "keep carid price" _n
    file write `fh' "gen double price_k = price / 1000" _n
    file write `fh' "drop price" _n
    file write `fh' "save price_index.dta, replace" _n
    file close `fh'

    quietly file open `fh' using `"`d'/02_join.do"', write text replace
    file write `fh' "* 02_join.do -- pool the two halves, then attach the lookups." _n
    file write `fh' "* Written by mergemap demo. Run after 01_cars.do." _n
    file write `fh' _n
    file write `fh' "use cars_early.dta, clear" _n
    file write `fh' _n
    file write `fh' "* append: stack the second half underneath the first" _n
    file write `fh' "append using cars_late.dta" _n
    file write `fh' _n
    file write `fh' "* m:1 lookup: many cars share one repair record" _n
    file write `fh' "merge m:1 rep78 using rep_lookup.dta, keep(1 3) nogenerate" _n
    file write `fh' _n
    file write `fh' "* 1:1 merge: one price row per car" _n
    file write `fh' "merge 1:1 carid using price_index.dta, nogenerate" _n
    file write `fh' _n
    file write `fh' "* a row filter: this is where most row loss usually happens" _n
    file write `fh' "* (the cars with no repair record found no lookup row)" _n
    file write `fh' "drop if missing(rep_mpg)" _n
    file write `fh' _n
    file write `fh' "save cars_joined.dta, replace" _n
    file close `fh'

    quietly file open `fh' using `"`d'/03_report.do"', write text replace
    file write `fh' "* 03_report.do -- attach census regions, then one deliberate mistake." _n
    file write `fh' "* Written by mergemap demo. Run after 02_join.do." _n
    file write `fh' _n
    file write `fh' "sysuse census, clear" _n
    file write `fh' "keep state region pop" _n
    file write `fh' "save census_states.dta, replace" _n
    file write `fh' _n
    file write `fh' "* one row per region: another m:1 lookup" _n
    file write `fh' "use census_states.dta, clear" _n
    file write `fh' "collapse (sum) region_pop = pop, by(region)" _n
    file write `fh' "save region_totals.dta, replace" _n
    file write `fh' _n
    file write `fh' "use cars_joined.dta, clear" _n
    file write `fh' "merge m:1 region using region_totals.dta, keep(1 3) nogenerate" _n
    file write `fh' _n
    file write `fh' "* DELIBERATE MISTAKE, so you can see what a flag looks like:" _n
    file write `fh' "* both sides have many rows per region, so m:m pairs rows by" _n
    file write `fh' "* position within region. It is not a join. mergemap flags it." _n
    file write `fh' "merge m:m region using census_states.dta" _n
    file write `fh' "drop _merge" _n
    file write `fh' _n
    file write `fh' "save demo_analysis.dta, replace" _n
    file close `fh'
end
