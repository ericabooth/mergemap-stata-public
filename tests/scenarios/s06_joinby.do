* s06_joinby.do -- joinby with unmatched(both)
* staff 1 exists only among participants; staff 26-28 exist only in the
* assignments file; matched staff fan out across their 1-3 assignments.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/participants.dta, clear
joinby staff using ../raw/staff_assign.dta, unmatched(both)
save ../out/s06_joined.dta, replace
