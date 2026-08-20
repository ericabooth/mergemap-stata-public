* t8: row filters and variable-list filters (DECISIONS 16a)
use raw/participants, clear
drop if missing(wage)
keep if inrange(year, 2019, 2022)
drop _merge
keep pid county year wage
keep in 1/100
merge 1:1 pid using raw/lookup, nogenerate
save built/t8_out, replace
