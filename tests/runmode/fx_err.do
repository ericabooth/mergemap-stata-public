* fx_err.do -- fixture that fails half way through, on purpose.
use fxdata/master.dta, clear
merge 1:1 id using fxdata/lookup.dta, nogenerate
save fxdata/out_err1.dta, replace
merge 1:1 id using fxdata/no_such_file.dta, nogenerate
save fxdata/out_err2.dta, replace
