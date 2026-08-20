* s09_append_loop.do -- foreach over an explicit list of four files
* Starts from an empty dataset; force matters only for cps_2022 (str3
* hours) and is harmless on the clean years.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

clear
foreach f in cps_2019 cps_2020 cps_2021 cps_2022 {
    append using ../raw/`f'.dta, force
}
save ../out/s09_cps_pool.dta, replace
