*! _mm_renderhtml.ado 0.2.0 19aug2026 Eric Booth
*! render a mergemap v2 journal (TSV, 34 columns) as HTML + inline SVG
* syntax: _mm_renderhtml using journal.tsv, saving(x.html)
*         [layout(vertical|horizontal) accent(hex) details embed idprefix(name)
*          noheader noprovenance replace]
*
* Two output shapes:
*   page  (default) a self-contained document: <!DOCTYPE html> ... </html>
*   embed (option)  a FRAGMENT for pasting into a host report: one scoped
*                   <style>, one <div class="mm-embed ...">, one <svg> with a
*                   viewBox and no width/height. Every class is prefixed mm-,
*                   every id is namespaced per diagram, and the stylesheet
*                   contains NO element selectors, so the host page is untouched.
* No external assets, no JavaScript: opens offline at file://.
*
* Marker control chars used internally (mapped to XML entities on write):
*   char(1)=ellipsis char(2)=multiply char(3)=middot char(4)=arrow char(5)=indent
*   char(6)=backtick char(7)=dollar char(16)=amp char(17)=lt char(18)=gt
*   char(19)=doublequote

program define _mm_renderhtml
    version 16.0
    syntax using/, SAVing(string) [LAYout(string) ACCent(string) DETails ///
        EMBed IDPrefix(string) NOHEADer NOPROVenance REPLACE]

    * ------------------------------------------------ options
    if "`layout'" == ""                     local layout "vertical"
    if inlist("`layout'", "v", "vert")      local layout "vertical"
    if inlist("`layout'", "h", "horiz")     local layout "horizontal"
    if !inlist("`layout'", "vertical", "horizontal") {
        display as error "layout() must be vertical or horizontal"
        exit 198
    }
    if "`accent'" == "" local accent "#4a6d8c"
    if substr("`accent'",1,1) != "#" local accent "#`accent'"
    if !ustrregexm(lower("`accent'"), "^#[0-9a-f]{6}$") {
        display as error "accent() must be a 6-digit hex color, e.g. accent(4a6d8c)"
        exit 198
    }
    local out "`saving'"
    if !strmatch(lower("`out'"), "*.html") & !strmatch(lower("`out'"), "*.htm") {
        local out "`out'.html"
    }
    capture confirm file "`out'"
    if !_rc & "`replace'" == "" {
        display as error "file `out' already exists; specify replace"
        exit 602
    }

    * ------------------------------------------------ per-diagram id namespace
    * ids and the CSS scope class both live under this prefix, so two diagrams
    * on one page never share an arrowhead marker or a style rule (DECISIONS 20e)
    if `"`idprefix'"' == "" {
        local stem = substr("`out'", strrpos(subinstr("`out'","\","/",.), "/") + 1, .)
        local stem = subinstr("`stem'", ".html", "", .)
        local stem = subinstr("`stem'", ".htm",  "", .)
        local idprefix "mm-`stem'"
    }
    _rh_slug `"`idprefix'"'
    local pfx `"`s(o)'"'

    * ------------------------------------------------ load journal into a frame
    tempname J
    frame create `J'
    frame `J' {
        quietly import delimited using "`using'", delimiter(tab) ///
            varnames(1) stringcols(_all) clear
        * v2 reads BY NAME. Column 9 is usingfile: "using" is a reserved word
        * and silently became v9 under the v1 header (JOURNAL_SCHEMA.md).
        capture confirm variable usingfile
        if _rc {
            capture confirm variable v9
            if !_rc {
                display as error "journal looks like schema v1 (column 9 named " ///
                    "{it:using}); regenerate it with the v2 header"
                exit 459
            }
            display as error "journal has no {it:usingfile} column; expected the " ///
                "v2 header (see JOURNAL_SCHEMA.md)"
            exit 459
        }
        rename usingfile usingf
        capture rename line    linenum
        capture rename class   evclass
        * required core; anything else may be absent in an older journal
        foreach v in seq dofile linenum evclass cmd subtype keys master usingf ///
                     result n_in k_in n_using k_using n_out k_out m1 m2 m3 m4 ///
                     m5 dup_master dup_using force opts loop_n loop_first ///
                     loop_last severity keytypes cover_master cover_using ///
                     lifecycle flags {
            capture confirm variable `v'
            if _rc quietly generate str1 `v' = "."
            quietly replace `v' = "." if `v' == ""
        }
        * neutralize macro-hostile and XML-special chars IN THE DATA before any
        * value passes through a macro (backtick contents are re-expanded on
        * macro dereference; & < > break XML; a double quote can close a
        * compound quote early)
        foreach v in dofile evclass cmd subtype keys master usingf result opts ///
                     loop_first loop_last severity keytypes lifecycle flags {
            quietly replace `v' = subinstr(`v', "&",      char(16), .)
            quietly replace `v' = subinstr(`v', "<",      char(17), .)
            quietly replace `v' = subinstr(`v', ">",      char(18), .)
            quietly replace `v' = subinstr(`v', char(96), char(6),  .)
            quietly replace `v' = subinstr(`v', char(36), char(7),  .)
            quietly replace `v' = subinstr(`v', char(34), char(19), .)
        }
    }
    frame `J': quietly count
    local N = r(N)
    frame `J': quietly count if n_out != "." | n_in != "."
    local runmode = (r(N) > 0)
    frame `J': quietly count if inlist(severity, "warn", "stop") | strpos(flags, "!!")
    local nany = r(N)
    frame `J': quietly count if inlist(evclass, "join", "link")
    local njoin = r(N)
    frame `J': quietly count if inlist(evclass, "join", "link") & ///
        (inlist(severity, "warn", "stop") | strpos(flags, "!!"))
    local nflag = r(N)
    frame `J': quietly count if inlist(evclass, "join", "link") & severity == "warn"
    local nwarn = r(N)
    frame `J': quietly count if inlist(evclass, "join", "link") & severity == "stop"
    local nstop = r(N)
    local nother = `nany' - `nflag'

    * globals the writers read (dropped at the end)
    global RH_ACC "`accent'"
    global RH_PFX "`pfx'"

    * ------------------------------------------------ SVG body to a tempfile
    * (written first because the <svg> tag needs the finished extent)
    tempfile bodyf
    tempname B
    file open `B' using "`bodyf'", write text replace
    if "`layout'" == "vertical"  _rh_body_v `B' `J' `N' `runmode'
    else                         _rh_body_h `B' `J' `N' `runmode'
    local svgw = `s(w)'
    local svgh = `s(h)'
    file close `B'

    * ------------------------------------------------ assemble
    local jname = substr("`using'", strrpos(subinstr("`using'","\","/",.), "/") + 1, .)
    local mode  = cond(`runmode', "run", "scan")
    local jdir  = substr("`using'", 1, strrpos(subinstr("`using'","\","/",.), "/") - 1)
    if "`jdir'" == "" local jdir "."

    tempname H
    file open `H' using "`out'", write text replace

    if "`embed'" == "" {
        file write `H' `"<!DOCTYPE html>"' _n
        file write `H' `"<html xmlns="http://www.w3.org/1999/xhtml" lang="en">"' _n
        file write `H' `"<head>"' _n
        file write `H' `"<meta charset="utf-8" />"' _n
        file write `H' `"<title>mergemap &#183; `jname' (`mode', `layout')</title>"' _n
        file write `H' `"<style type="text/css">"' _n
        * page chrome: element selectors are safe here, never in embed mode
        file write `H' `"body { font-family: -apple-system, Segoe UI, Helvetica, Arial, sans-serif; color: #222; background: #fff; margin: 24px; max-width: 1100px; }"' _n
        file write `H' `"h1 { font-size: 19px; margin: 0 0 2px 0; font-weight: 600; }"' _n
        _rh_css `H' "`pfx'" "`accent'" "`layout'" `svgw'
        file write `H' `"</style>"' _n
        file write `H' `"</head>"' _n
        file write `H' `"<body>"' _n
        file write `H' `"<h1>mergemap &#183; `jname'</h1>"' _n
    }
    else {
        file write `H' `"<!-- mergemap embed fragment: `jname' (`mode', `layout'). Scoped to .`pfx'; no element selectors; ids namespaced `pfx'-*. -->"' _n
        file write `H' `"<style type="text/css">"' _n
        _rh_css `H' "`pfx'" "`accent'" "`layout'" `svgw'
        file write `H' `"</style>"' _n
    }

    file write `H' `"<div class="mm-embed `pfx'">"' _n

    * syntax returns NOHEADer / NOPROVenance under their full names
    if "`noheader'" == "" {
        local cap `"mode: `mode' &#183; layout: `layout' &#183; `N' events"'
        if `njoin' > 0 {
            if `nflag' == 0 local cap `"`cap' &#183; all `njoin' joins clean"'
            else {
                local cap `"`cap' &#183; `nflag' of `njoin' joins flagged"'
                local sv ""
                if `nstop' > 0 local sv `"`nstop' stop"'
                if `nwarn' > 0 {
                    if `"`sv'"' != "" local sv `"`sv', "'
                    local sv `"`sv'`nwarn' warn"'
                }
                if `"`sv'"' != "" local cap `"`cap': `sv'"'
            }
        }
        if `nother' > 0 {
            local ev = cond(`nother' == 1, "event", "events")
            local cap `"`cap' &#183; `nother' other `ev' flagged"'
        }
        file write `H' `"<div class="mm-cap">`cap'</div>"' _n
        file write `H' `"<div class="mm-leg"><span class="mm-legk">!!</span> = warning or stop (never colour alone) &#183; dashed box = tempfile &#183; &#215;N = collapsed loop &#183; #k = journal event &#183; hover a node for detail</div>"' _n
    }

    file write `H' `"<div class="mm-wrap">"' _n
    if "`embed'" == "" {
        file write `H' `"<svg xmlns="http://www.w3.org/2000/svg" class="mm-svg" role="img" viewBox="0 0 `svgw' `svgh'" width="`svgw'" height="`svgh'">"' _n
    }
    else {
        * embed: viewBox only, no width/height (DECISIONS 21). Horizontal keeps
        * its natural width through a scoped CSS rule inside .mm-wrap.
        file write `H' `"<svg xmlns="http://www.w3.org/2000/svg" class="mm-svg" role="img" viewBox="0 0 `svgw' `svgh'">"' _n
    }
    file write `H' `"<title>mergemap join map for `jname' (`mode' mode)</title>"' _n
    file write `H' `"<desc>Boxes are datasets in memory or on disk; arrows are joins, filters and saves, top to bottom, in do-file order.</desc>"' _n
    file write `H' `"<defs>"' _n
    file write `H' `"<marker id="`pfx'-ag" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#444" /></marker>"' _n
    file write `H' `"<marker id="`pfx'-aa" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="`accent'" /></marker>"' _n
    file write `H' `"</defs>"' _n
    * copy the body (data was neutralized, so no backticks, dollars or quotes)
    tempname R
    file open `R' using "`bodyf'", read text
    file read `R' bline
    while r(eof) == 0 {
        file write `H' `"`macval(bline)'"' _n
        file read `R' bline
    }
    file close `R'
    file write `H' `"</svg>"' _n
    file write `H' `"</div>"' _n

    * ------------------------------------------------ per-event ledger
    if "`details'" != "" {
        file write `H' `"<div class="mm-h2">Event ledger (joins, links, filters)</div>"' _n
        _rh_ledger `H' `J' `N' `runmode'
    }

    * ------------------------------------------------ provenance footer (16g)
    if "`noprovenance'" == "" {
        _rh_prov "`jname'" "`mode'" "`layout'" `N' "`jdir'"
        file write `H' `"<div class="mm-foot">`s(o)'</div>"' _n
    }

    file write `H' `"</div>"' _n
    if "`embed'" == "" {
        file write `H' `"</body>"' _n
        file write `H' `"</html>"' _n
    }
    file close `H'

    frame drop `J'
    _rh_dropglobals

    local tag = cond("`embed'" != "", ", embed fragment", "")
    display as text "_mm_renderhtml: wrote " as result "`out'" ///
        as text " (`mode' mode, `layout', `N' events`tag')"
end


* ============================================================ stylesheet
* Every rule is scoped under the per-diagram class and every selector is a
* class selector. No body/h1/h2/pre/details/summary/bare-svg: those restyled
* the host report in testing (DECISIONS 20d).
program define _rh_css
    args H pfx accent layout svgw

    local P ".`pfx'"
    local MONO "SF Mono, Menlo, Consolas, DejaVu Sans Mono, monospace"
    local SANS "-apple-system, Segoe UI, Helvetica, Arial, sans-serif"

    file write `H' `"`P' { margin: 1rem 0; }"' _n
    * bounded, resizable viewport; the print query below lifts the cap (16k)
    file write `H' `"`P' .mm-wrap { max-height: 32rem; overflow: auto; resize: vertical; border: 1px solid #e4e4e4; border-radius: 4px; padding: 6px; background: #fff; }"' _n
    if "`layout'" == "horizontal" {
        * a horizontal diagram squeezed into a text column drops its labels
        * below 2px (DECISIONS 20h): keep native width, scroll sideways
        file write `H' `"`P' .mm-svg { width: `svgw'px; max-width: none; height: auto; display: block; }"' _n
    }
    else {
        file write `H' `"`P' .mm-svg { max-width: 100%; height: auto; display: block; }"' _n
    }
    file write `H' `"`P' .mm-cap { font-family: `SANS'; font-size: 12px; color: #666; margin: 0 0 3px 0; }"' _n
    file write `H' `"`P' .mm-leg { font-family: `SANS'; font-size: 11px; color: #888; margin: 0 0 8px 0; }"' _n
    file write `H' `"`P' .mm-legk { color: `accent'; font-weight: 700; }"' _n
    file write `H' `"`P' .mm-foot { font-family: `SANS'; font-size: 10px; color: #999; margin: 10px 0 0 0; line-height: 1.5; }"' _n
    file write `H' `"`P' .mm-h2 { font-family: `SANS'; font-size: 15px; font-weight: 600; color: #222; margin: 18px 0 6px 0; }"' _n
    file write `H' `"`P' .mm-det { margin: 6px 0; border: 1px solid #ddd; border-radius: 3px; }"' _n
    file write `H' `"`P' .mm-sum { font-family: `MONO'; font-size: 12px; padding: 5px 8px; cursor: pointer; background: #f7f7f7; }"' _n
    file write `H' `"`P' .mm-pre { font-family: `MONO'; font-size: 12px; line-height: 1.35; color: #222; background: #fff; margin: 0; padding: 8px 12px; overflow-x: auto; }"' _n
    file write `H' `"`P' .mm-flag { font-weight: 700; color: `accent'; }"' _n
    file write `H' `"`P' .mm-node { cursor: help; }"' _n
    * svg text roles
    file write `H' `"`P' .mm-t { font-family: `MONO'; }"' _n
    file write `H' `"`P' .mm-bh { font-size: 12px; font-weight: 700; fill: #111; }"' _n
    file write `H' `"`P' .mm-bl { font-size: 12px; fill: #333; }"' _n
    file write `H' `"`P' .mm-bn { font-size: 11px; fill: #666; }"' _n
    file write `H' `"`P' .mm-bf { font-size: 11px; font-weight: 700; fill: `accent'; }"' _n
    file write `H' `"`P' .mm-bs { font-size: 11px; font-weight: 700; fill: `accent'; }"' _n
    file write `H' `"`P' .mm-cc { font-size: 11px; font-weight: 700; fill: #111; }"' _n
    file write `H' `"`P' .mm-cl { font-size: 11px; fill: #333; }"' _n
    file write `H' `"`P' .mm-cn { font-size: 11px; fill: #666; }"' _n
    file write `H' `"`P' .mm-cf { font-size: 11px; font-weight: 700; fill: `accent'; }"' _n
    file write `H' `"`P' .mm-cs { font-size: 11px; font-weight: 700; fill: `accent'; }"' _n
    file write `H' `"`P' .mm-dof { font-size: 13px; font-weight: 700; fill: #222; }"' _n
    file write `H' `"`P' .mm-hc { font-size: 10px; fill: #333; }"' _n
    file write `H' `"`P' .mm-hn { font-size: 10px; fill: #666; }"' _n
    file write `H' `"`P' .mm-hb { font-size: 10px; font-weight: 700; fill: #111; }"' _n
    file write `H' `"`P' .mm-hf { font-size: 10px; font-weight: 700; fill: `accent'; }"' _n
    file write `H' `"`P' .mm-hs { font-size: 10px; font-weight: 700; fill: `accent'; }"' _n
    * svg shape roles
    file write `H' `"`P' .mm-bx { fill: #f7f7f7; stroke: #333; stroke-width: 1.1; }"' _n
    file write `H' `"`P' .mm-bu { fill: #fcfcfc; stroke: #666; stroke-width: 1; }"' _n
    file write `H' `"`P' .mm-bt { fill: #fff; stroke: #666; stroke-width: 1; stroke-dasharray: 5 3; }"' _n
    file write `H' `"`P' .mm-bstk { fill: #fff; stroke: #999; stroke-width: 1; }"' _n
    file write `H' `"`P' .mm-bw { fill: #fff; stroke: #999; stroke-width: 1; }"' _n
    file write `H' `"`P' .mm-bfil { fill: #fbfbfb; stroke: #888; stroke-width: 1; }"' _n
    file write `H' `"`P' .mm-sevw { stroke: #222; stroke-width: 1.7; }"' _n
    file write `H' `"`P' .mm-sevs { stroke: `accent'; stroke-width: 2.2; }"' _n
    file write `H' `"`P' .mm-sp { stroke: #444; stroke-width: 1.2; fill: none; }"' _n
    file write `H' `"`P' .mm-spd { stroke: #777; stroke-width: 1.1; fill: none; stroke-dasharray: 4 3; }"' _n
    file write `H' `"`P' .mm-hl { stroke: #ccc; stroke-width: 1; }"' _n
    file write `H' `"@media print { `P' .mm-wrap { max-height: none; overflow: visible; resize: none; border: 0; padding: 0; } }"' _n
end


* ============================================================ vertical layout
program define _rh_body_v, sclass
    args B J N runmode

    local W    880
    local SBX  40
    local SBW  310
    local CX   195
    local LX   215
    local UBX  520
    local UBW  340
    local LMAX 44
    local BMAX 40
    local UMAX 44
    local FIN  18

    local y = 8
    local pendconn  0
    local havebox   0
    local prevdof   ""
    local prevcmd   ""
    local prevnout  "."
    local prevkout  "."

    forvalues i = 1/`N' {
        _rh_getrow `J' `i'
        local seq     `"$RH_seq"'
        local dofile  `"$RH_dofile"'
        local evclass `"$RH_evclass"'
        local cmd     `"$RH_cmd"'
        local usingf  `"$RH_usingf"'
        local sev     `"$RH_severity"'
        local n_out   `"$RH_n_out"'
        local k_out   `"$RH_k_out"'
        local flags   `"$RH_flags"'

        * ---- do-file section header
        if `"`dofile'"' != `"`prevdof'"' {
            if `i' > 1 local y = `y' + 8
            local yt = `y' + 12
            _rh_wtext `B' `SBX' `yt' dof `dofile'
            local yl = `y' + 18
            _rh_line `B' `SBX' `yl' 860 `yl' hl
            local y = `y' + 30
            local prevdof `"`dofile'"'
        }

        * ---- source: starts a new spine segment
        if "`evclass'" == "source" {
            if `pendconn' {
                _rh_statebox_v `B' `y' `SBX' `SBW' "`prevcmd'" "`prevnout'" "`prevkout'" `runmode'
                local y = `s(y)'
                local pendconn 0
            }
            if `havebox' local y = `y' + 14
            _rh_sourcelines `BMAX' `runmode'
            local nb     = `s(n)'
            local boxcls "`s(boxcls)'"
            file write `B' `"<g class="mm-node">"' _n
            _rh_tip `B'
            _rh_boxout `B' `SBX' `y' `SBW' `nb' "`boxcls'" "`sev'" "#`seq'" 0
            file write `B' `"</g>"' _n
            local y = `s(y)'
            local havebox 1
        }
        else if inlist("`evclass'", "join", "link") {
            if `pendconn' {
                _rh_statebox_v `B' `y' `SBX' `SBW' "`prevcmd'" "`prevnout'" "`prevkout'" `runmode'
                local y = `s(y)'
                local pendconn 0
            }
            _rh_connlabels `LMAX' `runmode'
            local nl = `s(n)'
            _rh_usinglines `UMAX' `runmode'
            local nu     = `s(n)'
            local ucls   "`s(boxcls)'"
            local isloop = `s(isloop)'
            local uboxh  = 16*`nu' + 14
            * ---------- geometry
            local ay = max(`y' + 15*`nl' + 17, `y' + 12 + ceil(`uboxh'/2) + 10*`isloop')
            local connH = `ay' + ceil(`uboxh'/2) + 10 - `y'
            local yb = `y' + `connH'
            * spine, arrowhead into the next box
            _rh_line `B' `CX' `y' `CX' `=`yb'-1' sp ag
            file write `B' `"<g class="mm-node">"' _n
            _rh_tip `B'
            * connector labels
            forvalues k = 1/`nl' {
                local ly = `y' + 4 + 15*`k'
                _rh_wtext `B' `LX' `ly' ${MMAC`k'} ${MMAL`k'}
            }
            * arrow from the using box into the spine
            local dash = cond("`cmd'" == "fralias", "spd", "sp")
            _rh_line `B' `UBX' `ay' 203 `ay' `dash' aa
            * using box (stack rects behind it when the loop is collapsed)
            local ut = `ay' - ceil(`uboxh'/2)
            if `isloop' {
                _rh_rect `B' `=`UBX'+10' `=`ut'-10' `UBW' `uboxh' bstk ""
                _rh_rect `B' `=`UBX'+5'  `=`ut'-5'  `UBW' `uboxh' bstk ""
            }
            _rh_rect `B' `UBX' `ut' `UBW' `uboxh' "`ucls'" "`sev'"
            forvalues k = 1/`nu' {
                local ly = `ut' + 5 + 16*`k'
                _rh_wtext `B' `=`UBX'+8' `ly' ${MMBC`k'} ${MMBL`k'}
            }
            file write `B' `"</g>"' _n
            local y = `yb'
            local pendconn 1
            local havebox 0
            local prevcmd  "`cmd'"
            local prevnout "`n_out'"
            local prevkout "`k_out'"
        }
        else {
            * transform / filter / save / note / flow: a box on the spine
            if !`pendconn' & `havebox' {
                _rh_line `B' `CX' `y' `CX' `=`y'+25' sp ag
                local y = `y' + 26
            }
            local pendconn 0
            local slim = ("`evclass'" == "filter")
            local bx   = cond(`slim', `SBX' + `FIN', `SBX')
            local bw   = cond(`slim', `SBW' - 2*`FIN', `SBW')
            local bmax = cond(`slim', `BMAX' - 5, `BMAX')
            _rh_nodelines `bmax' `runmode'
            local nb     = `s(n)'
            local boxcls "`s(boxcls)'"
            file write `B' `"<g class="mm-node">"' _n
            _rh_tip `B'
            _rh_boxout `B' `bx' `y' `bw' `nb' "`boxcls'" "`sev'" "#`seq'" `slim'
            file write `B' `"</g>"' _n
            local y = `s(y)'
            local havebox 1
        }
    }
    if `pendconn' {
        _rh_statebox_v `B' `y' `SBX' `SBW' "`prevcmd'" "`prevnout'" "`prevkout'" `runmode'
        local y = `s(y)'
    }
    sreturn clear
    sreturn local w = `W'
    sreturn local h = `y' + 14
end

* implicit in-memory state box (lands a join when the next event is another join)
program define _rh_statebox_v, sclass
    args B y x w cmd nout kout runmode
    _rh_clearlines B
    global MMBL1 "work (after `cmd')"
    global MMBC1 "bl"
    local nb 1
    if `runmode' & "`nout'" != "." {
        _rh_n `nout'
        local c1 `"`s(o)'"'
        _rh_n `kout'
        local nb 2
        global MMBL2 `"`c1' `=char(2)' `s(o)'"'
        global MMBC2 "bn"
    }
    _rh_boxout `B' `x' `y' `w' `nb' "bw" "" "" 0
    sreturn local y = `s(y)'
end


* ============================================================ horizontal layout
program define _rh_body_h, sclass
    args B J N runmode

    local SBY   210
    local SBH   78
    local SBW   230
    local SPY   249
    local UBW   250
    local UBOT  178
    local GAPJ  270
    local GAPP  64
    local GAPS  46
    local LY0   306
    local LMAX  46
    local BMAX  28
    local UMAX  32

    local x = 24
    local pendconn 0
    local havebox  0
    local prevdof  ""
    local prevcmd  ""
    local prevnout "."
    local prevkout "."
    local maxlab   0

    forvalues i = 1/`N' {
        _rh_getrow `J' `i'
        local seq     `"$RH_seq"'
        local dofile  `"$RH_dofile"'
        local evclass `"$RH_evclass"'
        local cmd     `"$RH_cmd"'
        local sev     `"$RH_severity"'
        local n_out   `"$RH_n_out"'
        local k_out   `"$RH_k_out"'

        if `"`dofile'"' != `"`prevdof'"' {
            if `i' > 1 local x = `x' + 10
            _rh_wtext `B' `x' 26 dof `dofile'
            file write `B' `"<line x1="`x'" y1="32" x2="`x'" y2="`SBY'" class="mm-hl" stroke="#ccc" stroke-width="1" stroke-dasharray="2 4" />"' _n
            local prevdof `"`dofile'"'
        }

        if "`evclass'" == "source" {
            if `pendconn' {
                _rh_statebox_h `B' `x' `SBY' `SBW' `SBH' "`prevcmd'" "`prevnout'" "`prevkout'" `runmode'
                local x = `s(x)'
                local pendconn 0
            }
            if `havebox' local x = `x' + `GAPS'
            _rh_sourcelines `BMAX' `runmode'
            local nb     = min(`s(n)', 4)
            local boxcls "`s(boxcls)'"
            file write `B' `"<g class="mm-node">"' _n
            _rh_tip `B'
            _rh_hbox `B' `x' `SBY' `SBW' `SBH' "`boxcls'" "`sev'" "#`seq'" `nb'
            file write `B' `"</g>"' _n
            local x = `x' + `SBW'
            local havebox 1
        }
        else if inlist("`evclass'", "join", "link") {
            if `pendconn' {
                _rh_statebox_h `B' `x' `SBY' `SBW' `SBH' "`prevcmd'" "`prevnout'" "`prevkout'" `runmode'
                local x = `s(x)'
                local pendconn 0
            }
            _rh_connlabels `LMAX' `runmode'
            local nl = `s(n)'
            local maxlab = max(`maxlab', `nl')
            _rh_usinglines `UMAX' `runmode'
            local nu     = `s(n)'
            local ucls   "`s(boxcls)'"
            local isloop = `s(isloop)'
            local uboxh  = 16*`nu' + 14
            * spine segment across the gap, arrowhead into the next box
            _rh_line `B' `x' `SPY' `=`x'+`GAPJ'-2' `SPY' sp ag
            file write `B' `"<g class="mm-node">"' _n
            _rh_tip `B'
            * labels under the gap (small font)
            local lxx = `x' - 26
            forvalues k = 1/`nl' {
                local ly = `LY0' + 13*`k' - 13
                local cc "${MMAC`k'}"
                if      "`cc'" == "cf" local hcl "hf"
                else if "`cc'" == "cs" local hcl "hs"
                else if "`cc'" == "cn" local hcl "hn"
                else if "`cc'" == "cc" local hcl "hb"
                else                   local hcl "hc"
                _rh_wtext `B' `lxx' `ly' `hcl' ${MMAL`k'}
            }
            * using box above the spine, arrow down into it
            local gcx = `x' + floor(`GAPJ'/2)
            local ut  = `UBOT' - `uboxh'
            local ux  = `gcx' - floor(`UBW'/2)
            if `isloop' {
                _rh_rect `B' `=`ux'+10' `=`ut'-10' `UBW' `uboxh' bstk ""
                _rh_rect `B' `=`ux'+5'  `=`ut'-5'  `UBW' `uboxh' bstk ""
            }
            _rh_rect `B' `ux' `ut' `UBW' `uboxh' "`ucls'" "`sev'"
            forvalues k = 1/`nu' {
                local ly = `ut' + 5 + 16*`k'
                _rh_wtext `B' `=`ux'+8' `ly' ${MMBC`k'} ${MMBL`k'}
            }
            local dash = cond("`cmd'" == "fralias", "spd", "sp")
            _rh_line `B' `gcx' `UBOT' `gcx' `=`SPY'-4' `dash' aa
            file write `B' `"</g>"' _n
            local x = `x' + `GAPJ'
            local pendconn 1
            local havebox 0
            local prevcmd  "`cmd'"
            local prevnout "`n_out'"
            local prevkout "`k_out'"
        }
        else {
            if !`pendconn' & `havebox' {
                _rh_line `B' `x' `SPY' `=`x'+`GAPP'-2' `SPY' sp ag
                local x = `x' + `GAPP'
            }
            local pendconn 0
            local slim = ("`evclass'" == "filter")
            local by   = cond(`slim', `SBY' + 12, `SBY')
            local bh   = cond(`slim', `SBH' - 24, `SBH')
            local bw   = cond(`slim', 190, `SBW')
            local bmax = cond(`slim', 22, `BMAX')
            _rh_nodelines `bmax' `runmode'
            local nb     = min(`s(n)', cond(`slim', 3, 4))
            local boxcls "`s(boxcls)'"
            file write `B' `"<g class="mm-node">"' _n
            _rh_tip `B'
            _rh_hbox `B' `x' `by' `bw' `bh' "`boxcls'" "`sev'" "#`seq'" `nb'
            file write `B' `"</g>"' _n
            local x = `x' + `bw'
            local havebox 1
        }
    }
    if `pendconn' {
        _rh_statebox_h `B' `x' `SBY' `SBW' `SBH' "`prevcmd'" "`prevnout'" "`prevkout'" `runmode'
        local x = `s(x)'
    }
    sreturn clear
    sreturn local w = `x' + 24
    sreturn local h = `LY0' + 13*max(`maxlab',1) + 16
end

program define _rh_statebox_h, sclass
    args B x y w h cmd nout kout runmode
    _rh_clearlines B
    global MMBL1 "work (after `cmd')"
    global MMBC1 "bl"
    local nb 1
    if `runmode' & "`nout'" != "." {
        _rh_n `nout'
        local c1 `"`s(o)'"'
        _rh_n `kout'
        local nb 2
        global MMBL2 `"`c1' `=char(2)' `s(o)'"'
        global MMBC2 "bn"
    }
    _rh_hbox `B' `x' `y' `w' `h' "bw" "" "" `nb'
    sreturn local x = `x' + `w'
end


* ============================================================ box writers
* Both read the line stack in MMBL1..MMBL8 / MMBC1..MMBC8.

* horizontal fixed-height box
program define _rh_hbox
    args B x y w h cls sev seq nb
    _rh_rect `B' `x' `y' `w' `h' "`cls'" "`sev'"
    if "`seq'" != "" _rh_wtext `B' `=`x'+3' `=`y'-5' bn `seq'
    forvalues k = 1/`nb' {
        if `"${MMBL`k'}"' != "" {
            local ly = `y' + 4 + 16*`k'
            _rh_wtext `B' `=`x'+8' `ly' ${MMBC`k'} ${MMBL`k'}
        }
    }
end

* vertical variable-height box; returns s(y) = y after the box
program define _rh_boxout, sclass
    args B x y w nb cls sev seq slim
    if "`slim'" == "" local slim 0
    local lh  = cond(`slim', 15, 16)
    local pad = cond(`slim', 10, 14)
    local h = `lh'*`nb' + `pad'
    _rh_rect `B' `x' `y' `w' `h' "`cls'" "`sev'"
    if "`seq'" != "" _rh_wtext `B' `=`x'-30' `=`y'+16' bn `seq'
    forvalues k = 1/`nb' {
        if `"${MMBL`k'}"' != "" {
            local ly = `y' + `=`pad'/2 + 1' + `lh'*`k'
            _rh_wtext `B' `=`x'+8' `ly' ${MMBC`k'} ${MMBL`k'}
        }
    }
    sreturn local y = `y' + `h'
end


* ============================================================ content builders
* _rh_getrow caches the current journal row in globals RH_* so the label
* builders below can be called after the caller has consumed s().

program define _rh_getrow
    args J i
    foreach f in seq dofile linenum evclass cmd subtype keys master usingf ///
                 result n_in k_in n_using k_using n_out k_out m1 m2 m3 m4 m5 ///
                 dup_master dup_using force opts loop_n loop_first loop_last ///
                 severity keytypes cover_master cover_using lifecycle flags {
        frame `J': local v = `f'[`i']
        global RH_`f' `"`v'"'
    }
end

* clear a line stack: prefix B = box lines, A = connector labels
program define _rh_clearlines
    args p
    forvalues k = 1/16 {
        global MM`p'L`k' ""
        global MM`p'C`k' ""
    }
end

* --------------------------------------------------- source box (use/import)
* fills MMBL*/MMBC*; s(n), s(boxcls)
program define _rh_sourcelines, sclass
    args BMAX runmode
    _rh_clearlines B
    local n 1
    _rh_mell `BMAX' `"$RH_usingf"'
    global MMBL1 `"`s(o)'"'
    global MMBC1 "bh"
    local boxcls "bx"
    if strpos(`"$RH_usingf"', "tempfile:") == 1 {
        local ++n
        global MMBL`n' "[tempfile]"
        global MMBC`n' "bn"
        local boxcls "bt"
    }
    else if "$RH_lifecycle" == "overwrite" {
        local ++n
        global MMBL`n' "[read, later overwritten]"
        global MMBC`n' "bn"
    }
    if `runmode' & `"$RH_n_out"' != "." {
        _rh_n $RH_n_out
        local cnt `"`s(o)'"'
        _rh_n $RH_k_out
        local ++n
        global MMBL`n' `"`cnt' `=char(2)' `s(o)'"'
        global MMBC`n' "bl"
    }
    _rh_flagtext
    local ftxt `"`s(o)'"'
    if `"`ftxt'"' != "" {
        _rh_flaglines `BMAX' 3 "$RH_severity" `"`ftxt'"'
        local nf = `s(n)'
        forvalues fj = 1/`nf' {
            local fl`fj' `"`s(l`fj')'"'
            local fc`fj' `"`s(c`fj')'"'
        }
        forvalues fj = 1/`nf' {
            if `n' >= 8 continue, break
            local ++n
            global MMBL`n' `"`fl`fj''"'
            global MMBC`n' `"b`fc`fj''"'
        }
    }
    sreturn clear
    sreturn local n = `n'
    sreturn local boxcls "`boxcls'"
end

* --------------------------------------------------- connector labels (join)
* fills MMAL*/MMAC*; s(n)
program define _rh_connlabels, sclass
    args LMAX runmode
    _rh_clearlines A
    local n 0
    * 1. command line: #seq cmd subtype keys [force]
    local cl `"#$RH_seq $RH_cmd"'
    if `"$RH_subtype"' != "." local cl `"`cl' $RH_subtype"'
    if `"$RH_keys"'    != "." local cl `"`cl' $RH_keys"'
    if "$RH_force" == "1"     local cl `"`cl', force"'
    local ++n
    _rh_mell `LMAX' `"`cl'"'
    local l`n' `"`s(o)'"'
    local c`n' "cc"
    * 2. collapsed loop stack
    if `"$RH_loop_n"' != "." & `"$RH_loop_n"' != "" {
        _rh_mell 18 `"$RH_loop_first"'
        local lf `"`s(o)'"'
        _rh_mell 18 `"$RH_loop_last"'
        local ++n
        local l`n' `"`=char(2)'$RH_loop_n: `lf' `=char(1)' `s(o)'"'
        local c`n' "cl"
    }
    * 3. run-mode _merge breakdown (with keep() drop annotation)
    if `runmode' {
        if `"$RH_m3"' != "." | `"$RH_m1"' != "." {
            _rh_keepset `"$RH_opts"'
            local kept `"`s(kept)'"'
            local parts ""
            local sep ""
            foreach c in 3 1 2 {
                local v "${RH_m`c'}"
                if "`v'" == "." | "`v'" == "" continue
                if `c' == 3 local nm "matched"
                if `c' == 1 local nm "master-only"
                if `c' == 2 local nm "using-only"
                _rh_n `v'
                local vf `"`s(o)'"'
                if !strpos(`"`kept'"', " `c' ") & "`v'" != "0" {
                    local parts `"`parts'`sep'`nm' (`vf' dropped)"'
                }
                else local parts `"`parts'`sep'`nm' `vf'"'
                local sep `" `=char(3)' "'
            }
            _rh_wrapn `LMAX' 2 `"`parts'"'
            local nw = `s(n)'
            local w1 `"`s(l1)'"'
            local w2 `"`s(l2)'"'
            local ++n
            local l`n' `"`w1'"'
            local c`n' "cl"
            if `nw' == 2 {
                local ++n
                local l`n' `"`w2'"'
                local c`n' "cl"
            }
        }
        * append: obs added
        if "$RH_cmd" == "append" & `"$RH_n_using"' != "." {
            _rh_n $RH_n_using
            local ln `"+`s(o)' obs"'
            if `"$RH_loop_n"' != "." & `"$RH_loop_n"' != "" {
                local ln `"`ln' from $RH_loop_n files"'
            }
            local ++n
            local l`n' `"`ln'"'
            local c`n' "cl"
        }
        * update counts
        local u4 "$RH_m4"
        local u5 "$RH_m5"
        if ("`u4'" != "." & "`u4'" != "0" & "`u4'" != "") | ///
           ("`u5'" != "." & "`u5'" != "0" & "`u5'" != "") {
            _rh_n `u4'
            local a `"`s(o)'"'
            _rh_n `u5'
            local ++n
            local l`n' `"updated: `a' missing `=char(3)' `s(o)' conflicts"'
            local c`n' "cl"
        }
        * duplicate-key note
        local dm "$RH_dup_master"
        local du "$RH_dup_using"
        if ("`dm'" != "." & "`dm'" != "0" & "`dm'" != "") | ///
           ("`du'" != "." & "`du'" != "0" & "`du'" != "") {
            _rh_n `dm'
            local a `"`s(o)'"'
            _rh_n `du'
            local b `"`s(o)'"'
            if "`a'" == "" local a "0"
            if "`b'" == "" local b "0"
            local ++n
            local l`n' `"dup-key obs: master `a' `=char(3)' using `b'"'
            local c`n' "cn"
        }
    }
    * 4. coverage percentages (16e), present whenever run mode measured them
    _rh_cover
    if `"`s(o)'"' != "" {
        local ++n
        local l`n' `"`s(o)'"'
        local c`n' "cl"
    }
    * 5. key storage types (16c); a drift is a flag, agreement is a note
    _rh_keytypes `"$RH_keytypes"'
    if `"`s(o)'"' != "" {
        local mis = `s(mis)'
        local kt  `"`s(o)'"'
        * a storage-type drift is a warning, and it says so in text as well as
        * in colour
        if `mis' local kt `"!! `kt'"'
        local ++n
        _rh_mell `LMAX' `"`kt'"'
        local l`n' `"`s(o)'"'
        local c`n' = cond(`mis', "cf", "cn")
    }
    * 6. options (both modes: scan needs them to say anything at all)
    if `"$RH_opts"' != "." & `"$RH_opts"' != "" & `"$RH_opts"' != "clear" {
        _rh_mell `=`LMAX'-6' `"$RH_opts"'
        local ++n
        local l`n' `"opts: `s(o)'"'
        local c`n' "cn"
    }
    * 7. run-mode result
    if `runmode' & `"$RH_n_out"' != "." {
        _rh_n $RH_n_out
        local a `"`s(o)'"'
        _rh_n $RH_k_out
        local ++n
        local l`n' `"`=char(4)' `a' `=char(2)' `s(o)'"'
        local c`n' "cl"
    }
    * 8. flags, severity-marked
    _rh_flagtext
    local ftxt `"`s(o)'"'
    if `"`ftxt'"' != "" {
        _rh_flaglines `LMAX' 3 "$RH_severity" `"`ftxt'"'
        local nf = `s(n)'
        forvalues k = 1/`nf' {
            local fl`k' `"`s(l`k')'"'
            local fc`k' `"`s(c`k')'"'
        }
        forvalues k = 1/`nf' {
            local ++n
            local l`n' `"`fl`k''"'
            local c`n' `"c`fc`k''"'
        }
    }
    if `n' > 16 local n 16
    forvalues k = 1/`n' {
        global MMAL`k' `"`l`k''"'
        global MMAC`k' `"`c`k''"'
    }
    sreturn clear
    sreturn local n = `n'
end

* --------------------------------------------------- using box lines
* fills MMBL*/MMBC*; s(n), s(boxcls), s(isloop)
program define _rh_usinglines, sclass
    args UMAX runmode
    _rh_clearlines B
    local n 1
    _rh_mell `UMAX' `"$RH_usingf"'
    global MMBL1 `"`s(o)'"'
    global MMBC1 "bh"
    local boxcls "bu"
    local isloop 0
    if strpos(`"$RH_usingf"', "tempfile:") == 1 local boxcls "bt"
    if `"$RH_loop_n"' != "." & `"$RH_loop_n"' != "" {
        local isloop 1
        _rh_mell `=floor((`UMAX'-8)/2)' `"$RH_loop_first"'
        local lf `"`s(o)'"'
        _rh_mell `=floor((`UMAX'-8)/2)' `"$RH_loop_last"'
        local ++n
        global MMBL`n' `"`=char(2)'$RH_loop_n: `lf' `=char(1)' `s(o)'"'
        global MMBC`n' "bn"
    }
    * a path still holding a macro is a designed boundary, not a bug (NOVICE_UX B8)
    if `"$RH_loop_n"' == "." & strpos(`"$RH_usingf"', char(6)) {
        local ++n
        global MMBL`n' "(macro path; run mode resolves it)"
        global MMBC`n' "bn"
    }
    local cnt ""
    if `runmode' & `"$RH_n_using"' != "." {
        _rh_n $RH_n_using
        local cnt `"`s(o)'"'
        _rh_n $RH_k_using
        local cnt `"`cnt' `=char(2)' `s(o)'"'
    }
    local keyln ""
    if `"$RH_keys"' != "." & `"$RH_keys"' != "" local keyln "key: $RH_keys"
    if `"`cnt'"' != "" & `"`keyln'"' != "" {
        if strlen(`"`cnt' x `keyln'"') + 2 <= `UMAX' {
            local ++n
            global MMBL`n' `"`cnt' `=char(3)' `keyln'"'
            global MMBC`n' "bl"
        }
        else {
            local ++n
            global MMBL`n' `"`cnt'"'
            global MMBC`n' "bl"
            local ++n
            _rh_mell `UMAX' `"`keyln'"'
            global MMBL`n' `"`s(o)'"'
            global MMBC`n' "bl"
        }
    }
    else if `"`cnt'"' != "" {
        local ++n
        global MMBL`n' `"`cnt'"'
        global MMBC`n' "bl"
    }
    else if `"`keyln'"' != "" {
        local ++n
        _rh_mell `UMAX' `"`keyln'"'
        global MMBL`n' `"`s(o)'"'
        global MMBC`n' "bl"
    }
    sreturn clear
    sreturn local n = `n'
    sreturn local boxcls "`boxcls'"
    sreturn local isloop = `isloop'
end

* --------------------------------------------------- spine box lines
* transform / filter / save / note / flow; fills MMBL*/MMBC*; s(n), s(boxcls)
program define _rh_nodelines, sclass
    args BMAX runmode
    _rh_clearlines B
    local n 0
    local boxcls "bx"
    if "$RH_evclass" == "save" {
        local ++n
        _rh_mell `BMAX' `"$RH_result"'
        local l`n' `"`s(o)'"'
        local c`n' "bh"
        local mark "[saved]"
        if "$RH_subtype" == "tempfile" | strpos(`"$RH_result"', "tempfile:") == 1 {
            local mark "[tempfile]"
            local boxcls "bt"
        }
        else if "$RH_lifecycle" == "overwrite" local mark "[saved, overwrites]"
        else if "$RH_lifecycle" == "create"    local mark "[saved, new]"
        local cnt ""
        if `runmode' & `"$RH_n_out"' != "." {
            _rh_n $RH_n_out
            local cnt `"`s(o)'"'
            _rh_n $RH_k_out
            local cnt `"`cnt' `=char(2)' `s(o)' `=char(3)' "'
        }
        local ++n
        local l`n' `"`cnt'`mark'"'
        local c`n' "bl"
    }
    else if "$RH_evclass" == "filter" {
        * a slim spine node: what the condition was, and what it cost
        local boxcls "bfil"
        local hd "$RH_cmd"
        if `"$RH_opts"' != "." & `"$RH_opts"' != "" local hd `"`hd' $RH_opts"'
        else if `"$RH_subtype"' != "." local hd `"`hd' $RH_subtype"'
        _rh_wrapn `BMAX' 2 `"`hd'"'
        local nw = `s(n)'
        local h1 `"`s(l1)'"'
        local h2 `"`s(l2)'"'
        local ++n
        local l`n' `"`h1'"'
        local c`n' "bh"
        if `nw' == 2 {
            local ++n
            local l`n' `"`h2'"'
            local c`n' "bh"
        }
        if `runmode' & `"$RH_n_in"' != "." & `"$RH_n_out"' != "." & ///
           `"$RH_flags"' == "." {
            _rh_n $RH_n_in
            local a `"`s(o)'"'
            _rh_n $RH_n_out
            local ++n
            local l`n' `"`a' `=char(4)' `s(o)' obs"'
            local c`n' "bn"
        }
        if !`runmode' {
            local ln "row change unknown until run"
            if strlen("`ln'") > `BMAX' local ln "rows: run mode only"
            local ++n
            _rh_mell `BMAX' `"`ln'"'
            local l`n' `"`s(o)'"'
            local c`n' "bn"
        }
    }
    else if "$RH_evclass" == "transform" {
        local ++n
        local hd "$RH_cmd"
        if `"$RH_subtype"' != "." local hd `"`hd' $RH_subtype"'
        if "$RH_force" == "1"     local hd `"`hd', force"'
        local l`n' `"`hd'"'
        local c`n' "bh"
        if `"$RH_opts"' != "." & `"$RH_opts"' != "" {
            local ++n
            _rh_mell `BMAX' `"$RH_opts"'
            local l`n' `"`s(o)'"'
            local c`n' "bl"
        }
        else if `"$RH_keys"' != "." & `"$RH_keys"' != "" {
            local ++n
            _rh_mell `BMAX' `"keys: $RH_keys"'
            local l`n' `"`s(o)'"'
            local c`n' "bl"
        }
        if `runmode' & `"$RH_n_in"' != "." & `"$RH_n_out"' != "." {
            _rh_n $RH_n_in
            local a `"`s(o)'"'
            _rh_n $RH_n_out
            local ++n
            local l`n' `"`a' `=char(4)' `s(o)' obs"'
            local c`n' "bn"
        }
    }
    else {
        * note / flow
        local ++n
        local hd "$RH_cmd"
        if `"$RH_usingf"' != "." local hd `"`hd' $RH_usingf"'
        _rh_mell `BMAX' `"`hd'"'
        local l`n' `"`s(o)'"'
        local c`n' "bl"
        local boxcls "bw"
    }
    _rh_flagtext
    local ftxt `"`s(o)'"'
    if `"`ftxt'"' != "" {
        _rh_flaglines `BMAX' 3 "$RH_severity" `"`ftxt'"'
        local nf = `s(n)'
        forvalues k = 1/`nf' {
            local fl`k' `"`s(l`k')'"'
            local fc`k' `"`s(c`k')'"'
        }
        forvalues k = 1/`nf' {
            if `n' >= 8 continue, break
            local ++n
            local l`n' `"`fl`k''"'
            local c`n' `"b`fc`k''"'
        }
    }
    forvalues k = 1/`n' {
        global MMBL`k' `"`l`k''"'
        global MMBC`k' `"`c`k''"'
    }
    sreturn clear
    sreturn local n = `n'
    sreturn local boxcls "`boxcls'"
end


* ============================================================ tooltips (16k)
* One <title> per node group: key, counts, coverage, types, flags. No JS.
program define _rh_tip
    args B
    file write `B' `"<title>"'
    local hd `"#$RH_seq `=char(3)' $RH_dofile line $RH_linenum `=char(3)' $RH_cmd"'
    if `"$RH_subtype"' != "." local hd `"`hd' $RH_subtype"'
    _rh_wtip `B' `hd'
    if `"$RH_keys"' != "." _rh_wtip `B' key: $RH_keys
    if `"$RH_usingf"' != "." _rh_wtip `B' file: $RH_usingf
    if `"$RH_result"' != "." & "$RH_evclass" == "save" _rh_wtip `B' saved to: $RH_result
    * counts
    _rh_n $RH_n_in
    local a `"`s(o)'"'
    _rh_n $RH_k_in
    local b `"`s(o)'"'
    _rh_n $RH_n_out
    local e `"`s(o)'"'
    _rh_n $RH_k_out
    local f `"`s(o)'"'
    if "`a'" != "" | "`e'" != "" {
        local ln ""
        if "`a'" != "" local ln `"in `a' `=char(2)' `b'"'
        if "`e'" != "" {
            if `"`ln'"' != "" local ln `"`ln' `=char(4)' "'
            local ln `"`ln'out `e' `=char(2)' `f'"'
        }
        _rh_wtip `B' `ln'
    }
    _rh_n $RH_n_using
    local c `"`s(o)'"'
    _rh_n $RH_k_using
    if "`c'" != "" _rh_wtip `B' using `c' `=char(2)' `s(o)'
    * merge categories
    if `"$RH_m3"' != "." | `"$RH_m1"' != "." {
        local parts ""
        local sep ""
        foreach cc in 3 1 2 4 5 {
            local v "${RH_m`cc'}"
            if "`v'" == "." | "`v'" == "" continue
            if `cc' == 3 local nm "matched"
            if `cc' == 1 local nm "master-only"
            if `cc' == 2 local nm "using-only"
            if `cc' == 4 local nm "missing-updated"
            if `cc' == 5 local nm "conflict-updated"
            _rh_n `v'
            local parts `"`parts'`sep'`nm' `s(o)'"'
            local sep `" `=char(3)' "'
        }
        if `"`parts'"' != "" _rh_wtip `B' `parts'
    }
    _rh_cover
    if `"`s(o)'"' != "" _rh_wtip `B' `s(o)'
    _rh_keytypes `"$RH_keytypes"'
    if `"`s(o)'"' != "" _rh_wtip `B' `s(o)'
    if `"$RH_dup_master"' != "." | `"$RH_dup_using"' != "." {
        _rh_n $RH_dup_master
        local a `"`s(o)'"'
        _rh_n $RH_dup_using
        local b `"`s(o)'"'
        if "`a'" == "" local a "0"
        if "`b'" == "" local b "0"
        _rh_wtip `B' dup-key obs: master `a' `=char(3)' using `b'
    }
    if `"$RH_opts"' != "." & `"$RH_opts"' != "" _rh_wtip `B' opts: $RH_opts
    if "$RH_force" == "1" _rh_wtip `B' !! force
    if `"$RH_lifecycle"' != "." _rh_wtip `B' lifecycle: $RH_lifecycle
    if `"$RH_severity"' != "." & "$RH_severity" != "note" ///
        _rh_wtip `B' severity: $RH_severity
    if `"$RH_flags"' != "." & `"$RH_flags"' != "" {
        local rest `"$RH_flags"'
        while `"`rest'"' != "" {
            local p = strpos(`"`rest'"', "; ")
            if `p' {
                local one = substr(`"`rest'"', 1, `p'-1)
                local rest = substr(`"`rest'"', `p'+2, .)
            }
            else {
                local one `"`rest'"'
                local rest ""
            }
            _rh_wtip `B' `one'
        }
    }
    file write `B' `"</title>"' _n
end

* one tooltip line (a real newline: browsers honour it inside svg <title>)
program define _rh_wtip
    gettoken h 0 : 0
    _rh_map `"`0'"'
    local t = trim(`"`s(o)'"')
    file write `h' `"`t'"' _n
end


* ============================================================ ledger (details)
program define _rh_ledger
    args H J N runmode
    forvalues i = 1/`N' {
        _rh_getrow `J' `i'
        if !inlist("$RH_evclass", "join", "link", "filter") continue
        local hd `"#$RH_seq `=char(3)' $RH_dofile line $RH_linenum `=char(3)' $RH_cmd"'
        if "$RH_evclass" == "filter" {
            * opts already carries the whole condition, subtype just repeats "if"
            if `"$RH_opts"' != "." local hd `"`hd' $RH_opts"'
            else if `"$RH_subtype"' != "." local hd `"`hd' $RH_subtype"'
        }
        else {
            if `"$RH_subtype"' != "." local hd `"`hd' $RH_subtype"'
            if `"$RH_keys"'    != "." local hd `"`hd' $RH_keys"'
            if `"$RH_usingf"'  != "." local hd `"`hd' using $RH_usingf"'
        }
        if inlist("$RH_severity", "warn", "stop") local hd `"`hd'   !! $RH_severity"'
        file write `H' `"<details class="mm-det">"' _n
        file write `H' `"<summary class="mm-sum">"'
        _rh_wraw `H' `hd'
        file write `H' `"</summary>"' _n
        file write `H' `"<pre class="mm-pre">"' _n
        local l1 `"mergemap: $RH_cmd"'
        if "$RH_evclass" == "filter" {
            if `"$RH_opts"' != "." local l1 `"`l1' $RH_opts"'
        }
        else {
            if `"$RH_subtype"' != "." local l1 `"`l1' $RH_subtype"'
            if `"$RH_keys"'    != "." local l1 `"`l1' $RH_keys"'
            if `"$RH_usingf"'  != "." local l1 `"`l1' using $RH_usingf"'
        }
        local l1 `"`l1'   ($RH_dofile line $RH_linenum)"'
        _rh_wpre `H' - `l1'
        if `"$RH_keys"' != "." {
            local l2 `"`=char(5)'key: $RH_keys"'
            if `"$RH_subtype"' != "." local l2 `"`l2'   declared $RH_subtype"'
            _rh_wpre `H' - `l2'
        }
        if `"$RH_loop_n"' != "." & `"$RH_loop_n"' != "" {
            _rh_wpre `H' - `=char(5)'loop: `=char(2)'$RH_loop_n files, $RH_loop_first `=char(1)' $RH_loop_last
        }
        if `runmode' & `"$RH_n_in"' != "." {
            _rh_n $RH_n_in
            local a `"`s(o)'"'
            _rh_n $RH_k_in
            local b `"`s(o)'"'
            _rh_n $RH_n_using
            local c `"`s(o)'"'
            _rh_n $RH_k_using
            local d `"`s(o)'"'
            _rh_n $RH_n_out
            local e `"`s(o)'"'
            _rh_n $RH_k_out
            local f `"`s(o)'"'
            * build the whole line in a local: a command line collapses the
            * double spaces that keep the separators readable
            local mid `"master `a' `=char(2)' `b'"'
            if "`c'" != "" local mid `"`mid'  `=char(3)'  using `c' `=char(2)' `d'"'
            local mid `"`mid'  `=char(3)'  result `e' `=char(2)' `f'"'
            _rh_wpre `H' - `=char(5)'`mid'
        }
        if `runmode' & (`"$RH_m3"' != "." | `"$RH_m1"' != ".") {
            _rh_keepset `"$RH_opts"'
            local kept `"`s(kept)'"'
            local parts ""
            local sep ""
            foreach c in 3 1 2 {
                local v "${RH_m`c'}"
                if "`v'" == "." | "`v'" == "" continue
                if `c' == 3 local nm "matched"
                if `c' == 1 local nm "master-only"
                if `c' == 2 local nm "using-only"
                _rh_n `v'
                local vf `"`s(o)'"'
                if !strpos(`"`kept'"', " `c' ") & "`v'" != "0" {
                    local parts `"`parts'`sep'`nm' (`vf' dropped)"'
                }
                else local parts `"`parts'`sep'`nm' `vf'"'
                local sep `"  `=char(3)'  "'
            }
            _rh_wpre `H' - `=char(5)'`parts'
        }
        if `runmode' {
            local u4 "$RH_m4"
            local u5 "$RH_m5"
            if ("`u4'" != "." & "`u4'" != "0" & "`u4'" != "") | ///
               ("`u5'" != "." & "`u5'" != "0" & "`u5'" != "") {
                _rh_n `u4'
                local a `"`s(o)'"'
                _rh_n `u5'
                local ml `"updated: missing `a'  `=char(3)'  conflicts `s(o)'"'
                _rh_wpre `H' - `=char(5)'`ml'
            }
            local dm "$RH_dup_master"
            local du "$RH_dup_using"
            if ("`dm'" != "." & "`dm'" != "") | ("`du'" != "." & "`du'" != "") {
                _rh_n `dm'
                local a `"`s(o)'"'
                _rh_n `du'
                local b `"`s(o)'"'
                if "`a'" == "" local a "."
                if "`b'" == "" local b "."
                local dl `"duplicate-key obs: master `a'  `=char(3)'  using `b'"'
                _rh_wpre `H' - `=char(5)'`dl'
            }
        }
        _rh_cover
        if `"`s(o)'"' != "" _rh_wpre `H' - `=char(5)'`s(o)'
        _rh_keytypes `"$RH_keytypes"'
        if `"`s(o)'"' != "" {
            local mis = `s(mis)'
            local kt `"`s(o)'"'
            if `mis' _rh_wpre `H' flag `=char(5)'!! `kt'
            else     _rh_wpre `H' -    `=char(5)'`kt'
        }
        if `"$RH_opts"' != "." & `"$RH_opts"' != "" {
            _rh_wpre `H' - `=char(5)'options: $RH_opts
        }
        if `"$RH_lifecycle"' != "." {
            _rh_wpre `H' - `=char(5)'lifecycle: $RH_lifecycle
        }
        if "$RH_force" == "1" {
            _rh_wpre `H' flag `=char(5)'!! force
        }
        _rh_flagtext
        local ftxt `"`s(o)'"'
        if `"`ftxt'"' != "" {
            local rest `"`ftxt'"'
            while `"`rest'"' != "" {
                local p = strpos(`"`rest'"', "; ")
                if `p' {
                    local one = substr(`"`rest'"', 1, `p'-1)
                    local rest = substr(`"`rest'"', `p'+2, .)
                }
                else {
                    local one `"`rest'"'
                    local rest ""
                }
                if strpos(`"`one'"', "!!") == 1 _rh_wpre `H' flag `=char(5)'`one'
                else if inlist("$RH_severity","warn","stop") ///
                                                _rh_wpre `H' flag `=char(5)'!! `one'
                else                            _rh_wpre `H' -    `=char(5)'`one'
            }
        }
        file write `H' `"</pre>"' _n
        file write `H' `"</details>"' _n
    }
end


* ============================================================ small utilities

* provenance footer (16g): when, which Stata, which commit -> s(o)
program define _rh_prov, sclass
    args jname mode layout N jdir
    local flav = cond(c(MP) == 1, "MP", cond(c(SE) == 1, "SE", c(flavor)))
    local o `"mergemap `=char(3)' journal `jname' `=char(3)' `mode' mode, `layout' layout, `N' events"'
    local o `"`o' `=char(3)' generated `c(current_date)' `c(current_time)'"'
    local o `"`o' `=char(3)' Stata `c(stata_version)' `flav'"'
    _rh_git `"`jdir'"'
    if `"`s(branch)'"' != "" | `"`s(commit)'"' != "" {
        local g "git"
        if `"`s(branch)'"' != "" local g `"`g' `s(branch)'"'
        if `"`s(commit)'"' != "" local g `"`g' @ `s(commit)'"'
        local o `"`o' `=char(3)' `g'"'
    }
    local o `"`o' `=char(3)' self-contained: no scripts, no external assets"'
    _rh_map `"`o'"'
    local oo `"`s(o)'"'
    sreturn clear
    sreturn local o `"`oo'"'
end

* git branch and short commit, read straight out of .git (no shell) -> s()
program define _rh_git, sclass
    args dir
    sreturn clear
    sreturn local branch ""
    sreturn local commit ""
    local d `"`dir'"'
    if `"`d'"' == "" local d "."
    local gd ""
    forvalues i = 1/6 {
        capture confirm file `"`d'/.git/HEAD"'
        if !_rc {
            local gd `"`d'/.git"'
            continue, break
        }
        local d `"`d'/.."'
    }
    if `"`gd'"' == "" exit
    tempname fh
    capture noisily {
        file open `fh' using `"`gd'/HEAD"', read text
        file read `fh' hline
        file close `fh'
    }
    if _rc exit
    local hline = trim(`"`hline'"')
    local branch ""
    local commit ""
    if substr(`"`hline'"', 1, 5) == "ref: " {
        local ref = trim(substr(`"`hline'"', 6, .))
        local branch = substr(`"`ref'"', strrpos(`"`ref'"', "/") + 1, .)
        capture confirm file `"`gd'/`ref'"'
        if !_rc {
            capture {
                file open `fh' using `"`gd'/`ref'"', read text
                file read `fh' cline
                file close `fh'
            }
            if !_rc local commit = substr(trim(`"`cline'"'), 1, 7)
        }
        if "`commit'" == "" {
            capture confirm file `"`gd'/packed-refs"'
            if !_rc {
                capture {
                    file open `fh' using `"`gd'/packed-refs"', read text
                    file read `fh' pline
                    while r(eof) == 0 {
                        if strpos(`"`pline'"', `"`ref'"') {
                            local commit = substr(trim(`"`pline'"'), 1, 7)
                            continue, break
                        }
                        file read `fh' pline
                    }
                    file close `fh'
                }
            }
        }
    }
    else local commit = substr(`"`hline'"', 1, 7)
    sreturn clear
    sreturn local branch "`branch'"
    sreturn local commit "`commit'"
end

* coverage percentages -> s(o) ("" when scan mode left them missing)
program define _rh_cover, sclass
    local cm "$RH_cover_master"
    local cu "$RH_cover_using"
    local o ""
    if "`cm'" != "." & "`cm'" != "" local o `"master `cm'% matched"'
    if "`cu'" != "." & "`cu'" != "" {
        if `"`o'"' != "" local o `"`o' `=char(3)' "'
        local o `"`o'using `cu'% used"'
    }
    if `"`o'"' != "" local o `"cover: `o'"'
    sreturn clear
    sreturn local o `"`o'"'
end

* key storage types -> s(o) text, s(mis)=1 when any side disagrees (16c)
program define _rh_keytypes, sclass
    args t
    local o ""
    local mis 0
    if `"`t'"' == "." | `"`t'"' == "" {
        sreturn clear
        sreturn local o ""
        sreturn local mis = 0
        exit
    }
    local rest `"`t'"'
    local sep ""
    while `"`rest'"' != "" {
        local p = strpos(`"`rest'"', "; ")
        if `p' {
            local one = substr(`"`rest'"', 1, `p'-1)
            local rest = substr(`"`rest'"', `p'+2, .)
        }
        else {
            local one `"`rest'"'
            local rest ""
        }
        local q = strpos(`"`one'"', ": ")
        local nm = cond(`q', substr(`"`one'"', 1, `q'-1), "")
        local tv = cond(`q', trim(substr(`"`one'"', `q'+2, .)), trim(`"`one'"'))
        local v = strpos(`"`tv'"', " vs ")
        if `v' {
            local a = trim(substr(`"`tv'"', 1, `v'-1))
            local b = trim(substr(`"`tv'"', `v'+4, .))
            if "`a'" != "`b'" local mis 1
        }
        local o `"`o'`sep'`nm' `tv'"'
        local sep `"`=char(3)' "'
    }
    local o = trim(`"`o'"')
    sreturn clear
    sreturn local o `"types: `o'"'
    sreturn local mis = `mis'
end

* flag text for the current row, or the bare severity word -> s(o)
program define _rh_flagtext, sclass
    local o `"$RH_flags"'
    if `"`o'"' == "." | `"`o'"' == "" {
        if inlist("$RH_severity", "warn", "stop") local o `"!! $RH_severity"'
        else local o ""
    }
    sreturn clear
    sreturn local o `"`o'"'
end

* parse keep() out of opts -> s(kept) as " 1 2 3 " token set (all kept if none)
program define _rh_keepset, sclass
    args o
    local p = strpos(`"`o'"', "keep(")
    if !`p' {
        sreturn local kept `" 1 2 3 4 5 "'
        exit
    }
    local rest = substr(`"`o'"', `p'+5, .)
    local q = strpos(`"`rest'"', ")")
    local inside = substr(`"`rest'"', 1, `q'-1)
    local inside = subinstr(`"`inside'"', "match_update",   "4", .)
    local inside = subinstr(`"`inside'"', "match_conflict", "5", .)
    local inside = subinstr(`"`inside'"', "match",  "3", .)
    local inside = subinstr(`"`inside'"', "master", "1", .)
    local inside = subinstr(`"`inside'"', "using",  "2", .)
    sreturn local kept `" `inside' "'
end

* comma-format a count string ("." or "" -> empty)
program define _rh_n, sclass
    args s
    if "`s'" == "." | "`s'" == "" sreturn local o ""
    else sreturn local o = trim(string(real("`s'"), "%20.0fc"))
end

* middle-ellipsis to maxlen -> s(o); only when the label genuinely overflows
program define _rh_mell, sclass
    args maxlen t
    if strlen(`"`t'"') <= `maxlen' {
        sreturn local o `"`t'"'
        exit
    }
    local h1 = floor((`maxlen'-1)/2)
    local h2 = `maxlen' - 1 - `h1'
    sreturn local o = substr(`"`t'"', 1, `h1') + char(1) + substr(`"`t'"', -`h2', .)
end

* word-wrap to at most maxlines lines -> s(n), s(l1..). Continuation lines are
* indented. Flag text is never cut mid-word unless it overruns every line.
program define _rh_wrapn, sclass
    args maxlen maxlines t
    local rest = trim(`"`t'"')
    local n 0
    while `"`rest'"' != "" & `n' < `maxlines' {
        local lim = cond(`n' == 0, `maxlen', `maxlen' - 2)
        if strlen(`"`rest'"') <= `lim' {
            local ++n
            local l`n' `"`rest'"'
            local rest ""
        }
        else {
            local head = substr(`"`rest'"', 1, `lim')
            local p = strrpos(`"`head'"', " ")
            if `p' < 10 local p = `lim'
            * do not strand a two-character tail on its own line
            if strlen(`"`rest'"') - `p' < 5 {
                local h2 = substr(`"`rest'"', 1, `p'-1)
                local p2 = strrpos(`"`h2'"', " ")
                if `p2' >= 10 local p = `p2'
            }
            local ++n
            local l`n' = trim(substr(`"`rest'"', 1, `p'))
            local rest = trim(substr(`"`rest'"', `p'+1, .))
        }
        * a line must not end on a separator left over from the split
        while inlist(substr(`"`l`n''"', -1, 1), char(3), " ", ";", ",") {
            local l`n' = trim(substr(`"`l`n''"', 1, strlen(`"`l`n''"')-1))
        }
        if `n' > 1 local l`n' `"`=char(5)'`l`n''"'
    }
    if `"`rest'"' != "" & `n' > 0 {
        local merged `"`l`n'' `rest'"'
        _rh_mell `maxlen' `"`merged'"'
        local l`n' `"`s(o)'"'
    }
    sreturn clear
    sreturn local n = `n'
    forvalues k = 1/`n' {
        sreturn local l`k' `"`l`k''"'
    }
end

* split flags on "; ", mark severity, wrap each -> s(n), s(l#), s(c#)
* class letter: n = plain note, f = warn, s = stop. Severity is never colour
* alone: warn and stop both carry the "!!" text marker.
program define _rh_flaglines, sclass
    args maxlen maxlines sev t
    local rest = trim(`"`t'"')
    local n 0
    while `"`rest'"' != "" {
        local p = strpos(`"`rest'"', "; ")
        if `p' {
            local one = substr(`"`rest'"', 1, `p'-1)
            local rest = substr(`"`rest'"', `p'+2, .)
        }
        else {
            local one `"`rest'"'
            local rest ""
        }
        * a bare "tempfile" flag is redundant with the [tempfile] marker
        if `"`one'"' == "tempfile" continue
        if strpos(`"`one'"', "!!") == 1 {
            local cls = cond("`sev'" == "stop", "s", "f")
        }
        else if "`sev'" == "stop" {
            local one `"!! `one'"'
            local cls "s"
        }
        else if "`sev'" == "warn" {
            local one `"!! `one'"'
            local cls "f"
        }
        else local cls "n"
        _rh_wrapn `maxlen' `maxlines' `"`one'"'
        local nw = `s(n)'
        forvalues k = 1/`nw' {
            local w`k' `"`s(l`k')'"'
        }
        forvalues k = 1/`nw' {
            local ++n
            local l`n' `"`w`k''"'
            local c`n' "`cls'"
        }
    }
    sreturn clear
    sreturn local n = `n'
    forvalues k = 1/`n' {
        sreturn local l`k' `"`l`k''"'
        sreturn local c`k' `"`c`k''"'
    }
end

* sanitize an id/class prefix -> s(o)
program define _rh_slug, sclass
    args t
    local out ""
    local L = strlen(`"`t'"')
    if `L' > 40 local L 40
    forvalues i = 1/`L' {
        local ch = substr(`"`t'"', `i', 1)
        if !ustrregexm("`ch'", "^[A-Za-z0-9-]$") local ch "-"
        local out "`out'`ch'"
    }
    while substr("`out'", -1, 1) == "-" {
        local out = substr("`out'", 1, strlen("`out'")-1)
    }
    if substr("`out'", 1, 3) != "mm-" local out "mm-`out'"
    if "`out'" == "mm-" local out "mm-1"
    sreturn clear
    sreturn local o "`out'"
end


* ============================================================ svg writers
* Shapes carry presentation attributes as well as classes, so a fragment whose
* stylesheet is stripped still renders as legible boxes (DECISIONS 21).

program define _rh_rect
    args B x y w h cls sev
    local fill "#f7f7f7"
    local strk "#333"
    local sw   "1.1"
    local dash ""
    if "`cls'" == "bu"   {
        local fill "#fcfcfc"
        local strk "#666"
        local sw   "1"
    }
    if "`cls'" == "bt"   {
        local fill "#ffffff"
        local strk "#666"
        local sw   "1"
        local dash `" stroke-dasharray="5 3""'
    }
    if "`cls'" == "bstk" {
        local fill "#ffffff"
        local strk "#999"
        local sw   "1"
    }
    if "`cls'" == "bw"   {
        local fill "#ffffff"
        local strk "#999"
        local sw   "1"
    }
    if "`cls'" == "bfil" {
        local fill "#fbfbfb"
        local strk "#888"
        local sw   "1"
    }
    local clist "mm-`cls'"
    if "`sev'" == "warn" {
        local clist "`clist' mm-sevw"
        local strk "#222"
        local sw   "1.7"
    }
    if "`sev'" == "stop" {
        local clist "`clist' mm-sevs"
        local strk "$RH_ACC"
        local sw   "2.2"
    }
    file write `B' `"<rect x="`x'" y="`y'" width="`w'" height="`h'" class="`clist'" fill="`fill'" stroke="`strk'" stroke-width="`sw'"`dash' />"' _n
end

program define _rh_line
    args B x1 y1 x2 y2 cls marker
    local strk "#444"
    local sw   "1.2"
    local dash ""
    if "`cls'" == "spd" {
        local strk "#777"
        local sw   "1.1"
        local dash `" stroke-dasharray="4 3""'
    }
    if "`cls'" == "hl" {
        local strk "#cccccc"
        local sw   "1"
    }
    local mk ""
    if "`marker'" != "" local mk `" marker-end="url(#${RH_PFX}-`marker')""'
    file write `B' `"<line x1="`x1'" y1="`y1'" x2="`x2'" y2="`y2'" class="mm-`cls'" stroke="`strk'" stroke-width="`sw'" fill="none"`dash'`mk' />"' _n
end

* write an svg <text>; maps marker chars to XML entities and mirrors the CSS
* into presentation attributes
program define _rh_wtext
    gettoken h   0 : 0
    gettoken x   0 : 0
    gettoken y   0 : 0
    gettoken cls 0 : 0
    if "`cls'" == "" local cls "bl"
    _rh_map `"`0'"'
    local t = trim(`"`s(o)'"')
    _rh_tattr "`cls'"
    file write `h' `"<text x="`x'" y="`y'" class="mm-t mm-`cls'"`s(a)'>`t'</text>"' _n
end

* presentation attributes for a text class -> s(a)
program define _rh_tattr, sclass
    args cls
    local size 12
    local wt   "normal"
    local fill "#333"
    if "`cls'" == "bh"  {
        local size 12
        local wt "bold"
        local fill "#111"
    }
    if "`cls'" == "bl"  local size 12
    if "`cls'" == "bn"  {
        local size 11
        local fill "#666"
    }
    if inlist("`cls'", "bf", "bs") {
        local size 11
        local wt "bold"
        local fill "$RH_ACC"
    }
    if "`cls'" == "cc"  {
        local size 11
        local wt "bold"
        local fill "#111"
    }
    if "`cls'" == "cl"  local size 11
    if "`cls'" == "cn"  {
        local size 11
        local fill "#666"
    }
    if inlist("`cls'", "cf", "cs") {
        local size 11
        local wt "bold"
        local fill "$RH_ACC"
    }
    if "`cls'" == "dof" {
        local size 13
        local wt "bold"
        local fill "#222"
    }
    if "`cls'" == "hc"  local size 10
    if "`cls'" == "hn"  {
        local size 10
        local fill "#666"
    }
    if "`cls'" == "hb"  {
        local size 10
        local wt "bold"
        local fill "#111"
    }
    if inlist("`cls'", "hf", "hs") {
        local size 10
        local wt "bold"
        local fill "$RH_ACC"
    }
    sreturn clear
    sreturn local a `" font-family="SF Mono, Menlo, Consolas, DejaVu Sans Mono, monospace" font-size="`size'" font-weight="`wt'" fill="`fill'""'
end

* write a ledger <pre> line (class "flag" wraps it in a span); "-" = plain
program define _rh_wpre
    gettoken h   0 : 0
    gettoken cls 0 : 0
    _rh_map `"`0'"'
    local t `"`s(o)'"'
    if "`cls'" == "flag" file write `h' `"<span class="mm-flag">`t'</span>"' _n
    else                 file write `h' `"`t'"' _n
end

* write inline (summary text), mapped, no newline
program define _rh_wraw
    gettoken h 0 : 0
    _rh_map `"`0'"'
    file write `h' `"`s(o)'"'
end

* map internal marker chars to XML entities -> s(o)
program define _rh_map, sclass
    args t
    local t = subinstr(`"`t'"', char(16), "&amp;",   .)
    local t = subinstr(`"`t'"', char(17), "&lt;",    .)
    local t = subinstr(`"`t'"', char(18), "&gt;",    .)
    local t = subinstr(`"`t'"', char(19), "&quot;",  .)
    local t = subinstr(`"`t'"', char(6),  "&#96;",   .)
    local t = subinstr(`"`t'"', char(7),  "&#36;",   .)
    local t = subinstr(`"`t'"', char(1),  "&#8230;", .)
    local t = subinstr(`"`t'"', char(2),  "&#215;",  .)
    local t = subinstr(`"`t'"', char(3),  "&#183;",  .)
    local t = subinstr(`"`t'"', char(4),  "&#8594;", .)
    local t = subinstr(`"`t'"', char(5),  "&#160;&#160;", .)
    sreturn local o `"`t'"'
end

program define _rh_dropglobals
    capture macro drop RH_seq RH_dofile RH_linenum RH_evclass RH_cmd RH_subtype ///
        RH_keys RH_master RH_usingf RH_result RH_n_in RH_k_in RH_n_using ///
        RH_k_using RH_n_out RH_k_out RH_m1 RH_m2 RH_m3 RH_m4 RH_m5 ///
        RH_dup_master RH_dup_using RH_force RH_opts RH_loop_n RH_loop_first ///
        RH_loop_last RH_severity RH_keytypes RH_cover_master RH_cover_using ///
        RH_lifecycle RH_flags RH_ACC RH_PFX
    forvalues k = 1/16 {
        capture macro drop MMAL`k' MMAC`k' MMBL`k' MMBC`k'
    }
end
