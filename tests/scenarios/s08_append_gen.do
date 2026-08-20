* s08_append_gen.do -- append with generate(src) and force
* cps_2022 stores hours as str3 against byte elsewhere: force lets the
* append run and leaves hours missing on the 2022 rows. src records which
* file each observation came from.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/cps_2019.dta, clear
append using ../raw/cps_2020.dta ../raw/cps_2021.dta ../raw/cps_2022.dta, ///
    generate(src) force
save ../out/s08_cps_pool.dta, replace
