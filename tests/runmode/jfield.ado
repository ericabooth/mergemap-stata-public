*! jfield -- read one field out of a mergemap journal, by row and column.
*! Kept in an ado-file so it survives the "clear all" that pipelines under
*! test are entitled to run.  Result lands in global JF.
program define jfield
    version 16
    args file row col
    global JF ""
    tempname jh
    file open `jh' using "`file'", read text
    file read `jh' line
    local i = 0
    file read `jh' line
    while r(eof) == 0 {
        local ++i
        if `i' == `row' {
            local s `"`line'"'
            local n = 0
            while 1 {
                local q = strpos(`"`s'"', char(9))
                local ++n
                if `q' {
                    local f = substr(`"`s'"', 1, `q' - 1)
                    local s = substr(`"`s'"', `q' + 1, .)
                }
                else local f `"`s'"'
                if `n' == `col' {
                    global JF `"`f'"'
                    continue, break
                }
                if !`q' continue, break
            }
            continue, break
        }
        file read `jh' line
    }
    file close `jh'
end
