*! version 0.5.0  23aug2026  Eric Booth
*! _mm_draw -- dispatcher behind -mergemap draw-.  Resolves which journal to
*! draw, picks the renderer from export(), forwards only the options that
*! renderer understands, and handles the SMCL-to-HTML auto-escalation plus
*! the open-in-browser courtesy for HTML output.
*!
*! Journal resolution, in order: an explicit file on the command line (a
*! leading -using- token is accepted and ignored), then the journal the last
*! mergemap scan/run/demo wrote in this session (a global, so it survives
*! -clear all-), then journal.tsv in the working directory.

program define _mm_draw, rclass
    version 16
    * The command line is  [using] [journal] [if exp] [, options].  The if
    * is split off before -syntax- sees the line: syntax rejects an if that
    * was not declared, and a declared [if] is checked against the data in
    * memory, where the journal is not.  _mm_jcut evaluates the expression
    * against the journal's own columns instead.
    _mm_splitif `"`0'"'
    local 0     `"`s(rest)'"'
    local ifexp `"`s(ifexp)'"'
    syntax [anything(name=jspec)] [, EXPort(string) SAVing(string)          ///
        STYLE(string) LAYout(string) WRAP(integer -1) MAXnodes(integer -1)  ///
        FORCEsmcl COMPact noCOUNTS noKEYS noTRANSFORMS noELLIPSIS           ///
        noFILTERS noROWfilters noVARfilters noTEMPfiles JOINSonly FILESonly ///
        PATHS(string) ROOT(string asis)                                     ///
        DETails EMBed ACCent(string) PAGE(string) replace NOOPen]

    * ---- which journal --------------------------------------------------
    gettoken w1 rest : jspec
    if `"`w1'"' == "using" local jspec `"`rest'"'
    gettoken jfile rest : jspec
    if strtrim(`"`rest'"') != "" {
        di as err `"mergemap draw: did not understand `rest'"'
        di as err "    syntax is: mergemap draw [journal] [if exp] [, options]"
        exit 198
    }
    if `"`jfile'"' == "" local jfile `"$MM_LASTJ"'
    if `"`jfile'"' == "" {
        capture confirm file "journal.tsv"
        if !_rc local jfile "journal.tsv"
    }
    if `"`jfile'"' == "" {
        di as err "mergemap draw: no journal to draw."
        di as err "    Scan something first (mergemap <do-files>), or name a"
        di as err "    journal file: mergemap draw myjournal.tsv"
        exit 601
    }
    capture confirm file `"`jfile'"'
    if _rc {
        di as err `"mergemap draw: journal `jfile' not found"'
        exit 601
    }

    * ---- which renderer -------------------------------------------------
    if `"`export'"' == "" local export "smcl"
    local export = strlower(`"`export'"')
    if "`export'" == "erdiagram" local export "er"
    if !inlist("`export'", "smcl", "html", "png", "svg", "mermaid", "dot", "er", "text") {
        di as err "mergemap draw: export() must be smcl, html, png, svg,"
        di as err "    mermaid, dot, erdiagram, or text"
        exit 198
    }

    * ---- hide events and shorten labels, before any renderer sees them --
    * Done on the journal rather than inside one renderer, so every option
    * here works for every export, from one implementation (_mm_jcut).
    local cutopts `"`transforms' `filters' `rowfilters' `varfilters' `tempfiles' `joinsonly' `filesonly'"'
    if `"`paths'"' != "" local cutopts `"`cutopts' paths(`paths')"'
    if `"`root'"'  != "" local cutopts `"`cutopts' root(`root')"'
    if `"`ifexp'"' != "" local cutopts `"`cutopts' if(`ifexp')"'
    _mm_jcut using `"`jfile'"', `cutopts'
    local jfile `"`s(jfile)'"'
    return local journal `"`jfile'"'
    return local hidden  `"`s(note)'"'

    * compact, nocounts and nokeys thin each node; they reach the Results
    * window and the HTML page.  For the other exports say so, rather than
    * accept the option and change nothing.
    if ("`compact'`counts'`keys'" != "") & !inlist("`export'", "smcl", "html") {
        di as txt "mergemap draw: `compact' `counts' `keys' apply to the Results-window and"
        di as txt "    HTML drawings; to shorten a `export' export, hide events instead:"
        di as txt "    nofilters, notempfiles, filesonly, or an if on the journal columns"
    }

    * ---- smcl -----------------------------------------------------------
    if "`export'" == "smcl" {
        local o ""
        if `"`style'"'  != "" local o `"`o' style(`style')"'
        if `"`layout'"' != "" local o `"`o' layout(`layout')"'
        if `wrap'     >= 0    local o `"`o' wrap(`wrap')"'
        if `maxnodes' >= 0    local o `"`o' maxnodes(`maxnodes')"'
        local o `"`o' `forcesmcl' `compact' `counts' `keys' `ellipsis'"'
        _mm_rendersmcl using `"`jfile'"', `o'
        * escalation: the renderer declined (too many nodes, or horizontal);
        * write the HTML it promised, into saving() or a default name
        if "$MM_RSM_DEFER" == "1" {
            local hf `"`saving'"'
            if `"`hf'"' == "" local hf "mergemap_map.html"
            _mm_draw_html `"`jfile'"' `"`hf'"' `"`layout'"' `"`accent'"' ///
                "`details'" "" "replace" "`noopen'" "`compact' `counts' `keys'"
            return local output `"`s(out)'"'
        }
        exit
    }

    * ---- html -----------------------------------------------------------
    if "`export'" == "html" {
        local hf `"`saving'"'
        if `"`hf'"' == "" local hf "mergemap_map.html"
        _mm_draw_html `"`jfile'"' `"`hf'"' `"`layout'"' `"`accent'"' ///
            "`details'" "`embed'" "`replace'" "`noopen'" "`compact' `counts' `keys'"
        return local output `"`s(out)'"'
        exit
    }

    * ---- png / svg (the native twoway renderer writes both) -------------
    if inlist("`export'", "png", "svg") {
        local stub `"`saving'"'
        if `"`stub'"' == "" local stub "mergemap_map"
        * rendertw takes a stub; forgive a pasted extension
        foreach e in .png .svg {
            if strlower(substr(`"`stub'"', -4, .)) == "`e'" {
                local stub = substr(`"`stub'"', 1, strlen(`"`stub'"') - 4)
            }
        }
        local o ""
        if `"`layout'"' != "" local o `"`o' layout(`layout')"'
        if `"`page'"'   != "" local o `"`o' page(`page')"'
        if `maxnodes' >= 0    local o `"`o' maxnodes(`maxnodes')"'
        capture noisily _mm_rendertw using `"`jfile'"', saving(`"`stub'"') `o'
        if _rc == 134 & `"`page'"' == "" {
            * too dense for one readable image; the renderer said so above.
            * Splitting per do-file is what page(dofile) exists for -- do it.
            di as txt "mergemap draw: retrying with one page per do-file, page(dofile)"
            _mm_rendertw using `"`jfile'"', saving(`"`stub'"') `o' page(dofile)
        }
        else if _rc exit _rc
        return local output `"`stub'.`export'"'
        exit
    }

    * ---- mermaid / dot / erdiagram / text -------------------------------
    local fmt "`export'"
    if "`fmt'" == "text" local fmt "all"
    local stub `"`saving'"'
    if `"`stub'"' == "" local stub "mergemap_map"
    local o `"format(`fmt') `replace'"'
    if `"`layout'"' != "" local o `"`o' layout(`layout')"'
    if `wrap' >= 0        local o `"`o' wrap(`wrap')"'
    _mm_rendertext using `"`jfile'"', saving(`"`stub'"') `o'
    return local output `"`stub'"'
end

* ---------------------------------------------------------------- html leg
* Writes the page (or fragment), prints a clickable link, and opens the
* system browser in GUI sessions unless noopen.  An embed fragment is not a
* standalone page, so it gets the path only, never an auto-open.
program define _mm_draw_html, sclass
    args jfile hf layout accent details embed replace noopen thin
    if strlower(substr(`"`hf'"', -5, .)) != ".html" local hf `"`hf'.html"'
    local o `"`details' `embed' `replace' `thin'"'
    if `"`layout'"' != "" local o `"`o' layout(`layout')"'
    if `"`accent'"' != "" local o `"`o' accent(`accent')"'
    _mm_renderhtml using `"`jfile'"', saving(`"`hf'"') `o'
    sreturn local out `"`hf'"'
    if "`embed'" != "" {
        di as txt `"mergemap draw: fragment written; drop it into your page's body"'
        exit
    }
    * absolute path, so the link still resolves after the user changes
    * directory.  Note the missing-file case also gets an absolute path:
    * an earlier version only absolutised when the file existed, which left
    * a relative path in the link on the one occasion it mattered.
    local abs `"`hf'"'
    _mm_isabs `"`abs'"'
    if !r(abs) local abs `"`c(pwd)'/`hf'"'
    global MM_LASTOUT `"`abs'"'
    * A {stata ...} link runs a Stata command.  Do NOT go back to
    * {browse "file://..."}: SMCL hands that to the platform URL parser, and
    * on macOS it throws inside NSURLComponents and aborts Stata outright.
    di as txt `"    {stata _mm_open:Open the diagram in your browser}"'
    di as txt `"    `abs'"'
    * auto-open where a handler can exist: GUI, not batch or console
    if "`noopen'" == "" & "`c(mode)'" != "batch" & "`c(console)'" == "" {
        capture _mm_open
    }
end

* ---------------------------------------------------------------- splitif
* Split "[using] [journal] if exp, options" into the line without its if,
* s(rest), and the expression, s(ifexp).  The walk respects double quotes,
* compound quotes and parentheses, so a comma inside
* inlist(class,"join","link") is part of the expression and the comma that
* starts the options is the first one at the top level.  A bare "if" word
* counts only at the top level, so "if" inside a quoted path is left alone.
program define _mm_splitif, sclass
    args cmd
    sreturn clear
    sreturn local rest  `"`cmd'"'
    sreturn local ifexp ""
    local L = strlen(`"`cmd'"')
    local i = 1
    local dq = 0
    local cq = 0
    local par = 0
    local comma = 0
    local ifpos = 0
    * Every test below is an expression on a substring of the line.  A
    * single quote character is never expanded inside compound quotes: a
    * lone `" or "' there opens or closes a nesting level and the line
    * fails with "too few quotes".
    while `i' <= `L' {
        local copen  = (substr(`"`cmd'"', `i', 2) == char(96) + char(34))
        local cclose = (substr(`"`cmd'"', `i', 2) == char(34) + char(39))
        local isdq   = (substr(`"`cmd'"', `i', 1) == char(34))
        if !`dq' & `copen' {
            local ++cq
            local i = `i' + 2
            continue
        }
        if !`dq' & `cq' > 0 & `cclose' {
            local --cq
            local i = `i' + 2
            continue
        }
        if `cq' == 0 & `isdq' {
            local dq = 1 - `dq'
            local ++i
            continue
        }
        if !`dq' & `cq' == 0 {
            if substr(`"`cmd'"', `i', 1) == "(" local ++par
            if substr(`"`cmd'"', `i', 1) == ")" local --par
            if `par' <= 0 & substr(`"`cmd'"', `i', 1) == "," {
                local comma = `i'
                continue, break
            }
            if `par' <= 0 & `ifpos' == 0 & substr(`"`cmd'"', `i', 2) == "if" {
                local okb = (`i' == 1 | inlist(substr(`"`cmd'"', `i' - 1, 1), " ", char(9)))
                local oka = (`i' + 2 > `L' | inlist(substr(`"`cmd'"', `i' + 2, 1), " ", char(9)))
                if `okb' & `oka' local ifpos = `i'
            }
        }
        local ++i
    }
    if `ifpos' == 0 exit
    local head = substr(`"`cmd'"', 1, `ifpos' - 1)
    if `comma' {
        local ifexp = substr(`"`cmd'"', `ifpos' + 2, `comma' - `ifpos' - 2)
        local tail  = substr(`"`cmd'"', `comma', .)
    }
    else {
        local ifexp = substr(`"`cmd'"', `ifpos' + 2, .)
        local tail ""
    }
    local ifexp = strtrim(`"`ifexp'"')
    sreturn local rest  `"`head'`tail'"'
    sreturn local ifexp `"`ifexp'"'
end
