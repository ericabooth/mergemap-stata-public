* s19_preserve.do -- merge inside a preserve/restore block
* The matched-only file is saved from inside the block; restore then puts
* the untouched master back.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/participants.dta, clear
preserve
merge m:1 county using ../raw/county_key.dta, keep(3) nogenerate
save ../out/s19_matched_only.dta, replace
restore
save ../out/s19_untouched.dta, replace
