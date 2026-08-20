*! version 0.3.0  20aug2026  Eric Booth
*! _mm_sql -- teach mode: joins drawn as row pairings, not Venn circles.
*! A join is a cartesian product with a filter, which is why a join can
*! return more rows than either input and why overlapping circles are the
*! wrong picture.  Each picture shows two small key-labelled row stacks,
*! the operator, the result stack (dropped rows in parentheses, padded
*! rows marked), the size rule, and the SQL / dplyr / pandas equivalent.

program define _mm_sql
    version 16
    gettoken what : 0
    local what = strlower(strtrim(`"`what'"'))
    if inlist("`what'", "left", "m:1", "keep(1 3)", "lookup") {
        _mm_sql_left
        exit
    }
    if inlist("`what'", "mm", "m:m") {
        _mm_sql_mm
        exit
    }
    if inlist("`what'", "inner", "keep(3)") {
        _mm_sql_inner
        exit
    }
    if inlist("`what'", "full", "outer", "merge", "default") {
        _mm_sql_full
        exit
    }
    if inlist("`what'", "fanout", "1:m") {
        _mm_sql_fanout
        exit
    }
    if "`what'" == "joinby" {
        _mm_sql_joinby
        exit
    }
    if "`what'" == "append" {
        _mm_sql_append
        exit
    }
    if "`what'" == "cross" {
        _mm_sql_cross
        exit
    }
    if "`what'" != "" & "`what'" != "table" {
        di as err `"mergemap sql: no picture called "`what'""'
    }
    _mm_sql_table
end

* -------------------------------------------------- the translation table
program define _mm_sql_table
    di as txt ""
    di as res "mergemap sql: what each Stata form is, in three other languages"
    di as txt ""
    di as txt %-34s "  Stata" %-26s "SQL" %-18s "dplyr" "pandas how="
    di as txt "  {hline 92}"
    di as txt %-34s "  merge 1:1 k using B" %-26s "FULL OUTER JOIN" %-18s "full_join" "outer"
    di as txt %-34s "  merge .., keep(3)" %-26s "INNER JOIN" %-18s "inner_join" "inner"
    di as txt %-34s "  merge .., keep(1 3)" %-26s "LEFT JOIN" %-18s "left_join" "left"
    di as txt %-34s "  merge .., keep(2 3)" %-26s "RIGHT JOIN" %-18s "right_join" "right"
    di as txt %-34s "  merge .., keep(1)" %-26s "anti join" %-18s "anti_join" "left_anti"
    di as txt %-34s "  merge m:1 k using B" %-26s "many-to-one lookup" %-18s "left_join" "validate m:1"
    di as txt %-34s "  merge 1:m k using B" %-26s "one-to-many fan-out" %-18s "left_join" "validate 1:m"
    di as txt %-34s "  merge m:m k using B" %-26s "(no equivalent: not a join)" %-18s "--" "--"
    di as txt %-34s "  joinby k using B" %-26s "INNER JOIN, dup keys" %-18s "inner_join" "validate m:m"
    di as txt %-34s "  cross using B" %-26s "CROSS JOIN" %-18s "cross_join" "cross"
    di as txt %-34s "  append using B" %-26s "UNION ALL (by name)" %-18s "bind_rows" "concat"
    di as txt %-34s "  frlink m:1 k, frame(B)" %-26s "declares the FK" %-18s "join_by" "--"
    di as txt %-34s "  frget v, from(lnk)" %-26s "LEFT JOIN projection" %-18s "left_join" "left"
    di as txt %-34s "  collapse (mean) x, by(k)" %-26s "GROUP BY" %-18s "summarise" "groupby.agg"
    di as txt %-34s "  reshape long / wide" %-26s "UNPIVOT / PIVOT" %-18s "pivot_longer/wider" "melt / pivot"
    di as txt "  {hline 92}"
    di as txt ""
    di as txt "  Pictures, one per form:"
    di as txt `"    {stata mergemap sql full:. mergemap sql full}      the default merge (full outer join)"'
    di as txt `"    {stata mergemap sql left:. mergemap sql left}      merge m:1 .., keep(1 3) (a left join)"'
    di as txt `"    {stata mergemap sql inner:. mergemap sql inner}     merge .., keep(3)"'
    di as txt `"    {stata mergemap sql fanout:. mergemap sql fanout}    merge 1:m (one row becomes many)"'
    di as txt `"    {stata mergemap sql joinby:. mergemap sql joinby}    the real many-to-many"'
    di as txt `"    {stata mergemap sql append:. mergemap sql append}    stacking, not joining"'
    di as txt `"    {stata mergemap sql cross:. mergemap sql cross}     every row against every row"'
    di as txt `"    {stata mergemap sql mm:. mergemap sql mm}        merge m:m, the warning case"'
end

program define _mm_sql_left
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

program define _mm_sql_mm
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


program define _mm_sql_full
    di as txt ""
    di as res "mergemap sql: merge 1:1 id using B  (a full outer join)"
    di as txt "every row from both sides survives; the side with no match is padded with missing"
    di as txt ""
    di as txt "  master              using               result (bare merge)"
    di as txt "  {c TLC}{hline 12}{c TRC}    {c TLC}{hline 12}{c TRC}    {c TLC}{hline 28}{c TRC}"
    di as txt "  {c |} id   x     {c |}    {c |} id   y     {c |}    {c |} id   x    y    _merge      {c |}"
    di as txt "  {c |}" as res " 1    a     " as txt "{c |}    {c |}" as res " 1    p     " as txt "{c |}    {c |}" as res " 1    a    p    3  matched  " as txt "{c |}"
    di as txt "  {c |}" as res " 2    b     " as txt "{c |}    {c |}" as res " 3    q     " as txt "{c |}    {c |}" as res " 2    b    .    1  master   " as txt "{c |}"
    di as txt "  {c BLC}{hline 12}{c BRC}    {c BLC}{hline 12}{c BRC}    {c |}" as res " 3    .    q    2  using    " as txt "{c |}"
    di as txt "                                      {c BLC}{hline 28}{c BRC}"
    di as txt ""
    di as txt "  size rule: rows(result) = matched + master-only + using-only;  3 = 1 + 1 + 1"
    di as txt "  this can be LARGER than either input, which no overlapping-circles picture can show"
    di as txt ""
    di as txt `"  SQL: FULL OUTER JOIN  |  dplyr: full_join  |  pandas: how="outer""'
end

program define _mm_sql_inner
    di as txt ""
    di as res "mergemap sql: merge 1:1 id using B, keep(3)  (an inner join)"
    di as txt "only the rows whose key appears on both sides survive"
    di as txt ""
    di as txt "  master              using               result: keep(3)"
    di as txt "  {c TLC}{hline 12}{c TRC}    {c TLC}{hline 12}{c TRC}    {c TLC}{hline 26}{c TRC}"
    di as txt "  {c |} id   x     {c |}    {c |} id   y     {c |}    {c |} id   x     y             {c |}"
    di as txt "  {c |}" as res " 1    a     " as txt "{c |}    {c |}" as res " 1    p     " as txt "{c |}    {c |}" as res " 1    a     p             " as txt "{c |}"
    di as txt "  {c |}" as res " 2    b     " as txt "{c |}    {c |}" as res " 3    q     " as txt "{c |}    {c |}" as res " 3    c     q             " as txt "{c |}"
    di as txt "  {c |}" as res " 3    c     " as txt "{c |}    {c BLC}{hline 12}{c BRC}    {c |}" as res "( 2    b     .  dropped ) " as txt "{c |}"
    di as txt "  {c BLC}{hline 12}{c BRC}                      {c BLC}{hline 26}{c BRC}"
    di as txt ""
    di as txt "  size rule: rows(result) = matched only;  2 = 2"
    di as txt "  master-only id 2 and any using-only rows are dropped, not padded"
    di as txt ""
    di as txt `"  SQL: INNER JOIN  |  dplyr: inner_join  |  pandas: how="inner""'
end

program define _mm_sql_fanout
    di as txt ""
    di as res "mergemap sql: merge 1:m id using B  (one row becomes many)"
    di as txt "the key is unique in master and repeats in using, so each master row is copied"
    di as txt "once for every using row it matches"
    di as txt ""
    di as txt "  master (id unique)  using (id repeats)  result"
    di as txt "  {c TLC}{hline 12}{c TRC}    {c TLC}{hline 12}{c TRC}    {c TLC}{hline 24}{c TRC}"
    di as txt "  {c |} id   x     {c |}    {c |} id   v     {c |}    {c |} id   x    v            {c |}"
    di as txt "  {c |}" as res " 1    a     " as txt "{c |}    {c |}" as res " 1    p     " as txt "{c |}    {c |}" as res " 1    a    p            " as txt "{c |}"
    di as txt "  {c |}" as res " 2    b     " as txt "{c |}    {c |}" as res " 1    q     " as txt "{c |}    {c |}" as res " 1    a    q  <- copy   " as txt "{c |}"
    di as txt "  {c BLC}{hline 12}{c BRC}    {c |}" as res " 2    r     " as txt "{c |}    {c |}" as res " 2    b    r            " as txt "{c |}"
    di as txt "                    {c BLC}{hline 12}{c BRC}    {c BLC}{hline 24}{c BRC}"
    di as txt ""
    di as txt "  size rule: rows(result) = rows(using) when all match;  3 = 3"
    di as txt "  the master value a is now in two rows: summing x after this join double-counts"
    di as txt ""
    di as txt `"  SQL: one-to-many JOIN  |  dplyr: one-to-many  |  pandas: validate="1:m""'
end

program define _mm_sql_joinby
    di as txt ""
    di as res "mergemap sql: joinby id using B  (the real many-to-many)"
    di as txt "within each key, every master row is paired with every using row: a cross"
    di as txt "product inside the key"
    di as txt ""
    di as txt "  master              using               result"
    di as txt "  {c TLC}{hline 12}{c TRC}    {c TLC}{hline 12}{c TRC}    {c TLC}{hline 18}{c TRC}"
    di as txt "  {c |} id   x     {c |}    {c |} id   y     {c |}    {c |} id   x    y      {c |}"
    di as txt "  {c |}" as res " 1    a     " as txt "{c |}    {c |}" as res " 1    p     " as txt "{c |}    {c |}" as res " 1    a    p      " as txt "{c |}"
    di as txt "  {c |}" as res " 1    b     " as txt "{c |}    {c |}" as res " 1    q     " as txt "{c |}    {c |}" as res " 1    a    q      " as txt "{c |}"
    di as txt "  {c BLC}{hline 12}{c BRC}    {c BLC}{hline 12}{c BRC}    {c |}" as res " 1    b    p      " as txt "{c |}"
    di as txt "                                      {c |}" as res " 1    b    q      " as txt "{c |}"
    di as txt "                                      {c BLC}{hline 18}{c BRC}"
    di as txt ""
    di as txt "  size rule, per key: rows = rows(master) x rows(using);  4 = 2 x 2"
    di as txt "  2 rows and 2 rows made 4: joins can multiply, which is why mergemap"
    di as txt "  reports row multiplication on every joinby"
    di as txt ""
    di as txt `"  SQL: INNER JOIN, dup keys  |  dplyr: many-to-many  |  pandas: validate="m:m""'
end

program define _mm_sql_append
    di as txt ""
    di as res "mergemap sql: append using B  (stacking, not joining)"
    di as txt "rows are stacked; variables are matched BY NAME, and a variable absent from"
    di as txt "one side is padded with missing in that side's rows"
    di as txt ""
    di as txt "  master              using               result"
    di as txt "  {c TLC}{hline 12}{c TRC}    {c TLC}{hline 12}{c TRC}    {c TLC}{hline 20}{c TRC}"
    di as txt "  {c |} id   x     {c |}    {c |} id   y     {c |}    {c |} id   x     y       {c |}"
    di as txt "  {c |}" as res " 1    a     " as txt "{c |}    {c |}" as res " 3    p     " as txt "{c |}    {c |}" as res " 1    a     .       " as txt "{c |}"
    di as txt "  {c |}" as res " 2    b     " as txt "{c |}    {c BLC}{hline 12}{c BRC}    {c |}" as res " 2    b     .       " as txt "{c |}"
    di as txt "  {c BLC}{hline 12}{c BRC}                      {c |}" as res " 3    .     p       " as txt "{c |}"
    di as txt "                                      {c BLC}{hline 20}{c BRC}"
    di as txt ""
    di as txt "  size rule: rows(result) = rows(master) + rows(using);  3 = 2 + 1"
    di as txt "  no key, no matching: id 3 is a NEW row, not a match for anything"
    di as txt ""
    di as txt `"  SQL: UNION ALL  |  dplyr: bind_rows  |  pandas: concat"'
end

program define _mm_sql_cross
    di as txt ""
    di as res "mergemap sql: cross using B  (every row against every row)"
    di as txt "no key at all: the result is every pairing, which is what every join is"
    di as txt "before its key filter is applied"
    di as txt ""
    di as txt "  master              using               result"
    di as txt "  {c TLC}{hline 12}{c TRC}    {c TLC}{hline 12}{c TRC}    {c TLC}{hline 16}{c TRC}"
    di as txt "  {c |} x          {c |}    {c |} y          {c |}    {c |} x     y        {c |}"
    di as txt "  {c |}" as res " a          " as txt "{c |}    {c |}" as res " p          " as txt "{c |}    {c |}" as res " a     p        " as txt "{c |}"
    di as txt "  {c |}" as res " b          " as txt "{c |}    {c |}" as res " q          " as txt "{c |}    {c |}" as res " a     q        " as txt "{c |}"
    di as txt "  {c BLC}{hline 12}{c BRC}    {c BLC}{hline 12}{c BRC}    {c |}" as res " b     p        " as txt "{c |}"
    di as txt "                                      {c |}" as res " b     q        " as txt "{c |}"
    di as txt "                                      {c BLC}{hline 16}{c BRC}"
    di as txt ""
    di as txt "  size rule: rows(result) = rows(master) x rows(using);  4 = 2 x 2"
    di as txt ""
    di as txt `"  SQL: CROSS JOIN  |  dplyr: cross_join  |  pandas: how="cross""'
end
