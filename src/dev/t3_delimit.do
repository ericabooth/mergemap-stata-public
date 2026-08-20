* t3: #delimit region, best-effort parse
use raw/base, clear
#delimit ;
merge m:1 county using
    xwalk/county_key,
    keep(1 3) nogenerate ;
collapse (mean) wage,
    by(county) ;
#delimit cr
save built/t3_out, replace
