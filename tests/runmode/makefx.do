* makefx.do -- build the small fixture datasets the run-mode tests use.
* Everything comes from sysuse auto and sysuse census, so nothing is
* downloaded and the tests run on any Stata installation.
clear all
capture mkdir fxdata

sysuse auto, clear
gen long id = _n
keep id make price mpg weight foreign
save fxdata/master.dta, replace

* lookup: unique on id, missing the last 14 cars, plus 6 ids that are not in
* the master at all (so keep() has something to drop and coverage is < 100%)
sysuse auto, clear
gen long id = _n
keep id rep78
drop if id > 60
save fxdata/lk1.dta, replace
clear
set obs 6
gen long id = 100 + _n
gen int rep78 = 3
append using fxdata/lk1.dta
save fxdata/lookup.dta, replace
erase fxdata/lk1.dta

* a many-side file: several rows per id
clear
set obs 180
gen long id = ceil(_n/3)
gen int visit = mod(_n, 3) + 1
gen double amount = 100 + mod(_n, 17)
save fxdata/many.dta, replace

* a key with a different storage type, for the type-drift check
sysuse auto, clear
gen long id = _n
gen str6 idstr = string(id, "%06.0f")
keep idstr foreign
save fxdata/drift.dta, replace

* a grouped file for collapse-style work
sysuse census, clear
keep state region pop medage
gen long id = _n
save fxdata/census.dta, replace
display as txt "fixtures built in fxdata/"
