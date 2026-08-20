* s14_contract_merge.do -- contract to pid frequencies, merge back m:1
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/visits.dta, clear
contract pid, freq(nvisits)
save ../out/s14_pid_freq.dta, replace

use ../raw/participants.dta, clear
merge m:1 pid using ../out/s14_pid_freq.dta, keep(1 3) nogenerate
save ../out/s14_participants_freq.dta, replace
