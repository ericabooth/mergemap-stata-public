* 01_build.do -- pool the CPS extracts, attach the county key, collapse to
* a county-year panel. Part of the mergemap test pipeline; run via
* 00_master.do from tests/pipeline/. Reads ../raw/, writes ../out/ (the
* sample journal's built/ maps to ../out/ here).
*
* Deviation from the sample journal: the journal shows this append without
* force, but cps_2022.dta stores hours as str3 (the type-clash file for
* the append-force scenarios), so pooling all four years needs force;
* hours arrives missing on the 2022 rows and collapse handles it.

* ---- pool the four CPS years --------------------------------------------
use ../raw/cps_2019.dta, clear

forvalues y = 2020/2022 {
    append using ../raw/cps_`y'.dta, force
}

* ---- attach the county key (m:1) -----------------------------------------
* keep(1 3): counties that appear only in the key are dropped; stray
* counties in the data (48997/48999) stay as master-only rows.

merge m:1 county using ../raw/county_key.dta, keep(1 3) nogenerate

* ---- drop the rows the forced append left without hours ------------------
* cps_2022.dta stores hours as str3, so the forced append above leaves hours
* missing on every 2022 row. Dropping them here keeps the county-year panel
* from carrying a whole year of missing means -- and it is exactly the kind
* of row loss mergemap records as a filter event, so that the attrition is
* not misread as something one of the merges did.

drop if missing(hours)

* ---- collapse to the county-year panel -----------------------------------
* One row per county-year; hours2022 will be all missing (see the force
* note above), which collapse tolerates.




collapse (mean) wage hours, by(county year)

save ../out/county_panel.dta, replace
