*! _mm_rendersmcl.ado  --  SMCL diagram renderer for mergemap journals (prototype)
*! version 0.2  19aug2026  Eric Booth
*
* _mm_rendersmcl using <journal.tsv> [, style(boxes|rail) layout(vertical|horizontal)
*                                   wrap(#) maxnodes(#) forcesmcl compact
*                                   nocounts nokeys notransforms noellipsis]
*
* Reads a mergemap journal (tab separated; schema v2, 34 columns, see
* proto/JOURNAL_SCHEMA.md) into a frame and draws a vertical pipeline diagram
* in SMCL.  Two styles:
*   boxes : left spine of boxes, using-files boxed to the right of each join.
*           THIS IS THE DEFAULT.
*   rail  : compact vertical rail, one line per node.  A do-file that holds
*           more than one independent chain opens each later chain with a
*           short labelled rule ("-- new chain ---"), because a blank line
*           alone read as a continuation of the chain above it.
*
* Schema v2 notes
*   - column 9 is usingfile and is read BY NAME.  "using" is a reserved word
*     and must never be a column name again: with the old header
*     import delimited silently produced v9 and levelsof died r(100).
*     Every column is read by name and unknown extra columns are ignored, so a
*     later schema addition does not break this renderer.
*   - class=filter (keep if / drop if / keep / drop) draws a slim node on the
*     spine carrying the condition and, in run mode, the row change.  Most row
*     loss happens in filters, not in joins.
*   - severity (note|warn|stop) drives emphasis, but the "!!" text marker is
*     what carries the meaning: warn and stop BOTH print "!!" so the signal
*     survives a log file, a monochrome printout, and a reader who does not
*     distinguish colours.  stop is additionally bold.  Severity is never
*     encoded in colour alone.
*   - keytypes prints only where the two sides disagree, and not at all when
*     the flag text already names the mismatch.
*   - cover_master / cover_using print as one coverage line where present.
*   - lifecycle labels a sink box [saved] / [overwritten] / [tempfile].
*
* THE RECEIPT IS NOT IN THIS FILE ANY MORE.  It used to live here as
* _rsm_receipt.  The package now has exactly one receipt and mergemap.ado
* prints it (see the receipt section of src/mergemap.ado).  This file draws
* diagrams only; when the diagram auto-escalates it prints the defer notice
* and nothing else, because mergemap.ado has already printed the receipt.
*
* All journal-derived strings are displayed through string scalars, never
* macro substitution, so a literal ` or $ in a journal field survives.

program define _mm_rendersmcl
    version 16.0
    syntax using/ [, STYLE(string) LAYOUT(string) WRAP(integer 32) ///
        MAXnodes(integer 8) FORCEsmcl COMPact noCOUNTS noKEYS ///
        noTRANSFORMS noELLIPSIS]

    if `"`style'"' == "" local style boxes
    if !inlist("`style'", "boxes", "rail") {
        di as err "style() must be boxes or rail"
        exit 198
    }
    if `"`layout'"' == "" local layout vertical
    if !inlist("`layout'", "vertical", "horizontal") {
        di as err "layout() must be vertical or horizontal"
        exit 198
    }
    if `wrap' < 12 | `wrap' > 60 {
        di as err "wrap() must be between 12 and 60"
        exit 198
    }

    * ---- load journal into a frame --------------------------------------
    cap frame drop _rsmj
    frame create _rsmj
    qui frame _rsmj: import delimited using `"`using'"', ///
        delimiter(tab) varnames(1) stringcols(_all) clear
    frame _rsmj {
        cap confirm variable usingfile
        if _rc {
            di as err `"journal has no usingfile column: `using'"'
            di as err "_mm_rendersmcl needs journal schema v2 (see JOURNAL_SCHEMA.md)"
            exit 459
        }
        * every v2 column, by name; create any the journal does not carry so
        * that a shorter journal still renders, and normalise blanks to "."
        foreach v in seq dofile line class cmd subtype keys master usingfile ///
                     result n_in k_in n_using k_using n_out k_out ///
                     m1 m2 m3 m4 m5 dup_master dup_using force opts ///
                     loop_n loop_first loop_last severity keytypes ///
                     cover_master cover_using lifecycle flags {
            cap confirm variable `v'
            if _rc qui gen str1 `v' = "."
            else {
                cap confirm string variable `v'
                if _rc qui tostring `v', replace force
            }
            qui replace `v' = "." if strtrim(`v') == ""
        }
        qui replace severity = "note" if !inlist(strtrim(severity), "warn", "stop")

        local nev = _N
        qui count if strtrim(class) == "join"
        local ndraw = r(N)
        qui count if strtrim(class) == "filter"
        local ndraw = `ndraw' + r(N)
        if "`transforms'" != "notransforms" {
            qui count if strtrim(class) == "transform"
            local ndraw = `ndraw' + r(N)
        }
        qui count if strtrim(n_out) != "." | strtrim(n_in) != "."
        local runmode = r(N) > 0
    }
    if `nev' == 0 {
        di as txt "_mm_rendersmcl: journal is empty; nothing to draw"
        cap frame drop _rsmj
        exit
    }

    * ---- header ---------------------------------------------------------
    local mlab = cond(`runmode', "run mode", "scan mode - nothing executed")
    di as txt ""
    di as txt "mergemap diagram: `using'"

    * ---- auto-escalation ------------------------------------------------
    * the receipt has already been printed by mergemap.ado; all that belongs
    * here is the one-line notice deferring the DIAGRAM to the HTML renderer
    global MM_RSM_DEFER = 0
    if "`layout'" == "horizontal" {
        di as txt "(`mlab'; `ndraw' join/transform/filter events)"
        di as txt ""
        di as txt "note: layout(horizontal) cannot be drawn in SMCL;"
        di as txt "      the diagram is written as HTML instead."
        global MM_RSM_DEFER = 1
        cap frame drop _rsmj
        exit
    }
    if `ndraw' > `maxnodes' & "`forcesmcl'" == "" {
        di as txt "(`mlab'; `ndraw' join/transform/filter events)"
        di as txt ""
        di as txt "note: `ndraw' join/transform/filter events exceed maxnodes(`maxnodes');"
        di as txt "      a diagram this size is written as HTML instead."
        di as txt "      Use maxnodes(#) or forcesmcl to draw it in SMCL anyway."
        global MM_RSM_DEFER = 1
        cap frame drop _rsmj
        exit
    }

    * ---- dispatch --------------------------------------------------------
    di as txt "(`mlab'; style: `style')"
    local mode "`compact' `counts' `keys' `transforms' `ellipsis'"
    if "`style'" == "boxes" _rsm_boxes , wrap(`wrap') mode(`mode')
    else                    _rsm_rail  , wrap(`wrap') mode(`mode')
    cap frame drop _rsmj
end

* =======================================================================
* boxes style: left spine of boxes, using files boxed right of each join
* =======================================================================
program define _rsm_boxes
    syntax , WRAP(integer) [MODE(string)]
    local ls = c(linesize)
    if `ls' < 80 local ls 80
    * interior label width.  The cap is what keeps the using box (which starts
    * at column 42) inside the line: 34 at linesize 80, wider when there is
    * room, so wrap() is worth something at linesize 120.
    local lw = min(`wrap', max(20, `ls'-46))
    local nocnt = (ustrpos("`mode'","nocounts") > 0 | ustrpos("`mode'","compact") > 0)
    local nokey = ustrpos("`mode'","nokeys") > 0
    local notr  = ustrpos("`mode'","notransforms") > 0
    local noell = ustrpos("`mode'","noellipsis") > 0
    local cmpct = ustrpos("`mode'","compact") > 0

    local sp8 "        "                // spine {c |} sits at column 9
    local gap  = 32*" "                 // col 10-41; using box starts col 42
    local gap2 = 34*" "                 // col 10-43; drop bar at col 44
    local dc 44                         // column of the using-drop connector
    tempname USG RES OPT FLG LP1 LP2 L1 L2 KL LBL LN RC KT
    local lastdf ""
    local afterhdr 0

    frame _rsmj {
        local N = _N
        forvalues i = 1/`N' {
            local class = strtrim(class[`i'])
            local cmdw  = strtrim(cmd[`i'])
            local sub   = strtrim(subtype[`i'])
            local kys   = strtrim(keys[`i'])
            local dfl   = strtrim(dofile[`i'])
            local lpn   = strtrim(loop_n[`i'])
            local sev   = strtrim(severity[`i'])
            local lifec = strtrim(lifecycle[`i'])
            foreach c in n_in k_in n_using k_using n_out k_out ///
                         dup_master dup_using {
                local `c' = strtrim(`c'[`i'])
            }
            foreach c in n_in n_using n_out dup_master dup_using {
                _rsm_num ``c''
                local f`c' "`s(n)'"
            }
            scalar `USG' = strtrim(usingfile[`i'])
            scalar `RES' = strtrim(result[`i'])
            scalar `OPT' = strtrim(opts[`i'])
            scalar `FLG' = strtrim(flags[`i'])
            scalar `LP1' = strtrim(loop_first[`i'])
            scalar `LP2' = strtrim(loop_last[`i'])
            scalar `KT'  = strtrim(keytypes[`i'])
            if scalar(`OPT') == "." scalar `OPT' = ""
            if scalar(`FLG') == "." scalar `FLG' = ""

            * ---- do-file banner ----
            if "`dfl'" != "`lastdf'" {
                di as txt ""
                * the rule reaches at least the right edge of the boxes
                local hl = min(`ls', max(80, 46+`lw')) - ustrlen("`dfl'") - 2
                if `hl' < 3 local hl 3
                di as txt "`dfl' {hline `hl'}"
                di as txt ""
                local lastdf "`dfl'"
                local afterhdr 1
            }

            * ================= source =================
            if "`class'" == "source" {
                if !`afterhdr' di as txt ""
                scalar `LBL' = scalar(`USG')
                _rsm_fit `LBL' `lw'
                local extra ""
                if !`nocnt' & "`n_out'" != "." local extra "  `fn_out' x `k_out'"
                di as txt "  {c TLC}{hline `=`lw'+2'}{c TRC}"
                di as txt ("  {c |} " + scalar(`LBL') + " {c |}`extra'")
                di as txt "  {c BLC}{hline `=`lw'+2'}{c BRC}"
                _rsm_flag , sc(`FLG') sev(`sev') pre("      ") bare
            }

            * ================= join / frlink ==========
            else if "`class'" == "join" | ("`class'" == "link" & "`cmdw'" == "frlink") {
                if !`afterhdr' di as txt "`sp8'{c |}"
                local isloop = ("`lpn'" != "." & "`lpn'" != "")
                if `isloop' & !`noell' {
                    * stacked-cards box for a collapsed loop
                    scalar `L1' = "x`lpn': " + scalar(`LP1')
                    scalar `L2' = "  ... " + scalar(`LP2')
                    _rsm_fit `L1' `lw'
                    _rsm_fit `L2' `lw'
                    di as txt "`sp8'{c |}`gap' {c TLC}{hline `=`lw'+2'}{c TRC}"
                    di as txt "`sp8'{c |}`gap'{c TLC}{c BT}{hline `=`lw'+1'}{c TRC}{c |}"
                    di as txt ("`sp8'{c |}`gap'{c |} " + scalar(`L1') + " {c LT}{c BRC}")
                    di as txt ("`sp8'{c |}`gap'{c |} " + scalar(`L2') + " {c |}")
                    di as txt "`sp8'{c |}`gap'{c BLC}{hline `=`lw'+2'}{c BRC}"
                }
                else if `isloop' & `noell' {
                    * expanded (best effort: journal stores first/last only)
                    scalar `LBL' = scalar(`USG')
                    _rsm_fit `LBL' `lw'
                    di as txt "`sp8'{c |}`gap'{c TLC}{hline `=`lw'+2'}{c TRC}"
                    di as txt ("`sp8'{c |}`gap'{c |} " + scalar(`LBL') + " {c |}")
                    scalar `L1' = scalar(`LP1')
                    _rsm_fit `L1' `lw'
                    di as txt ("`sp8'{c |}`gap'{c |} " + scalar(`L1') + " {c |}")
                    if real("`lpn'") > 2 {
                        scalar `L1' = "  (`=real("`lpn'")-2' more)"
                        _rsm_fit `L1' `lw'
                        di as txt ("`sp8'{c |}`gap'{c |} " + scalar(`L1') + " {c |}")
                    }
                    scalar `L2' = scalar(`LP2')
                    _rsm_fit `L2' `lw'
                    di as txt ("`sp8'{c |}`gap'{c |} " + scalar(`L2') + " {c |}")
                    di as txt "`sp8'{c |}`gap'{c BLC}{hline `=`lw'+2'}{c BRC}"
                }
                else {
                    * plain using box
                    scalar `LBL' = scalar(`USG')
                    _rsm_fit `LBL' `lw'
                    di as txt "`sp8'{c |}`gap'{c TLC}{hline `=`lw'+2'}{c TRC}"
                    di as txt ("`sp8'{c |}`gap'{c |} " + scalar(`LBL') + " {c |}")
                    if !`nocnt' & "`n_using'" != "." {
                        scalar `KL' = "`fn_using' x `k_using'"
                        if !`nokey' & "`kys'" != "." ///
                            scalar `KL' = scalar(`KL') + "   key: `kys'"
                        _rsm_fit `KL' `lw'
                        di as txt ("`sp8'{c |}`gap'{c |} " + scalar(`KL') + " {c |}")
                    }
                    di as txt "`sp8'{c |}`gap'{c BLC}{hline `=`lw'+2'}{c BRC}"
                }
                * drop bar under the using box
                di as txt "`sp8'{c |}`gap2'{c |}"
                * annotation on the spine with connector from the using box
                local annot "`cmdw'"
                if "`sub'" != "." & "`sub'" != "" local annot "`annot' `sub'"
                if !`nokey' & "`kys'" != "." local annot "`annot' `kys'"
                if `isloop' local annot "`annot'  x`lpn' files"
                local maxa = `dc' - 17
                if ustrlen("`annot'") > `maxa' ///
                    local annot = usubstr("`annot'", 1, `maxa'-2) + ".."
                local nhl = `dc' - ustrlen("`annot'") - 15
                if `nhl' < 1 local nhl 1
                di as txt "`sp8'{c |}  `annot'  <{hline `nhl'}{c BRC}"
                * options sub-line; suppressed when a flag repeats it verbatim,
                * so that "update replace" is not printed twice
                _rsm_optdup , opt(`OPT') flg(`FLG')
                local optdup = `s(dup)'
                if !`cmpct' & !`optdup' {
                    if scalar(`OPT') != "" ///
                        di as txt ("`sp8'{c |}    " + scalar(`OPT'))
                }
                * key storage types, only where the two sides disagree
                if !`nokey' {
                    _rsm_types , kt(`KT') flg(`FLG')
                    if "`s(mm)'" != "" ///
                        di as res "`sp8'{c |}    !! key types differ: `s(mm)'"
                }
                * _merge breakdown (run mode only)
                if !`nocnt' & "`n_out'" != "." {
                    _rsm_bd , i(`i') opt(`OPT')
                    local bd "`s(bd)'"
                    if "`bd'" != "" ///
                        _rsm_bdwrap , txt(`"`bd'"') pre("`sp8'{c |}    ") w(`=`ls'-14')
                    * coverage shares, which counts alone do not give
                    _rsm_cov , i(`i')
                    if "`s(cov)'" != "" di as txt "`sp8'{c |}    `s(cov)'"
                    * duplicate-key info where keys are not unique by design
                    if "`sub'" == "m:m" | "`cmdw'" == "joinby" {
                        local dd ""
                        if "`dup_master'" != "." & "`dup_master'" != "0" ///
                            local dd "master +`fdup_master'"
                        if "`dup_using'" != "." & "`dup_using'" != "0" {
                            if "`dd'" != "" local dd "`dd'; "
                            local dd "`dd'using +`fdup_using'"
                        }
                        if "`dd'" != "" di as txt "`sp8'{c |}    dup keys: `dd'"
                    }
                    di as txt "`sp8'{c |}    -> `fn_out' x `k_out'"
                }
                _rsm_flag , sc(`FLG') sev(`sev') pre("`sp8'{c |}  ") bare
            }

            * ================= frget / fralias ========
            else if "`class'" == "link" {
                if !`afterhdr' di as txt "`sp8'{c |}"
                scalar `LN' = "`cmdw'"
                if scalar(`OPT') != "" ///
                    scalar `LN' = scalar(`LN') + " " + scalar(`OPT')
                if scalar(`USG') != "." & scalar(`USG') != "" ///
                    scalar `LN' = scalar(`LN') + "   <- " + scalar(`USG')
                _rsm_cap `LN' `=`ls'-12'
                di as txt ("`sp8'{c |}  " + scalar(`LN'))
                if !`nocnt' & "`n_out'" != "." ///
                    di as txt "`sp8'{c |}    -> `fn_out' x `k_out'"
                _rsm_flag , sc(`FLG') sev(`sev') pre("`sp8'{c |}  ") bare
            }

            * ================= filter =================
            * a slim node on the spine: most row loss happens here, not in
            * the joins, so it carries the condition and the row change
            else if "`class'" == "filter" {
                if !`afterhdr' {
                    di as txt "`sp8'{c |}"
                    di as txt "`sp8'v"
                }
                scalar `LBL' = "`cmdw'"
                if scalar(`OPT') != "" ///
                    scalar `LBL' = scalar(`LBL') + " " + scalar(`OPT')
                else if "`sub'" != "." & "`sub'" != "" ///
                    scalar `LBL' = scalar(`LBL') + " `sub'"
                _rsm_cap `LBL' `=`ls'-10'
                scalar `L1' = "  [ " + scalar(`LBL') + " ]"
                _rsm_rowchg , flg(`FLG') out(`RC')
                local marked = 0
                if scalar(`RC') != "" & inlist("`sev'","warn","stop") {
                    if usubstr(scalar(`RC'),1,2) != "!!" scalar `RC' = "!! " + scalar(`RC')
                    local marked 1
                }
                if `nocnt' scalar `RC' = ""
                if scalar(`RC') == "" {
                    di as txt (scalar(`L1'))
                }
                else if `marked' {
                    * a flagged row change gets its own highlighted line
                    di as txt (scalar(`L1'))
                    di as res ("      " + scalar(`RC'))
                }
                else if ustrlen(scalar(`L1')) + 2 + ustrlen(scalar(`RC')) <= `ls'-1 {
                    di as txt (scalar(`L1') + "  " + scalar(`RC'))
                }
                else {
                    di as txt (scalar(`L1'))
                    di as txt ("      " + scalar(`RC'))
                }
                * the node line already carries the marker when marked
                local barefl = cond(`marked', "", "bare")
                _rsm_flag , sc(`FLG') sev(`sev') pre("      ") `barefl'
            }

            * ================= transform ==============
            else if "`class'" == "transform" {
                if `notr' continue
                if !`afterhdr' {
                    di as txt "`sp8'{c |}"
                    di as txt "`sp8'v"
                }
                scalar `LBL' = "`cmdw'"
                if "`sub'" != "." & "`sub'" != "" scalar `LBL' = scalar(`LBL') + " `sub'"
                if "`cmdw'" == "duplicates" & "`kys'" != "." & !`nokey' ///
                    scalar `LBL' = scalar(`LBL') + " `kys'"
                if scalar(`OPT') != "" ///
                    scalar `LBL' = scalar(`LBL') + " " + scalar(`OPT')
                local tw = min(max(ustrlen(scalar(`LBL')), 12), 44)
                _rsm_fit `LBL' `tw'
                local extra ""
                if !`nocnt' & "`n_out'" != "." local extra "  `fn_in' -> `fn_out' obs"
                di as txt "  {c TLC}{hline `=`tw'+2'}{c TRC}"
                di as txt ("  {c |} " + scalar(`LBL') + " {c |}`extra'")
                di as txt "  {c BLC}{hline `=`tw'+2'}{c BRC}"
                _rsm_flag , sc(`FLG') sev(`sev') pre("      ") bare
            }

            * ================= save ===================
            else if "`class'" == "save" {
                if !`afterhdr' {
                    di as txt "`sp8'{c |}"
                    di as txt "`sp8'v"
                }
                scalar `LBL' = scalar(`RES')
                _rsm_fit `LBL' `lw'
                local mark "[saved]"
                if "`lifec'" == "overwrite" local mark "[overwritten]"
                if "`sub'" == "tempfile" local mark "[tempfile]"
                local extra "  `mark'"
                if !`nocnt' & "`n_out'" != "." local extra "  `fn_out' x `k_out'  `mark'"
                di as txt "  {c TLC}{hline `=`lw'+2'}{c TRC}"
                di as txt ("  {c |} " + scalar(`LBL') + " {c |}`extra'")
                di as txt "  {c BLC}{hline `=`lw'+2'}{c BRC}"
                if scalar(`FLG') == "tempfile" scalar `FLG' = ""
                _rsm_flag , sc(`FLG') sev(`sev') pre("      ") bare
            }

            * ================= flow / note ============
            else {
                if !`afterhdr' di as txt "`sp8'{c |}"
                scalar `LN' = "(`cmdw'"
                if scalar(`OPT') != "" ///
                    scalar `LN' = scalar(`LN') + " " + scalar(`OPT')
                scalar `LN' = scalar(`LN') + ")"
                _rsm_cap `LN' `=`ls'-12'
                di as txt ("`sp8'{c |}  " + scalar(`LN'))
                _rsm_flag , sc(`FLG') sev(`sev') pre("`sp8'{c |}  ") bare
            }
            local afterhdr 0
        }
    }
    di as txt ""
end

* =======================================================================
* rail style: compact vertical rail, one line per node
* =======================================================================
program define _rsm_rail
    syntax , WRAP(integer) [MODE(string)]
    local ls = c(linesize)
    if `ls' < 80 local ls 80
    local nocnt = (ustrpos("`mode'","nocounts") > 0 | ustrpos("`mode'","compact") > 0)
    local nokey = ustrpos("`mode'","nokeys") > 0
    local notr  = ustrpos("`mode'","notransforms") > 0
    local noell = ustrpos("`mode'","noellipsis") > 0
    local cmpct = ustrpos("`mode'","compact") > 0

    * total width of the "new chain" break rule.  Fixed, not linesize-driven:
    * it is half the 80-column do-file banner at every linesize, so the two
    * rules can never be confused for one another.
    local chw = 40

    tempname USG RES OPT FLG LP1 LP2 LN LBL RC KT
    local lastdf ""
    local anynode 0
    frame _rsmj {
        local N = _N
        forvalues i = 1/`N' {
            local class = strtrim(class[`i'])
            local cmdw  = strtrim(cmd[`i'])
            local sub   = strtrim(subtype[`i'])
            local kys   = strtrim(keys[`i'])
            local dfl   = strtrim(dofile[`i'])
            local lpn   = strtrim(loop_n[`i'])
            local sev   = strtrim(severity[`i'])
            local lifec = strtrim(lifecycle[`i'])
            foreach c in n_in k_in n_using k_using n_out k_out ///
                         dup_master dup_using {
                local `c' = strtrim(`c'[`i'])
            }
            foreach c in n_in n_using n_out dup_master dup_using {
                _rsm_num ``c''
                local f`c' "`s(n)'"
            }
            scalar `USG' = strtrim(usingfile[`i'])
            scalar `RES' = strtrim(result[`i'])
            scalar `OPT' = strtrim(opts[`i'])
            scalar `FLG' = strtrim(flags[`i'])
            scalar `LP1' = strtrim(loop_first[`i'])
            scalar `LP2' = strtrim(loop_last[`i'])
            scalar `KT'  = strtrim(keytypes[`i'])
            if scalar(`OPT') == "." scalar `OPT' = ""
            if scalar(`FLG') == "." scalar `FLG' = ""

            * is this node the end of its chain?  a chain ends at the last
            * event, at the next source (a new dataset is read), or at a
            * change of do-file -- all three used to be invisible in rail
            local terminal = 0
            if `i' == `N' local terminal 1
            else if strtrim(class[`i'+1]) == "source" local terminal 1
            else if strtrim(dofile[`i'+1]) != "`dfl'" local terminal 1

            * ---- do-file banner: ruled, like the boxes style, so the break
            * ---- between do-files is visible in a wall of rail lines ----
            if "`dfl'" != "`lastdf'" {
                di as txt ""
                local hl = min(`ls',80) - ustrlen("`dfl'") - 2
                if `hl' < 3 local hl 3
                di as txt "`dfl' {hline `hl'}"
                local lastdf "`dfl'"
                local anynode 0
            }
            * ---- a second, independent chain inside the SAME do-file ------
            * a blank line was the only signal and readers ran the two chains
            * together, so print a labelled rule.  It is built from {hline}
            * (never a Unicode box character) so it survives translation to
            * ASCII, and it is deliberately shorter than the do-file banner
            * above it: full-width rule = new do-file, short rule = new chain
            * inside that do-file.
            if "`class'" == "source" & `anynode' {
                di as txt ""
                di as txt "{hline 2} new chain {hline `=`chw'-13'}"
            }

            if "`class'" == "source" {
                scalar `LN' = scalar(`USG')
                if !`nocnt' & "`n_out'" != "." ///
                    scalar `LN' = scalar(`LN') + "  (`fn_out' x `k_out')"
                _rsm_cap `LN' `=`ls'-5'
                di as res ("{c TLC}{hline 2} " + scalar(`LN'))
                _rsm_flag , sc(`FLG') sev(`sev') pre("{c |}      ") bare
            }
            else if "`class'" == "join" | "`class'" == "link" {
                local tick = cond(`terminal', "{c BLC}", "{c LT}")
                local isloop = ("`lpn'" != "." & "`lpn'" != "")
                local annot "`cmdw'"
                if "`sub'" != "." & "`sub'" != "" local annot "`annot' `sub'"
                if !`nokey' & "`kys'" != "." local annot "`annot' `kys'"
                if "`cmdw'" == "frget" | "`cmdw'" == "fralias" {
                    * view-style link: indented dim line, no tick
                    scalar `LN' = "`cmdw'"
                    if scalar(`OPT') != "" ///
                        scalar `LN' = scalar(`LN') + " " + scalar(`OPT')
                    if scalar(`USG') != "." & scalar(`USG') != "" ///
                        scalar `LN' = scalar(`LN') + "  <- " + scalar(`USG')
                    _rsm_cap `LN' `=`ls'-6'
                    di as txt ("{c |}   " + scalar(`LN'))
                }
                else if `isloop' {
                    * the obs count comes from the breakdown line below, so it
                    * is not repeated here
                    scalar `LN' = "`annot'  x`lpn': " + scalar(`LP1') + " ... " + scalar(`LP2')
                    _rsm_cap `LN' `=`ls'-5'
                    di as res ("`tick'{hline 2} " + scalar(`LN'))
                }
                else {
                    scalar `LN' = "`annot' <- " + scalar(`USG')
                    _rsm_cap `LN' `=`ls'-5'
                    di as res ("`tick'{hline 2} " + scalar(`LN'))
                }
                local rpre = cond(`terminal', "       ", "{c |}      ")
                * options sub-line; suppressed when a flag on this same event
                * already carries the option text (loose = containment, not
                * equality, so "force" gives way to "!! force used").  The
                * flagged line is the one that matters, so it is the one kept.
                _rsm_optdup , opt(`OPT') flg(`FLG') loose
                local optdup = `s(dup)'
                if !`cmpct' & !`optdup' {
                    if scalar(`OPT') != "" & !inlist("`cmdw'","frget","fralias") ///
                        di as txt (`"`rpre'"' + scalar(`OPT'))
                }
                if !`nokey' & !inlist("`cmdw'","frget","fralias") {
                    _rsm_types , kt(`KT') flg(`FLG')
                    if "`s(mm)'" != "" ///
                        di as res `"`rpre'!! key types differ: `s(mm)'"'
                }
                if !`nocnt' & "`n_out'" != "." & !inlist("`cmdw'","frget","fralias") {
                    _rsm_bd , i(`i') opt(`OPT')
                    local bd "`s(bd)'"
                    if "`bd'" != "" ///
                        _rsm_bdwrap , txt(`"`bd'"') pre("`rpre'") w(`=`ls'-8')
                    _rsm_cov , i(`i')
                    if "`s(cov)'" != "" di as txt `"`rpre'`s(cov)'"'
                    if "`sub'" == "m:m" | "`cmdw'" == "joinby" {
                        local dd ""
                        if "`dup_master'" != "." & "`dup_master'" != "0" ///
                            local dd "master +`fdup_master'"
                        if "`dup_using'" != "." & "`dup_using'" != "0" {
                            if "`dd'" != "" local dd "`dd'; "
                            local dd "`dd'using +`fdup_using'"
                        }
                        if "`dd'" != "" di as txt `"`rpre'dup keys: `dd'"'
                    }
                    di as txt "`rpre'-> `fn_out' x `k_out'"
                }
                _rsm_flag , sc(`FLG') sev(`sev') pre("`rpre'") bare
            }
            else if "`class'" == "filter" {
                * slim node: brackets mark a filter, the row change follows
                local tick = cond(`terminal', "{c BLC}{hline 2} ", "{c |}   ")
                local rpre = cond(`terminal', "       ", "{c |}      ")
                scalar `LBL' = "`cmdw'"
                if scalar(`OPT') != "" ///
                    scalar `LBL' = scalar(`LBL') + " " + scalar(`OPT')
                else if "`sub'" != "." & "`sub'" != "" ///
                    scalar `LBL' = scalar(`LBL') + " `sub'"
                _rsm_cap `LBL' `=`ls'-12'
                scalar `LN' = "[ " + scalar(`LBL') + " ]"
                _rsm_rowchg , flg(`FLG') out(`RC')
                local marked = 0
                if scalar(`RC') != "" & inlist("`sev'","warn","stop") {
                    if usubstr(scalar(`RC'),1,2) != "!!" scalar `RC' = "!! " + scalar(`RC')
                    local marked 1
                }
                if `nocnt' scalar `RC' = ""
                if scalar(`RC') == "" {
                    di as txt ("`tick'" + scalar(`LN'))
                }
                else if `marked' {
                    di as txt ("`tick'" + scalar(`LN'))
                    di as res (`"`rpre'"' + scalar(`RC'))
                }
                else if ustrlen(scalar(`LN')) + 8 + ustrlen(scalar(`RC')) <= `ls'-1 {
                    di as txt ("`tick'" + scalar(`LN') + "  " + scalar(`RC'))
                }
                else {
                    di as txt ("`tick'" + scalar(`LN'))
                    di as txt (`"`rpre'"' + scalar(`RC'))
                }
                * the node line already carries the marker when marked
                local barefl = cond(`marked', "", "bare")
                _rsm_flag , sc(`FLG') sev(`sev') pre("`rpre'") `barefl'
            }
            else if "`class'" == "transform" {
                if `notr' continue
                local tick = cond(`terminal', "{c BLC}{hline 2} ", "{c |}   ")
                local rpre = cond(`terminal', "       ", "{c |}      ")
                scalar `LN' = "`cmdw'"
                if "`sub'" != "." & "`sub'" != "" scalar `LN' = scalar(`LN') + " `sub'"
                if "`cmdw'" == "duplicates" & "`kys'" != "." & !`nokey' ///
                    scalar `LN' = scalar(`LN') + " `kys'"
                if scalar(`OPT') != "" ///
                    scalar `LN' = scalar(`LN') + " " + scalar(`OPT')
                if !`nocnt' & "`n_out'" != "." ///
                    scalar `LN' = scalar(`LN') + "  [`fn_in' -> `fn_out' obs]"
                _rsm_cap `LN' `=`ls'-6'
                di as txt ("`tick'" + scalar(`LN'))
                _rsm_flag , sc(`FLG') sev(`sev') pre("`rpre'") bare
            }
            else if "`class'" == "save" {
                local tick = cond(`terminal', "{c BLC}", "{c LT}")
                local rpre = cond(`terminal', "       ", "{c |}      ")
                scalar `LN' = scalar(`RES')
                local mark "  [saved]"
                if "`lifec'" == "overwrite" local mark "  [overwritten]"
                if "`sub'" == "tempfile" local mark "  [tempfile]"
                scalar `LN' = scalar(`LN') + "`mark'"
                if !`nocnt' & "`n_out'" != "." ///
                    scalar `LN' = scalar(`LN') + "  (`fn_out' x `k_out')"
                _rsm_cap `LN' `=`ls'-5'
                di as res ("`tick'{hline 2} " + scalar(`LN'))
                if scalar(`FLG') == "tempfile" scalar `FLG' = ""
                _rsm_flag , sc(`FLG') sev(`sev') pre("`rpre'") bare
            }
            else {
                local tick = cond(`terminal', "{c BLC}{hline 2} ", "{c |}   ")
                local rpre = cond(`terminal', "       ", "{c |}      ")
                scalar `LN' = "(`cmdw'"
                if scalar(`OPT') != "" ///
                    scalar `LN' = scalar(`LN') + " " + scalar(`OPT')
                scalar `LN' = scalar(`LN') + ")"
                _rsm_cap `LN' `=`ls'-6'
                di as txt ("`tick'" + scalar(`LN'))
                _rsm_flag , sc(`FLG') sev(`sev') pre("`rpre'") bare
            }
            local anynode 1
        }
    }
    di as txt ""
end

* =======================================================================
* receipt: REMOVED.  _rsm_receipt used to print a compact ruled table here.
* The package now has exactly one receipt, the lighter aligned one, and it
* lives in src/mergemap.ado (Agent A).  _mm_rendersmcl draws diagrams only.
* =======================================================================

* ---- helpers ----------------------------------------------------------

* format a count string with thousands separators (safe: digits only)
program define _rsm_num, sclass
    args s
    if "`s'" == "." | "`s'" == "" local out ""
    else {
        local x : display %20.0fc real("`s'")
        local out = strtrim("`x'")
    }
    sreturn local n "`out'"
end

* middle-ellipsize a string scalar to width w, then right-pad to w
program define _rsm_fit
    args sc w
    if ustrlen(scalar(`sc')) > `w' {
        local h = ceil((`w'-3)/2)
        local t = `w' - 3 - `h'
        scalar `sc' = usubstr(scalar(`sc'), 1, `h') + "..." ///
                    + usubstr(scalar(`sc'), -`t', .)
    }
    scalar `sc' = scalar(`sc') + (`w'-ustrlen(scalar(`sc')))*" "
end

* ellipsize a string scalar to width w, no padding; middle-ellipsis by
* default, trailing ".." when a third argument "end" is given
program define _rsm_cap
    args sc w how
    if ustrlen(scalar(`sc')) > `w' {
        if "`how'" == "end" {
            scalar `sc' = usubstr(scalar(`sc'), 1, `w'-2) + ".."
        }
        else {
            local h = ceil((`w'-3)/2)
            local t = `w' - 3 - `h'
            scalar `sc' = usubstr(scalar(`sc'), 1, `h') + "..." ///
                        + usubstr(scalar(`sc'), -`t', .)
        }
    }
end

* print "; "-separated flag pieces, one per line.
*   - severity warn and stop BOTH get the "!!" text marker, so severity is
*     never carried by colour alone; a piece that already has "!!" keeps it
*   - severity stop is additionally bold
*   - bare: print the marker even when the event carries no flag text, so a
*     severity cannot go silent.  Callers that have already consumed the flag
*     text into a node line omit it.
program define _rsm_flag
    syntax , SC(name) [PRE(string) SEV(string) BARE]
    local warn = inlist("`sev'", "warn", "stop")
    local stop = ("`sev'" == "stop")
    if scalar(`sc') == "." | scalar(`sc') == "" {
        if `warn' & "`bare'" != "" di as res `"`pre'!! `sev'"'
        exit
    }
    tempname piece
    while ustrlen(scalar(`sc')) > 0 {
        local p = ustrpos(scalar(`sc'), "; ")
        if `p' == 0 {
            scalar `piece' = scalar(`sc')
            scalar `sc' = ""
        }
        else {
            scalar `piece' = usubstr(scalar(`sc'), 1, `p'-1)
            scalar `sc' = usubstr(scalar(`sc'), `p'+2, .)
        }
        if `warn' & usubstr(scalar(`piece'), 1, 2) != "!!" ///
            scalar `piece' = "!! " + scalar(`piece')
        if usubstr(scalar(`piece'), 1, 2) == "!!" {
            if `stop' & ustrpos(scalar(`piece'),"{") == 0 & ///
                        ustrpos(scalar(`piece'),"}") == 0 {
                di as res (`"`pre'"' + "{bf:" + scalar(`piece') + "}")
            }
            else di as res (`"`pre'"' + scalar(`piece'))
        }
        else di as txt (`"`pre'"' + scalar(`piece'))
    }
end

* greedy wrap of a "; "-separated breakdown (safe text) at width w
program define _rsm_bdwrap
    syntax , TXT(string) PRE(string) [W(integer 66)]
    local rest `"`txt'"'
    if `w' < 20 local w 20
    while ustrlen(`"`rest'"') > `w' {
        local cut 0
        local p = ustrpos(`"`rest'"', "; ")
        while `p' > 0 & `p' <= `w' {
            local cut = `p'
            local nxt = ustrpos(usubstr(`"`rest'"', `p'+1, .), "; ")
            if `nxt' == 0 local p 0
            else local p = `p' + `nxt'
        }
        if `cut' == 0 {
            di as txt (`"`pre'"' + usubstr(`"`rest'"', 1, `w'))
            local rest = usubstr(`"`rest'"', `w'+1, .)
        }
        else {
            di as txt (`"`pre'"' + usubstr(`"`rest'"', 1, `cut'-1) + ";")
            local rest = strtrim(usubstr(`"`rest'"', `cut'+1, .))
        }
    }
    if ustrlen(`"`rest'"') > 0 di as txt (`"`pre'"' + `"`rest'"')
end

* extract the keep() categories from an opts scalar into s(keep)
program define _rsm_keepset, sclass
    syntax , OPT(name)
    local out ""
    local p = ustrpos(scalar(`opt'), "keep(")
    if `p' > 0 {
        tempname rest
        scalar `rest' = usubstr(scalar(`opt'), `p'+5, .)
        local q = ustrpos(scalar(`rest'), ")")
        if `q' > 1 local out = usubstr(scalar(`rest'), 1, `q'-1)
    }
    sreturn local keep "`out'"
end

* build the join breakdown line for row i into s(bd); counts only, so the
* result is always safe to carry in a local
program define _rsm_bd, sclass
    syntax , I(integer) OPT(name)
    local cmdw = strtrim(cmd[`i'])
    foreach c in n_using m1 m2 m3 m4 m5 {
        local `c' = strtrim(`c'[`i'])
        _rsm_num ``c''
        local f`c' "`s(n)'"
    }
    local bd ""
    if "`cmdw'" == "merge" {
        _rsm_keepset , opt(`opt')
        local kp "`s(keep)'"
        if "`m3'" != "." local bd "`bd'matched `fm3'; "
        if "`m1'" != "." & ("`m1'" != "0" | "`m3'" == "0") {
            if "`kp'" != "" & !ustrpos(" `kp' ", " 1 ") ///
                local bd "`bd'master-only (`fm1' dropped); "
            else local bd "`bd'master-only `fm1'; "
        }
        if "`m2'" != "." & "`m2'" != "0" {
            if "`kp'" != "" & !ustrpos(" `kp' ", " 2 ") ///
                local bd "`bd'using-only (`fm2' dropped); "
            else local bd "`bd'using-only `fm2'; "
        }
        if "`m4'" != "." & "`m4'" != "0" local bd "`bd'missing-updated `fm4'; "
        if "`m5'" != "." & "`m5'" != "0" local bd "`bd'conflicts-updated `fm5'; "
    }
    else if "`cmdw'" == "append" {
        if "`n_using'" != "." local bd "+`fn_using' obs; "
    }
    else if "`cmdw'" == "frlink" {
        if "`m3'" != "." local bd "`bd'matched `fm3'; "
        if "`m1'" != "." & "`m1'" != "0" local bd "`bd'unmatched `fm1'; "
    }
    if "`bd'" != "" local bd = usubstr("`bd'", 1, ustrlen("`bd'")-2)
    sreturn local bd "`bd'"
end

* coverage shares for row i into s(cov); percentages only, safe in a local
program define _rsm_cov, sclass
    syntax , I(integer)
    local cm = strtrim(cover_master[`i'])
    local cu = strtrim(cover_using[`i'])
    local t ""
    if "`cm'" != "." & "`cm'" != "" local t "`cm'% of master matched"
    if "`cu'" != "." & "`cu'" != "" {
        if "`t'" != "" local t "`t', "
        local t "`t'`cu'% of using used"
    }
    if "`t'" != "" local t "coverage: `t'"
    sreturn local cov "`t'"
end

* keytypes -> s(mm): the "name: A vs B" pieces where A and B disagree.
* A mismatch the flag text already names is dropped, so the same fact is
* never printed twice.
program define _rsm_types, sclass
    syntax , KT(name) [FLG(name)]
    local out ""
    if scalar(`kt') != "." & scalar(`kt') != "" {
        tempname s p
        scalar `s' = scalar(`kt')
        while ustrlen(scalar(`s')) > 0 {
            local q = ustrpos(scalar(`s'), "; ")
            if `q' == 0 {
                scalar `p' = scalar(`s')
                scalar `s' = ""
            }
            else {
                scalar `p' = usubstr(scalar(`s'), 1, `q'-1)
                scalar `s' = usubstr(scalar(`s'), `q'+2, .)
            }
            local c = ustrpos(scalar(`p'), ": ")
            if `c' > 1 {
                local nm = strtrim(usubstr(scalar(`p'), 1, `c'-1))
                scalar `p' = strtrim(usubstr(scalar(`p'), `c'+2, .))
                local v = ustrpos(scalar(`p'), " vs ")
                if `v' > 1 {
                    local ta = strtrim(usubstr(scalar(`p'), 1, `v'-1))
                    local tb = strtrim(usubstr(scalar(`p'), `v'+4, .))
                    if "`ta'" != "`tb'" {
                        local dup 0
                        if "`flg'" != "" {
                            if ustrpos(ustrlower(scalar(`flg')), ustrlower("`nm'")) > 0 & ///
                               ustrpos(ustrlower(scalar(`flg')), ustrlower("`ta'")) > 0 & ///
                               ustrpos(ustrlower(scalar(`flg')), ustrlower("`tb'")) > 0 ///
                                local dup 1
                        }
                        if !`dup' {
                            if "`out'" != "" local out "`out'; "
                            local out "`out'`nm' `ta' vs `tb'"
                        }
                    }
                }
            }
        }
    }
    sreturn local mm "`out'"
end

* s(dup)=1 when some "; "-piece of the SAME event's flags already carries the
* opts text, so the plain options sub-line would only restate the flag.  The
* caller then drops the options sub-line and keeps the flagged version, which
* is the line that carries the "!!" marker and therefore the meaning.
*
* Two tests, because the two styles want different strictness:
*   default : the piece must EQUAL the opts text.  boxes uses this.
*   loose   : the piece need only CONTAIN the opts text, matched
*             case-insensitively after trimming and only at token boundaries.
*             rail uses this, so that
*                 opts "force"               vs flag "!! force used"
*                 opts "update replace"      vs flag "!! update replace"
*             both collapse to the flag alone, while
*                 opts "keep(1 3) nogenerate" vs flag "2 using-only dropped
*                 by keep(1 3)"
*             does NOT collapse: the options string names nogenerate, which
*             the flag never mentions, so it still prints.  The boundary test
*             is what keeps this conservative -- "force" is not deduplicated
*             by a flag that merely says "enforced".
program define _rsm_optdup, sclass
    syntax , OPT(name) FLG(name) [LOOSE]
    local dup 0
    if scalar(`opt') != "." & scalar(`opt') != "" & ///
       scalar(`flg') != "." & scalar(`flg') != "" {
        tempname s p o t
        scalar `o' = ustrlower(strtrim(scalar(`opt')))
        local ol = ustrlen(scalar(`o'))
        scalar `s' = scalar(`flg')
        while ustrlen(scalar(`s')) > 0 & `dup' == 0 {
            local q = ustrpos(scalar(`s'), "; ")
            if `q' == 0 {
                scalar `p' = scalar(`s')
                scalar `s' = ""
            }
            else {
                scalar `p' = usubstr(scalar(`s'), 1, `q'-1)
                scalar `s' = usubstr(scalar(`s'), `q'+2, .)
            }
            if usubstr(scalar(`p'), 1, 2) == "!!" ///
                scalar `p' = strtrim(usubstr(scalar(`p'), 3, .))
            scalar `p' = ustrlower(strtrim(scalar(`p')))
            if "`loose'" == "" {
                if scalar(`p') == scalar(`o') local dup 1
            }
            else if `ol' > 0 {
                * walk every occurrence; accept the first one whose two ends
                * both fall on a token boundary
                local base 0
                scalar `t' = scalar(`p')
                local at = ustrpos(scalar(`t'), scalar(`o'))
                while `at' > 0 & `dup' == 0 {
                    local hit = `base' + `at'
                    local ok 1
                    if `hit' > 1 {
                        if ustrregexm(usubstr(scalar(`p'), `hit'-1, 1), ///
                                      "[0-9a-z_]") local ok 0
                    }
                    local nxt = `hit' + `ol'
                    if `nxt' <= ustrlen(scalar(`p')) {
                        if ustrregexm(usubstr(scalar(`p'), `nxt', 1), ///
                                      "[0-9a-z_]") local ok 0
                    }
                    if `ok' local dup 1
                    else {
                        local base = `hit'
                        scalar `t' = usubstr(scalar(`p'), `base'+1, .)
                        local at = ustrpos(scalar(`t'), scalar(`o'))
                    }
                }
            }
        }
    }
    sreturn local dup `dup'
end

* move a leading tidylog row-change piece out of the flags scalar into out,
* so a filter node can carry it inline instead of repeating it as a flag
program define _rsm_rowchg
    syntax , FLG(name) OUT(name)
    scalar `out' = ""
    if scalar(`flg') == "." | scalar(`flg') == "" exit
    tempname p t
    local q = ustrpos(scalar(`flg'), "; ")
    if `q' == 0 scalar `p' = scalar(`flg')
    else        scalar `p' = usubstr(scalar(`flg'), 1, `q'-1)
    scalar `t' = scalar(`p')
    if usubstr(scalar(`t'), 1, 2) == "!!" scalar `t' = strtrim(usubstr(scalar(`t'), 3, .))
    if ustrpos(ustrlower(scalar(`t')), "removed ") == 1 | ///
       ustrpos(ustrlower(scalar(`t')), "kept ") == 1 | ///
       ustrpos(ustrlower(scalar(`t')), "no rows") == 1 | ///
       ustrpos(ustrlower(scalar(`t')), "dropped ") == 1 {
        scalar `out' = scalar(`p')
        if `q' == 0 scalar `flg' = ""
        else        scalar `flg' = usubstr(scalar(`flg'), `q'+2, .)
    }
end
