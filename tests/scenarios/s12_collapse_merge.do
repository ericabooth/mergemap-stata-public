* s12_collapse_merge.do -- collapse visits to counts, merge back m:1
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/visits.dta, clear
collapse (count) nvisits = visitid, by(pid)
save ../out/s12_visit_counts.dta, replace

use ../raw/participants.dta, clear
merge m:1 pid using ../out/s12_visit_counts.dta, keep(1 3) nogenerate
save ../out/s12_participants_counts.dta, replace
