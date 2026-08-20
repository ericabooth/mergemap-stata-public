* t9: macro-built paths and cd tracking
local path "raw"
cd "sub"
use `path'/b.dta, clear
merge 1:1 id using c.dta, nogenerate
cd ..
local d "elsewhere"
cd "`d'"
use d.dta, clear
save built/t9_out, replace
