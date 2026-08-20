*! version 0.3.1  20aug2026  Eric Booth
*! _mm_jresolve -- one rule for "which journal did you mean", shared by the
*! journal-reading subcommands (list, detail, export).  Order: an explicit
*! file (a leading -using- token is accepted and ignored), then the journal
*! the last scan/run/demo wrote ($MM_LASTJ, a global so it survives
*! -clear all-), then journal.tsv in the working directory.

program define _mm_jresolve, sclass
    version 16
    gettoken w1 rest : 0
    if `"`w1'"' == "using" local 0 `"`rest'"'
    gettoken jfile : 0
    if `"`jfile'"' == "" local jfile `"$MM_LASTJ"'
    if `"`jfile'"' == "" {
        capture confirm file "journal.tsv"
        if !_rc local jfile "journal.tsv"
    }
    if `"`jfile'"' == "" {
        di as err "mergemap: no journal to read."
        di as err "    Scan something first (mergemap <do-files>), or name a"
        di as err "    journal file on the command line."
        exit 601
    }
    capture confirm file `"`jfile'"'
    if _rc {
        di as err `"mergemap: journal `jfile' not found"'
        exit 601
    }
    sreturn local jfile `"`jfile'"'
end
