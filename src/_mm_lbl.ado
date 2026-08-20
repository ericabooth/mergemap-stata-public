*! version 0.2.0  19aug2026  Eric Booth
*! _mm_lbl -- journal label and provenance for a dataset path.
*!
*! Run mode only ever sees the expanded path, so a Stata tempfile arrives as
*! something like /var/folders/.../St12345.000003.tmp.  Such a path is
*! labelled tempfile:<name> for the journal, and save-to-use provenance is
*! tracked by exact path within the run so that a later use of the same
*! tempfile can say where it came from (PLAN 2.3).
*!
*! _mm_lbl , path(p)                 -> globals MM_R_LBL, MM_R_PROV
*! _mm_lbl , path(p) register(txt)   -> also records txt as p's producer

program define _mm_lbl
    version 16
    syntax , path(string) [register(string)]
    global MM_R_LBL  : copy local path
    global MM_R_PROV ""
    if `"`path'"' == "" exit

    local td `"`c(tmpdir)'"'
    local istmp = 0
    if `"`td'"' != "" {
        if strpos(`"`path'"', `"`td'"') == 1 local istmp = 1
    }
    if `istmp' {
        local b `"`path'"'
        local p = max(strrpos(`"`b'"', "/"), strrpos(`"`b'"', char(92)))
        if `p' local b = substr(`"`b'"', `p' + 1, .)
        global MM_R_LBL "tempfile:`b'"
    }

    * ---- provenance table, keyed on the exact expanded path ----
    if "$MM_R_NSP" == "" global MM_R_NSP = 0
    if `"`register'"' != "" {
        local n = $MM_R_NSP + 1
        global MM_R_NSP = `n'
        global MM_R_SP`n'  : copy local path
        global MM_R_SPL`n' : copy local register
        exit
    }
    forvalues i = 1/$MM_R_NSP {
        local q : copy global MM_R_SP`i'
        if `"`q'"' == `"`path'"' {
            global MM_R_PROV : copy global MM_R_SPL`i'
        }
    }
end
