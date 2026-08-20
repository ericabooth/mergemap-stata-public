*! version 0.3.1  20aug2026  Eric Booth
*! _mm_export -- the journal as a dataset, for your own auditing.  Count and
*! percentage columns arrive numeric; text columns stay text.  The point is
*! that the record of your joins is data like any other: keep the flagged
*! rows, merge journals from different runs, graph coverage over time.

program define _mm_export, rclass
    version 16
    syntax [anything(name=jspec)] [, Format(string) SAVing(string) replace]
    if "`format'" == "" local format "dta"
    if !inlist("`format'", "dta", "csv") {
        di as err "mergemap export: format() must be dta or csv"
        exit 198
    }
    _mm_jresolve `jspec'
    local jfile `"`s(jfile)'"'
    if `"`saving'"' == "" local saving "mergemap_journal.`format'"
    _mm_jload using `"`jfile'"', frame(_mmexp)
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
        else {
            quietly export delimited using `"`saving'"', `replace'
        }
    }
    frame drop _mmexp
    di as txt "mergemap export: `N' events from " as res `"`jfile'"'
    di as txt "             to " as res `"`saving'"'
    return local file    `"`saving'"'
    return local journal `"`jfile'"'
    return scalar N_events = `N'
end
