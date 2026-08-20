* s20_nested_do.do -- parent loads data; a child do-file performs the merge
* The scanner should recurse into s20_child.do and attribute the merge to
* the child file and line.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/participants.dta, clear
do s20_child.do
save ../out/s20_nested.dta, replace
