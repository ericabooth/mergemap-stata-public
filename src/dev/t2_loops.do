* t2: loop resolution (static forvalues, foreach-in, runtime list, numlist)
use raw/cps_2019, clear
forvalues y = 2020/2022 {
    append using raw/cps_`y'
}
foreach f in raw/a.dta raw/b.dta raw/c.dta {
    append using `f'
}
local files : dir "raw" files "*.dta"
foreach f of local files {
    append using raw/`f'
}
foreach k of numlist 1(1)3 {
    merge 1:1 id using raw/part`k', nogenerate
}
save built/t2_out, replace
