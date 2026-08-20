* s04_mergemm_force.do -- merge m:m plus force
* staff repeats on both sides: m:m pairs rows by order within staff, it is
* not a join. schednote is byte here vs str8 in schedules, hence force.
* Expected to RUN; flagging the m:m is the scanner's job, not this file's.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/staff_assign.dta, clear
merge m:m staff using ../raw/schedules.dta, force
save ../out/s04_mm_forced.dta, replace
