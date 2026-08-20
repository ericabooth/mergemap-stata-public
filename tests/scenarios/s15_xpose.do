* s15_xpose.do -- xpose on a small all-numeric block; sxpose if installed
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/scores_wide.dta, clear
keep in 1/10
xpose, clear varname
save ../out/s15_xposed.dta, replace

capture which sxpose
if _rc == 0 {
    clear
    set obs 3
    gen str8 a = word("alpha beta gamma", _n)
    gen str8 b = word("one two three", _n)
    sxpose, clear
    save ../out/s15_sxposed.dta, replace
}
else {
    display as txt "sxpose not installed - skipping the sxpose demo"
}
