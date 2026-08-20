* fx_delimit.do -- a #delimit ; region, which run mode must not instrument.
use fxdata/master.dta, clear
#delimit ;
merge 1:1 id using fxdata/lookup.dta,
    keep(1 3) nogenerate ;
#delimit cr
save fxdata/out_delimit.dta, replace
