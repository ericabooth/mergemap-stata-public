*! version 0.2.0  19aug2026  Eric Booth
*! _mm_rendertw : draw a mergemap journal (schema v2) as a native twoway
*!            boxes-and-arrows diagram
*!
*! syntax:  _mm_rendertw using <journal.tsv>, saving(stub)
*!              [layout(vertical|horizontal) page(none|dofile)
*!               maxnodes(#) noprovenance]
*!
*! Builds ONE twoway call per page: boxes from pci segments, arrows from
*! pcarrowi, labels from text().  Exports <stub>.png (width 1600) and
*! <stub>.svg; with page(dofile), one image per do-file, named
*! <stub>_<dofile>.png / .svg.
*!
*! Monochrome (black boxes/arrows, grays for notes); a single accent color
*! (#4a6d8c, written as the RGB triplet 74 109 140 so it is valid at the
*! Stata 16 floor) is used only for warn/stop flag text.  Severity is never
*! colour-only: warn and stop both print "!!", and stop is bolded as well.
*!
*! Reads the v2 journal BY COLUMN NAME (column 9 is usingfile, never using),
*! tolerates unknown trailing columns, and fills the five v2 columns with "."
*! if an older producer omitted them.
*!
*! Capped at maxnodes() join+transform+filter events per page (default 12);
*! denser pages are referred to the HTML renderer.

program define _mm_rendertw
    version 16

    syntax using/, SAVing(string) [LAYout(string) PAGE(string)      ///
        MAXnodes(integer 12) noPROVenance]

    if "`layout'" == "" local layout vertical
    if !inlist("`layout'", "vertical", "horizontal") {
        di as err "_mm_rendertw: layout() must be vertical or horizontal"
        exit 198
    }
    if "`page'" == "" local page none
    if !inlist("`page'", "none", "dofile") {
        di as err "_mm_rendertw: page() must be none or dofile"
        exit 198
    }
    if `maxnodes' < 1 {
        di as err "_mm_rendertw: maxnodes() must be a positive integer"
        exit 198
    }

    * ------------------------------------------------------------------
    * 1. load the journal into a frame and read it BY NAME
    * ------------------------------------------------------------------
    tempname jrn
    frame create `jrn'
    frame `jrn' {
        qui import delimited using "`using'", delimiter(tab) varnames(1) ///
            stringcols(_all) clear

        * schema v2 column 9 is usingfile; the v1 name (using) is a reserved
        * word that import delimited turns into a positional variable, so a
        * v1 journal is refused rather than silently misread
        capture confirm variable usingfile
        if _rc {
            di as err "_mm_rendertw: `using' is not a v2 mergemap journal"
            di as err "    column 9 must be named usingfile (v1 called it" ///
                " using, a reserved word)"
            exit 459
        }
        foreach v in seq dofile line class cmd subtype keys master result ///
            n_in k_in n_using k_using n_out k_out m1 m2 m3 m4 m5          ///
            dup_master dup_using force opts loop_n loop_first loop_last   ///
            flags {
            capture confirm variable `v'
            if _rc {
                di as err "_mm_rendertw: `using' has no column named `v'"
                exit 459
            }
        }
        * five columns added in v2; fill them if an older producer omitted
        * them, and ignore any column this renderer does not know about
        foreach v in severity keytypes cover_master cover_using lifecycle {
            capture confirm variable `v'
            if _rc qui gen str1 `v' = "."
        }

        * neutralize characters macro expansion would eat inside graph text:
        * backtick -> U+02CB (modifier grave), dollar -> fullwidth dollar,
        * double quote -> single quote.  char(1)/char(2)/char(3) are the
        * scanner's placeholders for backtick/dollar/single quote; the journal
        * restores them, but map them here too so a leaked placeholder shows
        * as the character it stands for instead of a control code
        foreach v of varlist _all {
            qui replace `v' = subinstr(`v', char(1),  uchar(715),   .)
            qui replace `v' = subinstr(`v', char(2),  uchar(65284), .)
            qui replace `v' = subinstr(`v', char(3),  char(39),     .)
            qui replace `v' = subinstr(`v', char(96), uchar(715),   .)
            qui replace `v' = subinstr(`v', char(36), uchar(65284), .)
            qui replace `v' = subinstr(`v', char(34), char(39),     .)
        }
        local N = _N
        forvalues i = 1/`N' {
            foreach v in seq dofile line class cmd subtype keys master   ///
                usingfile result n_in k_in n_using k_using n_out k_out   ///
                m1 m2 m3 m4 m5 dup_master dup_using force opts           ///
                loop_n loop_first loop_last severity keytypes            ///
                cover_master cover_using lifecycle flags {
                local `v'_`i' = `v'[`i']
            }
        }
    }
    frame drop `jrn'

    if `N' == 0 {
        di as err "_mm_rendertw: journal `using' has no events"
        exit 2000
    }

    * ------------------------------------------------------------------
    * 2. layout parameters
    * ------------------------------------------------------------------
    * the single accent color (warn/stop flags only), as an RGB triplet so it
    * matches the HTML/mermaid/DOT renderers' #4a6d8c exactly; a triplet also
    * keeps this valid back to the Stata 16 floor, where hex colorstyles are
    * not accepted
    local accent 74 109 140
    if "`layout'" == "vertical" {
        local capsp   42            // char cap, spine box lines
        local capus   25            // char cap, using box lines
        local lineh   3             // units per text line
        local padv    1.3           // box padding, top and bottom
        local gapv    5             // gap between consecutive spine boxes
        local brkextra 4            // extra gap at a chain break (use, clear)
        local hdrh    6             // do-file header strip height
        local sxl     6
        local sxr     62            // spine box x-extent
        local finset  5             // filter nodes are inset: slim spine node
        local uxl     68
        local uxr     100           // using box x-extent
        local xmax    103
        local maxwrap 3
        local capfl = round(`capsp'*(`sxr' - `sxl' - 2*`finset')/(`sxr' - `sxl'))
    }
    else {
        * a glyph is about 1.25 units wide at this text size, so the char cap
        * must stay under colw/1.25 or the longest line touches the box edges
        local capsp   23
        local capus   23
        local lineh   3
        local padv    1.3
        local agap    5             // using box to spine box arrow gap
        local bandgap 9
        local hstrip  5             // header strip under the spine row
        local colw    34
        local gapx    6
        local finset  0             // horizontal filters are slim by height
        local maxwrap 4
        local capfl   `capsp'
    }

    * ------------------------------------------------------------------
    * 3. build the text lines for every event
    *    a`i'n / a`i'l* / a`i's*  : spine box lines (style 0 black,
    *                               1 dim gray, 2 accent flag)
    *    u`i'n / u`i'l* / u`i't*  : using box lines
    * ------------------------------------------------------------------
    forvalues i = 1/`N' {
        local SL 0
        local UL 0
        local stack 0
        local dash  0
        local cls  "`class_`i''"
        local cmd  "`cmd_`i''"
        local sub  = cond("`subtype_`i''" == ".", "", "`subtype_`i''")
        local kys  = cond("`keys_`i''"    == ".", "", "`keys_`i''")
        local opt  = cond(`"`opts_`i''"'  == ".", "", `"`opts_`i''"')
        local flg  = cond(`"`flags_`i''"' == ".", "", `"`flags_`i''"')
        local sev  = cond("`severity_`i''" == ".", "note", "`severity_`i''")
        local usg  "`usingfile_`i''"
        local res  "`result_`i''"
        local life "`lifecycle_`i''"
        local dspu : subinstr local usg  "tempfile:" "tempfile: "
        local dspu : subinstr local dspu "frame:"    "frame: "
        local slim = ("`cls'" == "filter")
        local cap  = cond(`slim', `capfl', `capsp')

        * ---- flag parts, with the severity marker attached ----
        * the marker, not the colour, carries severity: warn and stop both
        * print "!!" (stop is bolded too) so the signal survives greyscale
        local nfp 0
        local optdup 0
        if `"`flg'"' != "" & `"`flg'"' != "tempfile" {
            local rest `"`flg'"'
            while `"`rest'"' != "" {
                local p = strpos(`"`rest'"', "; ")
                if `p' {
                    local part = substr(`"`rest'"', 1, `p' - 1)
                    local rest = substr(`"`rest'"', `p' + 2, .)
                }
                else {
                    local part `"`rest'"'
                    local rest ""
                }
                local bare = strtrim(`"`part'"')
                if substr(`"`bare'"', 1, 2) == "!!" {
                    local bare = strtrim(substr(`"`bare'"', 3, .))
                    local mark 1
                }
                else local mark = inlist("`sev'", "warn", "stop")
                * a flag that only repeats the options text is not printed
                * twice: the options line is dropped and the flag keeps it,
                * so the severity marker is not lost either
                if `"`bare'"' == `"`opt'"' local optdup 1
                local ++nfp
                local fp`nfp' = cond(`mark', "!! ", "") + `"`bare'"'
                local fs`nfp' = cond(`mark', 2, 1)
            }
        }

        * ---- line 1: the event itself (bold) ----
        if "`cls'" == "source" {
            _rtw_ell `= `cap' - ustrlen("`cmd'") - 1' `dspu'
            local ++SL
            local zl`SL' "{bf:`cmd' `r(s)'}"
            local zs`SL' 0
        }
        else if "`cls'" == "save" {
            local dspr : subinstr local res  "tempfile:" "tempfile: "
            if "`sub'" == "tempfile"        local mark "[tempfile]"
            else if "`life'" == "overwrite" local mark "[overwritten]"
            else                            local mark "[saved]"
            if "`layout'" == "vertical" {
                _rtw_ell `= `cap' - ustrlen("`mark'") - 2' `dspr'
                local ++SL
                local zl`SL' "{bf:`r(s)'  `mark'}"
                local zs`SL' 0
            }
            else {
                _rtw_ell `cap' `dspr'
                local ++SL
                local zl`SL' "{bf:`r(s)'}"
                local zs`SL' 0
                local ++SL
                local zl`SL' "`mark'"
                local zs`SL' 0
            }
        }
        else if `slim' {
            * filter: the condition IS the headline
            local t = itrim(strtrim("`cmd' `opt'"))
            _rtw_wrap `cap' `maxwrap' `t'
            local nw = r(n)
            forvalues w = 1/`nw' {
                local ++SL
                local zl`SL' `"{bf:`r(l`w')'}"'
                local zs`SL' 0
            }
        }
        else if "`cls'" == "transform" & inlist("`cmd'", "collapse", "reshape") {
            local t = itrim(strtrim("`cmd' `sub'"))
            _rtw_ell `cap' `t'
            local ++SL
            local zl`SL' "{bf:`r(s)'}"
            local zs`SL' 0
        }
        else {
            local t = itrim(strtrim("`cmd' `sub' `kys'"))
            _rtw_ell `cap' `t'
            local ++SL
            local zl`SL' "{bf:`r(s)'}"
            local zs`SL' 0
        }

        * ---- options line(s), dim ----
        if `"`opt'"' != "" & !inlist("`cls'", "source", "save", "filter") ///
            & !`optdup' {
            _rtw_wrap `cap' `maxwrap' `opt'
            local nw = r(n)
            forvalues w = 1/`nw' {
                local ++SL
                local zl`SL' `"`r(l`w')'"'
                local zs`SL' 1
            }
        }

        * ---- count line(s), run mode only (all "." in scan mode) ----
        local nit 0
        if inlist("`cls'", "join", "link") & !inlist("`m3_`i''", "", ".") {
            _rtw_num `m3_`i''
            local ++nit
            local it`nit' "matched `r(s)'"
            if "`cls'" == "link" {
                if !inlist("`m1_`i''", "", ".", "0") {
                    _rtw_num `m1_`i''
                    local ++nit
                    local it`nit' "unmatched `r(s)'"
                }
            }
            else {
                * which _merge categories does keep() retain?
                local ks ""
                local p = strpos(`"`opt'"', "keep(")
                if `p' {
                    local rest = substr(`"`opt'"', `p' + 5, .)
                    local ks   = substr("`rest'", 1, strpos("`rest'", ")") - 1)
                }
                foreach c in 1 2 {
                    local mv "`m`c'_`i''"
                    if inlist("`mv'", "", ".", "0") continue
                    _rtw_num `mv'
                    local lab = cond(`c' == 1, "master", "using")
                    if "`ks'" == "" | strpos("`ks'", "`c'") {
                        local ++nit
                        local it`nit' "`lab' `r(s)'"
                    }
                    else {
                        local ++nit
                        local it`nit' "`lab' (`r(s)' dropped)"
                    }
                }
                foreach c in 4 5 {
                    local mv "`m`c'_`i''"
                    if inlist("`mv'", "", ".", "0") continue
                    _rtw_num `mv'
                    local lab = cond(`c' == 4, "upd", "confl")
                    local ++nit
                    local it`nit' "`lab' `r(s)'"
                }
            }
        }
        else if inlist("`cls'", "source", "save") ///
            & !inlist("`n_out_`i''", "", ".") {
            _rtw_num `n_out_`i''
            local ++nit
            local it`nit' "`r(s)' obs × `k_out_`i'' vars"
        }
        else if `slim' & `nfp' > 0 {
            * a filter's row change is carried by its flag (tidylog phrasing),
            * so do not repeat it as an obs line
        }
        else if !inlist("`n_in_`i''", "", ".") & !inlist("`n_out_`i''", "", ".") {
            _rtw_num `n_in_`i''
            local na "`r(s)'"
            _rtw_num `n_out_`i''
            local nb "`r(s)'"
            local ++nit
            if "`na'" == "`nb'" local it`nit' "obs `nb'"
            else                local it`nit' "obs `na' → `nb'"
            if !inlist("`k_in_`i''", "", ".") & !inlist("`k_out_`i''", "", ".") ///
                & "`k_in_`i''" != "`k_out_`i''" & "`cls'" != "join" {
                local ++nit
                local it`nit' "vars `k_in_`i'' → `k_out_`i''"
            }
        }
        if `nit' > 0 {
            if "`layout'" == "vertical" {
                * pack whole items onto lines: a count never breaks across
                * lines, and the " · " separator disappears at a line break
                * instead of dangling at the start of the next line
                local cur ""
                forvalues z = 1/`nit' {
                    if `"`cur'"' == "" local cand `"`it`z''"'
                    else               local cand `"`cur' · `it`z''"'
                    if ustrlen(`"`cand'"') <= `cap' {
                        local cur `"`cand'"'
                    }
                    else {
                        if `"`cur'"' != "" {
                            local ++SL
                            local zl`SL' `"`cur'"'
                            local zs`SL' 0
                        }
                        _rtw_ell `cap' `it`z''
                        local cur `"`r(s)'"'
                    }
                }
                if `"`cur'"' != "" {
                    local ++SL
                    local zl`SL' `"`cur'"'
                    local zs`SL' 0
                }
            }
            else {
                forvalues z = 1/`nit' {
                    _rtw_ell `cap' `it`z''
                    local ++SL
                    local zl`SL' `"`r(s)'"'
                    local zs`SL' 0
                }
            }
        }

        * ---- coverage, v2: share of master matched / using used ----
        if inlist("`cls'", "join", "link") {
            local cvm ""
            local cvu ""
            if !inlist("`cover_master_`i''", "", ".") {
                _rtw_pct `cover_master_`i''
                local cvm "`r(s)' master"
            }
            if !inlist("`cover_using_`i''", "", ".") {
                _rtw_pct `cover_using_`i''
                local cvu "`r(s)' using"
            }
            if "`layout'" == "vertical" {
                * both shares on one line: "cover 94% master / 61% using"
                local cv "`cvm'"
                local cv = "`cv'" + cond("`cv'" == "" | "`cvu'" == "", "", " / ") ///
                    + "`cvu'"
                if "`cv'" != "" {
                    _rtw_ell `cap' cover `cv'
                    local ++SL
                    local zl`SL' `"`r(s)'"'
                    local zs`SL' 0
                }
            }
            else {
                * a column is too narrow for both, so one share per line
                forvalues z = 1/2 {
                    local cv = cond(`z' == 1, "`cvm'", "`cvu'")
                    if "`cv'" == "" continue
                    _rtw_ell `cap' cover `cv'
                    local ++SL
                    local zl`SL' `"`r(s)'"'
                    local zs`SL' 0
                }
            }
        }

        * ---- key type drift, v2 (16c) ----
        * printed only when the two sides really differ, and only when the
        * flags do not already name that key, so the box says it once
        if !inlist("`keytypes_`i''", "", ".") {
            local kt "`keytypes_`i''"
            local kvar = strtrim(substr("`kt'", 1, strpos("`kt'", ":") - 1))
            local ktr  = strtrim(substr("`kt'", strpos("`kt'", ":") + 1, .))
            local ta   = strtrim(substr("`ktr'", 1, strpos("`ktr'", " vs ") - 1))
            local tb   = strtrim(substr("`ktr'", strpos("`ktr'", " vs ") + 4, .))
            if "`ta'" != "`tb'" & "`ta'" != "" & "`tb'" != "" {
                local named 0
                forvalues z = 1/`nfp' {
                    if strpos(`"`fp`z''"', "`kvar'") local named 1
                }
                if !`named' {
                    _rtw_wrap `cap' `maxwrap' types `kt'
                    local nw = r(n)
                    forvalues w = 1/`nw' {
                        local ++SL
                        local zl`SL' `"`r(l`w')'"'
                        local zs`SL' 1
                    }
                }
            }
        }

        * ---- flags: accent + "!!" for warn/stop, bold as well for stop ----
        forvalues z = 1/`nfp' {
            _rtw_wrap `cap' `maxwrap' `fp`z''
            local nw = r(n)
            forvalues w = 1/`nw' {
                local ++SL
                if "`sev'" == "stop" & `fs`z'' == 2 ///
                     local zl`SL' `"{bf:`r(l`w')'}"'
                else local zl`SL' `"`r(l`w')'"'
                local zs`SL' `fs`z''
            }
        }

        * ---- using box (joins and links only) ----
        if inlist("`cls'", "join", "link") & !inlist("`usg'", "", ".") {
            local dash = ("`cls'" == "link")
            _rtw_ell `capus' `dspu'
            local ++UL
            local yl`UL' "{bf:`r(s)'}"
            local yt`UL' 0
            if !inlist("`loop_n_`i''", "", ".") {
                local stack 1
                foreach z in first last {
                    local f "`loop_`z'_`i''"
                    local slp = strrpos("`f'", "/")
                    if `slp' local f = substr("`f'", `slp' + 1, .)
                    local f : subinstr local f ".dta" ""
                    local b`z' "`f'"
                }
                * "x3: cps_2020 … cps_2022"; if the column is too narrow,
                * close the spaces around the ellipsis before resorting to
                * a middle-ellipsis that would print two of them
                local ls "×`loop_n_`i'': `bfirst' … `blast'"
                if ustrlen("`ls'") > `capus' ///
                    local ls "×`loop_n_`i'': `bfirst'…`blast'"
                _rtw_ell `capus' `ls'
                local ++UL
                local yl`UL' `"`r(s)'"'
                local yt`UL' 0
            }
            else if ustrpos("`usg'", uchar(715)) {
                local ++UL
                local yl`UL' "runtime list (unresolved)"
                local yt`UL' 1
            }
            if !inlist("`n_using_`i''", "", ".") {
                _rtw_num `n_using_`i''
                local nl "`r(s)' obs"
                if `stack' local nl "`nl' total"
                else if !inlist("`k_using_`i''", "", ".") ///
                    local nl "`nl' × `k_using_`i'' vars"
                local ++UL
                local yl`UL' "`nl'"
                local yt`UL' 0
            }
        }

        * ---- store ----
        local a`i'n `SL'
        forvalues j = 1/`SL' {
            local a`i'l`j' `"`zl`j''"'
            local a`i's`j' `zs`j''
        }
        local u`i'n `UL'
        forvalues j = 1/`UL' {
            local u`i'l`j' `"`yl`j''"'
            local u`i't`j' `yt`j''
        }
        local ustack_`i' `stack'
        local udash_`i'  `dash'
        local uslim_`i'  `slim'
    }

    * ------------------------------------------------------------------
    * 4. pages: one image, or one image per do-file
    * ------------------------------------------------------------------
    if "`page'" == "none" {
        local npages 1
        local rows1 ""
        forvalues i = 1/`N' {
            local rows1 "`rows1' `i'"
        }
        local stub1 `"`saving'"'
    }
    else {
        local npages 0
        local prev "-none-"
        forvalues i = 1/`N' {
            if "`dofile_`i''" != "`prev'" {
                local ++npages
                local rows`npages' ""
                local prev "`dofile_`i''"
                _rtw_base `dofile_`i''
                * a do-file the journal returns to later would otherwise
                * overwrite its own earlier page, so keep the stubs distinct
                local bn `"`r(s)'"'
                local cand `"`bn'"'
                local k 1
                while strpos(" `used' ", " `cand' ") {
                    local ++k
                    local cand `"`bn'_`k'"'
                }
                local used `"`used' `cand'"'
                local stub`npages' `"`saving'_`cand'"'
            }
            local rows`npages' "`rows`npages'' `i'"
        }
    }

    * node cap, applied per page: this renderer is for small diagrams
    forvalues p = 1/`npages' {
        local njt`p' 0
        foreach i of local rows`p' {
            if inlist("`class_`i''", "join", "transform", "filter") ///
                local ++njt`p'
        }
        if `njt`p'' > `maxnodes' {
            di as err "_mm_rendertw: page `p' has `njt`p'' join+transform+filter" ///
                " events, above this renderer's cap of `maxnodes'."
            di as err "    a native-graph diagram this dense is not readable;" ///
                " use the HTML export instead:"
            di as err `"        . renderhtml using "`using'", saving(diagram.html)"'
            di as err "    (or split it with page(dofile), or raise the cap" ///
                " with maxnodes(#))"
            exit 134
        }
    }

    * provenance footer (16g): timestamp, Stata version and flavour, and the
    * project's git branch/commit if the working directory sits in a repo
    local prov ""
    if "`provenance'" != "noprovenance" {
        local jb `"`using'"'
        local slp = strrpos(`"`jb'"', "/")
        if `slp' local jb = substr(`"`jb'"', `slp' + 1, .)
        local slp = strrpos(`"`jb'"', "\")
        if `slp' local jb = substr(`"`jb'"', `slp' + 1, .)
        _rtw_prov , journal(`"`jb'"') dir(`"`c(pwd)'"')
        local prov `"`r(s)'"'
    }

    * ------------------------------------------------------------------
    * 5. draw each page
    * ------------------------------------------------------------------
    forvalues p = 1/`npages' {
        local rows  `"`rows`p''"'
        local savp  `"`stub`p''"'
        local NP : word count `rows'

        local boxsegs ""
        local thinsegs ""
        local dashsegs ""
        local arrs ""
        local arrd ""
        local txts ""

        if "`layout'" == "vertical" {
            local scx = (`sxl' + `sxr')/2
            local ucx = (`uxl' + `uxr')/2
            local ycur = -2
            local prevdo ""
            local prevbot .
            local pos 0
            foreach i of local rows {
                local ++pos
                local nsl `a`i'n'
                local nul `u`i'n'
                * do-file header strip
                if "`dofile_`i''" != "`prevdo'" {
                    local yh = `ycur' - `hdrh'/2
                    local txts `"`txts' text(`yh' 1 "{bf:`dofile_`i''}", size(@SZH@) color(gs6) placement(e))"'
                    local ycur = `ycur' - `hdrh'
                    local prevdo "`dofile_`i''"
                }
                local hasarrow = ("`class_`i''" != "source") & (`pos' > 1)
                if !`hasarrow' & `pos' > 1 {
                    local ycur = `ycur' - `brkextra'
                }
                local xl = cond(`uslim_`i'', `sxl' + `finset', `sxl')
                local xr = cond(`uslim_`i'', `sxr' - `finset', `sxr')
                local hsp  = 2*`padv' + `nsl'*`lineh'
                local hus  = cond(`nul' > 0, 2*`padv' + `nul'*`lineh', 0)
                local rowh = max(`hsp', `hus')
                local yc = `ycur' - `rowh'/2
                local bt = `yc' + `hsp'/2
                local bb = `yc' - `hsp'/2
                local segs "`bt' `xl' `bt' `xr'  `bb' `xl' `bb' `xr'  `bt' `xl' `bb' `xl'  `bt' `xr' `bb' `xr'"
                if `uslim_`i'' local thinsegs "`thinsegs' `segs'"
                else           local boxsegs  "`boxsegs' `segs'"
                * spine text lines
                forvalues j = 1/`nsl' {
                    local ytx = `bt' - `padv' - (`j' - 0.5)*`lineh'
                    local sty `a`i's`j''
                    if `sty' == 0 local o "size(@SZ@) color(black)"
                    if `sty' == 1 local o "size(@SZS@) color(gs7)"
                    if `sty' == 2 local o `"size(@SZ@) color("`accent'")"'
                    local txts `"`txts' text(`ytx' `scx' `"`a`i'l`j''"', `o' placement(c))"'
                }
                * seq marker
                local ysq = `bt' - `padv' - 0.5*`lineh'
                local txts `"`txts' text(`ysq' `= `sxl' - 1' "`seq_`i''", size(@SZT@) color(gs10) placement(w))"'
                * using box + join arrow
                if `nul' > 0 {
                    local ut = `yc' + `hus'/2
                    local ub = `yc' - `hus'/2
                    local segs "`ut' `uxl' `ut' `uxr'  `ub' `uxl' `ub' `uxr'  `ut' `uxl' `ub' `uxl'  `ut' `uxr' `ub' `uxr'"
                    if `ustack_`i'' {
                        local d 1.2
                        local segs "`segs'  `= `ut' + `d'' `= `uxl' + `d'' `= `ut' + `d'' `= `uxr' + `d''  `= `ut' + `d'' `= `uxr' + `d'' `= `ub' + `d'' `= `uxr' + `d''"
                    }
                    if `udash_`i'' {
                        local dashsegs "`dashsegs' `segs'"
                        local arrd "`arrd' `yc' `uxl' `yc' `xr'"
                    }
                    else {
                        local boxsegs "`boxsegs' `segs'"
                        local arrs "`arrs' `yc' `uxl' `yc' `xr'"
                    }
                    forvalues j = 1/`nul' {
                        local ytx = `ut' - `padv' - (`j' - 0.5)*`lineh'
                        local sty `u`i't`j''
                        if `sty' == 0 local o "size(@SZ@) color(black)"
                        if `sty' == 1 local o "size(@SZS@) color(gs7)"
                        local txts `"`txts' text(`ytx' `ucx' `"`u`i'l`j''"', `o' placement(c))"'
                    }
                }
                * spine arrow from previous box bottom edge to this top edge
                if `hasarrow' {
                    local arrs "`arrs' `prevbot' `scx' `bt' `scx'"
                }
                local prevbot `bb'
                local ycur = `ycur' - `rowh' - `gapv'
            }
            local ymin = `ycur' + `gapv' - 2
            local W = `xmax'
        }
        else {
            * -------- horizontal, wrapped into bands of <= 7 columns --------
            local ncols 7
            local nbands = ceil(`NP'/`ncols')
            local ncols  = ceil(`NP'/`nbands')
            local W = 8 + `ncols'*(`colw' + `gapx') - `gapx'
            local ycur = -2
            local prevdo ""
            forvalues b = 1/`nbands' {
                local j0 = (`b' - 1)*`ncols' + 1
                local j1 = min(`b'*`ncols', `NP')
                * band extents
                local usH 0
                local spH 0
                forvalues j = `j0'/`j1' {
                    local i : word `j' of `rows'
                    if `u`i'n' > 0 {
                        local husi = 2*`padv' + `u`i'n'*`lineh' + cond(`ustack_`i'', 1.2, 0)
                        local usH = max(`usH', `husi')
                    }
                    local spH = max(`spH', 2*`padv' + `a`i'n'*`lineh')
                }
                local ytop = `ycur'
                local ysc = `ytop' - `usH' - cond(`usH' > 0, `agap', 0) - `spH'/2
                forvalues j = `j0'/`j1' {
                    local i : word `j' of `rows'
                    local col = `j' - `j0' + 1
                    local cx = 4 + (`col' - 0.5)*(`colw' + `gapx')
                    local xl = `cx' - `colw'/2
                    local xr = `cx' + `colw'/2
                    local nsl `a`i'n'
                    local nul `u`i'n'
                    local hsp = 2*`padv' + `nsl'*`lineh'
                    local bt = `ysc' + `hsp'/2
                    local bb = `ysc' - `hsp'/2
                    local segs "`bt' `xl' `bt' `xr'  `bb' `xl' `bb' `xr'  `bt' `xl' `bb' `xl'  `bt' `xr' `bb' `xr'"
                    if `uslim_`i'' local thinsegs "`thinsegs' `segs'"
                    else           local boxsegs  "`boxsegs' `segs'"
                    forvalues jj = 1/`nsl' {
                        local ytx = `bt' - `padv' - (`jj' - 0.5)*`lineh'
                        local sty `a`i's`jj''
                        if `sty' == 0 local o "size(@SZ@) color(black)"
                        if `sty' == 1 local o "size(@SZS@) color(gs7)"
                        if `sty' == 2 local o `"size(@SZ@) color("`accent'")"'
                        local txts `"`txts' text(`ytx' `cx' `"`a`i'l`jj''"', `o' placement(c))"'
                    }
                    * seq marker above the box, left corner
                    local txts `"`txts' text(`= `bt' + 1.1' `xl' "`seq_`i''", size(@SZT@) color(gs10) placement(ne))"'
                    * do-file header under the spine row
                    if "`dofile_`i''" != "`prevdo'" {
                        local yhd = `ysc' - `spH'/2 - 2.2
                        local txts `"`txts' text(`yhd' `cx' "{bf:`dofile_`i''}", size(@SZH@) color(gs6) placement(s))"'
                        local prevdo "`dofile_`i''"
                    }
                    * using box above, arrow down into the spine box top edge
                    if `nul' > 0 {
                        local hus = 2*`padv' + `nul'*`lineh'
                        local ub = `ysc' + `spH'/2 + `agap'
                        local ut = `ub' + `hus'
                        local segs "`ut' `xl' `ut' `xr'  `ub' `xl' `ub' `xr'  `ut' `xl' `ub' `xl'  `ut' `xr' `ub' `xr'"
                        if `ustack_`i'' {
                            local d 1.2
                            local segs "`segs'  `= `ut' + `d'' `= `xl' + `d'' `= `ut' + `d'' `= `xr' + `d''  `= `ut' + `d'' `= `xr' + `d'' `= `ub' + `d'' `= `xr' + `d''"
                        }
                        if `udash_`i'' {
                            local dashsegs "`dashsegs' `segs'"
                            local arrd "`arrd' `ub' `cx' `bt' `cx'"
                        }
                        else {
                            local boxsegs "`boxsegs' `segs'"
                            local arrs "`arrs' `ub' `cx' `bt' `cx'"
                        }
                        forvalues jj = 1/`nul' {
                            local ytx = `ut' - `padv' - (`jj' - 0.5)*`lineh'
                            local sty `u`i't`jj''
                            if `sty' == 0 local o "size(@SZ@) color(black)"
                            if `sty' == 1 local o "size(@SZS@) color(gs7)"
                            local txts `"`txts' text(`ytx' `cx' `"`u`i'l`jj''"', `o' placement(c))"'
                        }
                    }
                    * flow arrow from the previous column
                    if "`class_`i''" != "source" & `j' > 1 {
                        if `col' > 1 {
                            local arrs "`arrs' `ysc' `= `xl' - `gapx'' `ysc' `xl'"
                        }
                        else {
                            * continuation from the previous band
                            local arrs "`arrs' `ysc' 0.8 `ysc' `xl'"
                            local txts `"`txts' text(`= `ysc' + 1.6' 0.8 "…", size(@SZ@) color(gs7) placement(e))"'
                        }
                    }
                    * continuation stub out of the band
                    if `j' == `j1' & `j' < `NP' {
                        local nxt : word `= `j' + 1' of `rows'
                        if "`class_`nxt''" != "source" {
                            local arrs "`arrs' `ysc' `xr' `ysc' `= `xr' + 3.2'"
                            local txts `"`txts' text(`= `ysc' + 1.6' `= `xr' + 3.4' "…", size(@SZ@) color(gs7) placement(e))"'
                        }
                    }
                }
                local bandH = `usH' + cond(`usH' > 0, `agap', 0) + `spH' + `hstrip'
                local ycur = `ytop' - `bandH' - `bandgap'
            }
            local ymin = `ycur' + `bandgap' - 2
        }

        * ---- provenance footer, drawn inside the plot region so the
        *      geometry (and therefore the text scale) stays exact ----
        if `"`prov'"' != "" {
            local capft = floor(`W'*0.95/0.96)
            _rtw_wrap `capft' 2 `prov'
            local nw = r(n)
            local ymin = `ymin' - 2
            forvalues w = 1/`nw' {
                local ymin = `ymin' - 2.6
                local txts `"`txts' text(`ymin' 0.8 `"`r(l`w')'"', size(@SZF@) color(gs9) placement(e))"'
            }
            local ymin = `ymin' - 2
        }
        local H = -(`ymin')

        * --------------------------------------------------------------
        * 6. scale: proportional units -> inches; text size relative to the
        *    smaller graph dimension so glyph height tracks the line height
        * --------------------------------------------------------------
        local k  = min(20/`W', 20/`H')
        local xs = `W'*`k'
        local ys = `H'*`k'
        local tszv  = 0.72*`lineh'/min(`W', `H')*100
        local tsz   = strtrim(string(`tszv',       "%9.2f"))
        local tszs  = strtrim(string(0.88*`tszv',  "%9.2f"))
        local tszt  = strtrim(string(0.60*`tszv',  "%9.2f"))
        local tszh  = strtrim(string(1.00*`tszv',  "%9.2f"))
        local tszf  = strtrim(string(0.72*`tszv',  "%9.2f"))
        local xsize = strtrim(string(`xs', "%9.2f"))
        local ysize = strtrim(string(`ys', "%9.2f"))
        local txts : subinstr local txts "@SZH@" "`tszh'", all
        local txts : subinstr local txts "@SZS@" "`tszs'", all
        local txts : subinstr local txts "@SZT@" "`tszt'", all
        local txts : subinstr local txts "@SZF@" "`tszf'", all
        local txts : subinstr local txts "@SZ@"  "`tsz'",  all

        * --------------------------------------------------------------
        * 7. the single twoway call for this page
        * --------------------------------------------------------------
        local plots `"(scatteri `= `ymin'' 0 0 `W', msymbol(none))"'
        local plots `"`plots' (pci `boxsegs', lcolor(black) lwidth(medthin))"'
        if `"`thinsegs'"' != "" {
            local plots `"`plots' (pci `thinsegs', lcolor(gs6) lwidth(thin))"'
        }
        if `"`dashsegs'"' != "" {
            local plots `"`plots' (pci `dashsegs', lcolor(black) lwidth(medthin) lpattern(dash))"'
        }
        if `"`arrs'"' != "" {
            local plots `"`plots' (pcarrowi `arrs', lcolor(black) mcolor(black) lwidth(medthin) msize(1.2) mlwidth(thin))"'
        }
        if `"`arrd'"' != "" {
            local plots `"`plots' (pcarrowi `arrd', lcolor(black) mcolor(black) lwidth(medthin) msize(1.2) mlwidth(thin) lpattern(dash))"'
        }

        twoway `plots', `txts'                                    ///
            yscale(off) xscale(off)                               ///
            ylabel(none, nogrid) xlabel(none, nogrid)             ///
            legend(off) graphregion(color(white))                 ///
            plotregion(margin(zero) style(none))                  ///
            scheme(s1color)                                       ///
            xsize(`xsize') ysize(`ysize') name(_rtw, replace)

        qui graph export `"`savp'.png"', width(1600) replace
        qui graph export `"`savp'.svg"', replace
        graph drop _rtw

        local evw = cond(`NP' == 1, "event", "events")
        di as txt "_mm_rendertw: wrote `savp'.png and `savp'.svg" ///
            " (`layout', `NP' `evw', `njt`p'' join+transform+filter)"
    }

    if `npages' > 1 {
        di as txt "_mm_rendertw: `npages' pages, one per do-file"
    }
end


* ----------------------------------------------------------------------
* helpers
* ----------------------------------------------------------------------

* middle-ellipsis a string to <= cap characters: _rtw_ell <cap> <text...>
program define _rtw_ell, rclass
    version 16
    gettoken cap 0 : 0
    local s = strtrim(`"`0'"')
    if ustrlen(`"`s'"') <= `cap' {
        return local s `"`s'"'
        exit
    }
    local h = ceil((`cap' - 1)/2)
    local t = `cap' - 1 - `h'
    local a = usubstr(`"`s'"', 1, `h')
    local b = usubstr(`"`s'"', -`t', .)
    return local s `"`a'…`b'"'
end

* word-wrap a string: _rtw_wrap <cap> <maxlines> <text...>
* returns r(n) and r(l1)..r(l<n>); the last line is ellipsized on overflow
program define _rtw_wrap, rclass
    version 16
    gettoken cap  0 : 0
    gettoken maxl 0 : 0
    local s = strtrim(`"`0'"')
    local n 0
    while `"`s'"' != "" & `n' < `maxl' {
        local ++n
        if ustrlen(`"`s'"') <= `cap' {
            return local l`n' `"`s'"'
            local s ""
            continue
        }
        local cut 0
        forvalues p = `cap'(-1)1 {
            if usubstr(`"`s'"', `p', 1) == " " {
                local cut `p'
                continue, break
            }
        }
        if `cut' == 0 local cut `cap'
        local piece = strtrim(usubstr(`"`s'"', 1, `cut'))
        local s     = strtrim(usubstr(`"`s'"', `cut' + 1, .))
        if `n' == `maxl' & `"`s'"' != "" {
            local piece = usubstr(`"`piece'"', 1, max(1, `cap' - 1)) + "…"
            local s ""
        }
        return local l`n' `"`piece'"'
    }
    return local n `n'
end

* comma-format a count held as a string ("." or "" -> empty)
program define _rtw_num, rclass
    version 16
    args v
    if "`v'" == "." | "`v'" == "" {
        return local s ""
        exit
    }
    local s = strtrim(string(real("`v'"), "%18.0fc"))
    return local s "`s'"
end

* format a coverage percentage held as a string: 99.7 -> 99.7%, 100.0 -> 100%
program define _rtw_pct, rclass
    version 16
    args v
    if "`v'" == "." | "`v'" == "" {
        return local s ""
        exit
    }
    local s = strtrim("`v'")
    if substr("`s'", -2, 2) == ".0" local s = substr("`s'", 1, ustrlen("`s'") - 2)
    return local s "`s'%"
end

* strip directory and .do extension from a do-file name, and make what is
* left safe to paste into a filename: _rtw_base <name>
program define _rtw_base, rclass
    version 16
    local s = strtrim(`"`0'"')
    local slp = strrpos(`"`s'"', "/")
    if `slp' local s = substr(`"`s'"', `slp' + 1, .)
    local slp = strrpos(`"`s'"', "\")
    if `slp' local s = substr(`"`s'"', `slp' + 1, .)
    if lower(substr(`"`s'"', -3, 3)) == ".do" ///
        local s = substr(`"`s'"', 1, ustrlen(`"`s'"') - 3)
    local out ""
    forvalues j = 1/`= ustrlen(`"`s'"')' {
        local ch = usubstr(`"`s'"', `j', 1)
        if !strpos("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-", "`ch'") ///
            local ch "_"
        local out "`out'`ch'"
    }
    if `"`out'"' == "" local out "page"
    return local s `"`out'"'
end

* provenance footer (16g): _rtw_prov , journal(<name>) dir(<start directory>)
* timestamp, Stata version and flavour, and the git branch/commit of the
* first ancestor directory holding a .git; read straight from .git so no
* shell call is needed and the ado stays portable
program define _rtw_prov, rclass
    version 16
    syntax [, Journal(string) Dir(string)]
    local jname `"`journal'"'
    local sdir  `"`dir'"'
    if `"`sdir'"' == "" local sdir `"`c(pwd)'"'

    local stamp = "`c(current_date)' " + substr("`c(current_time)'", 1, 5)
    * c(flavor) reports IC on an SE or MP licence, so read the flavour from
    * the c(MP)/c(SE) flags instead
    if      `c(MP)' local flav "MP"
    else if `c(SE)' local flav "SE"
    else            local flav "`c(flavor)'"
    local s "mergemap · `stamp' · Stata `c(stata_version)' `flav'"

    * find the nearest ancestor with a .git directory
    local d `"`sdir'"'
    local root ""
    forvalues k = 1/8 {
        capture confirm file `"`d'/.git/HEAD"'
        if !_rc {
            local root `"`d'"'
            continue, break
        }
        local slp = strrpos(`"`d'"', "/")
        if `slp' <= 1 continue, break
        local d = substr(`"`d'"', 1, `slp' - 1)
    }
    if `"`root'"' != "" {
        tempname fh
        local head ""
        capture noisily {
            file open `fh' using `"`root'/.git/HEAD"', read text
            file read `fh' head
            file close `fh'
        }
        local br ""
        local sha ""
        if substr(`"`head'"', 1, 5) == "ref: " {
            local ref = strtrim(substr(`"`head'"', 6, .))
            local br  `"`ref'"'
            if strpos(`"`ref'"', "refs/heads/") == 1 ///
                local br = substr(`"`ref'"', 12, .)
            capture confirm file `"`root'/.git/`ref'"'
            if !_rc {
                capture noisily {
                    file open `fh' using `"`root'/.git/`ref'"', read text
                    file read `fh' sha
                    file close `fh'
                }
            }
            else {
                capture confirm file `"`root'/.git/packed-refs"'
                if !_rc {
                    tempname ph
                    file open `ph' using `"`root'/.git/packed-refs"', read text
                    file read `ph' pl
                    while r(eof) == 0 {
                        if `"`: word 2 of `pl''"' == `"`ref'"' {
                            local sha `"`: word 1 of `pl''"'
                        }
                        file read `ph' pl
                    }
                    file close `ph'
                }
            }
        }
        else {
            local br "detached"
            local sha `"`head'"'
        }
        if `"`br'"' != "" {
            local g "git `br'"
            if `"`sha'"' != "" local g = "`g'@" + substr(`"`sha'"', 1, 7)
            local s `"`s' · `g'"'
        }
    }
    if `"`jname'"' != "" local s `"`s' · `jname'"'
    * a stray double quote anywhere in this string would break the text()
    * option it is pasted into, so drop them
    local s : subinstr local s `"""' "", all
    return local s `"`s'"'
end
