* fx_clear.do -- fixture with a clear all in the middle.  The wrappers live
* on the adopath and the run state lives in globals and in the journal on
* disk, so a clear all mid-pipeline must be harmless: the ado-files reload
* lazily and journalling carries on.
use fxdata/master.dta, clear
merge 1:1 id using fxdata/lookup.dta, keep(1 3) nogenerate
save fxdata/out_clear1.dta, replace
clear all
use fxdata/master.dta, clear
merge 1:m id using fxdata/many.dta, keep(1 3) nogenerate
save fxdata/out_clear2.dta, replace
