*! version 0.2.0  19aug2026  Eric Booth
*! _mm_tag -- strip the "#file:line[:extra]#" marker that the run-mode
*! rewriter inserts immediately after an instrumented command word.
*!
*! Input  : global MM_R_ARG   (verbatim copy of the wrapper's `0')
*! Output : global MM_R_ARG   (the same text with the marker removed)
*!          global MM_R_TF    file index, or "."
*!          global MM_R_TL    original line number, or "."
*!          global MM_R_TX    extra field, or ""
*! Uses ": copy" throughout so that a literal $ or backtick surviving in a
*! user command is never re-expanded by this helper.

program define _mm_tag
    version 16
    local s : copy global MM_R_ARG
    local f "."
    local l "."
    local x ""
    gettoken tok rest : s
    local n = strlen(`"`tok'"')
    if `n' >= 5 & substr(`"`tok'"', 1, 1) == "#" & substr(`"`tok'"', `n', 1) == "#" {
        local body = substr(`"`tok'"', 2, `n' - 2)
        local p = strpos("`body'", ":")
        if `p' > 1 {
            local f  = substr("`body'", 1, `p' - 1)
            local r2 = substr("`body'", `p' + 1, .)
            local p2 = strpos("`r2'", ":")
            if `p2' {
                local x  = substr("`r2'", `p2' + 1, .)
                local r2 = substr("`r2'", 1, `p2' - 1)
            }
            local l "`r2'"
            global MM_R_ARG : copy local rest
        }
    }
    global MM_R_TF "`f'"
    global MM_R_TL "`l'"
    global MM_R_TX "`x'"
end
