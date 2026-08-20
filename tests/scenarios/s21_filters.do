* s21_filters.do -- row filters and variable-list filters.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.
*
* Filters are where most row loss in a pipeline actually happens, so
* mergemap records keep if / drop if / keep varlist / drop varlist as
* events of their own rather than letting the attrition be misread as
* something the merges did.

* ---- prime-age participants, one row per pid ----------------------------
use ../raw/participants.dta, clear
duplicates drop pid, force
keep if inrange(age, 25, 54)
drop female income
save ../out/s21_prime_age.dta, replace

* ---- first-half visits with a recorded service --------------------------
use ../raw/visits.dta, clear
drop if missing(svc)
keep if date <= mdy(6, 30, 2024)

* ---- attach the participant attributes ----------------------------------
merge m:1 pid using ../out/s21_prime_age.dta, keep(3) nogenerate
keep pid visitid date svc county staff
save ../out/s21_filtered.dta, replace
