*! version 0.2.0  19aug2026  Eric Booth
*! _mm_rendertext: emit mermaid flowcharts (.mmd/.md), a mermaid erDiagram, and
*! Graphviz DOT (.dot) from a mergemap journal (schema v2, 34 columns).
*!
*! syntax:
*!   _mm_rendertext using journal.tsv, saving(stub)
*!       [ format(mermaid|dot|er|all) layout(vertical|horizontal|both)
*!         wrap(#) replace ]
*!
*! files written (per format/layout):
*!   stub_td.mmd stub_td.md stub_lr.mmd stub_lr.md   (mermaid flowchart TD/LR)
*!   stub_er.mmd stub_er.md                          (mermaid erDiagram)
*!   stub_tb.dot stub_lr.dot                         (DOT rankdir TB / LR)
*!
*! conventions (JOURNAL_SCHEMA.md v2 + PLAN sections 3-6):
*!   boxes = datasets; command + keys + counts ride the edges; one subgraph
*!   per do-file; collapsed loops render as ONE stacked node
*!   ("x3: raw/cps_2020.dta ... raw/cps_2022.dta"); class=filter renders as a
*!   slim node on the spine carrying the condition and the row change; dashed
*!   edges mark dropped/unmatched paths and frame view-links; severity is
*!   carried by the text marker "!!" (warn AND stop), never by colour alone;
*!   scan mode (all counts ".") omits count lines entirely; long paths get
*!   middle-ellipsis. Monochrome plus ONE accent, #4a6d8c, on flagged nodes
*!   and on the edges that reach them.
*!
*! column 9 is read BY NAME as usingfile; there is no positional fallback.

program define _mm_rendertext
    version 16
    syntax using/, SAVing(string) ///
        [ Format(string) LAYout(string) WRAP(integer 44) replace ]

    if "`format'" == "" local format all
    if !inlist("`format'", "mermaid", "dot", "er", "all") {
        di as err "format() must be mermaid, dot, er, or all"
        exit 198
    }
    if "`layout'" == "" local layout both
    if !inlist("`layout'", "vertical", "horizontal", "both") {
        di as err "layout() must be vertical, horizontal, or both"
        exit 198
    }
    if `wrap' < 16 {
        di as err "wrap() must be at least 16"
        exit 198
    }

    * ---- load the journal into a frame (contract: import delimited) ----
    tempname jrn nodes edges attrs rels
    frame create `jrn'
    frame `jrn' {
        quietly import delimited using "`using'", delimiter(tab) ///
            varnames(1) stringcols(_all) clear
        capture confirm variable usingfile
        if _rc {
            di as err "journal has no usingfile column: this is not journal"
            di as err "schema v2. Column 9 is read by name, never by position;"
            di as err "regenerate the journal with a current scanner."
            exit 459
        }
        * a journal that predates a later schema addition still renders: fill
        * any column this file does not carry. Unknown extra columns are
        * simply never referenced.
        foreach v in seq dofile line class cmd subtype keys master ///
            usingfile result n_in k_in n_using k_using n_out k_out ///
            m1 m2 m3 m4 m5 dup_master dup_using force opts ///
            loop_n loop_first loop_last severity keytypes ///
            cover_master cover_using lifecycle flags {
            capture confirm variable `v'
            if _rc quietly gen `v' = "."
        }
        quietly {
            * the scanner protects backticks, dollars and single quotes with
            * char(1)/char(2)/char(3) placeholders; restore any that survived
            * into the journal, then normalise the missing-value marker
            foreach v of varlist _all {
                replace `v' = subinstr(`v', char(1), char(96), .)
                replace `v' = subinstr(`v', char(2), char(36), .)
                replace `v' = subinstr(`v', char(3), char(39), .)
                replace `v' = trim(`v')
                replace `v' = "" if `v' == "."
            }
            replace severity = "note" if severity == ""
        }

        * headline counts for the accessible description
        quietly count if inlist(class, "join", "link")
        local n_join = r(N)
        quietly count if class == "filter"
        local n_filt = r(N)
        quietly count if inlist(class, "source", "save")
        local n_data = r(N)
        quietly count if inlist(severity, "warn", "stop") | strpos(flags, "!!")
        local n_flag = r(N)
        tempvar tag
        quietly egen byte `tag' = tag(dofile)
        quietly count if `tag'
        local n_do = r(N)
        quietly drop `tag'
    }

    * ---- provenance (16g): timestamp, Stata build, git if the tree has one --
    local jname = substr("`using'", ///
        cond(max(strrpos("`using'", "/"), strrpos("`using'", char(92))) > 0, ///
        max(strrpos("`using'", "/"), strrpos("`using'", char(92))) + 1, 1), .)
    _rt_git
    * c(flavor) reports the flavour Stata is *behaving* as (it says IC on an
    * MP binary); c(edition_real) is the build actually running, and is
    * absent on older Stata, hence the capture
    local ed ""
    capture local ed = c(edition_real)
    if "`ed'" == "" local ed "`c(flavor)'"
    local prov "mergemap _mm_rendertext 0.2.0 - journal `jname'"
    local prov "`prov' - rendered `c(current_date)' `c(current_time)'"
    local prov "`prov' - Stata `c(stata_version)' `ed'"
    if "`r(git)'" != "" local prov "`prov' - git `r(git)'"

    local acct "mergemap data-flow map of `jname'"
    local accd "`n_do' do-files, `n_data' dataset events, `n_join' joins and"
    local accd "`accd' `n_filt' filters, of which `n_flag' are flagged."
    local accd "`accd' Boxes are datasets or the dataset in memory; edges"
    local accd "`accd' carry the command, its keys and its counts. Two"
    local accd "`accd' exclamation marks flag an event that needs attention."

    * ---- build node and edge tables ----
    frame create `nodes' str12 id str2000 label str200 dofile ///
        byte flagged str8 sev str8 shape
    frame create `edges' str12 from str12 to str2000 label ///
        byte dashed byte accent
    _rt_build `jrn' `nodes' `edges' `wrap'

    * ---- emit requested variants ----
    local written ""
    if inlist("`format'", "mermaid", "all") {
        if inlist("`layout'", "vertical", "both") {
            _rt_emit, nodes(`nodes') edges(`edges') fmt(mermaid) dir(TD) ///
                out(`saving'_td.mmd) prov(`prov') acct(`acct') accd(`accd') ///
                `replace'
            _rt_emit, nodes(`nodes') edges(`edges') fmt(mermaid) dir(TD) ///
                out(`saving'_td.md) fence prov(`prov') acct(`acct') ///
                accd(`accd') title(mergemap: `jname' - mermaid, vertical) ///
                `replace'
            local written "`written' `saving'_td.mmd `saving'_td.md"
        }
        if inlist("`layout'", "horizontal", "both") {
            _rt_emit, nodes(`nodes') edges(`edges') fmt(mermaid) dir(LR) ///
                out(`saving'_lr.mmd) prov(`prov') acct(`acct') accd(`accd') ///
                `replace'
            _rt_emit, nodes(`nodes') edges(`edges') fmt(mermaid) dir(LR) ///
                out(`saving'_lr.md) fence prov(`prov') acct(`acct') ///
                accd(`accd') title(mergemap: `jname' - mermaid, horizontal) ///
                `replace'
            local written "`written' `saving'_lr.mmd `saving'_lr.md"
        }
    }
    if inlist("`format'", "er", "all") {
        frame create `attrs' str64 ent str64 aname str24 atype str3 akey
        frame create `rels' str64 lft str64 rgt str16 glyph str300 lab
        _rt_erbuild `jrn' `attrs' `rels'
        local eacc "keys and cardinality behind `jname'"
        _rt_eremit, attrs(`attrs') rels(`rels') out(`saving'_er.mmd) ///
            prov(`prov') acct(`eacc') accd(`accd') `replace'
        _rt_eremit, attrs(`attrs') rels(`rels') out(`saving'_er.md) fence ///
            prov(`prov') acct(`eacc') accd(`accd') ///
            title(mergemap: `jname' - mermaid, erDiagram) `replace'
        local written "`written' `saving'_er.mmd `saving'_er.md"
    }
    if inlist("`format'", "dot", "all") {
        if inlist("`layout'", "vertical", "both") {
            _rt_emit, nodes(`nodes') edges(`edges') fmt(dot) dir(TB) ///
                out(`saving'_tb.dot) prov(`prov') acct(`acct') accd(`accd') ///
                `replace'
            local written "`written' `saving'_tb.dot"
        }
        if inlist("`layout'", "horizontal", "both") {
            _rt_emit, nodes(`nodes') edges(`edges') fmt(dot) dir(LR) ///
                out(`saving'_lr.dot) prov(`prov') acct(`acct') accd(`accd') ///
                `replace'
            local written "`written' `saving'_lr.dot"
        }
    }

    di as txt "_mm_rendertext: `jname' -> " as res trim("`written'")
end

* ---------------------------------------------------------------------------
* _rt_git: branch@shortsha for the enclosing work tree, read straight off
* disk (.git/HEAD, .git/refs/..., .git/packed-refs). No shell call, so this
* behaves identically on macOS, Windows and Linux and under -b batch.
* Returns r(git) == "" when there is no repository above the working
* directory.
* ---------------------------------------------------------------------------
program define _rt_git, rclass
    version 16
    return local git ""
    local root "`c(pwd)'"
    local found ""
    forvalues up = 0/6 {
        capture confirm file "`root'/.git/HEAD"
        if !_rc {
            local found "`root'"
            continue, break
        }
        local pos = max(strrpos("`root'", "/"), strrpos("`root'", char(92)))
        if `pos' <= 1 continue, break
        local root = substr("`root'", 1, `pos' - 1)
    }
    if "`found'" == "" exit

    tempname fh
    file open `fh' using "`found'/.git/HEAD", read text
    file read `fh' hd
    file close `fh'
    local hd = trim(`"`hd'"')
    local br ""
    local sha ""
    if substr("`hd'", 1, 5) == "ref: " {
        local ref = trim(substr("`hd'", 6, .))
        local br = subinstr("`ref'", "refs/heads/", "", 1)
        capture confirm file "`found'/.git/`ref'"
        if !_rc {
            file open `fh' using "`found'/.git/`ref'", read text
            file read `fh' sha
            file close `fh'
        }
        else {
            capture confirm file "`found'/.git/packed-refs"
            if !_rc {
                file open `fh' using "`found'/.git/packed-refs", read text
                file read `fh' pl
                while r(eof) == 0 {
                    if strpos(`"`pl'"', " `ref'") > 0 & "`sha'" == "" {
                        local sha = substr(`"`pl'"', 1, ///
                            strpos(`"`pl'"', " ") - 1)
                    }
                    file read `fh' pl
                }
                file close `fh'
            }
        }
    }
    else {
        local br "detached"
        local sha "`hd'"
    }
    local sha = substr(trim("`sha'"), 1, 7)
    if "`br'" == "" & "`sha'" == "" exit
    return local git = trim("`br'" + cond("`sha'" == "", "", "@`sha'"))
end

* ---------------------------------------------------------------------------
* _rt_sanvar: generate newvar as a mermaid-safe identifier built from the
* file path in srcvar. Runs against whatever frame is current.
* Done as a variable, never through a local: a path such as raw/cps_`y'.dta
* read into a macro would be re-expanded by Stata and silently collapse.
* ---------------------------------------------------------------------------
program define _rt_sanvar
    version 16
    args newvar srcvar
    quietly {
        gen `newvar' = `srcvar'
        replace `newvar' = subinstr(`newvar', "tempfile:", "tempfile_", .)
        replace `newvar' = subinstr(`newvar', "frame:", "frame_", .)
        replace `newvar' = subinstr(`newvar', ".dta", "", .)
        replace `newvar' = ustrregexra(`newvar', "[^A-Za-z0-9_]+", "_")
        replace `newvar' = ustrregexra(`newvar', "^_+", "")
        replace `newvar' = ustrregexra(`newvar', "_+$", "")
        replace `newvar' = "n" + `newvar' ///
            if substr(`newvar', 1, 1) >= "0" & substr(`newvar', 1, 1) <= "9"
        replace `newvar' = "unnamed" if `newvar' == "" & `srcvar' != ""
    }
end

* ---------------------------------------------------------------------------
* _rt_build: walk the journal frame, post dataset/state/filter nodes and
* edges. Dataset nodes are deduplicated by path so a save and a later
* use/merge of the same file (tempfiles included) share one node: that is
* what carries lineage across do-files.
* ---------------------------------------------------------------------------
program define _rt_build
    version 16
    args jrn nodes edges wrap

    frame `jrn' {
        quietly {
            * formatted counts: "" when unknown (scan mode), else 52,431 style
            foreach v in n_in k_in n_using k_using n_out k_out ///
                m1 m2 m3 m4 m5 dup_master dup_using {
                gen _rtf`v' = cond(`v' == "", "", ///
                    trim(string(real(`v'), "%15.0fc")))
            }

            * ---- severity and flag text -----------------------------------
            * the marker is the text "!!", never colour: warn AND stop both
            * carry it, and stop adds a labelled line of its own
            gen _rtsev = lower(severity)
            replace _rtsev = "note" if !inlist(_rtsev, "note", "warn", "stop")
            gen _rtflag = subinstr(flags, "; ", "~~", .)
            replace _rtflag = "!! " + _rtflag ///
                if inlist(_rtsev, "warn", "stop") & _rtflag != "" ///
                & strpos(_rtflag, "!!") == 0
            replace _rtflag = "!! " + _rtsev ///
                if inlist(_rtsev, "warn", "stop") & _rtflag == ""
            replace _rtflag = "!! stop~~" + _rtflag ///
                if _rtsev == "stop" & strpos(_rtflag, "!! stop") == 0
            gen byte _rtwarn = strpos(_rtflag, "!!") > 0

            * ---- key type drift (16c): report only a genuine mismatch -----
            gen _rtktlab = ""
            gen _rtktsan = ustrregexra(keytypes, "[^A-Za-z0-9_ :;]+", " ")
            forvalues i = 1/`=_N' {
                local kt = _rtktsan[`i']
                if "`kt'" == "" continue
                local bad ""
                local rest "`kt'"
                while "`rest'" != "" {
                    local p = strpos("`rest'", ";")
                    if `p' > 0 {
                        local seg = substr("`rest'", 1, `p' - 1)
                        local rest = trim(substr("`rest'", `p' + 1, .))
                    }
                    else {
                        local seg "`rest'"
                        local rest ""
                    }
                    local c = strpos("`seg'", ":")
                    local tail = cond(`c' > 0, substr("`seg'", `c' + 1, .), "")
                    local vp = strpos("`tail'", " vs ")
                    if `vp' > 0 {
                        local ta = trim(substr("`tail'", 1, `vp' - 1))
                        local tb = trim(substr("`tail'", `vp' + 4, .))
                        if "`ta'" != "`tb'" {
                            local bad = trim("`bad' " + trim("`seg'"))
                        }
                    }
                }
                if "`bad'" != "" {
                    replace _rtktlab = "!! key type mismatch: " + "`bad'" ///
                        in `i'
                }
            }

            * ---- coverage percentages (16e) -------------------------------
            gen _rtcovm = cond(cover_master == "", "", ///
                trim(string(real(cover_master), "%9.1f")) ///
                + "% of master matched")
            gen _rtcovu = cond(cover_using == "", "", ///
                trim(string(real(cover_using), "%9.1f")) ///
                + "% of using used")

            * ---- dataset path per row (the file/frame box this row touches)
            gen _rtpath = ""
            replace _rtpath = usingfile ///
                if inlist(class, "source", "join", "link")
            replace _rtpath = result if class == "save"
            egen _rtdsid = group(_rtpath)

            * middle-ellipsis display form of the path, only on overflow
            gen _rtdisp = _rtpath
            replace _rtdisp = substr(_rtpath, 1, ceil((`wrap' - 3) / 2)) ///
                + "..." + substr(_rtpath, -floor((`wrap' - 3) / 2), .) ///
                if strlen(_rtpath) > `wrap'

            * loop stacks
            gen _rtloopn = loop_n
            gen byte _rtresolved = _rtloopn != "" & loop_first != ""
            gen byte _rtunres = strpos(_rtpath, char(96)) > 0 & !_rtresolved ///
                & inlist(class, "source", "join", "link")

            * ---- dataset node label ---------------------------------------
            gen _rtdslab = ""
            replace _rtdslab = _rtdisp ///
                if inlist(class, "source", "join", "link")
            replace _rtdslab = "x" + _rtloopn + ": " + loop_first + " ... " ///
                + loop_last if _rtresolved & inlist(class, "join", "link")
            replace _rtdslab = _rtdisp ///
                + "~~path built from a macro; run mode resolves it" ///
                if _rtunres
            replace _rtdslab = _rtdslab + "~~" + _rtfn_using + " x " ///
                + _rtfk_using if inlist(class, "source", "join", "link") ///
                & _rtfn_using != ""
            replace _rtdslab = _rtdslab + "~~" + _rtflag ///
                if class == "source" & _rtflag != ""
            gen byte _rttmp = class == "save" & (subtype == "tempfile" ///
                | strpos(result, "tempfile:") == 1)
            replace _rtdslab = _rtdisp + cond(_rttmp, " [tempfile]", ///
                cond(lifecycle == "overwrite", " [saved, overwrites]", ///
                " [saved]")) if class == "save"
            replace _rtdslab = _rtdslab + "~~" + _rtfn_out + " x " ///
                + _rtfk_out if class == "save" & _rtfn_out != ""
            replace _rtdslab = _rtdslab + "~~" + _rtflag ///
                if class == "save" & _rtflag != "" & _rtflag != "tempfile"

            * ---- state node label (result of a join/link/transform) -------
            gen _rtstate = cond(result == "", "work", result)
            gen _rtstlab = ""
            replace _rtstlab = _rtstate if inlist(class, "join", "link")
            replace _rtstlab = _rtstlab + "~~" + _rtfn_out + " x " ///
                + _rtfk_out if inlist(class, "join", "link") & _rtfn_out != ""
            replace _rtstlab = _rtstlab + "~~" + _rtflag ///
                if inlist(class, "join", "link") & _rtflag != ""
            replace _rtstlab = _rtstlab + "~~" + _rtktlab ///
                if inlist(class, "join", "link") & _rtktlab != ""

            gen _rtcmdl = cmd
            replace _rtcmdl = _rtcmdl + " " + subtype if subtype != ""
            replace _rtcmdl = _rtcmdl + " " + opts ///
                if class == "transform" & opts != ""
            replace _rtcmdl = _rtcmdl + " " + keys ///
                if class == "transform" & opts == "" & keys != ""
            replace _rtstlab = _rtcmdl if class == "transform"
            replace _rtstlab = _rtstlab + "~~" + _rtfn_in + " -> " ///
                + _rtfn_out + " obs" if class == "transform" ///
                & _rtfn_in != "" & _rtfn_out != ""
            replace _rtstlab = _rtstlab + "~~" + _rtflag ///
                if class == "transform" & _rtflag != ""

            * ---- filter node (16a): condition, then the row change --------
            * a filter is a slim node on the spine. The row change comes from
            * the tidylog-style flag in run mode, and from the obs counts if
            * the scanner supplied counts but no phrasing. Scan mode has
            * neither, so the node carries the condition alone.
            gen _rtfilt = ""
            replace _rtfilt = cmd + " " + opts if class == "filter" ///
                & subtype == "if" & substr(opts, 1, 3) == "if "
            replace _rtfilt = cmd + " if " + opts if class == "filter" ///
                & subtype == "if" & substr(opts, 1, 3) != "if "
            replace _rtfilt = cmd + cond(subtype == "", "", " " + subtype) ///
                + cond(opts != "", " " + opts, ///
                cond(keys != "", " " + keys, "")) ///
                if class == "filter" & subtype != "if"
            replace _rtfilt = trim(_rtfilt) if class == "filter"
            replace _rtfilt = _rtfilt + "~~" + _rtflag ///
                if class == "filter" & _rtflag != ""
            replace _rtfilt = _rtfilt + "~~" + _rtfn_in + " -> " ///
                + _rtfn_out + " obs" if class == "filter" & _rtflag == "" ///
                & _rtfn_in != "" & _rtfn_out != ""
            replace _rtstlab = _rtfilt if class == "filter"

            * ---- keep() contents: which _merge categories survive ---------
            gen _rtkp = ""
            replace _rtkp = substr(opts, strpos(opts, "keep(") + 5, .) ///
                if strpos(opts, "keep(")
            replace _rtkp = substr(_rtkp, 1, strpos(_rtkp, ")") - 1) ///
                if strpos(_rtkp, ")")
            gen byte _rtdropu = strpos(opts, "keep(") > 0 ///
                & strpos(_rtkp, "2") == 0
            gen byte _rtdropm = strpos(opts, "keep(") > 0 ///
                & strpos(_rtkp, "1") == 0

            * ---- master-side edge: command, options, counts, coverage -----
            gen _rtmlab = ""
            replace _rtmlab = cmd if inlist(class, "join", "link")
            replace _rtmlab = _rtmlab + " " + subtype ///
                if inlist(class, "join", "link") & subtype != ""
            replace _rtmlab = _rtmlab + " " + keys ///
                if inlist(class, "join", "link") & keys != ""
            * the options line is dropped when it merely repeats the flag
            * text, which otherwise prints the same words twice
            replace _rtmlab = _rtmlab + "~~" + opts ///
                if inlist(class, "join", "link") & opts != "" ///
                & lower(trim(opts)) != lower(trim(flags))
            gen _rtcline = ""
            replace _rtcline = "matched " + _rtfm3 ///
                if inlist(class, "join", "link") & _rtfm3 != ""
            replace _rtcline = _rtcline + cond(_rtcline == "", "", ", ") ///
                + "master-only " ///
                + cond(_rtdropm, "(" + _rtfm1 + " dropped)", _rtfm1) ///
                if inlist(class, "join", "link") & _rtfm1 != "" & real(m1) > 0
            replace _rtcline = _rtcline + cond(_rtcline == "", "", ", ") ///
                + "updated " + _rtfm4 + " missing" ///
                if inlist(class, "join", "link") & _rtfm4 != "" & real(m4) > 0
            replace _rtcline = _rtcline + cond(_rtcline == "", "", ", ") ///
                + _rtfm5 + " conflicts overwritten" ///
                if inlist(class, "join", "link") & _rtfm5 != "" & real(m5) > 0
            replace _rtcline = "+" + _rtfn_using + " obs" ///
                + cond(_rtresolved, " from " + _rtloopn + " files", "") ///
                if cmd == "append" & _rtfn_using != ""
            replace _rtmlab = _rtmlab + "~~" + _rtcline if _rtcline != ""
            replace _rtmlab = _rtmlab + "~~master-only dropped" ///
                if inlist(class, "join", "link") & _rtdropm & _rtfm1 == ""
            replace _rtmlab = _rtmlab + "~~" + _rtcovm ///
                if inlist(class, "join", "link") & _rtcovm != ""

            * ---- using-side edge; dashed when rows are dropped there ------
            gen _rtulab = ""
            gen byte _rtudash = 0
            replace _rtulab = "using-only (" + _rtfm2 + " dropped)" ///
                if inlist(class, "join", "link") & _rtfm2 != "" ///
                & real(m2) > 0 & _rtdropu
            replace _rtudash = 1 if inlist(class, "join", "link") ///
                & _rtfm2 != "" & real(m2) > 0 & _rtdropu
            replace _rtulab = "using-only " + _rtfm2 ///
                if inlist(class, "join", "link") & _rtfm2 != "" ///
                & real(m2) > 0 & !_rtdropu
            replace _rtulab = "using-only dropped by keep(" + _rtkp + ")" ///
                if inlist(class, "join", "link") & _rtfm2 == "" & _rtdropu
            replace _rtudash = 1 if inlist(class, "join", "link") ///
                & _rtfm2 == "" & _rtdropu
            replace _rtudash = 1 if inlist(cmd, "fralias", "frlink", "frget")
            replace _rtulab = _rtulab + cond(_rtulab == "", "", "~~") ///
                + _rtcovu if inlist(class, "join", "link") & _rtcovu != ""

            * labels must not carry double quotes into mermaid/DOT
            foreach v in _rtdslab _rtstlab _rtmlab _rtulab {
                replace `v' = subinstr(`v', char(34), char(39), .)
            }
        }

        * ---- event walk: post nodes and edges in journal order ------------
        local cur ""
        local declared " "
        forvalues i = 1/`=_N' {
            local cls = class[`i']
            local did = _rtdsid[`i']
            if "`cls'" == "source" {
                if strpos("`declared'", " `did' ") == 0 {
                    frame post `nodes' ("d`did'") (_rtdslab[`i']) ///
                        (dofile[`i']) (0) ("note") ("data")
                    local declared "`declared'`did' "
                }
                local cur d`did'
            }
            else if "`cls'" == "join" | "`cls'" == "link" {
                if strpos("`declared'", " `did' ") == 0 {
                    frame post `nodes' ("d`did'") (_rtdslab[`i']) ///
                        (dofile[`i']) (0) ("note") ("data")
                    local declared "`declared'`did' "
                }
                frame post `nodes' ("s`i'") (_rtstlab[`i']) ///
                    (dofile[`i']) (_rtwarn[`i']) (_rtsev[`i']) ("state")
                if "`cur'" != "" {
                    frame post `edges' ("`cur'") ("s`i'") (_rtmlab[`i']) ///
                        (0) (_rtwarn[`i'])
                }
                frame post `edges' ("d`did'") ("s`i'") (_rtulab[`i']) ///
                    (_rtudash[`i']) (_rtwarn[`i'])
                local cur s`i'
            }
            else if "`cls'" == "transform" | "`cls'" == "filter" {
                frame post `nodes' ("s`i'") (_rtstlab[`i']) ///
                    (dofile[`i']) (_rtwarn[`i']) (_rtsev[`i']) ///
                    (cond("`cls'" == "filter", "filter", "state"))
                if "`cur'" != "" {
                    frame post `edges' ("`cur'") ("s`i'") ("") (0) ///
                        (_rtwarn[`i'])
                }
                local cur s`i'
            }
            else if "`cls'" == "save" {
                if strpos("`declared'", " `did' ") == 0 {
                    frame post `nodes' ("d`did'") (_rtdslab[`i']) ///
                        (dofile[`i']) (_rtwarn[`i']) (_rtsev[`i']) ("data")
                    local declared "`declared'`did' "
                }
                if "`cur'" != "" {
                    frame post `edges' ("`cur'") ("d`did'") ///
                        (cond(cmd[`i'] == "save", "", cmd[`i'])) (0) ///
                        (_rtwarn[`i'])
                }
                * memory unchanged by save: the chain continues from `cur'
            }
            else if "`cls'" == "note" {
                frame post `nodes' ("s`i'") ///
                    (cond(_rtflag[`i'] != "", "note: " + _rtflag[`i'], ///
                    "note: " + _rtcmdl[`i'])) (dofile[`i']) (_rtwarn[`i']) ///
                    (_rtsev[`i']) ("note")
                if "`cur'" != "" {
                    frame post `edges' ("`cur'") ("s`i'") ("") (1) ///
                        (_rtwarn[`i'])
                }
                * notes hang off the chain; `cur' does not move
            }
            * class == "flow" (do/preserve/restore): no node in the prototype
        }

        quietly drop _rt*
    }
end

* ---------------------------------------------------------------------------
* _rt_erbuild: the second mermaid flavour (16j). Datasets become entities,
* join keys become attributes, and the Stata subtype becomes a mermaid
* cardinality glyph. The "master" entity of a join is the last named dataset
* the data in memory came from (a use, or the last save), so a chain of joins
* onto one working dataset renders as a star around it.
*
* Every name and label is posted straight from a frame variable that has
* already been stripped of backticks, dollars and quotes: a macro-built path
* read into a local would be re-expanded by Stata and silently collapse.
* ---------------------------------------------------------------------------
program define _rt_erbuild
    version 16
    args jrn attrs rels

    frame `jrn' {
        quietly {
            * entity name for the using side (a resolved loop is named after
            * its first file, with the iteration count appended)
            gen _rtesrc = usingfile
            replace _rtesrc = loop_first if loop_n != "" & loop_first != ""
            _rt_sanvar _rteu0 _rtesrc
            gen _rteu = _rteu0
            replace _rteu = _rteu + "_x" + loop_n ///
                if loop_n != "" & loop_first != ""
            * the entity this row names: a source names the file it read, a
            * save names the file it wrote
            _rt_sanvar _rteres result
            gen _rtecur = ""
            replace _rtecur = _rteu if class == "source"
            replace _rtecur = _rteres if class == "save"

            * macro-safe copies of the free text used for attributes/labels
            gen _rtkeysan = ustrregexra(keys, "[^A-Za-z0-9_ ]+", " ")
            gen _rtktsan  = ustrregexra(keytypes, "[^A-Za-z0-9_ :;]+", " ")
            gen _rtfrget  = cond(strpos(opts, ",") > 0, ///
                substr(opts, 1, strpos(opts, ",") - 1), opts)
            replace _rtfrget = ustrregexra(_rtfrget, "[^A-Za-z0-9_ ]+", " ")

            * cardinality glyph
            gen _rtglyph = "||--||"
            replace _rtglyph = "}o--||" if subtype == "m:1"
            replace _rtglyph = "||--o{" if subtype == "1:m"
            replace _rtglyph = "}o--o{" if subtype == "m:m"
            replace _rtglyph = "}o--o{" if cmd == "cross"
            * a dotted line is a link that does not pair rows on a key
            replace _rtglyph = "}o..o{" if cmd == "append"
            replace _rtglyph = "}o..||" if cmd == "frlink" & subtype == "m:1"
            replace _rtglyph = "||..||" if cmd == "frlink" & subtype != "m:1"

            * relationship label
            gen _rtrlab = cmd
            replace _rtrlab = _rtrlab + " " + subtype if subtype != ""
            replace _rtrlab = _rtrlab + " " + _rtkeysan if _rtkeysan != ""
            replace _rtrlab = _rtrlab + " x" + loop_n ///
                if cmd == "append" & loop_n != ""
            replace _rtrlab = _rtrlab + ", " ///
                + trim(string(real(cover_master), "%9.1f")) ///
                + "% of master matched" if cover_master != ""
            replace _rtrlab = "!! " + _rtrlab ///
                if inlist(lower(severity), "warn", "stop")
            replace _rtrlab = subinstr(_rtrlab, char(34), char(39), .)
        }

        local curj = 0
        forvalues i = 1/`=_N' {
            local cls = class[`i']
            local ecmd = cmd[`i']
            if "`cls'" == "source" | "`cls'" == "save" {
                if _rtecur[`i'] != "" local curj = `i'
            }
            else if "`cls'" == "join" | "`cls'" == "link" {
                if `curj' == 0 continue
                if _rteu[`i'] == "" continue
                if "`ecmd'" == "frget" {
                    * frget moves variables along an frlink that is already
                    * drawn: record them as attributes of the frame rather
                    * than as a second relationship
                    local vl = _rtfrget[`i']
                    foreach v of local vl {
                        frame post `attrs' (_rteu[`i']) ("`v'") ("var") ("")
                    }
                    continue
                }
                frame post `rels' (_rtecur[`curj']) (_rteu[`i']) ///
                    (_rtglyph[`i']) (_rtrlab[`i'])
                * keys become attributes on both sides, PK on whichever side
                * the cardinality says holds them uniquely
                local sub = subtype[`i']
                local mkey "FK"
                local ukey "FK"
                if "`sub'" == "1:1" {
                    local mkey "PK"
                    local ukey "PK"
                }
                else if "`sub'" == "m:1" local ukey "PK"
                else if "`sub'" == "1:m" local mkey "PK"
                local kl = _rtkeysan[`i']
                local kt = _rtktsan[`i']
                foreach k of local kl {
                    local ta "key"
                    local tb "key"
                    local p = strpos("`kt'", "`k':")
                    if `p' > 0 {
                        local tail = substr("`kt'", `p' + strlen("`k'") + 1, .)
                        local e = strpos("`tail'", ";")
                        if `e' > 0 local tail = substr("`tail'", 1, `e' - 1)
                        local vp = strpos("`tail'", " vs ")
                        if `vp' > 0 {
                            local ta = trim(substr("`tail'", 1, `vp' - 1))
                            local tb = trim(substr("`tail'", `vp' + 4, .))
                        }
                    }
                    if "`ta'" == "" local ta "key"
                    if "`tb'" == "" local tb "key"
                    frame post `attrs' (_rtecur[`curj']) ("`k'") ("`ta'") ///
                        ("`mkey'")
                    frame post `attrs' (_rteu[`i']) ("`k'") ("`tb'") ("`ukey'")
                }
            }
        }

        quietly drop _rte* _rtkeysan _rtktsan _rtfrget _rtglyph _rtrlab
    }

    * one row per (entity, attribute), PK winning over FK, entities and
    * attributes kept in order of first appearance
    frame `attrs' {
        quietly {
            if _N > 0 {
                gen long _o = _n
                gen byte _pk = akey == "PK"
                * a storage type read off the file beats the placeholder
                gen byte _kn = !inlist(atype, "key", "var")
                egen long _entfa = min(_o), by(ent)
                egen long _atfa = min(_o), by(ent aname)
                bysort ent aname (_pk _kn _o): gen byte _last = _n == _N
                keep if _last
                sort _entfa _atfa
                drop _o _pk _kn _last _entfa _atfa
            }
        }
    }
end

* ---------------------------------------------------------------------------
* _rt_emit: write one flowchart file from the node/edge frames.
*   fmt(mermaid) dir(TD|LR)  -> flowchart; fence adds a ```mermaid .md wrapper
*   fmt(dot)     dir(TB|LR)  -> DOT digraph, shape=box
* Greyscale, with ONE accent (#4a6d8c) on flagged nodes and on the edges that
* reach them. Never colour alone: those same events carry "!!" in their text.
* ---------------------------------------------------------------------------
program define _rt_emit
    version 16
    syntax, NODES(name) EDGES(name) FMT(string) DIR(string) OUT(string) ///
        PROV(string) [ ACCT(string) ACCD(string) FENCE TITLE(string) replace ]

    if "`replace'" == "" confirm new file "`out'"
    tempname fh
    file open `fh' using "`out'", write text replace

    * a backtick is written with char(96) inside an expression, never held in
    * a macro: a macro holding one is re-scanned by the macro expander
    if "`fence'" != "" {
        file write `fh' ("# `title'") _n _n
        file write `fh' ("Boxes are datasets; the spine is the dataset in ") ///
            ("memory. A slim rounded node is a row filter. ") ///
            (char(96) + "!!" + char(96)) ///
            (" marks an event that needs attention.") _n _n
        file write `fh' ("*`prov'*") _n _n
        file write `fh' (char(96) + char(96) + char(96) + "mermaid") _n
    }

    if "`fmt'" == "mermaid" {
        _rt_mminit `fh'
        file write `fh' ("%% `prov'") _n
        file write `fh' ("flowchart `dir'") _n
        if "`acct'" != "" file write `fh' ("  accTitle: `acct'") _n
        if "`accd'" != "" {
            file write `fh' ("  accDescr {") _n
            file write `fh' ("    `accd'") _n
            file write `fh' ("  }") _n
        }
        file write `fh' ("  classDef default fill:#ffffff,stroke:#606060,") ///
            ("color:#202020;") _n
        file write `fh' ("  classDef mmfilter fill:#f4f4f4,stroke:#909090,") ///
            ("color:#202020;") _n
        file write `fh' ("  classDef mmnote fill:#fafafa,stroke:#b0b0b0,") ///
            ("color:#404040;") _n
        file write `fh' ("  classDef mmwarn fill:#ffffff,stroke:#4a6d8c,") ///
            ("stroke-width:2.5px,color:#202020;") _n
        file write `fh' ("  classDef mmstop fill:#ffffff,stroke:#4a6d8c,") ///
            ("stroke-width:4px,color:#202020;") _n
        frame `nodes' {
            tempvar ln
            * a filter condition may contain "<", which mermaid would read
            * as the start of an html tag: escape it with mermaid's own
            * entity form BEFORE inserting the <br/> separators
            qui gen strL `ln' = "    " + id ///
                + cond(shape == "filter", "([" + char(34), ///
                char(91) + char(34)) ///
                + subinstr(subinstr(label, "<", "#60;", .), ///
                "~~", "<br/>", .) ///
                + cond(shape == "filter", char(34) + "])", ///
                char(34) + char(93))
            local prevdf ""
            local sg = 0
            forvalues i = 1/`=_N' {
                local df = dofile[`i']
                if "`df'" != "`prevdf'" {
                    if `sg' > 0 file write `fh' ("  end") _n
                    local ++sg
                    file write `fh' ("  subgraph sg`sg'[" + char(34) ///
                        + "`df'" + char(34) + "]") _n
                    local prevdf "`df'"
                }
                file write `fh' (`ln'[`i']) _n
            }
            if `sg' > 0 file write `fh' ("  end") _n
        }
        local accent ""
        frame `edges' {
            tempvar ln
            qui gen strL `ln' = ""
            qui replace `ln' = "  " + from + " --> " + to ///
                if !dashed & label == ""
            qui replace `ln' = "  " + from + " -- " + char(34) ///
                + subinstr(subinstr(label, "<", "#60;", .), ///
                "~~", "<br/>", .) + char(34) ///
                + " --> " + to if !dashed & label != ""
            qui replace `ln' = "  " + from + " -.-> " + to ///
                if dashed & label == ""
            qui replace `ln' = "  " + from + " -. " + char(34) ///
                + subinstr(subinstr(label, "<", "#60;", .), ///
                "~~", "<br/>", .) + char(34) ///
                + " .-> " + to if dashed & label != ""
            forvalues i = 1/`=_N' {
                file write `fh' (`ln'[`i']) _n
                if accent[`i'] {
                    local k = `i' - 1
                    local accent = "`accent'" ///
                        + cond("`accent'" == "", "", ",") + "`k'"
                }
            }
        }
        frame `nodes' {
            forvalues i = 1/`=_N' {
                if flagged[`i'] & sev[`i'] == "stop" {
                    file write `fh' ("  class " + id[`i'] + " mmstop;") _n
                }
                else if flagged[`i'] {
                    file write `fh' ("  class " + id[`i'] + " mmwarn;") _n
                }
                else if shape[`i'] == "filter" {
                    file write `fh' ("  class " + id[`i'] + " mmfilter;") _n
                }
                else if shape[`i'] == "note" {
                    file write `fh' ("  class " + id[`i'] + " mmnote;") _n
                }
            }
        }
        if "`accent'" != "" {
            file write `fh' ("  linkStyle `accent' stroke:#4a6d8c,") ///
                ("stroke-width:2px;") _n
        }
    }
    else {  // dot
        file write `fh' ("// `prov'") _n
        if "`acct'" != "" file write `fh' ("// `acct'") _n
        file write `fh' ("digraph mergemap {") _n
        file write `fh' ("  rankdir=`dir';") _n
        file write `fh' ("  graph [fontname=" + char(34) + "Helvetica" ///
            + char(34) + ", fontsize=11, labeljust=" + char(34) + "l" ///
            + char(34) + ", labelloc=" + char(34) + "b" + char(34) ///
            + ", fontcolor=" + char(34) + "#707070" + char(34) ///
            + ", label=" + char(34) + "`prov'" + char(34) + "];") _n
        file write `fh' ("  node  [shape=box, fontname=" + char(34) ///
            + "Helvetica" + char(34) + ", fontsize=10, color=" + char(34) ///
            + "#606060" + char(34) + ", fontcolor=" + char(34) + "#202020" ///
            + char(34) + "];") _n
        file write `fh' ("  edge  [fontname=" + char(34) + "Helvetica" ///
            + char(34) + ", fontsize=9, color=" + char(34) + "#606060" ///
            + char(34) + ", fontcolor=" + char(34) + "#202020" ///
            + char(34) + "];") _n
        frame `nodes' {
            tempvar ln
            qui gen strL `ln' = "    " + id + " [label=" + char(34) ///
                + subinstr(subinstr(label, char(92), char(92) + char(92), .), ///
                "~~", char(92) + "n", .) + char(34) ///
                + cond(shape == "filter", ", style=rounded", "") ///
                + cond(shape == "note", ", style=dashed", "") ///
                + cond(flagged, ", color=" + char(34) + "#4a6d8c" + char(34) ///
                + cond(sev == "stop", ", penwidth=3", ", penwidth=2"), "") ///
                + "];"
            local prevdf ""
            local sg = 0
            forvalues i = 1/`=_N' {
                local df = dofile[`i']
                if "`df'" != "`prevdf'" {
                    if `sg' > 0 file write `fh' ("  }") _n
                    local ++sg
                    file write `fh' ("  subgraph cluster_`sg' {") _n
                    file write `fh' ("    label=" + char(34) + "`df'" ///
                        + char(34) + ";") _n
                    file write `fh' ("    color=" + char(34) + "#909090" ///
                        + char(34) + ";") _n
                    local prevdf "`df'"
                }
                file write `fh' (`ln'[`i']) _n
            }
            if `sg' > 0 file write `fh' ("  }") _n
        }
        frame `edges' {
            tempvar ln
            qui gen strL `ln' = "  " + from + " -> " + to ///
                + cond(label == "" & !dashed & !accent, "", " [" ///
                + cond(label == "", "", "label=" + char(34) ///
                + subinstr(subinstr(label, char(92), char(92) + char(92), .), ///
                "~~", char(92) + "n", .) + char(34)) ///
                + cond(dashed, cond(label == "", "", ", ") ///
                + "style=dashed", "") ///
                + cond(accent, cond(label == "" & !dashed, "", ", ") ///
                + "color=" + char(34) + "#4a6d8c" + char(34), "") + "]") + ";"
            forvalues i = 1/`=_N' {
                file write `fh' (`ln'[`i']) _n
            }
        }
        file write `fh' ("}") _n
    }

    if "`fence'" != "" {
        file write `fh' (char(96) + char(96) + char(96)) _n
    }
    file close `fh'
end

* ---------------------------------------------------------------------------
* _rt_eremit: write the erDiagram flavour. Cardinality glyphs carry what the
* Stata subtype says; a dotted line is a link that does not pair rows on a
* key (append, frlink). erDiagram has no classDef, so severity travels only
* as the "!!" text marker on the relationship label -- which is the rule
* anyway: never colour alone.
* ---------------------------------------------------------------------------
program define _rt_eremit
    version 16
    syntax, ATTRS(name) RELS(name) OUT(string) PROV(string) ///
        [ ACCT(string) ACCD(string) FENCE TITLE(string) replace ]

    if "`replace'" == "" confirm new file "`out'"
    tempname fh
    file open `fh' using "`out'", write text replace

    if "`fence'" != "" {
        file write `fh' ("# `title'") _n _n
        file write `fh' ("Entities are datasets, attributes are the keys ") ///
            ("they were joined on, and the glyph carries the Stata ") ///
            ("subtype: ") ///
            (char(96) + "||--||" + char(96) + " is 1:1, ") ///
            (char(96) + "}o--||" + char(96) + " is m:1, ") ///
            (char(96) + "||--o{" + char(96) + " is 1:m, ") ///
            (char(96) + "}o--o{" + char(96) + " is m:m or joinby. ") ///
            ("A dotted line is a link that does not pair rows on a key: ") ///
            ("append, or frlink.") _n _n
        file write `fh' ("*`prov'*") _n _n
        file write `fh' (char(96) + char(96) + char(96) + "mermaid") _n
    }

    _rt_mminit `fh'
    file write `fh' ("%% `prov'") _n
    file write `fh' ("erDiagram") _n
    if "`acct'" != "" file write `fh' ("  accTitle: `acct'") _n
    if "`accd'" != "" {
        file write `fh' ("  accDescr {") _n
        file write `fh' ("    `accd'") _n
        file write `fh' ("  }") _n
    }

    frame `rels' {
        tempvar ln
        qui gen strL `ln' = "  " + lft + " " + glyph + " " + rgt ///
            + " : " + char(34) + subinstr(lab, "<", "#60;", .) + char(34)
        forvalues i = 1/`=_N' {
            file write `fh' (`ln'[`i']) _n
        }
    }
    frame `attrs' {
        local prev ""
        forvalues i = 1/`=_N' {
            local e = ent[`i']
            if "`e'" != "`prev'" {
                if "`prev'" != "" file write `fh' ("  }") _n
                file write `fh' ("  `e' {") _n
                local prev "`e'"
            }
            file write `fh' ("    " + atype[`i'] + " " + aname[`i'] ///
                + cond(akey[`i'] == "", "", " " + akey[`i'])) _n
        }
        if "`prev'" != "" file write `fh' ("  }") _n
    }

    if "`fence'" != "" {
        file write `fh' (char(96) + char(96) + char(96)) _n
    }
    file close `fh'
end

* ---------------------------------------------------------------------------
* _rt_mminit: the mermaid init directive (16i). Theme "base" plus explicit
* theme variables, so the diagram looks the same on GitHub, in mermaid.live,
* in Quarto and in VS Code. Greyscale here; the accent enters through
* classDef and linkStyle, which is where the flags are.
* No "click ... href" anywhere: GitHub renders mermaid in a framed context
* whose CSP blocks it (DECISIONS 18a). Nothing here is newer than the
* mermaid 10.0.2 that GitHub pins.
* ---------------------------------------------------------------------------
program define _rt_mminit
    version 16
    args fh
    local tv "'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'14px'"
    local tv "`tv','primaryColor':'#ffffff','primaryTextColor':'#202020'"
    local tv "`tv','primaryBorderColor':'#606060','lineColor':'#606060'"
    local tv "`tv','secondaryColor':'#f4f4f4','tertiaryColor':'#fafafa'"
    local tv "`tv','clusterBkg':'#fbfbfb','clusterBorder':'#b0b0b0'"
    local tv "`tv','edgeLabelBackground':'#ffffff','titleColor':'#202020'"
    file write `fh' ("%%{init: {'theme':'base','themeVariables':{`tv'}}}%%") _n
end
