* s10_merge_loop.do -- forvalues loop merging the cps_`y' year files
* Master is the 2019 pid list; each pass merges one year's file 1:1 on pid.
* keepusing(wage) sidesteps the str3 hours clash in cps_2022, and wage is
* renamed each pass so the next merge can bring in a fresh copy.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use pid using ../raw/cps_2019.dta, clear
duplicates drop
forvalues y = 2019/2022 {
    merge 1:1 pid using ../raw/cps_`y'.dta, keepusing(wage) keep(1 3) nogenerate
    rename wage wage`y'
}
save ../out/s10_wage_wide.dta, replace
