* s18_tempfile_chain.do -- save to a tempfile, then merge using it
* The scanner should label the using side tempfile:vcounts, not a raw
* /var/... path.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/visits.dta, clear
collapse (count) nvisits = visitid, by(pid)
tempfile vcounts
save `vcounts'

use ../raw/participants.dta, clear
merge m:1 pid using `vcounts', keep(1 3) nogenerate
save ../out/s18_via_tempfile.dta, replace
