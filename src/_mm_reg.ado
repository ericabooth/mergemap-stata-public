*! version 0.2.0  19aug2026  Eric Booth
*! _mm_reg -- register a do-file in the run-mode file table and give it an
*! index.  The index is what the "#file:line#" marker carries, so every
*! wrapper can name its own do-file without a runtime stack that a "clear
*! all" or an error could unbalance.
*!
*! Output: global MM_R_IDX (index, existing or new)
*!         globals MM_R_O<i> original path, MM_R_B<i> basename,
*!                 MM_R_R<i> path of the instrumented copy,
*!                 MM_R_D<i> 1 once the copy has been written

program define _mm_reg
    version 16
    syntax , path(string)
    if "$MM_R_NF" == "" global MM_R_NF = 0
    forvalues i = 1/$MM_R_NF {
        local q : copy global MM_R_O`i'
        if `"`q'"' == `"`path'"' {
            global MM_R_IDX = `i'
            exit
        }
    }
    local n = $MM_R_NF + 1
    global MM_R_NF = `n'
    local base `"`path'"'
    local p = max(strrpos(`"`base'"', "/"), strrpos(`"`base'"', char(92)))
    if `p' local base = substr(`"`base'"', `p' + 1, .)
    capture mkdir `"$MM_R_TMP/`n'"'
    global MM_R_O`n' : copy local path
    global MM_R_B`n' : copy local base
    global MM_R_R`n' `"$MM_R_TMP/`n'/`base'"'
    global MM_R_D`n' = 0
    global MM_R_IDX = `n'
end
