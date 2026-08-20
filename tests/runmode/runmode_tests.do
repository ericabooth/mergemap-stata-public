* runmode_tests.do -- everything about mergemap run except the transparency
* regression, which lives in transparency.do.
*
* Run from tests/runmode/:  /usr/local/bin/stata-mp -b do runmode_tests.do
* Success check: the log must contain no line starting with r(#  and no line
* containing "FAIL".

clear all
set more off
adopath + "../../src"
global NPASS = 0
global NFAIL = 0

capture confirm file "fxdata/master.dta"
if _rc do makefx.do

* =====================================================================
display as txt _newline "==== A. journal schema (v2, 34 columns) ===="
* =====================================================================
capture erase jA.tsv
capture noisily _mm_run fx_build.do, out("jA.tsv") noreceipt noledger
local c = (_rc == 0)
mmok `c' "mergemap run on fx_build.do returned rc 0"

tempname fh
file open `fh' using "jA.tsv", read text
file read `fh' hdr
file close `fh'
local T = char(9)
local want "seq`T'dofile`T'line`T'class`T'cmd`T'subtype`T'keys`T'master`T'usingfile`T'result`T'n_in`T'k_in`T'n_using`T'k_using`T'n_out`T'k_out`T'm1`T'm2`T'm3`T'm4`T'm5`T'dup_master`T'dup_using`T'force`T'opts`T'loop_n`T'loop_first`T'loop_last`T'severity`T'keytypes`T'cover_master`T'cover_using`T'lifecycle`T'flags"
local c = (`"`hdr'"' == `"`want'"')
mmok `c' "journal header matches the v2 contract exactly"

* every data line must have 34 fields
file open `fh' using "jA.tsv", read text
file read `fh' line
local bad = 0
local nrow = 0
file read `fh' line
while r(eof) == 0 {
    local n = 1
    local s `"`line'"'
    while strpos(`"`s'"', "`T'") {
        local ++n
        local s = substr(`"`s'"', strpos(`"`s'"', "`T'") + 1, .)
    }
    if `n' != 34 local ++bad
    local ++nrow
    file read `fh' line
}
file close `fh'
display as txt "`nrow' journal rows checked"
local c = (`bad' == 0 & `nrow' > 0)
mmok `c' "every journal row carries exactly 34 tab-separated fields"

* =====================================================================
display as txt _newline "==== C. run mode with a user log already open ===="
* =====================================================================
capture log close _all
capture erase userlog.log
log using userlog.log, replace text
display as txt "user log is open: this line must reach it"
capture erase jC.tsv
capture noisily _mm_run fx_build.do, out("jC.tsv") noreceipt
local c = (_rc == 0)
mmok `c' "mergemap run works with a user log already open"
local c = ("`c(logtype)'" != "")
mmok `c' "the user's log is still open afterwards"
* a second, named log on top of it -- the texdoc/webdoc shape
log using userlog2.log, replace text name(second)
capture noisily _mm_run fx_build.do, out("jC2.tsv") noreceipt noledger
local c = (_rc == 0)
mmok `c' "mergemap run works with two logs open (the texdoc/webdoc shape)"
capture log close second
log close
capture erase userlog2.log

tempname lh
file open `lh' using "userlog.log", read text
local sawline = 0
file read `lh' line
while r(eof) == 0 {
    if strpos(`"`line'"', "this line must reach it") local sawline = 1
    file read `lh' line
}
file close `lh'
local c = (`sawline' == 1)
mmok `c' "the user's own log captured its own output"
capture erase userlog.log

* =====================================================================
display as txt _newline "==== D. the merge wrapper is option-for-option faithful ===="
* =====================================================================
* Each variant is run plainly and through _mm_merge, then compared with
* datasignature and cf _all.  The sort seed is pinned before each half:
* Stata's sort is not stable, so without it even two plain runs can differ.
global MM_R_NOLED "noledger"
foreach v in "nogenerate" "keep(1 3) nogenerate" "keep(3) nogenerate" ///
    "generate(mflag)" "keep(match master) nogenerate" ///
    "keepusing(rep78) nogenerate" "assert(1 2 3) nogenerate" {
    mmcmp "`v'"
    local c = ("$SIGA" == "$SIGB" & $CFRC == 0)
    mmok `c' "merge wrapper is faithful for: `v'"
}
capture erase cmpA.dta

* generate() must leave the user's variable, nogenerate must leave none
set sortseed 31415
use fxdata/master.dta, clear
_mm_merge #9:1# 1:1 id using fxdata/lookup.dta, generate(mflag)
capture confirm variable mflag
local c = (_rc == 0)
mmok `c' "generate(mflag) leaves mflag behind"
capture confirm variable _mm_merge_tmp
local c = (_rc != 0)
mmok `c' "the wrapper's scratch indicator never survives"
qui levelsof mflag, local(lv)
local c = (`"`lv'"' != "")
mmok `c' "mflag carries the merge categories"

use fxdata/master.dta, clear
_mm_merge #9:1# 1:1 id using fxdata/lookup.dta, nogenerate
capture confirm variable _merge
local c = (_rc != 0)
mmok `c' "nogenerate leaves no indicator variable"

* the r(110) clash that generate(_mm_merge_tmp) would otherwise hide
use fxdata/master.dta, clear
quietly gen byte _merge = 1
capture noisily _mm_merge #9:1# 1:1 id using fxdata/lookup.dta
local c = (_rc == 110)
mmok `c' "an existing _merge still stops the merge with r(110)"

* =====================================================================
display as txt _newline "==== E. diagnostics ===="
* =====================================================================
capture erase jE.tsv
global MM_R_NOLED ""
capture noisily _mm_run fx_build.do, out("jE.tsv") noreceipt examples(3)
local c = (_rc == 0)
mmok `c' "examples(3) runs"

* read the first merge row out of the journal
jfield jE.tsv 2 30
display as txt "keytypes on the first merge: $JF"
local c = (strpos("$JF", "id:") == 1)
mmok `c' "keytypes reports the key storage type on both sides"
jfield jE.tsv 2 31
display as txt "cover_master = $JF"
local c = ("$JF" != "." & "$JF" != "")
mmok `c' "cover_master is filled in run mode"
jfield jE.tsv 2 32
local c = ("$JF" != "." & "$JF" != "")
mmok `c' "cover_using is filled in run mode"
jfield jE.tsv 2 22
display as txt "dup_master = $JF"
local c = ("$JF" == "0")
mmok `c' "dup_master is 0 on a unique key"

* nochecks leaves the frame-based numbers missing but still runs
capture erase jF.tsv
capture noisily _mm_run fx_build.do, out("jF.tsv") noreceipt noledger nochecks
local c = (_rc == 0)
mmok `c' "nochecks runs"
jfield jF.tsv 2 22
local c = ("$JF" == ".")
mmok `c' "nochecks leaves dup_master missing rather than guessing"
jfield jF.tsv 2 30
local c = (strpos("$JF", "id:") == 1)
mmok `c' "nochecks still reports key storage types (one observation is enough)"

* key type drift is detected and flagged
set sortseed 31415
use fxdata/master.dta, clear
quietly gen str6 idstr = string(id, "%06.0f")
global MM_R_JRN ""
capture noisily _mm_merge #9:1# 1:1 idstr using fxdata/drift.dta, nogenerate
local c = (_rc == 0)
mmok `c' "a merge on a str key runs through the wrapper"

* =====================================================================
display as txt _newline "==== F. thresholds that are not breached ===="
* =====================================================================
capture erase jH.tsv
capture noisily _mm_run fx_build.do, out("jH.tsv") noreceipt noledger warn(0.99) stop(0.999)
local c = (_rc == 0)
mmok `c' "thresholds that are not breached leave the run clean"
jfield jH.tsv 2 29
local c = ("$JF" == "note")
mmok `c' "an unbreached event is marked note"

* =====================================================================
display as txt _newline "==== G. #delimit ; regions are left alone ===="
* =====================================================================
capture erase jI.tsv
capture noisily _mm_run fx_delimit.do, out("jI.tsv") noreceipt noledger
local c = (_rc == 0)
mmok `c' "a do-file with a #delimit ; region still runs"
file open `fh' using "jI.tsv", read text
file read `fh' line
local sawmerge = 0
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`line'"', "merge") local sawmerge = 1
    file read `fh' line
}
file close `fh'
local c = (`sawmerge' == 0)
mmok `c' "the merge inside the #delimit ; region was not instrumented"
capture confirm file "fxdata/out_delimit.dta"
local c = (_rc == 0)
mmok `c' "the #delimit ; region still executed and saved its output"

* =====================================================================
display as txt _newline "==== H. recursion into do/run, and line numbers ===="
* =====================================================================
capture erase jJ.tsv
capture noisily _mm_run fx_master.do, out("jJ.tsv") noreceipt noledger
local c = (_rc == 0)
mmok `c' "a master do-file that calls a child runs"
file open `fh' using "jJ.tsv", read text
file read `fh' line
local sawchild = 0
local sawkeep = 0
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`line'"', "fx_child.do") local sawchild = 1
    if strpos(`"`line'"', "mpg >= 15")   local sawkeep = 1
    file read `fh' line
}
file close `fh'
local c = (`sawchild' == 1)
mmok `c' "the child do-file's events are journalled under its own name"
local c = (`sawkeep' == 1)
mmok `c' "a keep if inside the child is recorded as a filter event"

* the instrumented copy must have exactly as many lines as the original
capture erase jK.tsv
capture noisily _mm_run fx_build.do, out("jK.tsv") noreceipt noledger debug
local tmpdir `"`r(tmpdir)'"'
display as txt "instrumented copies in: `tmpdir'"
local norig = 0
file open `fh' using "fx_build.do", read text
file read `fh' line
while r(eof) == 0 {
    local ++norig
    file read `fh' line
}
file close `fh'
local ncopy = 0
capture file open `fh' using "`tmpdir'/1/fx_build.do", read text
if !_rc {
    file read `fh' line
    while r(eof) == 0 {
        local ++ncopy
        file read `fh' line
    }
    file close `fh'
}
display as txt "original `norig' lines, instrumented copy `ncopy' lines"
local c = (`norig' == `ncopy' & `norig' > 0)
mmok `c' "the instrumented copy has exactly the same number of lines"

* =====================================================================
display as txt _newline "==== I. clear all in the middle of a pipeline ===="
* =====================================================================
capture erase jM.tsv
capture noisily _mm_run fx_clear.do, out("jM.tsv") noreceipt noledger
local c = (_rc == 0)
mmok `c' "a pipeline that runs clear all half way through still runs"
file open `fh' using "jM.tsv", read text
file read `fh' line
local nrow = 0
local sawafter = 0
file read `fh' line
while r(eof) == 0 {
    local ++nrow
    if strpos(`"`line'"', "out_clear2.dta") local sawafter = 1
    file read `fh' line
}
file close `fh'
display as txt "journal rows across the clear all: `nrow'"
local c = (`sawafter' == 1)
mmok `c' "events after the clear all are still journalled"
local c = (`nrow' >= 6)
mmok `c' "both halves of the pipeline are in one journal"

* =====================================================================
display as txt _newline "==== J. warn() as a count, not only a fraction ===="
* =====================================================================
capture erase jN.tsv
capture noisily _mm_run fx_build.do, out("jN.tsv") noreceipt noledger warn(5)
local c = (_rc == 0)
mmok `c' "warn() given as a count runs"
jfield jN.tsv 2 29
display as txt "severity with warn(5) = $JF"
local c = ("$JF" == "warn")
mmok `c' "a count threshold marks the event warn"
capture erase jO.tsv
capture noisily _mm_run fx_build.do, out("jO.tsv") noreceipt noledger warn(100000)
jfield jO.tsv 2 29
local c = ("$JF" == "note")
mmok `c' "a count threshold above the unmatched count leaves it a note"

* =====================================================================
display as txt _newline "==== K. prefix chains and run (not do) ===="
* =====================================================================
capture erase jP.tsv
capture noisily _mm_run fx_prefix.do, out("jP.tsv") noreceipt noledger
local c = (_rc == 0)
mmok `c' "a do-file with capture noisily / quietly prefixes runs"
file open `fh' using "jP.tsv", read text
file read `fh' line
local nmerge = 0
local sawrun = 0
local sawkid = 0
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`line'"', char(9) + "merge" + char(9)) local ++nmerge
    if strpos(`"`line'"', char(9) + "run" + char(9))   local sawrun = 1
    if strpos(`"`line'"', "fx_child2.do")              local sawkid = 1
    file read `fh' line
}
file close `fh'
display as txt "merges journalled behind prefixes: `nmerge'"
local c = (`nmerge' == 2)
mmok `c' "both prefixed merges were instrumented"
local c = (`sawrun' == 1)
mmok `c' "run is journalled as run, not as do"
local c = (`sawkid' == 1)
mmok `c' "the child reached through run was followed"

* the prefix itself must survive into the instrumented copy
capture erase jQ.tsv
capture noisily _mm_run fx_prefix.do, out("jQ.tsv") noreceipt noledger debug
local tmpdir `"`r(tmpdir)'"'
local sawprefix = 0
capture file open `fh' using "`tmpdir'/1/fx_prefix.do", read text
if !_rc {
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "capture noisily _mm_merge") local sawprefix = 1
        file read `fh' line
    }
    file close `fh'
}
local c = (`sawprefix' == 1)
mmok `c' "capture noisily merge became capture noisily _mm_merge, in place"

* =====================================================================
display as txt _newline "==== L. returns ===="
* =====================================================================
capture erase jL.tsv
capture noisily _mm_run fx_build.do, out("jL.tsv") noreceipt noledger
local c = (`"`r(journal)'"' == "jL.tsv")
mmok `c' "r(journal) names the journal"
local c = (r(N_events) > 0)
mmok `c' "r(N_events) is set"
local c = (r(N_joins) > 0)
mmok `c' "r(N_joins) is set"
local c = (r(N_flags) < .)
mmok `c' "r(N_flags) is set"
local c = (r(N_stop) < .)
mmok `c' "r(N_stop) is set"

* =====================================================================
display as txt _newline "==== runmode_tests.do: $NPASS passed, $NFAIL failed ===="
if $NFAIL > 0 {
    display as err "FAIL: $NFAIL run-mode check(s) failed"
}

* ---- tidy the scratch journals this file wrote --------------------------
foreach j in jA jC jC2 jE jF jH jI jJ jK jL jM jN jO jP jQ {
    capture erase `j'.tsv
}
capture erase cmpA.dta
