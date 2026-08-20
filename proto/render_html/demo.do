* demo.do - drive _mm_renderhtml over both v2 contract journals
* run headless from this directory:
*   cd proto/render_html && /usr/local/bin/stata-mp -b do demo.do
* _mm_renderhtml.ado is picked up from the current directory (adopath includes ".")

adopath + "../../src"
version 16.0
clear all

* ------------------------------------------------------------ page outputs
_mm_renderhtml using "../journal_scan.tsv", saving(html_vert_scan.html)          layout(vertical)   replace
_mm_renderhtml using "../journal_scan.tsv", saving(html_vert_scan_details.html)  layout(vertical)   details replace
_mm_renderhtml using "../journal_run.tsv",  saving(html_vert_run.html)           layout(vertical)   replace
_mm_renderhtml using "../journal_run.tsv",  saving(html_vert_run_details.html)   layout(vertical)   details replace
_mm_renderhtml using "../journal_scan.tsv", saving(html_horiz_scan.html)         layout(horizontal) replace
_mm_renderhtml using "../journal_run.tsv",  saving(html_horiz_run.html)          layout(horizontal) replace

* ------------------------------------------------------------ embed fragments
* Three fragments with three id namespaces, so one host page can carry all of
* them without the arrowhead-id collision of DECISIONS 20e.
_mm_renderhtml using "../journal_run.tsv",  saving(frag_run_vert.html)   layout(vertical)   embed idprefix(mm-1) replace
_mm_renderhtml using "../journal_scan.tsv", saving(frag_scan_vert.html)  layout(vertical)   embed idprefix(mm-2) details replace
_mm_renderhtml using "../journal_run.tsv",  saving(frag_run_horiz.html)  layout(horizontal) embed idprefix(mm-3) replace

* ------------------------------------------------------------ host-page proof
capture program drop _mm_host
program define _mm_host
    args out
    tempname H
    file open `H' using "`out'", write text replace
    file write `H' `"<!DOCTYPE html>"' _n
    file write `H' `"<html xmlns="http://www.w3.org/1999/xhtml" lang="en">"' _n
    file write `H' `"<head>"' _n
    file write `H' `"<meta charset="utf-8" />"' _n
    file write `H' `"<title>mergemap embed fragments in a host page</title>"' _n
    file write `H' `"<style type="text/css">"' _n
    file write `H' `"/* HOST styles. If a mergemap fragment leaks, these are what change. */"' _n
    file write `H' `"body { font-family: Georgia, Times New Roman, serif; font-size: 17px; color: #1b2d55; background: #fbfbfb; margin: 0; max-width: none; padding: 0 0 4rem 0; }"' _n
    file write `H' `"h1 { font-size: 30px; font-weight: 400; margin: 0 0 10px 0; }"' _n
    file write `H' `"h2 { font-size: 22px; font-weight: 400; margin: 30px 0 8px 0; }"' _n
    file write `H' `"p  { line-height: 1.55; font-size: 17px; }"' _n
    file write `H' `"pre { background: #eef1f6; padding: 12px; font-size: 15px; }"' _n
    file write `H' `"details { border: 2px dashed #1b2d55; }"' _n
    file write `H' `"summary { color: #1b2d55; font-size: 16px; }"' _n
    file write `H' `".host { max-width: 960px; margin: 0 auto; padding: 0 1rem; }"' _n
    file write `H' `".host svg { border: 0; }"' _n
    file write `H' `"/* The host deliberately recolours the FIRST diagram's arrowheads. */"' _n
    file write `H' `"/* With ids namespaced per diagram, the other two must stay grey. */"' _n
    file write `H' `"#mm-1-ag path, #mm-1-aa path { fill: #b00020; }"' _n
    file write `H' `"</style>"' _n
    file write `H' `"</head>"' _n
    file write `H' `"<body>"' _n
    file write `H' `"<div class="host">"' _n
    file write `H' `"<h1>Host report with three mergemap fragments</h1>"' _n
    file write `H' `"<p>This page carries its own body, h1, h2, p, pre, details and summary rules. Three mergemap embed fragments are pasted into it verbatim. Nothing below is allowed to change anything above.</p>"' _n
    file write `H' `"<h2>1. Run mode, vertical (namespace mm-1)</h2>"' _n
    _mm_paste `H' "frag_run_vert.html"
    file write `H' `"<h2>2. Scan mode, vertical, with ledger (namespace mm-2)</h2>"' _n
    _mm_paste `H' "frag_scan_vert.html"
    file write `H' `"<h2>3. Run mode, horizontal (namespace mm-3)</h2>"' _n
    _mm_paste `H' "frag_run_horiz.html"
    file write `H' `"<h2>What this page proves</h2>"' _n
    file write `H' `"<ul>"' _n
    file write `H' `"<li>The heading above is still 22px Georgia and the body is still 17px on a #fbfbfb ground: no fragment emits an element selector, so no host rule was overridden.</li>"' _n
    file write `H' `"<li>Diagram 1's arrowheads are dark red because the host targeted <code>#mm-1-ag</code> and <code>#mm-1-aa</code>. Diagrams 2 and 3 are untouched, which is the DECISIONS 20e regression fixed.</li>"' _n
    file write `H' `"<li>Every fragment stylesheet is scoped to its own wrapper class, so the second fragment's rules cannot reach the first.</li>"' _n
    file write `H' `"<li>The ledger blocks are real details/summary elements. mergemap styles them through .mm-det and .mm-sum only, so they win on specificity for their own markup while the host's details and summary rules keep working everywhere else on the page (the summary text here is still the host's #1b2d55).</li>"' _n
    file write `H' `"<li>The horizontal diagram keeps its natural width inside its own sideways scroller instead of being squeezed into the text column.</li>"' _n
    file write `H' `"</ul>"' _n
    file write `H' `"</div>"' _n
    file write `H' `"</body>"' _n
    file write `H' `"</html>"' _n
    file close `H'
    display as text "wrote " as result "`out'"
end

capture program drop _mm_paste
program define _mm_paste
    args H f
    tempname R
    file open `R' using "`f'", read text
    file read `R' l
    while r(eof) == 0 {
        file write `H' `"`macval(l)'"' _n
        file read `R' l
    }
    file close `R'
end

_mm_host "html_embed_fragment.html"

display "demo.do: done"
