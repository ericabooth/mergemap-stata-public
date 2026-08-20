*! version 0.3.1  20aug2026  Eric Booth
*! _mm_detail -- everything the journal knows about one event, printed as a
*! ledger.  With -teach-, a join event is also drawn as a row-pairing picture
*! in the style of -mergemap sql-, but built from ITS observed counts, so the
*! teaching picture and your own pipeline become the same picture.  A scanned
*! event has no counts, so teach falls back to the generic picture for that
*! join form and says why.

program define _mm_detail, rclass
    version 16
    gettoken seq 0 : 0, parse(" ,")
    capture confirm integer number `seq'
    if _rc {
        di as err "mergemap detail: which event? e.g. mergemap detail 3"
        di as err `"    the receipt and {stata mergemap list:mergemap list} number them"'
        exit 198
    }
    syntax [anything(name=jspec)] [, TEACH]
    _mm_jresolve `jspec'
    local jfile `"`s(jfile)'"'
    _mm_jload using `"`jfile'"', frame(_mmdet)
    local missing = 0
    frame _mmdet {
        quietly count if seq == "`seq'"
        if r(N) == 0 {
            quietly count
            local N = r(N)
            local missing = 1
        }
    }
    if `missing' {
        frame drop _mmdet
        di as err "mergemap detail: no event `seq' in `jfile' (events run 1-`N')"
        exit 111
    }
    frame _mmdet {
        quietly keep if seq == "`seq'"
        foreach v in dofile line class cmd subtype keys usingfile result   ///
            n_in k_in n_using k_using n_out k_out m1 m2 m3 m4 m5           ///
            dup_master dup_using force opts loop_n loop_first loop_last    ///
            severity keytypes cover_master cover_using flags {
            local `v' = `v'[1]
        }
    }
    frame drop _mmdet

    di as txt ""
    di as res "event `seq': `cmd'" cond("`subtype'" == ".", "", " `subtype'") ///
        as txt "   (`dofile' line `line')"
    di as txt "  {hline 62}"
    _mm_detrow "class"      "`class'"
    _mm_detrow "keys"       "`keys'"
    _mm_detrow "using"      `"`usingfile'"'
    _mm_detrow "result"     `"`result'"'
    _mm_detrow "rows"       "`n_in' -> `n_out'"
    _mm_detrow "vars"       "`k_in' -> `k_out'"
    _mm_detrow "using size" "`n_using' x `k_using'"
    local mrow ""
    if "`m3'" != "."              local mrow "matched `m3'"
    if !inlist("`m1'", ".", "0")  local mrow "`mrow'  master-only `m1'"
    if !inlist("`m2'", ".", "0")  local mrow "`mrow'  using-only `m2'"
    if !inlist("`m4'", ".", "0")  local mrow "`mrow'  missing-updated `m4'"
    if !inlist("`m5'", ".", "0")  local mrow "`mrow'  conflicts `m5'"
    _mm_detrow "_merge"     "`mrow'"
    local cov ""
    if "`cover_master'" != "." local cov "`cover_master'% of master matched"
    if "`cover_using'"  != "." local cov "`cov', `cover_using'% of using used"
    _mm_detrow "coverage"   "`cov'"
    _mm_detrow "key types"  `"`keytypes'"'
    local dups ""
    if !inlist("`dup_master'", ".", "0") local dups "master +`dup_master'"
    if !inlist("`dup_using'",  ".", "0") local dups "`dups'  using +`dup_using'"
    _mm_detrow "dup keys"   "`dups'"
    if "`force'" == "1" _mm_detrow "force" "yes"
    _mm_detrow "options"    `"`opts'"'
    if "`loop_n'" != "." {
        _mm_detrow "loop" "x`loop_n': `loop_first' ... `loop_last'"
    }
    if !inlist("`severity'", "note", ".") _mm_detrow "severity" "`severity'"
    if `"`flags'"' != "." {
        di as txt %-12s "  flags" as err `"  `flags'"'
    }
    di as txt "  {hline 62}"
    return local journal `"`jfile'"'

    if "`teach'" == "" exit

    * ---- the bridge: this event, drawn with its own counts ---------------
    if !inlist("`class'", "join", "link") {
        di as txt "mergemap detail: teach draws join events; event `seq' is a `class'"
        exit
    }
    if "`m3'" == "." {
        * scanned, not run: no counts to draw with
        local pic ""
        if "`cmd'" == "joinby"                       local pic "joinby"
        else if "`cmd'" == "append"                  local pic "append"
        else if "`cmd'" == "cross"                   local pic "cross"
        else if "`subtype'" == "m:m"                 local pic "mm"
        else if "`subtype'" == "1:m"                 local pic "fanout"
        else if strpos(`"`opts'"', "keep(3)")        local pic "inner"
        else if strpos(`"`opts'"', "keep(1 3)")      local pic "left"
        else if inlist("`subtype'", "m:1", "1:1")    local pic "full"
        if "`pic'" == "" {
            di as txt "mergemap detail: no teaching picture for `cmd'"
            exit
        }
        di as txt ""
        di as txt "This event was scanned, not run, so there are no observed"
        di as txt "counts to draw; the generic picture for its form instead"
        di as txt "({stata mergemap run:mergemap run} fills it with your data):"
        _mm_sql `pic'
        exit
    }
    * observed counts: the schematic with this event's numbers in it
    local NIN  : display %15.0fc real("`n_in'")
    local NUS  : display %15.0fc real("`n_using'")
    local NOUT : display %15.0fc real("`n_out'")
    local M1   : display %15.0fc real("`m1'")
    local M2   : display %15.0fc real("`m2'")
    local M3   : display %15.0fc real("`m3'")
    foreach l in NIN NUS NOUT M1 M2 M3 {
        local `l' = strtrim("``l''")
    }
    di as txt ""
    di as res "event `seq', drawn: `cmd' `subtype' `keys'"
    di as txt ""
    di as txt "  master: `NIN' rows" _col(40) "using: `NUS' rows"
    di as txt "  key: `keys'" _col(40) `"file: `usingfile'"'
    di as txt "        {c |}"
    di as txt "        {c |}  `cmd' `subtype' `keys'" cond(`"`opts'"' == ".", "", `", `opts'"')
    di as txt "        v"
    * a keep() drops whole categories; parenthesize those so the box's
    * arithmetic agrees with the result count it sits under
    local kept "1 2 3 4 5"
    if regexm(`"`opts'"', "keep\(([0-9 ]+)\)") local kept = regexs(1)
    di as txt "  result: `NOUT' rows"
    di as txt "  {c TLC}{hline 44}{c TRC}"
    foreach k in 3 1 2 4 5 {
        local lab3 "matched"
        local lab1 "master-only"
        local lab2 "using-only"
        local lab4 "missing-updated"
        local lab5 "nonmissing conflicts"
        local v : display %15.0fc real("`m`k''")
        local v = strtrim("`v'")
        if "`m`k''" == "." | ("`m`k''" == "0" & `k' != 3) continue
        if strpos(" `kept' ", " `k' ") {
            di as txt "  {c |}" as res %-30s "  `lab`k''" %12s "`v'" as txt "  {c |}"
        }
        else {
            * interior stays 44 wide: 1 + 23 + 10 + 10
            di as txt "  {c |}(" %-23s " `lab`k''" %10s "`v'" " dropped ){c |}"
        }
    }
    di as txt "  {c BLC}{hline 44}{c BRC}"
    if "`cov'" != "" di as txt "  coverage: `cov'"
    if `"`flags'"' != "." di as err "  `flags'"
    di as txt ""
    di as txt `"  the generic form, with toy rows: {stata mergemap sql:mergemap sql}"'
end

program define _mm_detrow
    args label value
    if inlist(`"`value'"', "", ".", ". -> .", ". x .") exit
    di as txt %-12s "  `label'" as res `"  `value'"'
end
