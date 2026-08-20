*! version 0.2.0  19aug2026  Eric Booth
*! _mm_dropif -- run-mode wrapper around drop.  Filters are events because
*! most row loss happens in a drop if, not in a merge (DECISIONS 16a); a
*! diagram that omits them hands the blame to the wrong step.  Reported
*! tidylog style: "removed 6,519 rows (3.1%), 203,115 remaining".

program define _mm_dropif
    version 16
    global MM_R_ARG : copy local 0
    _mm_tag
    global MM_R_FARG : copy global MM_R_ARG
    global MM_R_FCMD "drop"
    global MM_R_FLINE "$MM_R_TL"
    local mmf "$MM_R_TF"
    local dof "."
    if "`mmf'" != "." & "`mmf'" != "" local dof : copy global MM_R_B`mmf'
    global MM_R_FDOF : copy local dof
    capture _return drop _mmret
    capture _return hold _mmret
    _mm_filter
    capture _return restore _mmret
end
