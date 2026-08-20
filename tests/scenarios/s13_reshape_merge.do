* s13_reshape_merge.do -- wide -> long, merge year-level means, back to wide
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/scores_wide.dta, clear
reshape long score, i(id) j(year)
preserve
collapse (mean) yravg = score, by(year)
save ../out/s13_year_means.dta, replace
restore
merge m:1 year using ../out/s13_year_means.dta, nogenerate
reshape wide score yravg, i(id) j(year)
save ../out/s13_scores_wide.dta, replace
