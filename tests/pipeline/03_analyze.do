* 03_analyze.do -- assemble the analysis file. Run via 00_master.do from
* tests/pipeline/ (needs global MM_VISITS published by 02_panel.do).
if `"$MM_VISITS"' == "" {
    display as error "global MM_VISITS is not set -- run 00_master.do"
    error 459
}
use "$MM_VISITS", clear

* ---- attach the wide county panel ----------------------------------------


merge m:1 county using ../out/county_wide.dta, keep(1 3) nogenerate

* ---- fan visits out across staff assignments (true many-to-many) ---------
* unmatched(none): rows whose staff has no assignment are dropped


joinby staff using ../raw/staff_assign.dta, unmatched(none)

* ---- apply corrections -----------------------------------------------------
* The sample journal shows 1:1 here, but the joinby above duplicates
* (pid, visitid) in the master, so m:1 against the unique corrections
* file is the form that runs; update replace semantics match per row.
merge m:1 pid visitid using ../raw/corrections.dta, update replace
drop _merge
capture frame drop counties
frame create counties
frame counties: use ../raw/counties_frame.dta
frlink m:1 county, frame(counties) generate(cnty)
frget povrate slots, from(cnty)

* ---- restrict to first-half visits -----------------------------------------
* A row filter, recorded as its own event: without it the row count change
* here would look like something the joins did.

keep if date <= mdy(6, 30, 2024)

* ---- staff schedules: m:m + force ------------------------------------------
* Duplicate staff keys on both sides: m:m pairs rows by order within
* staff (not a join). schednote is str8 in schedules vs byte in the
* master, hence force.
merge m:m staff using ../raw/schedules.dta, force
drop _merge


save ../out/analysis_file.dta, replace
