*! version 0.5.5  09nov2026  Eric Booth
*! _mm_export -- the journal as a dataset, for your own auditing.  Count and
*! percentage columns arrive numeric; text columns stay text.  The point is
*! that the record of your joins is data like any other: keep the flagged
*! rows, merge journals from different runs, graph coverage over time.
*!
*! Formats: dta (default), csv, xlsx.  The format follows the extension on
*! saving() when format() is not given.  The workbook has three sheets:
*!   events   every event and every column -- the receipt with nothing hidden
*!   joins    one row per join, with the counts, _merge breakdown, coverage
*!   filters  one row per keep/drop, with rows removed and percent removed
*! so the map can hide the filters while the workbook still has all of them,
*! sortable and filterable in Excel.
*!
*! paths() and root() shorten the file labels the same way they do for
*! mergemap draw, so a ledger can be written without this machine's folder
*! layout in it.

program define _mm_export, rclass
    version 16
    syntax [anything(name=jspec)] [, Format(string) SAVing(string) replace ///
        PATHS(string) ROOT(string asis)]
    local format = strlower("`format'")
    if "`format'" == "" {
        local lo = strlower(`"`saving'"')
        if substr(`"`lo'"', -4, .) == ".dta"       local format "dta"
        else if substr(`"`lo'"', -4, .) == ".csv"  local format "csv"
        else if substr(`"`lo'"', -5, .) == ".xlsx" local format "xlsx"
        else if substr(`"`lo'"', -4, .) == ".xls"  local format "xlsx"
        else local format "dta"
    }
    if inlist("`format'", "excel", "xls") local format "xlsx"
    if !inlist("`format'", "dta", "csv", "xlsx") {
        di as err "mergemap export: format() must be dta, csv, or xlsx"
        exit 198
    }
    _mm_jresolve `jspec'
    local jfile `"`s(jfile)'"'
    if `"`saving'"' == "" local saving "mergemap_journal.`format'"
    if "`format'" == "xlsx" & strlower(substr(`"`saving'"', -5, .)) != ".xlsx" ///
        & strlower(substr(`"`saving'"', -4, .)) != ".xls" {
        local saving `"`saving'.xlsx"'
    }
    * save and export delimited add .dta or .csv to a name with no
    * extension; add it here so the message and r(file) name the file
    if inlist("`format'", "dta", "csv") {
        local base `"`saving'"'
        local p = max(strrpos(`"`base'"', "/"), strrpos(`"`base'"', char(92)))
        if `p' local base = substr(`"`base'"', `p' + 1, .)
        if strpos(`"`base'"', ".") == 0 local saving `"`saving'.`format'"'
    }
    * Stata 19 writes the first sheet of a workbook whose path holds a
    * non-ASCII character but cannot reopen it for the next one (r(603);
    * plain export excel fails the same way).  Such a workbook is built
    * under an ASCII temporary name and copied into place at the end.
    local xfinal `"`saving'"'
    if "`format'" == "xlsx" & ustrlen(`"`saving'"') != strlen(`"`saving'"') {
        capture confirm file `"`xfinal'"'
        if !_rc & "`replace'" == "" {
            di as err `"mergemap export: file `xfinal' already exists; specify replace"'
            exit 602
        }
        tempfile xtmp
        local saving `"`xtmp'.xlsx"'
    }

    * shorten the labels first, if asked; the cut is a tempfile
    local src `"`jfile'"'
    if `"`paths'"' != "" | `"`root'"' != "" {
        local po ""
        if `"`paths'"' != "" local po `"`po' paths(`paths')"'
        if `"`root'"'  != "" local po `"`po' root(`root')"'
        _mm_jcut using `"`jfile'"', `po' quietly
        local src `"`s(jfile)'"'
    }

    _mm_jload using `"`src'"', frame(_mmexp)
    frame _mmexp {
        * numbers as numbers; "." was the journal's missing all along
        foreach v in seq line n_in k_in n_using k_using n_out k_out       ///
            m1 m2 m3 m4 m5 dup_master dup_using force loop_n             ///
            cover_master cover_using {
            capture confirm variable `v'
            if !_rc quietly destring `v', replace force
        }
        quietly count
        local N = r(N)
        if "`format'" == "dta" {
            quietly save `"`saving'"', `replace'
        }
        else if "`format'" == "csv" {
            quietly export delimited using `"`saving'"', `replace'
        }
        else {
            * ---- sheet 1: every event, every column ----
            local nc_events = c(k)
            quietly export excel using `"`saving'"', sheet("events")      ///
                firstrow(variables) `replace'
            * ---- sheet 2: the joins ----
            quietly count if inlist(class, "join", "link")
            local nj = r(N)
            capture frame drop _mmexpj
            frame copy _mmexp _mmexpj
            frame _mmexpj {
                quietly keep if inlist(class, "join", "link")
                local keepv ""
                foreach v in seq dofile line cmd subtype keys master      ///
                    usingfile n_in n_using n_out m1 m2 m3 m4 m5           ///
                    dup_master dup_using keytypes cover_master            ///
                    cover_using force opts loop_n loop_first loop_last    ///
                    severity flags {
                    capture confirm variable `v'
                    if !_rc local keepv "`keepv' `v'"
                }
                quietly keep `keepv'
                quietly order `keepv'
                local nc_joins : word count `keepv'
                _mm_xsheet `"`saving'"' joins `"`keepv'"'
            }
            frame drop _mmexpj
            * ---- sheet 3: the filters, with what each one removed ----
            quietly count if class == "filter"
            local nf = r(N)
            capture frame drop _mmexpf
            frame copy _mmexp _mmexpf
            frame _mmexpf {
                quietly keep if class == "filter"
                quietly gen str9 kind = cond(subtype == "if", "rows", "variables")
                label variable kind "rows (keep if / drop if) or variables (keep / drop varlist)"
                quietly gen double removed = n_in - n_out
                quietly gen double pct_removed = 100 * removed / n_in if n_in > 0
                quietly replace removed = . if kind == "variables"
                quietly replace pct_removed = . if kind == "variables"
                rename opts condition
                local keepv ""
                foreach v in seq dofile line cmd kind condition n_in n_out ///
                    removed pct_removed k_in k_out loop_n loop_first        ///
                    loop_last severity flags {
                    capture confirm variable `v'
                    if !_rc local keepv "`keepv' `v'"
                }
                quietly keep `keepv'
                quietly order `keepv'
                local nc_filters : word count `keepv'
                _mm_xsheet `"`saving'"' filters `"`keepv'"'
            }
            frame drop _mmexpf
            * a bold header row on each sheet, so it reads as a table; no
            * harm done if this Stata cannot style cells
            * only each sheet's own header cells: styling empty ones makes
            * import excel read them back as extra variables
            foreach sh in events joins filters {
                local n = `nc_`sh''
                if `n' <= 26 local hc = char(64 + `n')
                else local hc = char(64 + floor((`n' - 1) / 26)) + char(65 + mod(`n' - 1, 26))
                capture putexcel set `"`saving'"', sheet("`sh'") modify
                if !_rc {
                    capture putexcel A1:`hc'1, bold
                    capture putexcel clear
                }
            }
            if `"`xfinal'"' != `"`saving'"' {
                copy `"`saving'"' `"`xfinal'"', replace
                capture erase `"`saving'"'
                local saving `"`xfinal'"'
            }
        }
    }
    frame drop _mmexp
    di as txt "mergemap export: `N' events from " as res `"`jfile'"'
    di as txt "             to " as res `"`saving'"'
    if "`format'" == "xlsx" {
        di as txt "             sheets: events (`N'), joins (`nj'), filters (`nf')"
    }
    return local file    `"`saving'"'
    return local journal `"`jfile'"'
    return local format  "`format'"
    return scalar N_events = `N'
    if "`format'" == "xlsx" {
        return scalar N_joins   = `nj'
        return scalar N_filters = `nf'
    }
end

* one sheet of the workbook from the data in memory.  export excel refuses
* an empty frame (r(2000), "no observations"), so a journal with no joins or
* no filters gets a header-only sheet instead, keeping the three-sheet
* contract.
program define _mm_xsheet
    args book sheet vlist
    if _N > 0 {
        quietly export excel using `"`book'"', sheet("`sheet'") ///
            firstrow(variables) sheetreplace
        exit
    }
    quietly putexcel set `"`book'"', sheet("`sheet'") modify open
    local j = 0
    foreach v of local vlist {
        local ++j
        if `j' <= 26 local c = char(64 + `j')
        else local c = char(64 + floor((`j' - 1) / 26)) + char(65 + mod(`j' - 1, 26))
        quietly putexcel `c'1 = "`v'"
    }
    quietly putexcel save
    putexcel clear
end
