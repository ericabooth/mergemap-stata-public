* mmsql.do -- teach-mode prototype (PLAN section 7)
* Prints jOOQ-style row-stack pictures in SMCL for two cases:
*   1. merge m:1 ..., keep(1 3)   == a left join
*   2. merge m:m                  == the warning case (not a join at all)
* Each picture: two small key-labeled row stacks, the operator, the result
* stack with padded/dropped rows in parentheses, the size rule, and the
* SQL/dplyr/pandas equivalence line.
* Output captured to .smcl via named logs, then translated to ASCII .txt.
* Run headless:  stata-mp -b do mmsql.do
version 16
set linesize 100

capture program drop _teach_m1
program define _teach_m1
    di as txt ""
    di as res "mergemap sql: merge m:1 county using county_key.dta, keep(1 3)"
    di as txt "a merge is row pairing, not overlapping circles: each result row below is one master"
    di as txt "row paired (or not) with its key match in using"
    di as txt ""
    di as txt "  " %-38s "master: work (in memory)" "using: county_key.dta"
    di as txt "  " %-38s "key: county (duplicates ok)" "key: county (unique)"
    di as txt "  {c TLC}{hline 24}{c TRC}" _skip(10) "{c TLC}{hline 24}{c TRC}"
    di as txt "  {c |}" %-24s " county   wage" "{c |}" _skip(10) ///
              "{c |}" %-24s " county   cname" "{c |}"
    di as txt "  {c |}" as res %-24s " Bell     12.10" as txt "{c |}" _skip(10) ///
              "{c |}" as res %-24s " Bell     Bell Cty" as txt "{c |}"
    di as txt "  {c |}" as res %-24s " Bell     14.75" as txt "{c |}" _skip(10) ///
              "{c |}" as res %-24s " Coke     Coke Cty" as txt "{c |}"
    di as txt "  {c |}" as res %-24s " Coke      9.30" as txt "{c |}" _skip(10) ///
              "{c |}" as res %-24s " Duval    Duval Cty" as txt "{c |}"
    di as txt "  {c |}" as res %-24s " Hays     11.20" as txt "{c |}" _skip(10) ///
              "{c BLC}{hline 24}{c BRC}"
    di as txt "  {c BLC}{hline 24}{c BRC}"
    di as txt "        {c |}"
    di as txt "        {c |}  merge m:1 county, keep(1 3)"
    di as txt "        v"
    di as txt "  result: work (4 rows)"
    di as txt "  {c TLC}{hline 50}{c TRC}"
    di as txt "  {c |}" %-10s " county" %-8s "wage" %-11s "cname" ///
              %-8s "_merge" %-13s "" "{c |}"
    di as txt "  {c |}" as res %-10s " Bell" %-8s "12.10" %-11s "Bell Cty" ///
              %-8s "3" %-13s "matched" as txt "{c |}"
    di as txt "  {c |}" as res %-10s " Bell" %-8s "14.75" %-11s "Bell Cty" ///
              %-8s "3" %-13s "matched" as txt "{c |}"
    di as txt "  {c |}" as res %-10s " Coke" %-8s " 9.30" %-11s "Coke Cty" ///
              %-8s "3" %-13s "matched" as txt "{c |}"
    di as txt "  {c |}" as res %-10s " Hays" %-8s "11.20" %-11s "." ///
              %-8s "1" %-13s "master-only" as txt "{c |}" ///
              "  <- kept; cname padded with missing"
    di as txt "  {c |}" as res %-10s "( Duval" %-8s "." %-11s "Duval Cty" ///
              %-8s "2" %-13s "using-only )" as txt "{c |}" ///
              "  <- dropped by keep(1 3)"
    di as txt "  {c BLC}{hline 50}{c BRC}"
    di as txt "  size rule: rows(result) = matched + master-only        4 = 3 + 1"
    di as txt "  every master row appears exactly once (keys unique in using, m:1);"
    di as txt "  the unmatched using row (Duval) is dropped by keep(1 3), not padded"
    di as txt ""
    di as txt `"  SQL: LEFT JOIN ... USING(county)  |  dplyr: left_join  |  pandas: how="left""'
end

capture program drop _teach_mm
program define _teach_mm
    di as txt ""
    di as res "mergemap sql: merge m:m staff using schedules.dta        !! warning case"
    di as txt "merge m:m does NOT form all key pairs -- it pairs rows by ROW ORDER within each key"
    di as txt ""
    di as txt "  " %-38s "master: work (staff A: 3 rows)" "using: schedules.dta (staff A: 2 rows)"
    di as txt "  " %-38s "key: staff (duplicates)" "key: staff (duplicates)"
    di as txt "  {c TLC}{hline 24}{c TRC}" _skip(10) "{c TLC}{hline 24}{c TRC}"
    di as txt "  {c |}" %-24s " staff    visit" "{c |}" _skip(10) ///
              "{c |}" %-24s " staff    slot" "{c |}"
    di as txt "  {c |}" as res %-24s " A        v1     row 1" as txt "{c |}" _skip(10) ///
              "{c |}" as res %-24s " A        s1     row 1" as txt "{c |}"
    di as txt "  {c |}" as res %-24s " A        v2     row 2" as txt "{c |}" _skip(10) ///
              "{c |}" as res %-24s " A        s2     row 2" as txt "{c |}"
    di as txt "  {c |}" as res %-24s " A        v3     row 3" as txt "{c |}" _skip(10) ///
              "{c BLC}{hline 24}{c BRC}"
    di as txt "  {c BLC}{hline 24}{c BRC}"
    di as txt "        {c |}"
    di as txt "        {c |}  merge m:m staff"
    di as txt "        v"
    di as txt "  result: work (3 rows -- max of 3 and 2, NOT 3 x 2)"
    di as txt "  {c TLC}{hline 50}{c TRC}"
    di as txt "  {c |}" %-10s " staff" %-8s "visit" %-32s "slot" "{c |}"
    di as txt "  {c |}" as res %-10s " A" %-8s "v1" %-32s "s1" as txt "{c |}" ///
              "  row 1 <-> row 1"
    di as txt "  {c |}" as res %-10s " A" %-8s "v2" %-32s "s2" as txt "{c |}" ///
              "  row 2 <-> row 2"
    di as txt "  {c |}" as res %-10s " A" %-8s "v3" %-32s "(s2)" as txt "{c |}" ///
              "  row 3 <-> row 2  (last using row reused)"
    di as txt "  {c BLC}{hline 50}{c BRC}"
    di as txt "  size rule: rows per key = max(rows master, rows using)   -- order-dependent"
    di as txt "  !! resorting either file changes the answer: merge m:m is not a join"
    di as txt ""
    di as txt "  the true many-to-many (all 3 x 2 = 6 pairs within staff A) is joinby:"
    di as txt `"  SQL: INNER JOIN (cartesian per key)  |  dplyr: inner_join  |  pandas: how="inner""'
    di as txt "  merge m:m itself has no SQL equivalent (row-order dependent)"
end

* ---- capture to .smcl, translate to ASCII .txt (C1 convention) ----
* smcl2log (not smcl2txt): smcl2txt prepends the Stata logo and numbers
* every output line; smcl2log emits just the rendered text
translator set smcl2log linesize 100

capture log close t1
log using teach_merge_m1.smcl, name(t1) replace smcl nomsg
_teach_m1
log close t1
translate teach_merge_m1.smcl teach_merge_m1.txt, translator(smcl2log) replace

capture log close t2
log using teach_merge_mm.smcl, name(t2) replace smcl nomsg
_teach_mm
log close t2
translate teach_merge_mm.smcl teach_merge_mm.txt, translator(smcl2log) replace
