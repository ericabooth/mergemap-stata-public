*! version 0.2.0  19aug2026  Eric Booth
*! _mm_keepif -- run-mode wrapper around keep.  See _mm_dropif; the two share
*! _mm_filter, which runs the real command and reports the row change.

program define _mm_keepif
    version 16
    global MM_R_ARG : copy local 0
    _mm_tag
    global MM_R_FARG : copy global MM_R_ARG
    global MM_R_FCMD "keep"
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
