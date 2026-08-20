* s17_dups_isid.do -- duplicates drop, isid, then a clean 1:1 merge
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/visits.dta, clear
collapse (count) nvisits = visitid, by(pid)
save ../out/s17_visit_counts.dta, replace

use ../raw/participants.dta, clear
duplicates report pid
duplicates drop pid, force
isid pid
merge 1:1 pid using ../out/s17_visit_counts.dta, keep(1 3) nogenerate
save ../out/s17_clean_merge.dta, replace
