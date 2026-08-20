*! version 0.3.1  20aug2026  Eric Booth
*! _mm_clear -- forget mergemap's session state: the remembered last journal
*! and the scanner's working globals.  Journal FILES are never touched; they
*! are the record, and deleting records is not this package's job.

program define _mm_clear
    version 16
    local had `"$MM_LASTJ"'
    capture macro drop MM_LASTJ MM_RSM_DEFER MM_SEQ MM_TMPF MM_DEPTH   ///
        MM_CD MM_CDBAD MM_NSV MM_INP MM_JH
    capture macro drop MM_TFO_*
    capture macro drop MM_LINK_*
    capture macro drop MM_SVP*
    capture macro drop MM_SVW*
    capture macro drop MM_R_*
    if `"`had'"' != "" {
        di as txt `"mergemap clear: forgot the remembered journal (`had')"'
        di as txt "    the file itself is untouched"
    }
    else di as txt "mergemap clear: nothing was remembered"
end
