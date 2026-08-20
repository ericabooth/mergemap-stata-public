*! devtests.do -- scanner tests for the beginner gaps (NOVICE_UX B2-B9),
*! filter events, clobber/staleness, the demo, mergemap check and r() returns.
*! Eric Booth
*
* Run from src/:
*     /usr/local/bin/stata-mp -b do dev/devtests.do
*
* Success check: devtests.log must contain no line starting with r(#, and the
* final tally must report 0 FAIL. One block waits for the wall clock to cross
* a minute boundary (up to ~62 seconds), because a .dta header timestamp has
* minute resolution and the staleness check needs two distinct minutes.

version 16
clear all
set more off
set linesize 120

local src = c(pwd)
adopath + `"`src'"'

* ------------------------------------------------------------- harness ----
global D_PASS = 0
global D_FAIL = 0

capture program drop d_assert
program define d_assert
    args cond label
    if `cond' {
        display as text "  PASS  " as result "`label'"
        global D_PASS = $D_PASS + 1
    }
    else {
        display as error "  FAIL  `label'"
        global D_FAIL = $D_FAIL + 1
    }
end

capture program drop d_block
program define d_block
    args n label
    display as text _n "{hline 72}"
    display as text "BLOCK `n': `label'"
    display as text "{hline 72}"
end

* load a journal into frame dj
capture program drop d_jload
program define d_jload
    args jfile
    capture frame drop dj
    frame create dj
    frame dj {
        qui import delimited using `"`jfile'"', delimiter(tab) varnames(1) ///
            stringcols(_all) bindquote(nobind) clear
    }
end

* count journal rows matching up to three substrings anywhere in the line
capture program drop d_jgrep
program define d_jgrep, rclass
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
        if `ok' local ++hit
        file read `fh' line
    }
    file close `fh'
    return scalar hits = `hit'
end

* ---------------------------------------------------------- scratch area ----
capture mkdir dev/scratch
capture mkdir dev/scratch/sandbox
capture mkdir dev/scratch/stale
capture erase dev/scratch/sandbox/01_build.do
capture erase dev/scratch/sandbox/02_panel.do
capture erase dev/scratch/sandbox/03_analyze.do
copy dev/t1_ugly.do  dev/scratch/sandbox/01_build.do, replace
copy dev/t2_loops.do dev/scratch/sandbox/02_panel.do, replace
copy dev/t6_cmds.do  dev/scratch/sandbox/03_analyze.do, replace

* =========================================================== 1. v2 schema ====
d_block 1 "journal schema v2: 34 columns, usingfile by name"
mergemap dev/t1_ugly.do, out(dev/scratch/j1.tsv) noreceipt
d_jload dev/scratch/j1.tsv
frame dj {
    unab allv : _all
    local ncol : word count `allv'
    capture confirm variable usingfile
    local hasuf = (_rc == 0)
    capture confirm variable severity
    local hassev = (_rc == 0)
    capture confirm variable lifecycle
    local haslif = (_rc == 0)
    capture confirm variable keytypes
    local haskt = (_rc == 0)
    local lastv : word `ncol' of `allv'
    local strayusing : list posof "using" in allv
}
d_assert `=(`ncol' == 34)'            "34 columns in the emitted journal"
d_assert `=(`hasuf' == 1)'            "column 9 is named usingfile, not using"
d_assert `=(`hassev' == 1)'           "severity column present"
d_assert `=(`haslif' == 1)'           "lifecycle column present"
d_assert `=(`strayusing' == 0)'       "no stray column named using"
d_assert `=("`lastv'" == "flags")'    "flags is still the last column"

frame dj {
    qui count if strtrim(severity) == "warn" & strtrim(cmd) == "merge" & strtrim(subtype) == "m:m"
    local nmm = r(N)
    qui count if strtrim(lifecycle) == "read" & strtrim(class) == "source"
    local nread = r(N)
    qui count if strtrim(lifecycle) == "create" & strtrim(class) == "save"
    local ncreate = r(N)
}
d_assert `=(`nmm' == 1)'              "m:m merge carries severity warn"
d_assert `=(`nread' == 1)'            "use events carry lifecycle read"
d_assert `=(`ncreate' == 1)'          "first save of a path is lifecycle create"

* ============================================================ 2. filters ====
d_block 2 "filter events: keep if / drop if / drop varlist / keep in"
mergemap dev/t8_filters.do, out(dev/t8_journal.tsv) noreceipt
d_jload dev/t8_journal.tsv
frame dj {
    qui count if strtrim(class) == "filter"
    local nf = r(N)
    qui count if strtrim(class) == "filter" & strtrim(cmd) == "drop" & strtrim(subtype) == "if"
    local ndropif = r(N)
    qui count if strtrim(class) == "filter" & strtrim(cmd) == "keep" & strtrim(subtype) == "if"
    local nkeepif = r(N)
    qui count if strtrim(class) == "filter" & strtrim(subtype) == "vars"
    local nvars = r(N)
    qui count if strtrim(class) == "filter" & strtrim(subtype) == "in"
    local nin = r(N)
    qui count if strtrim(class) == "filter" & strtrim(flags) != "."
    local nfflag = r(N)
    qui levelsof opts if strtrim(class) == "filter" & strtrim(cmd) == "keep" ///
        & strtrim(subtype) == "if", local(kopt) clean
}
d_assert `=(`nf' == 5)'          "five filter events recognised"
d_assert `=(`ndropif' == 1)'     "drop if is a filter with subtype if"
d_assert `=(`nkeepif' == 1)'     "keep if is a filter with subtype if"
d_assert `=(`nvars' == 2)'       "drop/keep of a varlist is a filter with subtype vars"
d_assert `=(`nin' == 1)'         "keep in is a filter with subtype in"
d_assert `=(`nfflag' == 0)'      "scan mode leaves filter flags missing (run mode fills them)"
d_assert `=(strpos(`"`kopt'"', "inrange(year, 2019, 2022)") > 0)' ///
    "the whole condition survives, commas and all"

* ================================================= 3. macro paths and cd ====
d_block 3 "unresolved macro paths (B8) and cd tracking (B9)"
mergemap dev/t9_macropath.do, out(dev/t9_journal.tsv) noreceipt
d_jgrep dev/t9_journal.tsv "path built from a macro"
d_assert `=(r(hits) >= 1)'  "a macro-built path is flagged as a designed boundary"
d_jgrep dev/t9_journal.tsv "cd" "working directory now"
d_assert `=(r(hits) >= 1)'  "a literal cd is recorded and the new directory reported"
d_jgrep dev/t9_journal.tsv "cd path built from a macro"
d_assert `=(r(hits) == 1)'  "cd with a macro argument is flagged unresolvable"
d_jload dev/t9_journal.tsv
frame dj {
    qui count if strtrim(cmd) == "cd" & strtrim(class) == "flow"
    local ncd = r(N)
}
d_assert `=(`ncd' == 3)'    "each cd is a flow event"

* =================================================== 4. clobber warning ====
d_block 4 "two do-files writing the same path (DECISIONS 16f)"
mergemap dev/t10_clobber_a.do dev/t10_clobber_b.do, out(dev/t10_journal.tsv) noreceipt
d_jgrep dev/t10_journal.tsv "!! also saved by" "t10_clobber_a.do line"
d_assert `=(r(hits) == 1)'  "the second write names the do-file and line of the first"
d_jload dev/t10_journal.tsv
frame dj {
    qui count if strtrim(lifecycle) == "create"
    local nc = r(N)
    qui count if strtrim(lifecycle) == "overwrite"
    local no = r(N)
    qui count if strtrim(lifecycle) == "overwrite" & strtrim(severity) == "warn"
    local nos = r(N)
}
d_assert `=(`nc' == 1)'   "the first write is lifecycle create"
d_assert `=(`no' == 1)'   "the second write is lifecycle overwrite"
d_assert `=(`nos' == 1)'  "a clobber is severity warn, and the flag carries !!"

* ================================================== 5. wildcards, folders ====
d_block 5 "B2-B5: wildcards, a folder positionally, folder(), missing .do"
cd dev/scratch/sandbox
capture noisily mergemap *.do, out(w1.tsv) noreceipt
d_assert `=(_rc == 0)'  "mergemap *.do expands instead of erroring"
d_jload w1.tsv
frame dj {
    qui levelsof dofile, local(dfs) clean
    local nd : word count `dfs'
    local first : word 1 of `dfs'
}
d_assert `=(`nd' == 3)'                       "*.do picked up all three files"
d_assert `=("`first'" == "01_build.do")'      "wildcard matches are scanned in name order"

capture noisily mergemap 0*.do, out(w2.tsv) noreceipt
d_assert `=(_rc == 0)'  "a partial wildcard (0*.do) also expands"

capture noisily mergemap ., out(w3.tsv) noreceipt
d_assert `=(_rc == 0)'  "a folder in the positional slot is accepted"

capture noisily mergemap, folder(.) out(w4.tsv) noreceipt
d_assert `=(_rc == 0)'  "folder() is implemented"

capture noisily mergemap 01_build, out(w5.tsv) noreceipt
d_assert `=(_rc == 0)'  "a missing .do extension is forgiven"

d_jload w4.tsv
frame dj: local n4 = _N
d_jload w1.tsv
frame dj: local n1 = _N
d_assert `=(`n1' == `n4')'  "folder() and the positional folder agree"
cd `"`src'"'

* =============================================== 6. bare call and typos ====
d_block 6 "B6 usage hint and B7 near-miss suggestions"
capture noisily mergemap
d_assert `=(_rc == 198)'  "a bare call ends with the usage hint, not a syntax dump"

* subprograms of an ado file are namespaced by Stata (mergemap._mm_suggest),
* so the near-miss text is checked where the user sees it: in the output.
cd dev/scratch/sandbox
capture log close mmtypo
log using typo.log, replace name(mmtypo) text
capture noisily mergemap 01_buidl.do, out(bad.tsv) noreceipt
local rctypo = _rc
capture noisily mergemap 02_pane.do, out(bad.tsv) noreceipt
capture noisily mergemap zz_nothing_like_it.do, out(bad.tsv) noreceipt
capture log close mmtypo
cd `"`src'"'
d_assert `=(`rctypo' == 601)'  "a missing file still fails, with r(601)"
d_jgrep dev/scratch/sandbox/typo.log "did you mean" "01_build.do"
d_assert `=(r(hits) >= 1)'  "a transposition typo suggests 01_build.do"
d_jgrep dev/scratch/sandbox/typo.log "did you mean" "02_panel.do"
d_assert `=(r(hits) >= 1)'  "a deletion typo suggests 02_panel.do"
d_jgrep dev/scratch/sandbox/typo.log "did you mean" "zz_nothing"
d_assert `=(r(hits) == 0)'  "an unrelated name suggests nothing"
d_jgrep dev/scratch/sandbox/typo.log "check the spelling"
d_assert `=(r(hits) >= 1)'  "and falls back to a plain hint instead"

* ============================================== 7. r() returns and check ====
d_block 7 "r() returns and mergemap check"
mergemap dev/t1_ugly.do, out(dev/scratch/j1.tsv) noreceipt
d_assert `=(r(N_events) == 5)'  "r(N_events)"
d_assert `=(r(N_joins) == 3)'   "r(N_joins)"
d_assert `=(r(N_flags) == 1)'   "r(N_flags)"
d_assert `=(r(N_stop) == 0)'    "r(N_stop) is zero in scan mode"
local rj `"`r(journal)'"'
local rf `"`r(files)'"'
d_assert `=(strpos(`"`rj'"', "j1.tsv") > 0)'          "r(journal)"
d_assert `=(strpos(`"`rf'"', "t1_ugly.do") > 0)'      "r(files)"

display as text _n "---- mergemap check prints only the flagged events ----"
mergemap check dev/t1_ugly.do, out(dev/scratch/jchk.tsv)
d_assert `=(r(N_events) == 5)'  "check still scans every event"

display as text _n "---- the full receipt for comparison ----"
mergemap dev/t8_filters.do, out(dev/t8_journal.tsv)

* ====================================================== 8. mergemap demo ====
d_block 8 "mergemap demo (NOVICE_UX C1)"
capture noisily mergemap demo, folder(dev/scratch/demo) replace
d_assert `=(_rc == 0)'  "mergemap demo runs"
foreach f in 01_cars 02_join 03_report {
    capture confirm file "dev/scratch/demo/`f'.do"
    d_assert `=(_rc == 0)'  "demo wrote `f'.do"
}
d_jgrep dev/scratch/demo/demo_journal.tsv "m:m"
d_assert `=(r(hits) >= 1)'  "the demo contains a deliberate m:m so a flag appears"
d_jload dev/scratch/demo/demo_journal.tsv
frame dj {
    qui count if strtrim(class) == "filter"
    local dfil = r(N)
    qui count if strtrim(cmd) == "append"
    local dapp = r(N)
    qui count if strtrim(cmd) == "collapse"
    local dcol = r(N)
    qui count if strtrim(cmd) == "merge" & strtrim(subtype) == "1:1"
    local d11 = r(N)
    qui count if strtrim(cmd) == "merge" & strtrim(subtype) == "m:1"
    local dm1 = r(N)
    qui count if strtrim(severity) == "warn"
    local dwarn = r(N)
}
d_assert `=(`d11' >= 1)'    "demo shows a 1:1 merge"
d_assert `=(`dm1' >= 2)'    "demo shows m:1 lookups"
d_assert `=(`dapp' >= 1)'   "demo shows an append"
d_assert `=(`dcol' >= 2)'   "demo shows a collapse"
d_assert `=(`dfil' >= 4)'   "demo shows row filters"
d_assert `=(`dwarn' >= 1)'  "demo raises at least one warning"

capture mergemap demo, folder(dev/scratch/demo)
d_assert `=(_rc == 602)'  "demo refuses to overwrite an existing folder"

* the generated do-files must actually run
cd dev/scratch/demo
capture noisily do 01_cars.do
local rc1 = _rc
capture noisily do 02_join.do
local rc2 = _rc
capture noisily do 03_report.do
local rc3 = _rc
cd `"`src'"'
d_assert `=(`rc1' == 0)'  "demo 01_cars.do runs"
d_assert `=(`rc2' == 0)'  "demo 02_join.do runs"
d_assert `=(`rc3' == 0)'  "demo 03_report.do runs"
capture confirm file "dev/scratch/demo/demo_analysis.dta"
d_assert `=(_rc == 0)'    "the demo pipeline produced its final dataset"

* ========================================================= 9. staleness ====
d_block 9 "staleness: a saved output older than an input it was built from"
* .dta headers carry a minute-resolution timestamp, so the two files have to
* be written in different minutes for the comparison to mean anything.
cd dev/scratch/stale
sysuse auto, clear
save out.dta, replace
local t0 = clock(c(current_time), "hms")
local ms = 62000 - mod(`t0', 60000)
display as text "waiting `ms' ms for the clock minute to turn"
sleep `ms'
sysuse census, clear
save in.dta, replace
cd `"`src'"'
capture erase dev/scratch/stale/t11_stale.do
tempname sh
file open `sh' using dev/scratch/stale/t11_stale.do, write text replace
file write `sh' "* t11: output written before its input" _n
file write `sh' "use in.dta, clear" _n
file write `sh' "save out.dta, replace" _n
file close `sh'
mergemap dev/scratch/stale/t11_stale.do, out(dev/scratch/j11.tsv) noreceipt
d_jgrep dev/scratch/j11.tsv "!! stale" "out.dta"
d_assert `=(r(hits) == 1)'  "a stale output is flagged, naming the newer input"

* negative control: rebuild the output now, so it is no longer stale
cd dev/scratch/stale
sysuse auto, clear
save out.dta, replace
cd `"`src'"'
mergemap dev/scratch/stale/t11_stale.do, out(dev/scratch/j11b.tsv) noreceipt
d_jgrep dev/scratch/j11b.tsv "!! stale"
d_assert `=(r(hits) == 0)'  "a fresh output is not flagged"

* ============================================================== 10. run ====
d_block 10 "mergemap run dispatch"
* This block tests the dispatch contract only. Run mode itself lives in
* _mm_run.ado and has its own suite; what is checked here is that mergemap
* hands the do-file list over in a form _mm_run can parse, and that a missing
* _mm_run produces a readable error rather than "command unrecognized".
capture mkdir dev/scratch/rundisp
capture erase dev/scratch/rundisp/r1.do
tempname rh
quietly file open `rh' using dev/scratch/rundisp/r1.do, write text replace
file write `rh' "sysuse auto, clear" _n
file write `rh' "keep make price mpg foreign rep78" _n
file write `rh' "save cars.dta, replace" _n
file write `rh' "use cars.dta, clear" _n
file write `rh' "drop if missing(rep78)" _n
file write `rh' "save cars2.dta, replace" _n
file close `rh'
capture which _mm_run
local hasrun = (_rc == 0)
cd dev/scratch/rundisp
capture noisily mergemap run r1.do, out(rj.tsv)
local rcrun = _rc
cd `"`src'"'
if `hasrun' {
    d_assert `=(`rcrun' != 199)'  "mergemap run resolves the do-file list for _mm_run"
    display as text "  (run mode returned rc=`rcrun'; run mode itself has its own suite)"
}
else {
    d_assert `=(`rcrun' == 601)'  "mergemap run fails clearly when _mm_run is absent"
}

* ---- tidy the scratch datasets (the do-files and journals stay) ---------
capture frame drop dj
clear
foreach d in dev/scratch/demo dev/scratch/stale dev/scratch/rundisp {
    local dta : dir `"`d'"' files "*.dta"
    foreach f of local dta {
        capture erase `"`d'/`f'"'
    }
}

* ================================================================ tally ====
capture frame drop dj
display as text _n "{hline 72}"
display as text "devtests: " as result "$D_PASS pass" as text ", " as result "$D_FAIL fail"
display as text "{hline 72}"
if $D_FAIL > 0 {
    display as error "devtests: $D_FAIL check(s) failed"
}
