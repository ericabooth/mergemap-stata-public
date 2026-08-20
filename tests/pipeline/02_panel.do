* 02_panel.do -- participants + visits, then reshape the county panel wide.
* Run via 00_master.do from tests/pipeline/. Reads ../raw/ and ../out/.
* Hand-off to 03_analyze.do: the visit-level file is saved to the tempfile
* path in global MM_VISITS, declared by 00_master.do. The master declares
* it because Stata deletes a tempfile when the do-file that DECLARED it
* ends (verified: one declared here vanished before 03 ran); one declared
* by the master survives the whole pipeline.
use ../raw/participants.dta, clear

* a few pids were entered twice; keep the first occurrence
duplicates drop pid, force

* attach visits (1:m fan-out), then park the result at the tempfile path
merge 1:m pid using ../raw/visits.dta
drop _merge
save "$MM_VISITS"


use ../out/county_panel.dta, clear

* one row per county: years spread into wageYYYY / hoursYYYY

reshape wide wage hours, i(county) j(year)


save ../out/county_wide.dta, replace
