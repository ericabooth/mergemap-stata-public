*! version 0.3.1  20aug2026  Eric Booth
*! _mm_list -- the journal as a table.  The receipt is the curated view; this
*! is the data view: one line per event with the count columns run mode fills,
*! and -full- for every column via -list- when you want to audit the record.

program define _mm_list, rclass
    version 16
    syntax [anything(name=jspec)] [, FULL]
    _mm_jresolve `jspec'
    local jfile `"`s(jfile)'"'
    _mm_jload using `"`jfile'"', frame(_mmlst)
    frame _mmlst {
        quietly count
        local N = r(N)
        if `N' == 0 {
            di as txt "mergemap list: `jfile' has no events"
            frame drop _mmlst
            exit
        }
        if "`full'" != "" {
            list, noobs abbreviate(12)
        }
        else {
            di as txt ""
            di as txt "mergemap list: " as res `"`jfile'"' as txt "  (`N' events)"
            di as txt ""
            * explicit single-space separators: a %-4s field holding "  10"
            * fills exactly, so a two-digit event number ran into the filename
            di as txt "  " %3s "#" " " %-15s "file" " " %4s "line" "  " ///
                %-10s "command" " " %-7s "type" " " %-13s "keys" " "     ///
                %9s "n in" " " %9s "n out" "  " %-4s "sev"
            di as txt "  {hline 88}"
            forvalues i = 1/`N' {
                local sq  = seq[`i']
                local fl  = dofile[`i']
                local ln  = line[`i']
                local cm  = cmd[`i']
                local st  = subtype[`i']
                if "`st'" == "." local st ""
                local ky  = keys[`i']
                if "`ky'" == "." local ky ""
                local ni  = n_in[`i']
                local no  = n_out[`i']
                if "`ni'" == "." local ni ""
                if "`no'" == "." local no ""
                local sv  = severity[`i']
                if "`sv'" == "note" local sv ""
                if strlen("`fl'") > 15 local fl = substr("`fl'", 1, 14) + "~"
                if strlen("`ky'") > 13 local ky = substr("`ky'", 1, 12) + "~"
                di as txt "  " %3s "`sq'" " " %-15s "`fl'" " " %4s "`ln'" "  " ///
                    as res %-10s "`cm'" as txt " " %-7s "`st'" " " %-13s "`ky'" " " ///
                    %9s "`ni'" " " %9s "`no'" "  " as err %-4s "`sv'"
            }
            di as txt "  {hline 88}"
            di as txt `"  one event in depth: {stata mergemap detail 1:mergemap detail #} ; every column: mergemap list, full"'
        }
    }
    frame drop _mmlst
    return local journal `"`jfile'"'
    return scalar N_events = `N'
end
