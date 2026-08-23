*! mergemap_pkgtest.do -- regression battery for mergemap
*! Eric Booth
*
* Run from this directory:
*     cd tests
*     do mergemap_pkgtest.do
* or headless:
*     /usr/local/bin/stata-mp -b do mergemap_pkgtest.do
*
* Every block prints PASS or FAIL and the battery ends with a count. A block
* marked OPEN is a known gap that is not yet implemented; it reports OPEN
* instead of FAIL so the battery stays readable while the gaps are worked off.

version 16
clear all
set more off
set linesize 100

* ---------------------------------------------------------------- harness ----
global MM_PASS = 0
global MM_FAIL = 0
global MM_OPEN = 0

* call as:  mm_assert `=(<expression>)' "label"
* the expression must be evaluated by the caller: -args- splits on spaces,
* so a bare (a == b) would arrive as three separate arguments.
program define mm_assert
    args cond label
    if `cond' {
        display as text "  PASS  " as result "`label'"
        global MM_PASS = $MM_PASS + 1
    }
    else {
        display as error "  FAIL  `label'"
        global MM_FAIL = $MM_FAIL + 1
    }
end

program define mm_open
    args label
    display as text "  OPEN  `label'"
    global MM_OPEN = $MM_OPEN + 1
end

program define mm_block
    args n label
    display as text _n "{hline 78}"
    display as text "BLOCK `n': `label'"
    display as text "{hline 78}"
end

* count the data rows of a journal (header line excluded)
program define mm_jrows, rclass
    args jfile
    tempname fh
    local n = 0
    file open `fh' using `"`jfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar rows = `n' - 1
end

* does the journal contain a row whose fields include all of the given needles?
program define mm_jhas, rclass
    args jfile n1 n2 n3
    tempname fh
    local hit = 0
    file open `fh' using `"`jfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local ok = 1
        if `"`n1'"' != "" & strpos(`"`macval(line)'"', `"`n1'"') == 0 local ok = 0
        if `"`n2'"' != "" & strpos(`"`macval(line)'"', `"`n2'"') == 0 local ok = 0
        if `"`n3'"' != "" & strpos(`"`macval(line)'"', `"`n3'"') == 0 local ok = 0
        if `ok' local hit = 1
        file read `fh' line
    }
    file close `fh'
    return scalar hit = `hit'
end

* read one field of one event: mm_jfld <journal> <seq> <column-name>
* whole-line matching (mm_jhas) gives false positives -- "p4.do" contains "4" --
* so anything numeric must be asserted against a named column instead.
program define mm_jfld, rclass
    args jfile seq col
    tempname fr
    capture frame drop `fr'
    frame create `fr'
    local val ""
    frame `fr' {
        quietly import delimited using `"`jfile'"', delimiter(tab) ///
            varnames(1) stringcols(_all) clear
        * "using" is a RESERVED word, so -import delimited- renames that
        * header to a positional name (v9 today). Resolve it by position
        * rather than trusting the name.
        local c "`col'"
        capture confirm variable `c'
        if _rc {
            if "`col'" == "using" {
                unab all : _all
                local c : word 9 of `all'
            }
        }
        quietly count if seq == "`seq'"
        if r(N) > 0 {
            quietly levelsof `c' if seq == "`seq'", local(vv) clean
            local val `"`vv'"'
        }
    }
    frame drop `fr'
    return local val `"`val'"'
end

* ---------------------------------------------------------------- set-up ----
* Use a scratch subdirectory so the battery never disturbs the repo.
capture mkdir pkgtest_tmp
cd pkgtest_tmp
capture erase journal.tsv

* make the scanner findable whether or not mergemap is installed
adopath ++ ".."
adopath ++ "../../src"
capture discard

capture which mergemap
if _rc {
    display as error "mergemap.ado not found on the adopath; aborting"
    exit 111
}

* ------------------------------------------------------------ tiny inputs ----
* Two small files so the sample do-files are runnable as well as scannable.
clear
set obs 20
generate int id     = _n
generate byte grp   = mod(_n, 4) + 1
generate double x   = _n * 1.5
save a.dta, replace

clear
set obs 20
generate int id     = _n
generate str8 lbl   = "row" + string(_n)
save b.dta, replace

clear
set obs 4
generate byte grp   = _n
generate double w   = _n * 10
save g.dta, replace

* ============================================================================
mm_block 1 "plain scan of a single do-file"
* ============================================================================
capture erase p1.do
file open fh using p1.do, write text replace
file write fh "use a.dta, clear" _n
file write fh "merge 1:1 id using b.dta, nogenerate" _n
file write fh "merge m:1 grp using g.dta, keep(1 3) nogenerate" _n
file write fh "save out1.dta, replace" _n
file close fh

capture noisily mergemap p1.do, out(j1.tsv) noreceipt
mm_assert `=(_rc == 0)' "scan runs without error"
capture mm_jrows j1.tsv
mm_assert `=(r(rows) == 4)' "four events recorded (use, merge, merge, save)"
mm_jhas j1.tsv "merge" "1:1" "id"
mm_assert `=(r(hit) == 1)' "the 1:1 merge and its key are recorded"
mm_jhas j1.tsv "merge" "m:1" "grp"
mm_assert `=(r(hit) == 1)' "the m:1 merge and its key are recorded"
mm_jhas j1.tsv "save" "out1.dta"
mm_assert `=(r(hit) == 1)' "the save is recorded"
* ============================================================================
mm_block 2 "compound quotes must not break the parser"
* ============================================================================
* Regression for the r(132) 'too few quotes' failure: a scanned line that
* contains the compound-quote close sequence used to terminate the scanner's
* own quoting early. Defensive guards like this are common in careful code.
capture erase p2.do
file open fh using p2.do, write text replace
* build   if `"$SOMEGLOBAL"' == "" {   without ever putting a bare quote
* inside a quoted string: _char() writes by ASCII code.
* 96 = backtick, 34 = double quote, 39 = single quote, 36 = dollar
file write fh "if " _char(96) _char(34) _char(36) "SOMEGLOBAL" _char(34) ///
    _char(39) " == " _char(34) _char(34) " {" _n
file write fh "    error 459" _n
file write fh "}" _n
file write fh "use a.dta, clear" _n
file write fh "merge 1:1 id using b.dta, nogenerate" _n
file close fh

display as text "  (file content:)"
type p2.do

capture noisily mergemap p2.do, out(j2.tsv) noreceipt
mm_assert `=(_rc == 0)' "scan survives a compound-quoted line"
if _rc == 0 {
    mm_jhas j2.tsv "merge" "1:1" "id"
    mm_assert `=(r(hit) == 1)' "the merge after the guard is still found"
}
else {
    mm_assert `=(0)' "the merge after the guard is still found (scan aborted)"
}

* ============================================================================
mm_block 3 "several do-files in one call"
* ============================================================================
capture erase p3a.do
capture erase p3b.do
file open fh using p3a.do, write text replace
file write fh "use a.dta, clear" _n
file write fh "save s1.dta, replace" _n
file close fh
file open fh using p3b.do, write text replace
file write fh "use s1.dta, clear" _n
file write fh "merge 1:1 id using b.dta, nogenerate" _n
file close fh

capture noisily mergemap p3a.do p3b.do, out(j3.tsv) noreceipt
mm_assert `=(_rc == 0)' "two do-files scan in one call"
capture mm_jrows j3.tsv
mm_assert `=(r(rows) == 4)' "events from both files are recorded"
* ============================================================================
mm_block 4 "loops collapse into one stacked event"
* ============================================================================
capture erase p4.do
file open fh using p4.do, write text replace
file write fh "use a.dta, clear" _n
file write fh "forvalues i = 1/4 {" _n
file write fh "    append using part" _char(96) "i" _char(39) ".dta" _n
file write fh "}" _n
file close fh

capture noisily mergemap p4.do, out(j4.tsv) noreceipt
mm_assert `=(_rc == 0)' "a loop scans without error"
capture mm_jrows j4.tsv
mm_assert `=(r(rows) == 2)' "the loop is one event, not four"
mm_jfld j4.tsv 2 loop_n
mm_assert `=("`r(val)'" == "4")' "the loop event records 4 iterations"
mm_jfld j4.tsv 2 loop_first
mm_assert `=(strpos("`r(val)'", "part1.dta") > 0)' "the loop's first file is resolved"
mm_jfld j4.tsv 2 loop_last
mm_assert `=(strpos("`r(val)'", "part4.dta") > 0)' "the loop's last file is resolved"
* ============================================================================
mm_block 5 "flags: m:m and force are reported"
* ============================================================================
capture erase p5.do
file open fh using p5.do, write text replace
file write fh "use a.dta, clear" _n
file write fh "merge m:m id using b.dta, force" _n
file close fh

capture noisily mergemap p5.do, out(j5.tsv) noreceipt
mm_assert `=(_rc == 0)' "m:m with force scans"
mm_jhas j5.tsv "m:m"
mm_assert `=(r(hit) == 1)' "m:m is recorded as the subtype"
mm_jhas j5.tsv "!!"
mm_assert `=(r(hit) == 1)' "a warning flag is raised"
* ============================================================================
mm_block 6 "tempfiles are traced to where they were made"
* ============================================================================
capture erase p6.do
file open fh using p6.do, write text replace
file write fh "tempfile hold" _n
file write fh "use a.dta, clear" _n
file write fh "save " _char(96) "hold" _char(39) _n
file write fh "use b.dta, clear" _n
file write fh "merge 1:1 id using " _char(96) "hold" _char(39) ", nogenerate" _n
file close fh

capture noisily mergemap p6.do, out(j6.tsv) noreceipt
mm_assert `=(_rc == 0)' "a tempfile chain scans"
mm_jfld j6.tsv 4 using
mm_assert `=("`r(val)'" == "tempfile:hold")' "the merge reads tempfile:hold, not a raw path"
mm_jfld j6.tsv 2 subtype
mm_assert `=("`r(val)'" == "tempfile")' "the save is marked as a tempfile save"
* ============================================================================
mm_block 7 "file-shape traps: CRLF, block comments, continuations, prefixes"
* ============================================================================
capture erase p7.do
file open fh using p7.do, write text replace
file write fh "/* a block" _n
file write fh "   comment with the word merge inside it */" _n
file write fh "use a.dta, clear   // a trailing comment" _n
file write fh "quietly merge 1:1 id ///" _n
file write fh "    using b.dta, nogenerate" _n
file write fh `"* a star comment mentioning merge 1:1"' _n
file write fh "capture noisily merge m:1 grp using g.dta, nogenerate" _n
file close fh

capture noisily mergemap p7.do, out(j7.tsv) noreceipt
mm_assert `=(_rc == 0)' "traps scan without error"
capture mm_jrows j7.tsv
mm_assert `=(r(rows) == 3)' "comments are ignored and continuations joined"
mm_jhas j7.tsv "merge" "m:1" "grp"
mm_assert `=(r(hit) == 1)' "a prefixed command is still recognised"
* ============================================================================
mm_block 8 "beginner invocations"
* ============================================================================
* These are the ways a low-confidence user actually types the command. Each
* should either work or fail with advice, never with a bare Stata error.

* 8a: a folder in the positional slot
capture noisily mergemap ., out(j8a.tsv) noreceipt
if _rc == 0 {
    mm_assert `=(1)' "a folder is accepted positionally"
}
else {
    mm_open "a folder is accepted positionally (rc=`=_rc')"
}

* 8b: a wildcard pattern
capture noisily mergemap p*.do, out(j8b.tsv) noreceipt
if _rc == 0 {
    mm_assert `=(1)' "a wildcard pattern is expanded"
}
else {
    mm_open "a wildcard pattern is expanded (rc=`=_rc')"
}

* 8c: folder() option
capture noisily mergemap, folder(.) out(j8c.tsv) noreceipt
if _rc == 0 {
    mm_assert `=(1)' "folder() works"
}
else {
    mm_open "folder() works (rc=`=_rc')"
}

* 8d: a missing extension
capture noisily mergemap p1, out(j8d.tsv) noreceipt
if _rc == 0 {
    mm_assert `=(1)' "a missing .do extension is forgiven"
}
else {
    mm_open "a missing .do extension is forgiven (rc=`=_rc')"
}

* 8e: a bare call should advise, not just error
capture noisily mergemap
mm_assert `=(_rc != 0)' "a bare call does not silently succeed"
* ============================================================================
mm_block 9 "the receipt prints"
* ============================================================================
capture noisily mergemap p1.do, out(j9.tsv)
mm_assert `=(_rc == 0)' "the receipt renders without error"
* ============================================================================
mm_block 10 "help file renders"
* ============================================================================
capture findfile mergemap.sthlp
if _rc == 0 {
    local hf `"`r(fn)'"'
    capture translate `"`hf'"' "help_render.txt", translator(smcl2txt) replace
    mm_assert `=(_rc == 0)' "mergemap.sthlp translates cleanly"
    * a leaked directive means an unclosed {p} or {synopt} swallowed the rest
    tempname hh
    local leak = 0
    capture file open `hh' using "help_render.txt", read text
    if _rc == 0 {
        file read `hh' hline
        while r(eof) == 0 {
            if strpos(`"`macval(hline)'"', "{p_end}") | strpos(`"`macval(hline)'"', "{synopt") ///
               | strpos(`"`macval(hline)'"', "{phang") {
                local leak = 1
            }
            file read `hh' hline
        }
        file close `hh'
    }
    mm_assert `=(`leak' == 0)' "no SMCL directives leak into the rendered help"
}
else {
    mm_open "mergemap.sthlp found on the adopath"
}

* ============================================================================
mm_block 11 "mergemap draw renders from the last journal"
* ============================================================================
* p1.do was scanned in block 1; that journal is the draw default.
capture noisily mergemap p1.do, out(j11.tsv) noreceipt
capture noisily mergemap draw, forcesmcl
mm_assert `=(_rc == 0)' "bare draw renders the last journal in SMCL"
capture noisily mergemap draw, style(rail) forcesmcl
mm_assert `=(_rc == 0)' "draw accepts style(rail)"
capture noisily mergemap draw, export(html) saving(d11.html) replace noopen
mm_assert `=(_rc == 0)' "draw writes HTML"
local out `"`r(output)'"'
mm_assert `=("`out'" == "d11.html")' "r(output) names the HTML file"
capture confirm file d11.html
mm_assert `=(_rc == 0)' "the HTML file exists"
capture noisily mergemap draw, export(html) saving(d11f.html) embed replace
mm_assert `=(_rc == 0)' "draw writes an embed fragment"
* the fragment must never restyle a host page: no element selectors
tempname fh
local badsel = 0
file open `fh' using d11f.html, read text
file read `fh' line
while r(eof) == 0 {
    if regexm(`"`macval(line)'"', "^(body|h1|h2|pre|details|summary|svg)[ {]") local badsel = 1
    file read `fh' line
}
file close `fh'
mm_assert `=(`badsel' == 0)' "the fragment carries no element selectors"
capture noisily mergemap draw, export(mermaid) saving(d11) replace
mm_assert `=(_rc == 0)' "draw writes mermaid"
capture confirm file d11_td.mmd
mm_assert `=(_rc == 0)' "the .mmd file exists"
capture noisily mergemap draw, export(er) saving(d11e) replace
mm_assert `=(_rc == 0)' "draw writes an erDiagram"
capture noisily mergemap draw, export(png) saving(d11)
mm_assert `=(_rc == 0)' "draw writes PNG (paging itself if too dense)"
capture noisily mergemap draw nosuchjournal.tsv
mm_assert `=(_rc == 601)' "a missing journal is refused with advice"

* ============================================================================
mm_block 12 "mergemap sql teaches without touching the data"
* ============================================================================
sysuse auto, clear
local n = _N
capture noisily mergemap sql
mm_assert `=(_rc == 0)' "the translation table prints"
foreach k in full left inner fanout joinby append cross mm {
    capture noisily mergemap sql `k'
    mm_assert `=(_rc == 0)' "picture `k' prints"
}
capture noisily mergemap sql nonsense
mm_assert `=(_rc == 0)' "an unknown picture falls back to the table"
mm_assert `=(_N == `n')' "the data in memory are untouched"

* ============================================================================
mm_block 13 "list, detail, export, clear"
* ============================================================================
capture noisily mergemap p1.do, out(j13.tsv) noreceipt
capture noisily mergemap list
mm_assert `=(_rc == 0)' "list prints the remembered journal"
mm_assert `=(r(N_events) == 4)' "list counts the events"
capture noisily mergemap list j13.tsv, full
mm_assert `=(_rc == 0)' "list, full lists every column"
capture noisily mergemap detail 2
mm_assert `=(_rc == 0)' "detail prints one event"
capture noisily mergemap detail 2, teach
mm_assert `=(_rc == 0)' "detail, teach draws it (generic when scanned)"
capture noisily mergemap detail 99
mm_assert `=(_rc == 111)' "a missing event number is refused with the range"
capture noisily mergemap export, saving(j13.dta) replace
mm_assert `=(_rc == 0)' "export writes a dta"
preserve
quietly use j13.dta, clear
local numeric = ("`:type n_in'" != "str" & substr("`:type seq'", 1, 3) != "str")
mm_assert `=(_N == 4 & `numeric')' "the dta has 4 rows and numeric counts"
restore
capture noisily mergemap export, format(csv) saving(j13.csv) replace
mm_assert `=(_rc == 0)' "export writes a csv"
capture noisily mergemap clear
mm_assert `=(_rc == 0)' "clear runs"
mm_assert `=("$MM_LASTJ" == "")' "clear forgets the remembered journal"
capture confirm file j13.tsv
mm_assert `=(_rc == 0)' "clear leaves the journal FILE untouched"

* ============================================================================
mm_block 14 "mergemap demo can be run more than once"
* ============================================================================
* Reported from real use: the demo refused on every call after the first,
* which turns the first command a new user types into an error.
capture noisily mergemap demo, folder(dm14)
mm_assert `=(_rc == 0)' "demo runs on a fresh folder"
capture noisily mergemap demo, folder(dm14)
mm_assert `=(_rc == 0)' "demo runs again on its own folder"
capture noisily mergemap demo, folder(dm14)
mm_assert `=(_rc == 0)' "and again"

* a folder mergemap did not write is still protected
capture mkdir dm14_user
capture erase dm14_user/mywork.do
file open fh using dm14_user/mywork.do, write text replace
file write fh "* the user's own file" _n
file close fh
capture noisily mergemap demo, folder(dm14_user)
mm_assert `=(_rc == 602)' "a folder mergemap did not write is refused"
capture confirm file dm14_user/mywork.do
mm_assert `=(_rc == 0)' "and the user's file is left alone"

* ============================================================================
mm_block 15 "the open-diagram link never hands a URL to the platform"
* ============================================================================
* Reported from real use: clicking the link crashed Stata outright.  SMCL's
* {browse} passes its target to the OS URL parser, and a file:// URL kills
* Stata on macOS (NSURLComponents throws, abort()).  The link must be a
* {stata ...} command link instead, and no file:// may reach the output.
capture noisily mergemap demo, folder(dm15)
capture log close L15
log using dm15_draw.smcl, replace smcl name(L15) nomsg
capture noisily mergemap draw dm15/demo_journal.tsv, saving(dm15_map.html) replace noopen
log close L15

tempname fh
local sawbrowse = 0
local sawfile   = 0
local sawstata  = 0
file open `fh' using dm15_draw.smcl, read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "{browse") local sawbrowse = 1
    if strpos(`"`macval(line)'"', "file://") local sawfile   = 1
    if strpos(`"`macval(line)'"', "{stata _mm_open") local sawstata = 1
    file read `fh' line
}
file close `fh'
mm_assert `=(`sawbrowse' == 0)' "no {browse} directive in the draw output"
mm_assert `=(`sawfile' == 0)' "no file:// URL in the draw output"
mm_assert `=(`sawstata' == 1)' "the link is a {stata _mm_open} command link"

* _mm_open refuses a missing file rather than doing anything drastic
capture noisily _mm_open "no_such_file_here.html"
mm_assert `=(_rc == 601)' "_mm_open refuses a file that is not there"

* ============================================================================
mm_block 16 "hiding transforms and filters"
* ============================================================================
* Asked for from real use: a map of the joins alone, with the reshapes and the
* row filters left out.  The cut happens on the journal, so it applies to
* every export rather than only the Results-window drawing.
capture noisily mergemap demo, folder(dm16)
local j "dm16/demo_journal.tsv"

* count what each option leaves behind, straight from the journal
program define mm_cls, rclass
    args jfile cls
    tempname fr
    capture frame drop `fr'
    frame create `fr'
    local n = 0
    frame `fr' {
        quietly import delimited using "`jfile'", delimiter(tab) varnames(1) ///
            stringcols(_all) clear
        quietly count if class == "`cls'"
        local n = r(N)
    }
    frame drop `fr'
    return scalar n = `n'
end

mm_cls "`j'" transform
local ntrans = r(n)
mm_cls "`j'" filter
local nfilt = r(n)
mm_cls "`j'" join
local njoin = r(n)
mm_assert `=(`ntrans' > 0 & `nfilt' > 0 & `njoin' > 0)' "the demo journal has transforms, filters and joins to hide"

foreach o in notransforms nofilters joinsonly {
    capture noisily mergemap draw "`j'", forcesmcl maxnodes(99) `o'
    mm_assert `=(_rc == 0)' "draw accepts `o'"
}
* the cut reaches the other exports too, which it did not before
foreach o in notransforms joinsonly {
    capture noisily mergemap draw "`j'", export(mermaid) saving(dm16_`o') replace `o'
    mm_assert `=(_rc == 0)' "`o' works for a non-SMCL export"
}
capture noisily mergemap draw "`j'", export(html) saving(dm16.html) replace joinsonly noopen
mm_assert `=(_rc == 0)' "joinsonly works for HTML"
capture program drop mm_cls

* ---- block 18: shortening a long map ---------------------------------------
* Asked for from real use on a 3,092-event pipeline: row filters and variable
* filters hidden separately, tempfile traffic hidden, an if on the journal's
* columns, and file labels shortened or made relative to the project folder.
* Everything here cuts the journal before a renderer reads it, so one set of
* checks on the cut journal (r(journal)) covers every export.
mm_block 18 "shortening a long map"
capture mkdir dm18
capture mkdir dm18/raw
capture mkdir dm18/built
tempname fh
file open `fh' using dm18/01_cut.do, write text replace
file write `fh' "sysuse auto, clear" _n
file write `fh' "keep make price mpg foreign rep78" _n
file write `fh' "keep if price < 12000" _n
file write `fh' `"save "raw/cars.dta", replace"' _n
file write `fh' "sysuse auto, clear" _n
file write `fh' "keep make weight length" _n
file write `fh' "drop if weight > 4500" _n
file write `fh' "tempfile w" _n
file write `fh' "save " _char(96) "w" _char(39) _n
file write `fh' `"use "raw/cars.dta", clear"' _n
file write `fh' "merge 1:1 make using " _char(96) "w" _char(39) _n
file write `fh' "drop if _merge == 2" _n
file write `fh' "drop _merge" _n
file write `fh' "duplicates drop make, force" _n
file write `fh' "collapse (mean) price mpg weight, by(foreign)" _n
file write `fh' `"save "built/summary.dta", replace"' _n
file close `fh'
local here "`c(pwd)'"
cd dm18
capture noisily mergemap 01_cut.do, out(j18.tsv) noreceipt
mm_assert `=(_rc == 0)' "the block-18 fixture scans"

* count classes in whatever journal draw actually rendered
program define mm_cnt, rclass
    args jfile cond
    tempname fr
    capture frame drop `fr'
    frame create `fr'
    local n = 0
    frame `fr' {
        quietly import delimited using `"`jfile'"', delimiter(tab) varnames(1) ///
            stringcols(_all) clear
        quietly count if `cond'
        local n = r(N)
        quietly count
        local N = r(N)
    }
    frame drop `fr'
    return scalar n = `n'
    return scalar N = `N'
end
mm_cnt j18.tsv `"class == "filter" & subtype == "if""'
local nrow = r(n)
mm_cnt j18.tsv `"class == "filter" & subtype != "if""'
local nvar = r(n)
mm_cnt j18.tsv `"strpos(usingfile, "tempfile:") == 1 | strpos(result, "tempfile:") == 1"'
local ntmp = r(n)
mm_cnt j18.tsv `"class == "transform""'
local ntr = r(n)
local N0 = r(N)
mm_assert `=(`nrow' == 3 & `nvar' == 3 & `ntmp' == 2 & `ntr' == 2)' ///
    "fixture has 3 row filters, 3 variable filters, 2 tempfile events, 2 transforms"

* each option removes its own kind and nothing else
capture noisily mergemap draw j18.tsv, forcesmcl maxnodes(99) norowfilters
mm_assert `=(_rc == 0)' "norowfilters is accepted"
mm_cnt `"`r(journal)'"' `"class == "filter" & subtype == "if""'
local a = r(n)
local b = r(N)
mm_assert `=(`a' == 0 & `b' == `N0' - `nrow')' "norowfilters removes exactly the keep if / drop if events"

capture noisily mergemap draw j18.tsv, forcesmcl maxnodes(99) novarfilters
mm_cnt `"`r(journal)'"' `"class == "filter" & subtype != "if""'
local a = r(n)
local b = r(N)
mm_assert `=(`a' == 0 & `b' == `N0' - `nvar')' "novarfilters removes exactly the keep/drop varlist events"

capture noisily mergemap draw j18.tsv, forcesmcl maxnodes(99) notempfiles
mm_cnt `"`r(journal)'"' `"strpos(usingfile, "tempfile:") == 1 | strpos(result, "tempfile:") == 1"'
local a = r(n)
local b = r(N)
mm_assert `=(`a' == 0 & `b' == `N0' - `ntmp')' "notempfiles removes exactly the tempfile save and merge"

capture noisily mergemap draw j18.tsv, forcesmcl maxnodes(99) filesonly
mm_assert `=(_rc == 0)' "filesonly is accepted"
local hid `"`r(hidden)'"'
mm_cnt `"`r(journal)'"' `"inlist(class, "filter", "transform") | strpos(usingfile, "tempfile:") == 1 | strpos(result, "tempfile:") == 1"'
local a = r(n)
local b = r(N)
mm_assert `=(`a' == 0 & `b' == `N0' - `nrow' - `nvar' - `ntmp' - `ntr')' "filesonly = joinsonly + notempfiles"
mm_assert `=(strpos(`"`hid'"', "tempfile") > 0 & strpos(`"`hid'"', "filters") > 0)' "draw reports what it hid in r(hidden)"

* the if: numbers as numbers, text as text, commas inside functions
capture noisily mergemap draw j18.tsv if line < 9, forcesmcl maxnodes(99)
mm_assert `=(_rc == 0)' "an if on the line number is accepted"
mm_cnt `"`r(journal)'"' `"real(line) >= 9"'
mm_assert `=(r(n) == 0 & r(N) > 0)' "if line < 9 keeps only events before line 9"
capture noisily mergemap draw j18.tsv if inlist(class, "join", "save") & strpos(dofile, "cut"), export(mermaid) saving(dm18_if) replace
mm_assert `=(_rc == 0)' "an if with commas inside inlist() and a string compare is accepted"
mm_cnt `"`r(journal)'"' `"!inlist(class, "join", "save")"'
mm_assert `=(r(n) == 0)' "that if left only joins and saves"
capture noisily mergemap draw j18.tsv if nosuchcolumn == 1, forcesmcl
mm_assert `=(_rc == 111)' "an if on an unknown column fails with r(111) and a message, not a crash"
capture noisily mergemap draw j18.tsv if class == "join", export(html) saving(dm18_if.html) replace noopen
mm_assert `=(_rc == 0)' "the if works for HTML too"

* html: compact/nokeys accepted, the standalone page has no height cap
capture noisily mergemap draw j18.tsv, export(html) saving(dm18_c.html) replace noopen compact nokeys
mm_assert `=(_rc == 0)' "compact nokeys are accepted for HTML"
tempname fh
local capped = 0
local keyl = 0
file open `fh' using dm18_c.html, read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "max-height: 32rem") local capped = 1
    if strpos(`"`macval(line)'"', "key: ") local keyl = 1
    file read `fh' line
}
file close `fh'
mm_assert `=(`capped' == 0)' "a standalone HTML page is not capped to a 32rem scroll box"
mm_assert `=(`keyl' == 0)' "nokeys leaves no key line in the HTML"
capture noisily mergemap draw j18.tsv, export(html) saving(dm18_e.html) replace noopen embed
local capped = 0
file open `fh' using dm18_e.html, read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "max-height: 32rem") local capped = 1
    file read `fh' line
}
file close `fh'
mm_assert `=(`capped' == 1)' "an embed fragment keeps the bounded scroll box"
capture noisily mergemap draw j18.tsv, export(dot) saving(dm18_d) replace compact
mm_assert `=(_rc == 0)' "compact with a dot export is accepted, with a note"

* paths() and root(): a journal with absolute paths in both separator styles
local bs = char(92)
tempname fh
file open `fh' using jpath.tsv, write text replace
file write `fh' "seq" _tab "dofile" _tab "line" _tab "class" _tab "cmd" _tab "subtype" _tab "keys" _tab "master" _tab "usingfile" _tab "result" _tab "n_in" _tab "k_in" _tab "n_using" _tab "k_using" _tab "n_out" _tab "k_out" _tab "m1" _tab "m2" _tab "m3" _tab "m4" _tab "m5" _tab "dup_master" _tab "dup_using" _tab "force" _tab "opts" _tab "loop_n" _tab "loop_first" _tab "loop_last" _tab "severity" _tab "keytypes" _tab "cover_master" _tab "cover_using" _tab "lifecycle" _tab "flags" _n
local tail = "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "." + char(9) + "."
file write `fh' "1" _tab "a.do" _tab "1" _tab "source" _tab "use" _tab "." _tab "." _tab "work" _tab "/home/me/work/proj/data/raw/x.dta" _tab "work" _tab "`tail'" _n
file write `fh' "2" _tab "a.do" _tab "2" _tab "join" _tab "merge" _tab "1:1" _tab "id" _tab "work" _tab "C:`bs'Users`bs'me`bs'Documents`bs'proj`bs'data`bs'raw`bs'y.dta" _tab "work" _tab "`tail'" _n
file write `fh' "3" _tab "a.do" _tab "3" _tab "save" _tab "save" _tab "." _tab "." _tab "work" _tab "." _tab "`bs'`bs'server`bs'share`bs'proj`bs'data`bs'built`bs'z.dta" _tab "`tail'" _n
file write `fh' "4" _tab "a.do" _tab "4" _tab "source" _tab "use" _tab "." _tab "." _tab "work" _tab "tempfile:St1.000001" _tab "work" _tab "`tail'" _n
file close `fh'
capture noisily mergemap draw jpath.tsv, forcesmcl maxnodes(99) paths(base)
mm_assert `=(_rc == 0)' "paths(base) is accepted"
local jc `"`r(journal)'"'
mm_jfld `"`jc'"' 1 usingfile
mm_assert `=("`r(val)'" == "x.dta")' "paths(base): a unix path becomes its file name"
mm_jfld `"`jc'"' 2 usingfile
mm_assert `=("`r(val)'" == "y.dta")' "paths(base): a Windows drive path becomes its file name"
mm_jfld `"`jc'"' 3 result
mm_assert `=("`r(val)'" == "z.dta")' "paths(base): a UNC path becomes its file name"
mm_jfld `"`jc'"' 4 usingfile
mm_assert `=("`r(val)'" == "tempfile:St1.000001")' "paths(base) leaves a tempfile label alone"
capture noisily mergemap draw jpath.tsv, forcesmcl maxnodes(99) paths(parent)
local jc `"`r(journal)'"'
mm_jfld `"`jc'"' 1 usingfile
mm_assert `=("`r(val)'" == "raw/x.dta")' "paths(parent): parent folder and file name, separators kept"
mm_jfld `"`jc'"' 2 usingfile
mm_assert `=("`r(val)'" == "raw`bs'y.dta")' "paths(parent) keeps a Windows path's own backslash"
capture noisily mergemap draw jpath.tsv, forcesmcl maxnodes(99) root(proj)
local jc `"`r(journal)'"'
mm_jfld `"`jc'"' 1 usingfile
local v1 "`r(val)'"
mm_jfld `"`jc'"' 2 usingfile
local v2 "`r(val)'"
mm_jfld `"`jc'"' 3 result
local v3 "`r(val)'"
mm_assert `=("`v1'" == "data/raw/x.dta" & "`v2'" == "data`bs'raw`bs'y.dta" & "`v3'" == "data`bs'built`bs'z.dta")' ///
    "root(proj): every path becomes relative to the proj folder, whatever sat above it"
capture noisily mergemap draw jpath.tsv, forcesmcl maxnodes(99) root(nosuchfolder)
mm_jfld `"`r(journal)'"' 1 usingfile
mm_assert `=("`r(val)'" == "/home/me/work/proj/data/raw/x.dta")' "root() leaves a path that does not contain the folder as it was"
capture noisily mergemap draw jpath.tsv, forcesmcl maxnodes(99) root(/home/me/work)
mm_jfld `"`r(journal)'"' 1 usingfile
mm_assert `=("`r(val)'" == "proj/data/raw/x.dta")' "root() also accepts a path prefix"
capture noisily mergemap draw jpath.tsv, forcesmcl paths(nonsense)
mm_assert `=(_rc == 198)' "paths(nonsense) is refused with r(198)"

* the same two options on receipt, list and export
capture noisily mergemap receipt jpath.tsv, paths(base)
mm_assert `=(_rc == 0)' "mergemap receipt accepts paths()"
capture noisily mergemap list jpath.tsv, root(proj)
mm_assert `=(_rc == 0)' "mergemap list accepts root()"

* export to a workbook: three sheets, counts numeric, paths shortened
capture noisily mergemap export j18.tsv, saving(j18.xlsx) replace paths(base)
mm_assert `=(_rc == 0)' "mergemap export writes an xlsx"
mm_assert `=(r(N_joins) == 1 & r(N_filters) == 6)' "the workbook counts 1 join and 6 filters"
capture frame drop _t18
frame create _t18
frame _t18 {
    capture import excel using j18.xlsx, sheet("filters") firstrow clear
    local rc1 = _rc
    local nf = _N
    capture confirm numeric variable n_in
    local rc2 = _rc
    capture confirm variable condition kind removed pct_removed
    local rc3 = _rc
    capture import excel using j18.xlsx, sheet("joins") firstrow clear
    local rc4 = _rc
    local nj = _N
    capture import excel using j18.xlsx, sheet("events") firstrow clear
    local ne = _N
    quietly count if strpos(usingfile, "/") > 0
    local nslash = r(N)
}
frame drop _t18
mm_assert `=(`rc1' == 0 & `nf' == 6 & `rc2' == 0 & `rc3' == 0)' "filters sheet: 6 rows, n_in numeric, kind/condition/removed/pct_removed present"
mm_assert `=(`rc4' == 0 & `nj' == 1)' "joins sheet: one row for the one merge"
mm_assert `=(`ne' == `N0' & `nslash' == 0)' "events sheet: every event, with paths(base) applied"
capture noisily mergemap export j18.tsv, format(xlsx) saving(j18b) replace
mm_assert `=(_rc == 0 & strpos("`r(file)'", ".xlsx") > 0)' "format(xlsx) supplies the extension"
capture program drop mm_cnt
cd "`here'"

* ---- block 19: the HTML page spends one line per fact ----------------------
* Scanned from four real maps (3,092 events, 222,000 px tall): most of the
* height was the same advisory repeated on every box, a three-line
* provenance, count lines that fit beside their label, and a read that is
* saved straight away drawn as two boxes and an arrow.  These checks pin the
* compact forms so they do not drift back.
mm_block 19 "the HTML page spends one line per fact"
* lines in a file that contain a string -> r(n)
program define mm_fcount, rclass
    args f str
    tempname fh
    local n = 0
    file open `fh' using `"`f'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`str'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end
cd dm18
* (a) a scan with a macro path, a loop over a runtime list, and a read saved
*     straight away
tempname fh
file open `fh' using p19.do, write text replace
file write `fh' "use " _char(36) "{RAW}/cars.dta, clear" _n
file write `fh' "local fl : dir . files " _char(34) "*.dta" _char(34) _n
file write `fh' "foreach f of local fl {" _n
file write `fh' "    append using " _char(96) "f" _char(39) _n
file write `fh' "}" _n
file write `fh' `"save "built/all.dta", replace"' _n
file write `fh' `"use "raw/cars.dta", clear"' _n
file write `fh' `"save "built/copy.dta", replace"' _n
file close `fh'
capture noisily mergemap p19.do, out(j19.tsv) noreceipt
mm_assert `=(_rc == 0)' "the block-19 scan fixture scans"
capture noisily mergemap draw j19.tsv, export(html) saving(s19.html) replace noopen
mm_assert `=(_rc == 0)' "its HTML page renders"
mm_fcount s19.html "row change unknown until run"
mm_assert `=(r(n) == 0)' "scan mode: no box repeats 'row change unknown until run'"
mm_fcount s19.html "scan mode: row changes are unknown until run"
mm_assert `=(r(n) == 1)' "scan mode: the legend says it once"
* a drawn line is <text ...>path built from a macro</text>; the tooltip keeps
* the full flag text on lines of its own, which is where it belongs
mm_fcount s19.html ">path built from a macro"
local onbox = r(n)
mm_fcount s19.html "= path built from a macro"
mm_assert `=(r(n) == 1 & `onbox' == 0)' "a macro path is explained once, in the legend, not on the box"
mm_fcount s19.html "loop over a list built at run time"
mm_assert `=(r(n) == 1)' "a runtime list is explained once, in the legend"
mm_fcount s19.html "saved: "
mm_assert `=(r(n) >= 1)' "a read saved straight away is one box: '#k saved: ...' inside it"
* (b) the same run journal draws its counts compactly
capture noisily mergemap run 01_cut.do, out(r19.tsv) noreceipt
mm_assert `=(_rc == 0)' "the block-18 fixture runs (and mergemap run accepts noreceipt)"
capture noisily mergemap draw r19.tsv, export(html) saving(r19.html) replace noopen
mm_assert `=(_rc == 0)' "the run-mode HTML page renders"
* auto's make is unique, so this duplicates drop removes nothing: the row
* change rides on the command line, "duplicates drop . 69 -> 69 obs"
mm_fcount r19.html ">duplicates drop &#183; "
mm_assert `=(r(n) >= 1)' "a transform's row change rides on its command line when it fits"
mm_fcount r19.html ">keep if price "
local kl = r(n)
mm_fcount r19.html "(-"
mm_assert `=(`kl' >= 1 & r(n) >= 1)' "a flagged filter is one line: a -> b (-d, p%)"
mm_fcount r19.html "opts: nogenerate"
mm_assert `=(r(n) == 0)' "an option that changes no row (nogenerate) is not a line"
mm_fcount r19.html "% matched"
mm_assert `=(r(n) == 0)' "the old 'master N% matched . using N% used' wording is gone"
mm_fcount r19.html "tempfile:w"
local tfw = r(n)
mm_fcount r19.html "[tempfile]"
mm_assert `=(r(n) == 0)' "a box labelled tempfile:<name> does not add a [tempfile] line"
capture noisily mergemap draw r19.tsv, export(html) saving(r19c.html) replace noopen compact
mm_assert `=(_rc == 0)' "compact still renders on the compact page"
cd ..
capture program drop mm_fcount

* ---- block 17: absolute-path detection is platform-neutral ----------------
* An output path that is already absolute must not be sent back through
* c(pwd).  The Windows forms are the ones that regressed: a UNC share and a
* root-relative path both start with a backslash, which a test that only
* looks for a leading / and a drive letter reads as relative.  These run the
* same on every platform because the predicate is pure string work.
local bs = char(92)
foreach spec in ///
    "/home/eric/out.html|1|unix absolute" ///
    "C:`bs'project`bs'out.html|1|Windows drive letter" ///
    "`bs'`bs'server`bs'share`bs'out.html|1|Windows UNC share" ///
    "`bs'project`bs'out.html|1|Windows root-relative" ///
    "out.html|0|bare relative" ///
    "sub/out.html|0|relative with a subfolder" ///
    "./out.html|0|explicitly relative" {
    local path  = substr("`spec'", 1, strpos("`spec'", "|") - 1)
    local rest  = substr("`spec'", strpos("`spec'", "|") + 1, .)
    local want  = real(substr("`rest'", 1, strpos("`rest'", "|") - 1))
    local lab   = substr("`rest'", strpos("`rest'", "|") + 1, .)
    capture _mm_isabs "`path'"
    mm_assert `=(_rc == 0)' "_mm_isabs runs: `lab'"
    mm_assert `=(r(abs) == `want')' "_mm_isabs: `lab'"
}

* ---------------------------------------------------------------- summary ----
display as text _n "{hline 78}"
display as text "mergemap battery: " as result "$MM_PASS passed" as text ", " ///
    as result "$MM_FAIL failed" as text ", " as result "$MM_OPEN open"
display as text "{hline 78}"
if $MM_FAIL == 0 {
    display as result "ALL IMPLEMENTED CHECKS PASSED"
}
else {
    display as error "SOME CHECKS FAILED"
}
cd ..
