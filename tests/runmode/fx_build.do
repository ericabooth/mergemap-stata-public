* fx_build.do -- fixture pipeline for the run-mode tests.
use fxdata/master.dta, clear
merge 1:1 id using fxdata/lookup.dta, keep(1 3) nogenerate
drop if price > 10000
merge 1:m id using fxdata/many.dta, keep(1 3) nogenerate
collapse (mean) price mpg, by(id)
save fxdata/out_build.dta, replace
