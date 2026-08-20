*==============================================================================*
* test_mergemap_in_webdoc2.do
*
* Driver for the "mergemap output inside a webdoc2 report" test.
*
*   1. Slices reusable HTML fragments out of the mergemap prototype output
*      (proto/render_html, proto/render_twoway, proto/render_smcl).
*   2. Drives page_mergemap.do  through -webdoc do-  ->  mergemap_report.html
*   3. Drives page_collision.do through -webdoc do-  ->  collision_demo.html
*   4. Asserts the two pages exist and contain what they should.
*
* Run:  cd tests/webdoc && /usr/local/bin/stata-mp -b do test_mergemap_in_webdoc2.do
* Judge by the log: no r(NNN) errors, no "assertion is false".
*
* Nothing outside tests/webdoc/ is written or modified.
*==============================================================================*
clear all
set more off

local here `"`c(pwd)'"'
local proto `"`here'/../../proto"'

confirm file `"`proto'/render_html/html_vert_run.html"'
confirm file `"`proto'/render_twoway/tw_vert_run.png"'
confirm file `"`proto'/render_smcl/smcl_boxes_run.txt"'

* header.html is an ancillary file that -net install- does NOT place, so keep a
* copy next to the page: -wdinit- locates it with -findfile-, and "." is on the
* default adopath.
capture findfile header.html
if _rc {
    di as err "header.html not found; copy it from the webdoc2 package directory."
    exit 601
}
di as txt "header.html resolved to: `r(fn)'"

capture which webdoc
if _rc {
    di as err "requires -webdoc- (ssc install webdoc)"
    exit 111
}
capture which wdinit
if _rc {
    di as err "requires -webdoc2- (net install webdoc2)"
    exit 111
}

*------------------------------------------------------------------------------*
* 1. Fragment builder
*------------------------------------------------------------------------------*
mata:
mata clear

// ---- io -------------------------------------------------------------------
string scalar mm_read(string scalar fn)
{
    return(invtokens(cat(fn)', char(10)))
}

void mm_write(string scalar fn, string scalar s)
{
    real scalar fh
    if (fileexists(fn)) _unlink(fn)     // Mata fopen("w") refuses to overwrite
    fh = fopen(fn, "w")
    fput(fh, s)
    fclose(fh)
}

// ---- slice out the first <open ... close> run ------------------------------
string scalar mm_slice(string scalar s, string scalar op, string scalar cl)
{
    real scalar i, j
    i = strpos(s, op)
    if (i==0) return("")
    j = strpos(substr(s, i, .), cl)
    if (j==0) return("")
    return(substr(s, i, j + strlen(cl) - 1))
}

// ---- slice from the first <open to the LAST close --------------------------
string scalar mm_slice_last(string scalar s, string scalar op, string scalar cl)
{
    real scalar i, j
    i = strpos(s, op)
    if (i==0) return("")
    j = strrpos(s, cl)
    if (j==0) return("")
    return(substr(s, i, j + strlen(cl) - i))
}

// ---- HTML-escape for <pre> -------------------------------------------------
string scalar mm_esc(string scalar s)
{
    return(subinstr(subinstr(subinstr(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
}

// ---- rename mergemap's two-letter CSS classes to mm-* ----------------------
// The prototype emits .bh .bl .bn .bf .cc .cl .cn .cf .dof .hc .hn .hb .hf
// .bx .bu .bt .bstk .bw .sp .spd .hl -- all far too generic to drop into a
// page that already carries Bootstrap 5.
string scalar mm_prefix_css(string scalar s)
{
    return(ustrregexra(s,
        "\.(bstk|bh|bl|bn|bf|cc|cl|cn|cf|dof|hc|hn|hb|hf|bx|bu|bt|bw|spd|sp|hl)\b",
        ".mm-$1"))
}

// ---- scope every rule under a wrapper selector, drop body rules ------------
string scalar mm_scope_css(string scalar css0, string scalar scope)
{
    string scalar rest, rule, sel, decl, out, tmp, piece, newsel
    real scalar k, b, c
    out  = ""
    rest = css0
    while ((k = strpos(rest, "}")) > 0) {
        rule = substr(rest, 1, k)
        rest = substr(rest, k+1, .)
        b = strpos(rule, "{")
        if (b==0) continue
        sel  = substr(rule, 1, b-1)
        // newlines and tabs are blanks to CSS but not to strtrim()
        sel  = subinstr(subinstr(subinstr(sel, char(13), " "), char(10), " "),
                        char(9), " ")
        sel  = strtrim(stritrim(sel))
        decl = strtrim(stritrim(subinstr(subinstr(substr(rule, b, .),
                       char(10), " "), char(9), " ")))
        if (sel=="") continue
        if (sel=="body") continue          // would restyle the host report
        newsel = ""
        tmp = sel + ","
        while ((c = strpos(tmp, ",")) > 0) {
            piece = strtrim(substr(tmp, 1, c-1))
            tmp   = substr(tmp, c+1, .)
            if (piece=="") continue
            if (newsel!="") newsel = newsel + ", "
            newsel = newsel + scope + " " + piece
        }
        if (newsel=="") continue
        out = out + newsel + " " + decl + char(10)
    }
    return(out)
}

// ---- make an <svg> fragment safe to inline ---------------------------------
//   classes  -> mm-*        (avoid collisions with the host stylesheet)
//   ids      -> <pfx>*      (marker ids are "ag"/"aa" in EVERY mergemap file,
//                            so two diagrams on one page collide)
//   width/height attrs stripped when stripwh!=0, leaving viewBox to drive
//   aspect-ratio scaling.
string scalar mm_fix_svg(string scalar svg0, string scalar pfx, real scalar stripwh)
{
    string scalar q, svg, root, root2
    q = char(34)
    svg = svg0
    svg = ustrregexra(svg, "class=" + q + "([A-Za-z][-A-Za-z0-9_]*)" + q,
                           "class=" + q + "mm-$1" + q)
    svg = ustrregexra(svg, "id=" + q + "([A-Za-z][-A-Za-z0-9_]*)" + q,
                           "id=" + q + pfx + "$1" + q)
    svg = subinstr(svg, "url(#", "url(#" + pfx)
    if (stripwh) {
        root  = mm_slice(svg, "<svg", ">")
        root2 = ustrregexra(root, " width="  + q + "[^" + q + "]*" + q, "")
        root2 = ustrregexra(root2, " height=" + q + "[^" + q + "]*" + q, "")
        svg   = root2 + substr(svg, strlen(root)+1, .)
    }
    return(svg)
}

// ---------------------------------------------------------------------------
void mm_build(string scalar proto)
{
    string scalar h, hd, css, q

    q = char(34)

    h  = mm_read(proto + "/render_html/html_vert_run.html")
    hd = mm_read(proto + "/render_html/html_vert_run_details.html")

    // --- raw (unmodified) pieces, used by the collision demo ---------------
    css = mm_slice(h, "<style type=" + q + "text/css" + q + ">", "</style>")
    mm_write("frag_raw_style.html", css)
    mm_write("frag_raw_svg_v.html", mm_slice(h, "<svg", "</svg>"))
    mm_write("frag_raw_svg_h.html",
        mm_slice(mm_read(proto + "/render_html/html_horiz_run.html"), "<svg", "</svg>"))

    // --- scoped + prefixed CSS for the real report -------------------------
    // strip the <style> wrapper, prefix the class names, scope every rule
    css = substr(css, strpos(css, ">") + 1, .)
    css = subinstr(css, "</style>", "")
    css = mm_prefix_css(css)
    mm_write("frag_mm_css.html",
        "<style>" + char(10) + mm_scope_css(css, ".mm-embed") + "</style>")

    // --- vertical diagram, responsive (no width/height attrs) --------------
    mm_write("frag_mm_svg.html",
        mm_fix_svg(mm_slice(h, "<svg", "</svg>"), "mmA-", 1))

    // --- vertical diagram, natural size (width/height kept) ----------------
    mm_write("frag_mm_svg_nat.html",
        mm_fix_svg(mm_slice(h, "<svg", "</svg>"), "mmB-", 0))

    // --- horizontal diagram, natural size (6802 x 439) ---------------------
    mm_write("frag_mm_svg_horiz.html",
        mm_fix_svg(mm_slice(mm_read(proto + "/render_html/html_horiz_run.html"),
                            "<svg", "</svg>"), "mmC-", 0))

    // --- horizontal diagram, stretched to 100% (the wrong way) -------------
    mm_write("frag_mm_svg_horiz_100.html",
        mm_fix_svg(mm_slice(mm_read(proto + "/render_html/html_horiz_run.html"),
                            "<svg", "</svg>"), "mmD-", 1))

    // --- Stata twoway SVG: everything from <svg on (drops the <?xml?> prolog)
    mm_write("frag_tw_svg.html",
        mm_fix_svg(mm_slice(mm_read(proto + "/render_twoway/tw_vert_run.svg"),
                            "<svg", "</svg>"), "twA-", 1))

    // --- <details> blocks lifted out of the details variant ----------------
    mm_write("frag_details.html", mm_slice_last(hd, "<details>", "</details>"))

    // --- SMCL/text as <pre> ------------------------------------------------
    mm_write("frag_pre_smcl.html",
        "<pre class=" + q + "mm-pre" + q + ">" +
        mm_esc(mm_read(proto + "/render_smcl/smcl_boxes_run.txt")) + "</pre>")
    mm_write("frag_pre_receipt.html",
        "<pre class=" + q + "mm-pre" + q + ">" +
        mm_esc(mm_read(proto + "/render_smcl/smcl_escalation.txt")) + "</pre>")
}

mm_build(st_local("proto"))
end

*------------------------------------------------------------------------------*
* 2. Page-level CSS written by the test (this is what a mergemap user would add)
*------------------------------------------------------------------------------*
capture file close pc
file open pc using "frag_page_css.html", write text replace
file write pc "<style>" _n
file write pc "/* webdoc2 emits a bare <body> with no container: give the report a column */" _n
file write pc ".mm-page   { max-width: 960px; margin: 0 auto; padding: 0 1rem 4rem 1rem; }" _n
file write pc "/* a bounded viewport for a diagram taller than the screen           */" _n
file write pc ".mm-scroll { max-height: 70vh; overflow: auto; border: 1px solid #dee2e6;" _n
file write pc "             border-radius: 6px; padding: .5rem; background: #fff; margin: 1rem 0; }" _n
file write pc "/* horizontal diagrams: never stretch, scroll sideways instead        */" _n
file write pc ".mm-xscroll{ overflow-x: auto; overflow-y: hidden; border: 1px solid #dee2e6;" _n
file write pc "             border-radius: 6px; padding: .5rem; margin: 1rem 0; }" _n
file write pc "/* mergemap ships svg{max-width:100%}, which cancels the sideways     */" _n
file write pc "/* scroller: inside .mm-xscroll the svg must keep its natural width.  */" _n
file write pc ".mm-xscroll svg { max-width: none !important; width: auto; height: auto; }" _n
file write pc "/* an iframe height that a CSS rule can set (the height= attribute    */" _n
file write pc "/* cannot take vh units, so wdiframe's height() option cannot either) */" _n
file write pc ".mm-frame-vh { height: 78vh !important; width: 100%; }" _n
file write pc "/* height:auto on an iframe does NOT shrink-wrap the document        */" _n
file write pc ".mm-frame-auto { height: auto !important; width: 100%; }" _n
file write pc "/* monospace receipt / ASCII diagram blocks                           */" _n
file write pc ".mm-pre    { font-family: 'SF Mono', Menlo, Consolas, monospace; font-size: 12.5px;" _n
file write pc "             line-height: 1.35; background: #F5F7FA; border: 1px solid #DEE2E6;" _n
file write pc "             border-left: 4px solid #1B2D55; border-radius: 0 6px 6px 0;" _n
file write pc "             padding: .9rem 1.2rem; overflow-x: auto; }" _n
file write pc "/* the inline-SVG wrapper the scoped mergemap CSS hangs off           */" _n
file write pc ".mm-embed svg { display: block; }" _n
file write pc "</style>" _n
file close pc

*------------------------------------------------------------------------------*
* 3. Build the pages
*------------------------------------------------------------------------------*
* -webdoc do- scans the do-file TEXT for a literal "webdoc init"; -wdinit- is
* invisible to that scan, so webdoc prepends its own init and creates a stray
* <dofile>.html. wdinit removes it, but erase defensively so a rerun is clean.
capture erase "page_mergemap.html"
capture erase "page_collision.html"

webdoc do page_mergemap.do, replace
webdoc do page_collision.do, replace

capture webdoc close

*------------------------------------------------------------------------------*
* 4. Verify
*------------------------------------------------------------------------------*
confirm file "mergemap_report.html"
confirm file "collision_demo.html"

local html = fileread("mergemap_report.html")
assert strpos(`"`html'"', "bootstrap") > 0 | strpos(`"`html'"', "Bootstrap") > 0
assert strpos(`"`html'"', "<iframe")            > 0     // (b)
assert strpos(`"`html'"', "<img src=")          > 0     // (a)
assert strpos(`"`html'"', "<svg")               > 0     // (c)
assert strpos(`"`html'"', "<pre class=")        > 0     // (d)
assert strpos(`"`html'"', "mm-embed")           > 0
assert strpos(`"`html'"', "class=" + char(34) + "mm-bh" + char(34)) > 0
di as res "OK: report contains img, iframe, inline svg and pre blocks"

* the scoped stylesheet must carry NO unscoped rule at all
mata:
void mm_checkcss()
{
    string colvector v
    string scalar    ln
    real scalar      i, nrules
    v = cat("frag_mm_css.html")
    nrules = 0
    for (i=1; i<=rows(v); i++) {
        ln = strtrim(v[i])
        if (ln=="" | ln=="<style>" | ln=="</style>") continue
        nrules++
        if (substr(ln, 1, 10) != ".mm-embed ") {
            printf("{err}unscoped CSS rule: %s\n", ln)
            _error("unscoped rule in frag_mm_css.html")
        }
    }
    st_local("nrules", strofreal(nrules))
}
mm_checkcss()
end
di as txt "scoped rules: `nrules'"
assert `nrules' > 15
local frag = fileread("frag_mm_css.html")
assert strpos(`"`frag'"', "body {")            == 0   // host <body> untouched
assert strpos(`"`frag'"', ".mm-embed .mm-bh")   > 0
assert strpos(`"`frag'"', ".mm-embed h1")       > 0
assert strpos(`"`frag'"', ".mm-embed svg")      > 0
di as res "OK: mergemap CSS is prefixed and scoped under .mm-embed"

* the responsive svg fragment keeps viewBox and drops width/height
local frag = fileread("frag_mm_svg.html")
assert strpos(`"`frag'"', "viewBox=")                              > 0
assert strpos(`"`frag'"', "<svg xmlns")                            > 0
assert regexm(substr(`"`frag'"',1,200), "<svg[^>]*width=")         == 0
assert strpos(`"`frag'"', "id=" + char(34) + "mmA-ag" + char(34))  > 0
assert strpos(`"`frag'"', "url(#mmA-ag)")                          > 0
di as res "OK: inline svg keeps viewBox, drops width/height, ids are unique"

* the Stata twoway SVG: does it carry a viewBox?
local frag = fileread("frag_tw_svg.html")
assert strpos(`"`frag'"', "viewBox=") > 0
assert regexm(substr(`"`frag'"',1,200), "<svg[^>]*width=") == 0
assert strpos(`"`frag'"', "<?xml") == 0          // prolog dropped
mata: printf("{txt}twoway svg root: %s\n", cat("frag_tw_svg.html")[1])
mata: printf("{txt}source root:     %s\n", ///
      cat(st_local("proto") + "/render_twoway/tw_vert_run.svg")[4])
di as res "OK: Stata-generated SVG DOES carry a viewBox; inch width/height stripped"

di as res _n "ALL CHECKS PASSED"
