*! version 0.3.0  20aug2026  Eric Booth
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
    syntax [anything(name=jspec)] [, EXPort(string) SAVing(string)          ///
        STYLE(string) LAYout(string) WRAP(integer -1) MAXnodes(integer -1)  ///
        FORCEsmcl COMPact noCOUNTS noKEYS noTRANSFORMS noELLIPSIS           ///
        DETails EMBed ACCent(string) PAGE(string) replace NOOPen]

    * ---- which journal --------------------------------------------------
    gettoken w1 rest : jspec
    if `"`w1'"' == "using" local jspec `"`rest'"'
    gettoken jfile : jspec
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

    return local journal `"`jfile'"'

    * ---- smcl -----------------------------------------------------------
    if "`export'" == "smcl" {
        local o ""
        if `"`style'"'  != "" local o `"`o' style(`style')"'
        if `"`layout'"' != "" local o `"`o' layout(`layout')"'
        if `wrap'     >= 0    local o `"`o' wrap(`wrap')"'
        if `maxnodes' >= 0    local o `"`o' maxnodes(`maxnodes')"'
        local o `"`o' `forcesmcl' `compact' `counts' `keys' `transforms' `ellipsis'"'
        _mm_rendersmcl using `"`jfile'"', `o'
        * escalation: the renderer declined (too many nodes, or horizontal);
        * write the HTML it promised, into saving() or a default name
        if "$MM_RSM_DEFER" == "1" {
            local hf `"`saving'"'
            if `"`hf'"' == "" local hf "mergemap_map.html"
            _mm_draw_html `"`jfile'"' `"`hf'"' `"`layout'"' `"`accent'"' ///
                "`details'" "" "replace" "`noopen'"
            return local output `"`s(out)'"'
        }
        exit
    }

    * ---- html -----------------------------------------------------------
    if "`export'" == "html" {
        local hf `"`saving'"'
        if `"`hf'"' == "" local hf "mergemap_map.html"
        _mm_draw_html `"`jfile'"' `"`hf'"' `"`layout'"' `"`accent'"' ///
            "`details'" "`embed'" "`replace'" "`noopen'"
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
    args jfile hf layout accent details embed replace noopen
    if strlower(substr(`"`hf'"', -5, .)) != ".html" local hf `"`hf'.html"'
    local o `"`details' `embed' `replace'"'
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
    if substr(`"`abs'"', 1, 1) != "/" & substr(`"`abs'"', 2, 1) != ":" {
        local abs `"`c(pwd)'/`hf'"'
    }
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
