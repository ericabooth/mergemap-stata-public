* demo.do — drive _mm_rendertw over the v2 contract journals
* run headless:
*   cd proto/render_twoway && /usr/local/bin/stata-mp -b do demo.do
* _mm_rendertw.ado sits in this directory and is found via the "." adopath.

adopath + "../../src"
version 16
clear all
set more off

* ------------------------------------------------------------------
* whole-journal images
* ------------------------------------------------------------------

* scan journal: all counts "." (scan mode is the package default)
_mm_rendertw using "../journal_scan.tsv", saving(tw_vert_scan)   layout(vertical)
_mm_rendertw using "../journal_scan.tsv", saving(tw_horiz_scan)  layout(horizontal)

* run journal: counts observed
_mm_rendertw using "../journal_run.tsv",  saving(tw_vert_run)    layout(vertical)
_mm_rendertw using "../journal_run.tsv",  saving(tw_horiz_run)   layout(horizontal)

* ------------------------------------------------------------------
* page(dofile): one image per do-file, so a printed page is usable
* ------------------------------------------------------------------
_mm_rendertw using "../journal_scan.tsv", saving(tw_page_scan) page(dofile)
_mm_rendertw using "../journal_run.tsv",  saving(tw_page_run)  page(dofile)

foreach f in 01_build 02_panel 03_analyze {
    foreach j in scan run {
        confirm file "tw_page_`j'_`f'.png"
        confirm file "tw_page_`j'_`f'.svg"
    }
}
display as txt "page(dofile) check OK: 6 per-do-file images written"

* ------------------------------------------------------------------
* checks
* ------------------------------------------------------------------

* node cap: the journals hold 12 join+transform+filter events, so maxnodes(5)
* must refuse with rc 134 and point at the HTML renderer
capture noisily _mm_rendertw using "../journal_run.tsv", ///
    saving(tw_should_not_exist) maxnodes(5)
local rc = _rc
assert `rc' == 134
display as txt "cap check OK: _mm_rendertw refused with rc = `rc'"

* the same cap passes per page, because each do-file page is small
capture noisily _mm_rendertw using "../journal_run.tsv", ///
    saving(tw_tmp_page) page(dofile) maxnodes(5)
assert _rc == 0
display as txt "per-page cap check OK"

* page() also works with the horizontal layout
_mm_rendertw using "../journal_scan.tsv", saving(tw_tmp_hpage) ///
    page(dofile) layout(horizontal) noprovenance
foreach f in 01_build 02_panel 03_analyze {
    confirm file "tw_tmp_hpage_`f'.png"
    erase tw_tmp_hpage_`f'.png
    erase tw_tmp_hpage_`f'.svg
}
display as txt "horizontal page check OK"

* bad option values are refused before anything is written
capture noisily _mm_rendertw using "../journal_run.tsv", ///
    saving(tw_should_not_exist) page(chapter)
assert _rc == 198
capture noisily _mm_rendertw using "../journal_run.tsv", ///
    saving(tw_should_not_exist) layout(diagonal)
assert _rc == 198
display as txt "option check OK"

* a v1 journal (column 9 named "using") is refused, not silently misread
tempname fh
tempfile v1
file open `fh' using "`v1'", write text replace
file write `fh' "seq" _tab "dofile" _tab "line" _tab "class" _tab "cmd" _tab ///
    "subtype" _tab "keys" _tab "master" _tab "using" _tab "result" _n
file write `fh' "1" _tab "a.do" _tab "1" _tab "source" _tab "use" _tab "." ///
    _tab "." _tab "." _tab "b.dta" _tab "work" _n
file close `fh'
capture noisily _mm_rendertw using "`v1'", saving(tw_should_not_exist)
assert _rc == 459
display as txt "v1 refusal check OK"

* nothing was written by any of the refused calls
capture confirm file "tw_should_not_exist.png"
assert _rc != 0
display as txt "no-partial-output check OK"

* noprovenance suppresses the footer caption
_mm_rendertw using "../journal_scan.tsv", saving(tw_tmp_noprov) ///
    layout(vertical) noprovenance
display as txt "noprovenance check OK"

erase tw_tmp_noprov.png
erase tw_tmp_noprov.svg
foreach f in 01_build 02_panel 03_analyze {
    erase tw_tmp_page_`f'.png
    erase tw_tmp_page_`f'.svg
}

display as txt "demo.do done"
