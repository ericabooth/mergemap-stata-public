* s16_fillin_expand.do -- rectangularize with fillin, then expand
* fillin adds every staff x team combination (with _fillin marking the new
* rows); expand then duplicates the original rows.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/staff_assign.dta, clear
fillin staff team
expand 2 if _fillin == 0, generate(expanded)
save ../out/s16_filled.dta, replace
