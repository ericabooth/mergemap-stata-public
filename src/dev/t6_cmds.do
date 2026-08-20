* t6: command coverage
import delimited using raw/survey.csv, clear
isid pid
export delimited using out/survey_clean.csv, replace
use raw/scores, clear
reshape long score, i(id) j(year)
contract county year
xpose, clear varname
fillin county year
expand 2
frlink m:1 county, frame(counties) generate(cnty)
frget povrate slots, from(cnty)
fralias add region, from(cnty)
joinby staff using raw/staff_assign, unmatched(both)
cross using raw/grid
saveold built/t6_old, replace
