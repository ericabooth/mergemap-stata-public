* demo.do -- driver for the _mm_rendertext prototype
* Emits mermaid flowcharts (.mmd + fenced .md), the mermaid erDiagram
* flavour, and Graphviz DOT (.dot), vertical and horizontal, from both
* contract journals:
*   ../journal_run.tsv   (run mode: counts observed)
*   ../journal_scan.tsv  (scan mode: all counts ".", the package default)
* Run headless:  stata-mp -b do demo.do
adopath + "../../src"
version 16
clear all

_mm_rendertext using ../journal_run.tsv,  saving(text_run)  format(all) ///
    layout(both) replace
_mm_rendertext using ../journal_scan.tsv, saving(text_scan) format(all) ///
    layout(both) replace

* quick receipt of what landed on disk
foreach f in text_run_td.mmd text_run_td.md text_run_lr.mmd text_run_lr.md ///
    text_run_er.mmd text_run_er.md text_run_tb.dot text_run_lr.dot ///
    text_scan_td.mmd text_scan_td.md text_scan_lr.mmd text_scan_lr.md ///
    text_scan_er.mmd text_scan_er.md text_scan_tb.dot text_scan_lr.dot {
    confirm file "`f'"
    di as txt "  wrote " as res "`f'"
}

* ---- self-checks the renderer must pass -----------------------------------
* every check writes PASS/FAIL so a grep of the log tells the whole story
capture program drop _rtcheck
program define _rtcheck
    args label want file pat
    tempname fh
    local hits = 0
    file open `fh' using "`file'", read text
    file read `fh' ln
    while r(eof) == 0 {
        if strpos(`"`macval(ln)'"', `"`macval(pat)'"') > 0 local ++hits
        file read `fh' ln
    }
    file close `fh'
    local got = cond(`hits' > 0, "yes", "no")
    di as txt "  " %-6s cond("`got'" == "`want'", "PASS", "FAIL") ///
        " `label'  (`file': `hits' hits)"
end

di as txt "checks:"
_rtcheck "mermaid init directive carries the accent-free base theme" ///
    yes text_scan_td.mmd "%%{init:"
_rtcheck "accTitle present" yes text_scan_td.mmd "accTitle:"
_rtcheck "accDescr block present" yes text_scan_td.mmd "accDescr {"
_rtcheck "no click href (GitHub CSP blocks it)" no text_scan_td.mmd "click "
_rtcheck "no block-beta (post-10.0.2 syntax)" no text_scan_td.mmd "block-beta"
_rtcheck "provenance comment" yes text_scan_td.mmd "%% mergemap _mm_rendertext"
_rtcheck "provenance comment in DOT" yes text_scan_tb.dot "// mergemap"
_rtcheck "provenance comment in erDiagram" yes text_scan_er.mmd "%% mergemap"
_rtcheck "accent is 4a6d8c" yes text_scan_td.mmd "#4a6d8c"
_rtcheck "old accent 39537d gone" no text_scan_td.mmd "#39537d"
_rtcheck "filter node: drop if condition" yes text_scan_td.mmd ///
    "drop if missing(wage)"
_rtcheck "filter node: keep if condition" yes text_scan_td.mmd ///
    "keep if inrange(year, 2019, 2022)"
_rtcheck "filter node is a stadium (slim) node" yes text_scan_td.mmd "s4(["
_rtcheck "run mode filter carries the row change" yes text_run_td.mmd ///
    "removed 6,519 rows"
_rtcheck "scan mode prints no bare period counts" no text_scan_td.mmd "<br/>."
_rtcheck "warn severity prints !! even when the flag text lacks it" ///
    yes text_run_td.mmd "!! 12 duplicate pid obs dropped"
_rtcheck "stop severity is labelled in text, not colour" yes ///
    text_run_td.mmd "!! stop"
_rtcheck "coverage percentages shown when present" yes text_run_td.mmd ///
    "99.7% of master matched"
_rtcheck "coverage absent in scan mode" no text_scan_td.mmd "of master matched"
_rtcheck "key type mismatch reported" yes text_run_td.mmd "key type mismatch"
_rtcheck "matching key types not reported as a mismatch" no text_run_td.mmd ///
    "county: str5 vs str5"
_rtcheck "update replace not printed twice" no text_scan_td.mmd ///
    "update replace<br/>"
_rtcheck "lifecycle create renders as [saved]" yes text_scan_td.mmd "[saved]"
_rtcheck "erDiagram m:1 glyph" yes text_scan_er.mmd "}o--||"
_rtcheck "erDiagram 1:m glyph" yes text_scan_er.mmd "||--o{"
_rtcheck "erDiagram m:m glyph" yes text_scan_er.mmd "}o--o{"
_rtcheck "erDiagram append is a dotted link" yes text_scan_er.mmd "}o..o{"
_rtcheck "erDiagram key is an attribute" yes text_scan_er.mmd "key county PK"
_rtcheck "erDiagram uses storage types in run mode" yes text_run_er.mmd ///
    "str5 county PK"
_rtcheck "erDiagram carries !! on a flagged join" yes text_scan_er.mmd ///
    "!! merge m:m staff"
_rtcheck "DOT filter node is rounded" yes text_scan_tb.dot "style=rounded"
_rtcheck "DOT accent on the flagged node" yes text_scan_tb.dot "#4a6d8c"

di as txt ""
di as txt "_mm_rendertext demo complete"
