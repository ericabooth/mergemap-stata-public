*! version 0.3.1  20aug2026  Eric Booth
*! _mm_jload -- read a v2 journal into a named frame, all columns as strings.
*! Kept as its own program so every journal reader loads the same way and the
*! reserved-word rename (using -> usingfile) is asserted in exactly one place.

program define _mm_jload
    version 16
    syntax using/, FRAME(name)
    capture frame drop `frame'
    frame create `frame'
    frame `frame' {
        quietly import delimited `"`using'"', delimiter(tab) varnames(1) ///
            stringcols(_all) clear
        capture confirm variable usingfile
        if _rc {
            di as err "mergemap: `using' is not a v2 mergemap journal"
            di as err "    (no usingfile column; rescan with this version)"
            exit 459
        }
    }
end
