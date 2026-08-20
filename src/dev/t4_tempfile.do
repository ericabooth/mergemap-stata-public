* t4: tempfile chain, update replace, preserve/restore
use raw/visits, clear
tempfile v
save `v'
use raw/participants, clear
duplicates drop pid, force
merge 1:m pid using `v', keep(3)
preserve
merge m:1 county using raw/county_key, update replace
restore
save built/t4_out, replace
