* fx_prefix.do -- prefixed commands and a run (not do) of a child, so the
* rewriter has to replace the command word in place and leave the prefix
* chain alone.
use fxdata/master.dta, clear
capture noisily merge 1:1 id using fxdata/lookup.dta, keep(1 3) nogenerate
quietly merge 1:m id using fxdata/many.dta, keep(1 3) nogenerate
run fx_child2.do
