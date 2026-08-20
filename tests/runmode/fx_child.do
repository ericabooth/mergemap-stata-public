* fx_child.do -- child of fx_master.do
use fxdata/master.dta, clear
merge 1:1 id using fxdata/lookup.dta, keep(match master) nogenerate
keep if mpg >= 15
