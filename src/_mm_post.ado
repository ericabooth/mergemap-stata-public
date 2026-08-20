*! version 0.2.0  19aug2026  Eric Booth
*! _mm_post -- append one v2 journal line (34 tab-separated fields).
*!
*! The journal is opened, written, and closed on every event so that a
*! "clear all" in the middle of the user's pipeline cannot orphan a file
*! handle, and so that an error mid-pipeline still leaves a usable partial
*! journal on disk.  No log file is ever opened: texdoc/webdoc own the log
*! stack and Stata caps simultaneous logs at five.

program define _mm_post
    version 16
    syntax , dofile(string) line(string) class(string) cmd(string)      ///
        [subtype(string) keys(string) master(string)          ///
         usingfile(string) result(string)                          ///
         nin(string) kin(string) nusing(string) kusing(string)               ///
         nout(string) kout(string)                                           ///
         m1(string) m2(string) m3(string) m4(string) m5(string)               ///
         dupmaster(string) dupusing(string) force(string) opts(string)   ///
         loopn(string) loopfirst(string) looplast(string)           ///
         severity(string) keytypes(string) covermaster(string)           ///
         coverusing(string) lifecycle(string) flags(string)]

    if `"$MM_R_JRN"' == "" exit

    foreach f in dofile line class cmd subtype keys master usingfile result  ///
        nin kin nusing kusing nout kout m1 m2 m3 m4 m5 dupmaster dupusing    ///
        force opts loopn loopfirst looplast severity keytypes covermaster    ///
        coverusing lifecycle flags {
        local `f' = subinstr(`"``f''"', char(9), " ", .)
        local `f' = subinstr(`"``f''"', char(10), " ", .)
        local `f' = subinstr(`"``f''"', char(13), " ", .)
        local `f' = strtrim(`"``f''"')
        if `"``f''"' == "" local `f' "."
    }
    if "`severity'" == "." local severity "note"
    if "`force'"    == "." local force "0"

    global MM_R_SEQ = $MM_R_SEQ + 1
    global MM_R_NEV = $MM_R_SEQ
    if "`class'" == "join" | "`class'" == "link" {
        global MM_R_NJOIN = $MM_R_NJOIN + 1
    }
    if `"`flags'"' != "." global MM_R_NFLAG = $MM_R_NFLAG + 1
    if "`severity'" == "stop" global MM_R_NSTOP = $MM_R_NSTOP + 1
    if "`severity'" == "warn" global MM_R_NWARN = $MM_R_NWARN + 1

    local T = char(9)
    local o `"$MM_R_SEQ`T'`dofile'`T'`line'`T'`class'`T'`cmd'`T'`subtype'"'
    local o `"`o'`T'`keys'`T'`master'`T'`usingfile'`T'`result'"'
    local o `"`o'`T'`nin'`T'`kin'`T'`nusing'`T'`kusing'`T'`nout'`T'`kout'"'
    local o `"`o'`T'`m1'`T'`m2'`T'`m3'`T'`m4'`T'`m5'"'
    local o `"`o'`T'`dupmaster'`T'`dupusing'`T'`force'`T'`opts'"'
    local o `"`o'`T'`loopn'`T'`loopfirst'`T'`looplast'"'
    local o `"`o'`T'`severity'`T'`keytypes'`T'`covermaster'`T'`coverusing'"'
    local o `"`o'`T'`lifecycle'`T'`flags'"'

    tempname jh
    quietly file open `jh' using `"$MM_R_JRN"', write text append
    file write `jh' (`"`o'"') _n
    file close `jh'
end
