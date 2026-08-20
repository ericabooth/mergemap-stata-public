* s05_update.do -- 1:1 update replace with genuine conflicts
* corrections fills missing svc values (_merge==4) and overwrites some
* nonmissing ones (_merge==5); the result table in the log shows both.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/visits.dta, clear
merge 1:1 pid visitid using ../raw/corrections.dta, update replace
save ../out/s05_visits_corrected.dta, replace
