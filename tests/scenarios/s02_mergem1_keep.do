* s02_mergem1_keep.do -- m:1 merge with keep(1 3), unmatched on both sides
* Stray participant counties (48997/48999) have no key row (master-only,
* kept); two key rows (48081/48083) match no participant (using-only,
* dropped by keep(1 3)).
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/participants.dta, clear
merge m:1 county using ../raw/county_key.dta, keep(1 3) nogenerate
save ../out/s02_participants_key.dta, replace
