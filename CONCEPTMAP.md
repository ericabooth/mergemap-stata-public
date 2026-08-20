| Stata | What actually happens | SQL | dplyr | pandas |
|---|---|---|---|---|
| `merge 1:1 k using B` (default keep all) | one row per key on both sides; unmatched kept from both; `_merge` = 1/2/3 | `FULL OUTER JOIN ... USING (k)` | `full_join(A, B, by="k")` | `A.merge(B, on="k", how="outer", validate="1:1", indicator=True)` |
| `merge 1:1 k using B, keep(3)` | matched only | `INNER JOIN` | `inner_join` | `how="inner"` |
| `..., keep(1 3)` | all master + matched using | `LEFT JOIN` | `left_join` | `how="left"` |
| `..., keep(2 3)` | all using + matched master | `RIGHT JOIN` | `right_join` | `how="right"` |
| `..., keep(1)` | master rows with no match | `LEFT ANTI JOIN` (`WHERE NOT EXISTS`) | `anti_join` | `indicator` then filter `left_only` |
| `..., keep(2)` | using rows with no match | `RIGHT ANTI JOIN` | `anti_join(B, A)` | filter `right_only` |
| `..., keep(1 2)` | symmetric difference | full outer minus inner | no verb | filter `!= both` |
| `..., keepusing(v)` | project columns pulled from using | column list in `SELECT` | `select()` after join | `B[["k","v"]]` before merge |
| `..., assert(3)` / `assert(1 3)` | referential-integrity check, error if violated | `FOREIGN KEY` / assertion | `rows_...`? no; `stopifnot` | `validate` (cardinality only) |
| `merge m:1 k using B` | lookup: many master rows pull one using row each | many-to-one join (FK → PK lookup) | `left_join` with `relationship="many-to-one"` | `validate="m:1"` |
| `merge 1:m k using B` | each master row fans out to many using rows | one-to-many | `relationship="one-to-many"` | `validate="1:m"` |
| `merge m:m k using B` | **not a join**: pairs rows by observation order within key; row count = max of sides | no SQL equivalent (do not use) | no equivalent | no equivalent |
| `joinby k using B` | true many-to-many: all pairwise combinations within key (cross product within key) | `INNER JOIN` with non-unique keys on both sides | `inner_join(relationship="many-to-many")` | `validate="m:m"` |
| `joinby ..., unmatched(master|using|both)` | keep unmatched | `LEFT` / `RIGHT` / `FULL` | `left_join`/`right_join`/`full_join` | `how=` |
| `cross using B` | every master row × every using row | `CROSS JOIN` | `cross_join` / `tidyr::crossing` | `merge(how="cross")` |
| `append using B` | stack rows; variables matched by name, not position; types promoted | `UNION ALL` (by name) | `bind_rows` | `concat` |
| `append ..., generate(src)` | source indicator | a literal column per `SELECT` in the union | `bind_rows(.id=)` | `concat(keys=)` |
| `frlink m:1 k, frame(B)` | creates a link variable (row pointer into B) | declares a FK relationship; no columns moved yet | `join_by` spec | — |
| `frget v, from(lnk)` | pulls columns along the link; unmatched master rows get missing | `LEFT JOIN` projection | `left_join` then `select` | `merge(how="left")` |
| `fralias add v, from(lnk)` | virtual (view-like) column | a `VIEW` over the join | — | — |
| `merge ..., update` / `update replace` | fill missing / overwrite master values from using | `COALESCE` / `UPDATE ... FROM` | `rows_patch` / `rows_update` | `combine_first` / `update` |
| `collapse (mean) x, by(k)` | aggregate to one row per group | `SELECT k, AVG(x) ... GROUP BY k` | `summarise(.by=)` | `groupby().agg()` |
| `contract k` | group counts | `GROUP BY k` + `COUNT(*)` | `count()` | `value_counts()` |
| `reshape long` / `reshape wide` | unpivot / pivot | `UNPIVOT` / `PIVOT` | `pivot_longer` / `pivot_wider` | `melt` / `pivot` |
| `xpose` | transpose the matrix | no standard SQL | `t()` | `.T` |
| `fillin k1 k2` | rectangularize: cross of key levels, then left-join back | `CROSS JOIN` of distinct keys + `LEFT JOIN` | `tidyr::complete` | `reindex(MultiIndex.from_product)` |
| `expand n` | replicate rows | `CROSS JOIN generate_series` | `uncount` | `repeat` |
| `isid k` / `duplicates report k` | uniqueness check of the key | `PRIMARY KEY`/`UNIQUE` constraint | `distinct`/`count` | `validate`, `duplicated` |
| `keep if` / `keep vars` | row / column filter | `WHERE` / `SELECT` | `filter` / `select` | boolean mask / `[[]]` |
| `sort` | order rows | `ORDER BY` | `arrange` | `sort_values` |
