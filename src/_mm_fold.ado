*! version 0.2.0  20aug2026  Eric Booth
*! _mm_fold -- collapse a loop's repeated events into one stacked journal row.
*!
*! PLAN section 6: consecutive events with an identical command template --
*! same do-file, line, class, command, subtype, keys and options, only the
*! file token differing -- become one row labelled with the iteration count
*! and the first and last resolved names, with the row counts summed.  Scan
*! mode gets this for free because a loop is already one template; run mode
*! executes the loop body once per iteration, so the folding happens here,
*! after the run, over the journal this run wrote.
*!
*! Threshold: 3 or more repeats, as in PLAN section 6.  The journal is only
*! replaced once the folded copy has been written in full, so a failure
*! anywhere leaves the unfolded journal untouched.

program define _mm_fold
    version 16
    syntax , journal(string) [minrun(integer 3)]
    capture confirm file `"`journal'"'
    if _rc exit

    local T = char(9)
    tempname rh
    tempfile out

    * ---- read the journal into a frame, one row per event ----
    capture frame drop _mmfold
    frame create _mmfold
    frame _mmfold {
        qui gen strL raw = ""
        qui gen strL sig = ""
    }
    file open `rh' using `"`journal'"', read text
    file read `rh' hdr
    local n = 0
    file read `rh' line
    while r(eof) == 0 {
        local line : subinstr local line "\`" "`=char(1)'", all
        local line : subinstr local line "\$" "`=char(2)'", all
        local line : subinstr local line "'" "`=char(3)'", all
        * signature = the fields that must match for two events to be one loop
        local s `"`line'"'
        local i = 0
        local sig ""
        while 1 {
            local q = strpos(`"`s'"', "`T'")
            local ++i
            if `q' {
                local f = substr(`"`s'"', 1, `q' - 1)
                local s = substr(`"`s'"', `q' + 1, .)
            }
            else local f `"`s'"'
            if inlist(`i', 2, 3, 4, 5, 6, 7, 25) local sig `"`sig'|`f'"'
            if !`q' continue, break
        }
        frame post _mmfold (`"`line'"') (`"`sig'"')
        local ++n
        file read `rh' line
    }
    file close `rh'
    if `n' == 0 {
        capture frame drop _mmfold
        exit
    }

    * ---- walk the rows, folding runs of identical signatures ----
    tempname wh
    quietly file open `wh' using `"`out'"', write text replace
    file write `wh' (`"`hdr'"') _n
    local i = 1
    local nfold = 0
    local seq = 0
    while `i' <= `n' {
        frame _mmfold: local sig0 = sig[`i']
        local j = `i'
        while `j' < `n' {
            frame _mmfold: local sig1 = sig[`=`j'+1']
            if `"`sig1'"' != `"`sig0'"' continue, break
            local ++j
        }
        local runlen = `j' - `i' + 1
        if `runlen' >= `minrun' {
            _mm_foldrow , frame(_mmfold) from(`i') to(`j')
            local row : copy global MM_R_FOLDROW
            local ++seq
            local row = "`seq'" + substr(`"`row'"', strpos(`"`row'"', "`T'"), .)
            file write `wh' (subinstr(subinstr(subinstr(`"`row'"',    ///
                char(1), char(96), .), char(2), char(36), .),          ///
                char(3), char(39), .)) _n
            local ++nfold
        }
        else {
            forvalues z = `i'/`j' {
                frame _mmfold: local row = raw[`z']
                local ++seq
                local row = "`seq'" + substr(`"`row'"', strpos(`"`row'"', "`T'"), .)
                file write `wh' (subinstr(subinstr(subinstr(`"`row'"',    ///
                    char(1), char(96), .), char(2), char(36), .),          ///
                    char(3), char(39), .)) _n
            }
        }
        local i = `j' + 1
    }
    file close `wh'
    capture frame drop _mmfold
    if `nfold' > 0 {
        copy `"`out'"' `"`journal'"', replace
        di as txt "mergemap run: " as res "`nfold'" as txt              ///
            " loop(s) folded into a single stacked journal row"
    }
end

* build one folded row out of rows from..to of the journal frame
program define _mm_foldrow
    version 16
    syntax , frame(name) from(integer) to(integer)
    local T = char(9)
    local nrun = `to' - `from' + 1

    * split every row of the run into fields f<row>_<col>
    forvalues z = `from'/`to' {
        frame `frame': local row = raw[`z']
        local s `"`row'"'
        local i = 0
        while 1 {
            local q = strpos(`"`s'"', "`T'")
            local ++i
            if `q' {
                local f`z'_`i' = substr(`"`s'"', 1, `q' - 1)
                local s = substr(`"`s'"', `q' + 1, .)
            }
            else {
                local f`z'_`i' `"`s'"'
                local ncol = `i'
                continue, break
            }
        }
    }
    * sums over the run for the count columns, first/last for the rest
    foreach c in 13 14 17 18 19 20 21 {
        local tot = 0
        local any = 0
        forvalues z = `from'/`to' {
            if "`f`z'_`c''" != "." {
                local tot = `tot' + `f`z'_`c''
                local any = 1
            }
        }
        local sum`c' = cond(`any', "`tot'", ".")
    }
    * assemble
    local outrow ""
    forvalues i = 1/`ncol' {
        local v `"`f`from'_`i''"'
        if `i' == 15 local v `"`f`to'_15'"'
        if `i' == 16 local v `"`f`to'_16'"'
        if inlist(`i', 13, 14, 17, 18, 19, 20, 21) local v `"`sum`i''"'
        if `i' == 26 local v "`nrun'"
        if `i' == 27 local v `"`f`from'_9'"'
        if `i' == 28 local v `"`f`to'_9'"'
        if `i' == 1  local outrow `"`v'"'
        else local outrow `"`outrow'`T'`v'"'
    }
    global MM_R_FOLDROW : copy local outrow
end
