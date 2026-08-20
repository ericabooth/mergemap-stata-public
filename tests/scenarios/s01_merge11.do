* s01_merge11.do -- clean 1:1 merge: county key vs county frame data
* Both files are unique on county; some counties sit on only one side, but
* nothing is asserted so the merge runs clean.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/county_key.dta, clear
merge 1:1 county using ../raw/counties_frame.dta
save ../out/s01_county_join.dta, replace
