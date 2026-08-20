* transparency.do -- the run-mode transparency regression.
*
* Run from tests/runmode/:  /usr/local/bin/stata-mp -b do transparency.do
* Success check: the log must contain no line starting with r(#  and no line
* containing "FAIL".
*
* The claim run mode has to earn is that instrumentation changes nothing.
* So the test pipeline is executed twice in one session -- once plainly,
* once under mergemap run -- and every dataset it saves is compared with
* datasignature and cf _all.  The sort flag is compared too, because it is
* stored in the .dta and neither datasignature nor cf looks at it: merge
* sets it when the merge is 1:1 and no using-only rows survive, and applying
* keep() after the fact would otherwise silently clear it.
*
* Line numbers are checked against the scanner's own reading of the original
* files: every (dofile, line, command) the run journal reports must exist in
* the scan journal, which is built from the untouched sources.

clear all
set more off
adopath + "../../src"

global NPASS = 0
global NFAIL = 0

capture mkdir base

* ---- make sure the raw inputs exist --------------------------------------
capture confirm file "../raw/cps_2019.dta"
if _rc {
    display as txt "building ../raw from maketestdata.do"
    cd ..
    capture mkdir raw
    capture mkdir out
    do maketestdata.do
    cd runmode
}

* ---- which files does the pipeline save?  ask the scanner ---------------
cd ../pipeline
quietly mergemap scan 00_master.do, out("../runmode/scan.tsv") noreceipt
cd ../runmode

tempname sh
file open `sh' using "scan.tsv", read text
file read `sh' line
local T = char(9)
local outs ""
file read `sh' line
while r(eof) == 0 {
    local line : subinstr local line "\`" "`=char(1)'", all
    local line : subinstr local line "\$" "`=char(2)'", all
    local line : subinstr local line "'" "`=char(3)'", all
    local s `"`line'"'
    local nc = 0
    local vcls ""
    local vres ""
    while 1 {
        local q = strpos(`"`s'"', "`T'")
        local ++nc
        if `q' {
            local f = substr(`"`s'"', 1, `q' - 1)
            local s = substr(`"`s'"', `q' + 1, .)
        }
        else local f `"`s'"'
        if `nc' == 4  local vcls `"`f'"'
        if `nc' == 10 local vres `"`f'"'
        if !`q' continue, break
    }
    if "`vcls'" == "save" {
        local skip = 0
        if `"`vres'"' == "." local skip = 1
        if strpos(`"`vres'"', "tempfile:") == 1 local skip = 1
        if strpos(`"`vres'"', char(1)) local skip = 1
        if strpos(`"`vres'"', char(2)) local skip = 1
        if !`skip' local outs `"`outs' `vres'"'
    }
    file read `sh' line
}
file close `sh'
local outs = strtrim(`"`outs'"')
display as txt "pipeline outputs: `outs'"
local c = (`"`outs'"' != "")
mmok `c' "the scanner found at least one saved output"

* ---- 1. the plain run ----------------------------------------------------
* The sort seed is fixed before each run.  Stata's sort is not stable, ties
* are broken from that seed, and this pipeline merges m:1 on a key with
* duplicate master values -- so without a fixed seed even two PLAIN runs of
* 01_build.do give different row orders and, after collapse(mean), different
* datasignatures (measured: three plain runs, three signatures).  That is a
* property of Stata's sort, not of instrumentation, and pinning the seed is
* what makes "identical" a testable claim at all.
display as txt _newline "==== plain run ===="
cd ../pipeline
set sortseed 20260820
do 00_master.do
cd ../runmode

local sigs ""
local sbs  ""
local j = 0
foreach o of local outs {
    local ++j
    local src "../pipeline/`o'"
    quietly use "`src'", clear
    quietly datasignature
    local sig`j' = r(datasignature)
    local sb`j' : sortedby
    local b = subinstr("`o'", "/", "_", .)
    local b = subinstr("`b'", "..", "", .)
    local base`j' "base/`b'"
    quietly save "base/`b'", replace
    display as txt "  baseline `o' -> base/`b'  [`sig`j''] sortedby(`sb`j'')"
}
local nout = `j'

* ---- 2. the instrumented run --------------------------------------------
display as txt _newline "==== instrumented run ===="
cd ../pipeline
set sortseed 20260820
capture noisily _mm_run 00_master.do, out("../runmode/run.tsv") noreceipt noledger
local runrc = _rc
cd ../runmode
display as txt "mergemap run returned rc = `runrc'"
local c = (`runrc' == 0 | `runrc' == 9)
mmok `c' "mergemap run finished (rc 9 = stop threshold breached, by design)"

* ---- 3. compare every saved dataset -------------------------------------
display as txt _newline "==== transparency comparison ===="
local j = 0
foreach o of local outs {
    local ++j
    local src "../pipeline/`o'"
    quietly use "`src'", clear
    quietly datasignature
    local nsig = r(datasignature)
    local nsb : sortedby
    local c = ("`nsig'" == "`sig`j''")
    mmok `c' "datasignature identical for `o'"
    local c = ("`nsb'" == "`nsb'")
    local c = ("`nsb'" == "`sb`j''")
    mmok `c' "sort flag identical for `o' [`sb`j'' vs `nsb']"
    capture noisily cf _all using "`base`j''", verbose
    local c = (_rc == 0)
    mmok `c' "cf _all clean for `o'"
}

* ---- 4. line numbers in the journal match the original files -------------
display as txt _newline "==== line-number fidelity ===="
quietly {
    tempname rh
    file open `rh' using "scan.tsv", read text
    file read `rh' line
    local scanset ""
    file read `rh' line
    while r(eof) == 0 {
        local line : subinstr local line "\`" "`=char(1)'", all
        local line : subinstr local line "\$" "`=char(2)'", all
        local line : subinstr local line "'" "`=char(3)'", all
        local s `"`line'"'
        local nc = 0
        while 1 {
            local q = strpos(`"`s'"', "`T'")
            local ++nc
            if `q' {
                local f = substr(`"`s'"', 1, `q' - 1)
                local s = substr(`"`s'"', `q' + 1, .)
            }
            else local f `"`s'"'
            if `nc' == 2 local vdof `"`f'"'
            if `nc' == 3 local vlin `"`f'"'
            if `nc' == 5 local vcmd `"`f'"'
            if !`q' continue, break
        }
        local scanset `"`scanset' |`vdof':`vlin':`vcmd'|"'
        file read `rh' line
    }
    file close `rh'

    file open `rh' using "run.tsv", read text
    file read `rh' line
    local bad = 0
    local nchk = 0
    file read `rh' line
    while r(eof) == 0 {
        local line : subinstr local line "\`" "`=char(1)'", all
        local line : subinstr local line "\$" "`=char(2)'", all
        local line : subinstr local line "'" "`=char(3)'", all
        local s `"`line'"'
        local nc = 0
        while 1 {
            local q = strpos(`"`s'"', "`T'")
            local ++nc
            if `q' {
                local f = substr(`"`s'"', 1, `q' - 1)
                local s = substr(`"`s'"', `q' + 1, .)
            }
            else local f `"`s'"'
            if `nc' == 2 local vdof `"`f'"'
            if `nc' == 3 local vlin `"`f'"'
            if `nc' == 5 local vcmd `"`f'"'
            if !`q' continue, break
        }
        local ++nchk
        if !strpos(`"`scanset'"', `"|`vdof':`vlin':`vcmd'|"') {
            local bad = `bad' + 1
            noisily display as err "  unmatched journal row: `vdof' line `vlin' `vcmd'"
        }
        file read `rh' line
    }
    file close `rh'
}
display as txt "checked `nchk' run-journal rows against the scan journal"
local c = (`bad' == 0)
mmok `c' "every run-journal (dofile, line, command) exists in the scan journal"

* ---- summary -------------------------------------------------------------
display as txt _newline "==== transparency.do: $NPASS passed, $NFAIL failed ===="
if $NFAIL > 0 {
    display as err "FAIL: $NFAIL transparency check(s) failed"
}
