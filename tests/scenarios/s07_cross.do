* s07_cross.do -- cross: every county paired with every team
* The using file is derived first so the two files share no variable names.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/staff_assign.dta, clear
keep team
duplicates drop
save ../out/s07_teams.dta, replace

use ../raw/county_key.dta, clear
keep county region
cross using ../out/s07_teams.dta
save ../out/s07_county_team.dta, replace
