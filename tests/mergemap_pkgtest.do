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
