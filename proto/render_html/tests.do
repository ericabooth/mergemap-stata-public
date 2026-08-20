* tests.do - option and schema-tolerance checks for _mm_renderhtml
* cd proto/render_html && /usr/local/bin/stata-mp -b do tests.do
* Prints PASS/FAIL per check; a nonzero fail count exits 9.

adopath + "../../src"
version 16.0
clear all
capture mkdir tmp

global NF 0
* chk "label" <condition>
* the label comes first because `args' splits a parenthesized expression
* across arguments, which silently breaks `args ok label'
capture program drop chk
program define chk
    gettoken label 0 : 0
    local ok = (`0')
    if `ok' display as text "PASS  `label'"
    else {
        display as error "FAIL  `label'"
        global NF = $NF + 1
    }
end

* cnt FILE PATTERN -> r(n) = lines containing PATTERN.
* PATTERN is the rest of the line, so it may contain quotes and spaces; `args'
* would split it.
capture program drop cnt
program define cnt, rclass
    gettoken f 0 : 0
    local pat = trim(`"`0'"')
    tempname R
    local n 0
    file open `R' using "`f'", read text
    file read `R' l
    while r(eof) == 0 {
        if strpos(`"`macval(l)'"', `"`pat'"') local ++n
        file read `R' l
    }
    file close `R'
    return scalar n = `n'
end

* ---------------------------------------------------------------- 1 noheader
_mm_renderhtml using "../journal_run.tsv", saving(tmp/t_nohead.html) noheader replace
cnt tmp/t_nohead.html class="mm-cap"
chk "noheader suppresses the caption" r(n) == 0
cnt tmp/t_nohead.html class="mm-leg"
chk "noheader suppresses the legend" r(n) == 0

* ---------------------------------------------------------------- 2 noprov
_mm_renderhtml using "../journal_run.tsv", saving(tmp/t_noprov.html) noprov replace
cnt tmp/t_noprov.html class="mm-foot"
chk "noprovenance suppresses the footer" r(n) == 0
cnt tmp/t_noprov.html class="mm-cap"
chk "noprovenance keeps the caption" r(n) == 1

* ------------------------------------------------- 3 default id namespace
_mm_renderhtml using "../journal_run.tsv", saving(tmp/vert_x.html) replace
cnt tmp/vert_x.html id="mm-vert-x-ag"
chk "idprefix defaults to a slug of the output stem" r(n) == 1
cnt tmp/vert_x.html url(#mm-vert-x-ag)
chk "marker references use the namespaced id" r(n) > 0

* ------------------------------------------------- 4 v1 journal is refused
tempname W
file open `W' using "tmp/v1.tsv", write text replace
file write `W' "seq" _tab "dofile" _tab "line" _tab "class" _tab "cmd" _tab "using" _tab "flags" _n
file write `W' "1" _tab "a.do" _tab "3" _tab "source" _tab "use" _tab "a.dta" _tab "." _n
file close `W'
capture noisily _mm_renderhtml using "tmp/v1.tsv", saving(tmp/v1.html) replace
chk "a v1 header (column named using) is refused with a clear message" `=_rc' == 459

* ------------------------------- 5 older journal missing the v2 additions
* the renderer must tolerate a journal that stops before severity/keytypes
preserve
quietly import delimited using "../journal_scan.tsv", delimiter(tab) varnames(1) stringcols(_all) clear
quietly drop severity keytypes cover_master cover_using lifecycle
quietly export delimited using "tmp/short.tsv", delimiter(tab) replace novarnames datafmt
* re-add the header row by hand (export drops it with novarnames)
quietly describe, varlist
local vl "`r(varlist)'"
tempname S T
file open `S' using "tmp/short.tsv", read text
file open `T' using "tmp/short_h.tsv", write text replace
local hdr ""
foreach v of local vl {
    local hdr `"`hdr'`v'`=char(9)'"'
}
local hdr = substr(`"`hdr'"', 1, strlen(`"`hdr'"')-1)
file write `T' `"`hdr'"' _n
file read `S' l
while r(eof) == 0 {
    file write `T' `"`macval(l)'"' _n
    file read `S' l
}
file close `S'
file close `T'
restore
capture noisily _mm_renderhtml using "tmp/short_h.tsv", saving(tmp/short.html) replace
chk "a journal without the five v2 additions still renders" `=_rc' == 0

* ------------------------------- 6 unknown trailing column is tolerated
preserve
quietly import delimited using "../journal_scan.tsv", delimiter(tab) varnames(1) stringcols(_all) clear
quietly generate str3 future = "xyz"
quietly export delimited using "tmp/long.tsv", delimiter(tab) replace
restore
capture noisily _mm_renderhtml using "tmp/long.tsv", saving(tmp/long.html) replace
chk "an unknown trailing column is tolerated" `=_rc' == 0

* ------------------------------------------------- 7 accent validation
capture _mm_renderhtml using "../journal_run.tsv", saving(tmp/bad.html) accent(zzz) replace
chk "accent() rejects a non-hex value" `=_rc' == 198
capture _mm_renderhtml using "../journal_run.tsv", saving(tmp/bad.html) layout(sideways) replace
chk "layout() rejects an unknown value" `=_rc' == 198

* ------------------------------------------------- 8 replace protection
capture _mm_renderhtml using "../journal_run.tsv", saving(tmp/noreplace.html)
capture _mm_renderhtml using "../journal_run.tsv", saving(tmp/noreplace.html)
chk "a second write without replace is refused" `=_rc' == 602

* ------------------------------------------------- 9 embed shape
_mm_renderhtml using "../journal_run.tsv", saving(tmp/frag.html) embed idprefix(mm-z) replace
cnt tmp/frag.html <!DOCTYPE
chk "embed emits no doctype" r(n) == 0
cnt tmp/frag.html <body
chk "embed emits no body element" r(n) == 0
cnt tmp/frag.html <svg
chk "embed emits exactly one svg" r(n) == 1
cnt tmp/frag.html viewBox
chk "embed svg carries a viewBox" r(n) == 1
cnt tmp/frag.html class="mm-embed
chk "embed wraps the diagram in .mm-embed" r(n) == 1

* ------------------------------------------------- 10 no globals left behind
quietly macro list
capture confirm existence $RH_ACC
chk "no RH_ globals survive the call" "$RH_ACC" == ""
chk "no line-stack globals survive the call" "$MMBL1" == ""

* leave tmp/ behind only when something failed, so it can be inspected
if $NF == 0 {
    local junk : dir "tmp" files "*"
    foreach f of local junk {
        capture erase "tmp/`f'"
    }
    capture rmdir "tmp"
}

display ""
display as text "tests.do: " as result "$NF" as text " failure(s)"
if $NF > 0 exit 9
