* maketestdata.do -- build the synthetic raw datasets for the mergemap tests
* Run from tests/:  /usr/local/bin/stata-mp -b do maketestdata.do
* Writes every dataset to raw/.  Deterministic: one seed, no unstable sorts
* (every bysort that numbers rows sorts on an explicit prior row index).

clear all
set seed 20260819
capture mkdir raw
capture mkdir out

* ---- county_key: 42 counties; the last 2 appear nowhere else ------------
clear
set obs 42
gen str5 county = string(48001 + 2*(_n - 1), "%05.0f")
gen str16 cname = "County " + county
gen str8 region = "West"
replace region = "North"   if _n > 10
replace region = "Central" if _n > 20
replace region = "East"    if _n > 32
isid county
label data "county crosswalk: 40 live counties + 2 key-only"
save raw/county_key.dta, replace

* ---- participants: 792 obs, 12 duplicate pids, stray counties -----------
* Rows 1-12 carry counties 48997/48999, which have no county_key row
* (master-only side for the keep(1 3) scenarios). Rows 101-112 are
* duplicated wholesale to plant 12 duplicate pids.
clear
set obs 780
gen long pid = 10000 + _n
gen int cix = ceil(runiform()*40)
gen str5 county = string(48001 + 2*(cix - 1), "%05.0f")
replace county = "48999" in 1/6
replace county = "48997" in 7/12
gen int  staff  = 1 + mod(_n, 25)
gen byte female = runiform() < .52
gen int  age    = 18 + floor(runiform()*50)
gen double income = round(15000 + runiform()*80000, 1)
drop cix
expand 2 in 101/112
sort pid
assert _N == 792
label data "participants: 12 duplicate pids, stray counties"
save raw/participants.dta, replace

* ---- visits: 1-4 visits each for ~94% of participants -------------------
use raw/participants.dta, clear
duplicates drop pid, force
drop if mod(_n, 16) == 0
keep pid
gen int nvis = 1 + floor(runiform()*4)
expand nvis
gen long ord = _n
bysort pid (ord): gen int visitid = _n
gen int date = mdy(1,1,2024) + floor(runiform()*365)
format date %td
gen str8 svc = word("intake exam therapy followup refer", ///
    1 + floor(runiform()*5))
replace svc = "" if runiform() < .03
drop nvis ord
sort pid visitid
isid pid visitid
label data "visits: 1-4 per pid; some pids have none"
save raw/visits.dta, replace

* ---- corrections: (pid visitid) subset of visits ------------------------
* Includes every missing-svc visit (update fills those, _merge==4) and
* rewrites a third of the rest to a value the master never holds
* (nonmissing conflicts, _merge==5 under update replace).
use raw/visits.dta, clear
sort pid visitid
keep if mod(_n, 9) == 0 | svc == ""
replace svc = "review" if svc == ""
replace svc = "audit"  if mod(_n, 3) == 0 & svc != "review"
keep pid visitid svc
isid pid visitid
label data "corrections: fills + conflicts for update replace"
save raw/corrections.dta, replace

* ---- cps_2019..cps_2022 --------------------------------------------------
* Same variables every year except: 2021 carries an extra var (educ) and
* 2022 stores hours as str3 -- the type-clash file that makes append (and
* any merge that touches hours) need force.
forvalues y = 2019/2022 {
    clear
    set obs 500
    gen long pid = 90000 + _n
    drop if runiform() < .03
    gen int  year = `y'
    gen int  cix  = ceil(runiform()*40)
    gen str5 county = string(48001 + 2*(cix - 1), "%05.0f")
    replace county = "48999" if mod(_n, 97) == 0
    gen double wage = round(15 + runiform()*45, .01)
    if `y' == 2022 {
        gen str3 hours = string(20 + floor(runiform()*25))
        confirm string variable hours
    }
    else {
        gen byte hours = 20 + floor(runiform()*25)
    }
    gen int  age    = 18 + floor(runiform()*50)
    gen byte female = runiform() < .5
    if `y' == 2021 {
        gen byte educ = 1 + floor(runiform()*4)
    }
    drop cix
    isid pid
    label data "synthetic CPS extract `y'"
    save raw/cps_`y'.dta, replace
}

* ---- staff_assign: staff 2..28, 1-3 assignments each (m:m side) ----------
* staff 1 exists only among participants; staff 26-28 only here, so joinby
* unmatched(both) has something to show on each side. schednote is byte
* here and str8 in schedules -- the merge-force clash.
clear
set obs 27
gen int staff = _n + 1
gen int nasg = 1 + floor(runiform()*3)
expand nasg
gen long ord = _n
bysort staff (ord): gen int aseq = _n
gen str8 team = word("Blue Green Red Gold Silver Onyx", 1 + mod(staff + aseq, 6))
gen str8 role = word("lead support float", 1 + mod(aseq, 3))
gen byte schednote = floor(runiform()*5)
drop nasg ord aseq
label data "staff assignments: staff repeats (m:m side)"
save raw/staff_assign.dta, replace

* ---- schedules: duplicate staff keys, schednote as str8 ------------------
clear
set obs 25
gen int staff = _n
gen int nsh = 2 + floor(runiform()*6)
expand nsh
gen long ord = _n
bysort staff (ord): gen int shid = _n
gen str3 day   = word("Mon Tue Wed Thu Fri", 1 + mod(shid - 1, 5))
gen str2 shift = cond(mod(ord, 2) == 0, "AM", "PM")
gen str8 schednote = word("ontime flex remote split", 1 + mod(ord, 4))
drop nsh ord shid
label data "schedules: staff key duplicated, schednote str8"
save raw/schedules.dta, replace

* ---- scores_wide: one row per id, score2019-score2022 --------------------
clear
set obs 300
gen long id = 5000 + _n
forvalues y = 2019/2022 {
    gen double score`y' = round(50 + runiform()*50, .1)
}
isid id
label data "wide scores for the reshape scenarios"
save raw/scores_wide.dta, replace

* ---- counties_frame: first 38 counties only ------------------------------
* Live counties 48077/48079 (and the strays) are absent, so frlink leaves
* some observations unmatched.
use raw/county_key.dta, clear
keep county
keep in 1/38
gen double povrate = round(5 + runiform()*25, .1)
gen int    slots   = 10 + floor(runiform()*200)
isid county
label data "county-level frame data: povrate + slots"
save raw/counties_frame.dta, replace

display as txt "maketestdata: all raw/ datasets written"
