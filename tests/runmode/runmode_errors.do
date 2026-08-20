* runmode_errors.do -- the run-mode tests that are SUPPOSED to fail.
*
* Run from tests/runmode/:  /usr/local/bin/stata-mp -b do runmode_errors.do
* Success check: no line containing "FAIL".  Unlike the other two test
* do-files, this log DOES contain r(601) and r(9) lines: they are the whole
* point.  A pipeline that dies half way through must leave a usable journal,
* a stop() breach must return nonzero, and a failing assert() must fail
* exactly as it would without instrumentation.

clear all
set more off
adopath + "../../src"
global NPASS = 0
global NFAIL = 0
capture confirm file "fxdata/master.dta"
if _rc do makefx.do
tempname fh

* =====================================================================
display as txt _newline "==== B. an error mid-pipeline leaves a usable journal ===="
* =====================================================================
capture erase jB.tsv
capture noisily _mm_run fx_err.do, out("jB.tsv") noreceipt noledger
local errrc = _rc
display as txt "run of the failing fixture returned rc = `errrc'"
local c = (`errrc' != 0)
mmok `c' "a failing pipeline makes mergemap run exit nonzero"

capture confirm file "jB.tsv"
local c = (_rc == 0)
mmok `c' "the journal still exists after the failure"

file open `fh' using "jB.tsv", read text
file read `fh' line
local nrow = 0
local sawstop = 0
local sawsave = 0
file read `fh' line
while r(eof) == 0 {
    local ++nrow
    if strpos(`"`line'"', "pipeline stopped here") local sawstop = 1
    if strpos(`"`line'"', "out_err1.dta") local sawsave = 1
    file read `fh' line
}
file close `fh'
display as txt "partial journal has `nrow' rows"
local c = (`nrow' >= 4)
mmok `c' "the partial journal holds the events before the failure"
local c = (`sawsave' == 1)
mmok `c' "the save that ran before the failure is in the journal"
local c = (`sawstop' == 1)
mmok `c' "the failing event is recorded, marked as where the run stopped"
capture confirm file "fxdata/out_err2.dta"
local c = (_rc != 0)
mmok `c' "nothing after the failure was executed"


* =====================================================================
display as txt _newline "==== B. stop() thresholds gate the run ===="
* =====================================================================
capture erase jG.tsv
capture noisily _mm_run fx_build.do, out("jG.tsv") noreceipt noledger stop(0.01)
local rcs = _rc
display as txt "stop(0.01) returned rc = `rcs'"
local c = (`rcs' == 9)
mmok `c' "a stop() breach makes mergemap run exit nonzero"
jfield jG.tsv 2 29
display as txt "severity with stop(0.01) = $JF"
local c = ("$JF" == "stop")
mmok `c' "the breaching event is marked stop"


* =====================================================================
display as txt _newline "==== C. assert() still fails exactly as it would plainly ===="
* =====================================================================
global MM_R_NOLED "noledger"
global MM_R_JRN ""
set sortseed 31415
use fxdata/master.dta, clear
capture merge 1:1 id using fxdata/lookup.dta, assert(1 3) nogenerate
local rcplain = _rc
set sortseed 31415
use fxdata/master.dta, clear
capture _mm_merge #9:1# 1:1 id using fxdata/lookup.dta, assert(1 3) nogenerate
local rcwrap = _rc
display as txt "assert() rc plain = `rcplain', wrapped = `rcwrap'"
local c = (`rcplain' == `rcwrap' & `rcplain' != 0)
mmok `c' "a failing assert() returns the same nonzero rc through the wrapper"

* =====================================================================
display as txt _newline "==== runmode_errors.do: $NPASS passed, $NFAIL failed ===="
if $NFAIL > 0 {
    display as err "FAIL: $NFAIL run-mode error check(s) failed"
}
