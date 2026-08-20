* s20_child.do -- called by s20_nested_do.do; attaches the county key
* Operates on whatever the parent left in memory.

merge m:1 county using ../raw/county_key.dta, keep(1 3) nogenerate
