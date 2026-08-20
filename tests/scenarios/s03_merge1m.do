* s03_merge1m.do -- 1:m fan-out: participants gain one row per visit
* Participants with no visits stay as master-only rows.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/participants.dta, clear
duplicates drop pid, force
merge 1:m pid using ../raw/visits.dta
save ../out/s03_participant_visits.dta, replace
