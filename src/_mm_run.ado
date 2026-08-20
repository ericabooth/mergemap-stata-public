*! version 0.2.0  19aug2026  Eric Booth
*! _mm_run -- instrumented execution for mergemap (PLAN section 2.2).
*!
*! Called by mergemap as:
*!     _mm_run `"`files'"', out(`"`out'"') [examples(#) nochecks warn(#) stop(#)]
*!
*! How it works, and why.  Wrappers that shadow merge by name cannot call the
*! real merge (the wrapper wins the lookup and recurses), and use/save are
*! built-ins that cannot be shadowed at all.  So run mode rewrites each
*! do-file into a temporary copy in which recognised command words are
*! replaced, on the same line, by differently named _mm_* ado-files.  Line
*! numbers are preserved exactly, prefixes are preserved
*! (capture noisily merge -> capture noisily _mm_merge), and because the
*! wrappers live on the adopath a "clear all" in the middle of the pipeline
*! is harmless: they reload lazily, the state lives in globals, and the
*! journal is opened-written-closed once per event.
*!
*! No log is opened anywhere.  Stata caps simultaneous logs at five and
*! texdoc/webdoc own that stack, so nothing here captures printed output; the
*! wrappers compute what they need from the data instead.

program define _mm_run, rclass
    version 16
    syntax anything(name=files id="do-file list") [,                          ///
        out(string) EXAMPLEs(integer 0) noCHECKS warn(string) stop(string)    ///
        noFOLD noLEDger noRECEIPT DEBUG                                       ///
        COMPACT noELLipsis noTRANSforms noKEYS noCOUNTs DETAILS               ///
        WRAP(integer 0) TITLE(string) LAYOUT(string) EXPORT(string)           ///
        SAVING(string) REPLACE MAXNodes(integer 8) FORCESMCL noOPEN           ///
        STYLE(string) FOLDER(string)]

    if `"`out'"' == "" local out "journal.tsv"

    * the rewritten do-files call the wrappers by name, so fail early and
    * plainly if the package was installed without them
    foreach w in _mm_merge _mm_use _mm_save _mm_post _mm_rw {
        capture which `w'
        if _rc {
            di as err "mergemap run: `w'.ado is not on the adopath; " ///
                "run mode needs the whole package, not mergemap.ado alone"
            exit 601
        }
    }

    * ---------------- resolve the do-file list ----------------
    * mergemap dispatches as  _mm_run `"`files'"', ...  so the whole list can
    * arrive wrapped in one compound quote; unwrap it before treating it as a
    * list, but leave quotes around individual names alone (a single file name
    * may legitimately contain spaces).
    local n0 = strlen(`"`files'"')
    if `n0' > 3 {
        if substr(`"`files'"', 1, 2) == char(96) + char(34) &   ///
           substr(`"`files'"', `=`n0'-1', 2) == char(34) + char(39) {
            local files = substr(`"`files'"', 3, `n0' - 4)
        }
    }
    if `"`files'"' == "" {
        di as err "mergemap run: do-file list required"
        exit 100
    }

    * Stata's sort is not stable: ties are broken from the sort seed, every
    * sort advances it, and the scanner called below sorts.  Left alone that
    * would shift how the user's own sorts break ties, and a collapse (mean)
    * downstream would differ in the low bits from a plain run.  The state is
    * therefore captured before anything else happens and put back just
    * before the pipeline executes.  (The wrappers themselves never sort:
    * their diagnostics run in Mata, see _mm_keys.)
    local runss "`c(sortseed)'"

    * ---------------- fresh run state ----------------
    _mm_rclear
    global MM_R_SEQ   = 0
    global MM_R_NEV   = 0
    global MM_R_NJOIN = 0
    global MM_R_NFLAG = 0
    global MM_R_NSTOP = 0
    global MM_R_NWARN = 0
    global MM_R_NF    = 0
    global MM_R_NSP   = 0
    global MM_R_EX    = `examples'
    global MM_R_NOCHK "`checks'"
    global MM_R_NOLED "`ledger'"
    global MM_R_WARN  ".05"
    if "`warn'" != "" global MM_R_WARN "`warn'"
    global MM_R_STOP  "`stop'"
    if "`stop'" != "" {
        capture confirm number `stop'
        if _rc {
            di as err "mergemap run: stop() must be a count or a 0-1 fraction"
            exit 198
        }
    }
    if "`warn'" != "" {
        capture confirm number `warn'
        if _rc {
            di as err "mergemap run: warn() must be a count or a 0-1 fraction"
            exit 198
        }
    }

    * ---------------- temporary tree for the instrumented copies ----------
    tempfile anchor
    * tempfile names are reused within a session, and a run left behind by
    * debug keeps its directory, so try a few suffixes before giving up
    local made = 0
    forvalues t = 0/49 {
        if `made' continue
        local cand `"`anchor'_mmrun`t'"'
        capture mkdir `"`cand'"'
        if !_rc {
            global MM_R_TMP : copy local cand
            local made = 1
        }
    }
    if !`made' {
        di as err "mergemap run: could not create a temporary directory"
        exit 603
    }

    * ---------------- rewrite every do-file, children included ------------
    local disp ""
    foreach f of local files {
        local ff `"`f'"'
        capture confirm file `"`ff'"'
        if _rc {
            capture confirm file `"`ff'.do"'
            if _rc {
                di as err `"mergemap run: file `ff' not found"'
                _mm_rclear
                exit 601
            }
            local ff `"`ff'.do"'
        }
        _mm_reg , path(`"`ff'"')
        local disp = strtrim(`"`disp' `ff'"')
    }
    local top = $MM_R_NF
    local guard = 0
    local more = 1
    while `more' & `guard' < 64 {
        local ++guard
        local more = 0
        forvalues i = 1/$MM_R_NF {
            local done : copy global MM_R_D`i'
            if "`done'" == "0" {
                _mm_rw `i'
                local more = 1
            }
        }
    }

    * ---------------- open the journal with the v2 header -----------------
    tempname jh
    capture file close `jh'
    quietly file open `jh' using `"`out'"', write text replace
    file write `jh' "seq" _tab "dofile" _tab "line" _tab "class" _tab "cmd" _tab  ///
        "subtype" _tab "keys" _tab "master" _tab "usingfile" _tab "result" _tab   ///
        "n_in" _tab "k_in" _tab "n_using" _tab "k_using" _tab "n_out" _tab        ///
        "k_out" _tab "m1" _tab "m2" _tab "m3" _tab "m4" _tab "m5" _tab            ///
        "dup_master" _tab "dup_using" _tab "force" _tab "opts" _tab               ///
        "loop_n" _tab "loop_first" _tab "loop_last" _tab "severity" _tab          ///
        "keytypes" _tab "cover_master" _tab "cover_using" _tab "lifecycle" _tab   ///
        "flags" _n
    file close `jh'
    global MM_R_JRN : copy local out

    * ---------------- run the instrumented copies -------------------------
    di as txt _newline "mergemap run: executing " as res `"`disp'"' as txt   ///
        " with instrumentation" _newline
    set sortseed `runss'
    local rc = 0
    forvalues i = 1/`top' {
        if `rc' continue
        local exec : copy global MM_R_R`i'
        capture noisily do `"`exec'"'
        local rc = _rc
    }

    * ---------------- collapse repeated loop events -----------------------
    if "`fold'" == "" & `rc' == 0 {
        capture _mm_fold , journal(`"`out'"')
    }

    * ---------------- headline, receipt, returns --------------------------
    local nev  = $MM_R_NEV
    local njn  = $MM_R_NJOIN
    local nfl  = $MM_R_NFLAG
    local nst  = $MM_R_NSTOP
    local nwn  = $MM_R_NWARN
    di as txt _newline "mergemap run: " as res "`nev'" as txt " events, " ///
        as res "`njn'" as txt " joins, journal " as res `"`out'"'
    if `nst' > 0 {
        di as txt "mergemap run: " as res "`nst' stop" as txt ", " ///
            as res "`nwn' warn" as txt " -- see the flags column"
    }
    else if `nwn' > 0 {
        di as txt "mergemap run: " as res "`nwn' warn" as txt " -- see the flags column"
    }
    if `rc' {
        di as err "mergemap run: the pipeline stopped with r(`rc'); the " ///
            "journal holds every event up to the failure"
    }
    if "`receipt'" != "noreceipt" & `nev' > 0 {
        capture noisily mergemap receipt `"`out'"'
    }

    return local tmpdir   `"$MM_R_TMP"'
    return local journal  `"`out'"'
    return local files    `"`disp'"'
    return scalar N_events = `nev'
    return scalar N_joins  = `njn'
    return scalar N_flags  = `nfl'
    return scalar N_warn   = `nwn'
    return scalar N_stop   = `nst'

    * ---------------- tidy up --------------------------------------------
    if "`debug'" == "" {
        forvalues i = 1/$MM_R_NF {
            local p : copy global MM_R_R`i'
            capture erase `"`p'"'
            capture rmdir `"$MM_R_TMP/`i'"'
        }
        capture rmdir `"$MM_R_TMP"'
    }
    else {
        di as txt "mergemap run: instrumented copies kept in " as res "$MM_R_TMP"
    }
    _mm_rclear

    if `rc' exit `rc'
    if `nst' > 0 {
        di as err "mergemap run: `nst' event(s) breached the stop threshold"
        exit 9
    }
end
