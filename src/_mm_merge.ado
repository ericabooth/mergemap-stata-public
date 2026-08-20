*! version 0.2.0  20aug2026  Eric Booth
*! _mm_merge -- run-mode wrapper around merge.  Transparent by construction.
*!
*! No log is opened anywhere.  Stata caps simultaneous logs at five and
*! texdoc/webdoc own that stack, so nothing here captures merge's printed
*! table; the wrapper counts the _merge categories from the data instead.
*!
*! What is and is not altered.  The ONLY option this wrapper touches is the
*! one that names the merge indicator: generate()/nogenerate are replaced by
*! generate(_mm_merge_tmp), the categories are counted, and the variable is
*! then renamed to the user's name or dropped, which reproduces the user's
*! semantics exactly (verified: identical datasignature, identical value
*! label, identical variable position).  keepusing(), update, replace,
*! sorted, force, assert(), nolabel and nonotes are passed through byte for
*! byte, and assert() therefore keeps Stata's own error behaviour.
*!
*! keep() is ALSO passed through, deliberately.  An earlier design stripped
*! it, counted the categories, and applied the drop afterwards.  That is not
*! transparent: on an m:1 merge with duplicate master keys, letting the
*! using-only rows into the result changes how the key sort breaks ties, so
*! the surviving rows come back in a different ORDER.  Measured on a 2,000
*! row master: 1,962 of 2,000 rows landed at different positions, and the
*! collapse(mean) downstream then differed in the low bits.  So the real
*! merge does its own keep(), and the categories the user dropped are
*! recovered from key-only scratch frames instead (skipped under nochecks,
*! where they stay missing rather than being guessed).
*!
*! One fidelity detail the indicator swap would otherwise break: merge
*! refuses to overwrite an existing _merge (or generate()) variable with
*! r(110), and generate(_mm_merge_tmp) would not, so that check is
*! re-implemented here before the real merge runs.

program define _mm_merge
    version 16
    global MM_R_ARG : copy local 0
    _mm_tag
    local 0    : copy global MM_R_ARG
    local mmf   "$MM_R_TF"
    local mml   "$MM_R_TL"
    local dof "."
    if "`mmf'" != "." & "`mmf'" != "" local dof : copy global MM_R_B`mmf'
    if `"`dof'"' == "" local dof "."
    capture _return drop _mmret
    capture _return hold _mmret

    * ---------------- pick the command apart ----------------
    global MM_R_ARG : copy local 0
    _mm_opt
    local body  : copy global MM_R_BODY
    local opts  : copy global MM_R_OPTS
    local rest  : copy global MM_R_OREST
    local okeep : copy global MM_R_OKEEP
    local ogen  : copy global MM_R_OGEN
    local onogen  "$MM_R_ONOGEN"
    local oforce  "$MM_R_OFORCE"
    local oupd    "$MM_R_OUPD"
    local orepl   "$MM_R_OREPL"

    gettoken sub body2 : body
    global MM_R_ARG : copy local body2
    _mm_using
    local keys  : copy global MM_R_KEYS
    local uf    : copy global MM_R_UF
    local ufd   : copy global MM_R_UFD
    if `"`opts'"' == "" local opts "."

    * ---------------- which categories survive the user's keep()? ---------
    local kept "1 2 3 4 5"
    local kdrop ""
    if `"`okeep'"' != "" {
        local codes ""
        foreach w of local okeep {
            local w = strlower("`w'")
            if "`w'" == "master"              local w "1"
            else if "`w'" == "using"          local w "2"
            else if "`w'" == "match"          local w "3"
            else if "`w'" == "match_update"   local w "4"
            else if "`w'" == "match_conflict" local w "5"
            capture confirm number `w'
            if !_rc local codes "`codes' `w'"
        }
        local codes = strtrim("`codes'")
        if "`codes'" != "" {
            local kept ""
            forvalues j = 1/5 {
                if strpos(" `codes' ", " `j' ") local kept "`kept' `j'"
                else local kdrop "`kdrop' `j'"
            }
            local kept  = strtrim("`kept'")
            local kdrop = strtrim("`kdrop'")
        }
    }

    * ---------------- before ----------------
    local nin = _N
    local kin = c(k)
    _mm_pre , keys(`"`keys'"') usingfile(`"`ufd'"') $MM_R_NOCHK
    local nusing  "$MM_R_NU"
    local kusing  "$MM_R_KU"
    local dupm    "$MM_R_DUPM"
    local dupu    "$MM_R_DUPU"
    local ktype   : copy global MM_R_KTYPE
    local kdrift  "$MM_R_KDRIFT"
    local covmn "$MM_R_COVMN"
    local covmd "$MM_R_COVMD"
    local covun "$MM_R_COVUN"
    local covud "$MM_R_COVUD"
    local covm  "$MM_R_COVM"
    local covu  "$MM_R_COVU"
    local topk  : copy global MM_R_TOPK

    * ---------------- reproduce merge's own name clash error ----------------
    local target ""
    if "`onogen'" == "0" {
        local target = cond(`"`ogen'"' == "", "_merge", `"`ogen'"')
        capture confirm variable `target'
        if !_rc {
            di as err "variable `target' already defined"
            capture _return restore _mmret
            exit 110
        }
    }
    capture confirm variable _mm_merge_tmp
    if !_rc {
        di as err "_mm_merge_tmp is reserved by mergemap run and already exists"
        capture _return restore _mmret
        exit 110
    }

    * ---------------- run the real merge, keep() and all ------------------
    local rcmd `"merge `sub' `keys' using `uf'"'
    local rcmd `"`rcmd', `rest' generate(_mm_merge_tmp) noreport"'
    capture noisily `rcmd'
    local rc = _rc
    if `rc' {
        _mm_post , dofile(`"`dof'"') line(`mml') class(join) cmd(merge)      ///
            subtype(`"`sub'"') keys(`"`keys'"') master(work)                 ///
            usingfile(`"`ufd'"') result(work) nin(`nin') kin(`kin')          ///
            nusing(`nusing') kusing(`kusing') dupmaster(`dupm')              ///
            dupusing(`dupu') force(`oforce') opts(`"`opts'"')                ///
            severity(stop) keytypes(`"`ktype'"')                             ///
            flags(`"!! merge failed with r(`rc') -- pipeline stopped here"')
        capture _return restore _mmret
        exit `rc'
    }

    * ---------------- categories: observed for the ones that survived, ----
    * ---------------- recovered from the key sets for the ones keep() ----
    * ---------------- removed (missing when nochecks skipped the frames) --
    forvalues j = 1/5 {
        if strpos(" `kept' ", " `j' ") {
            qui count if _mm_merge_tmp == `j'
            local m`j' = r(N)
        }
        else local m`j' "."
    }
    if "`covmd'" != "." {
        if !strpos(" `kept' ", " 1 ") local m1 = `covmd' - `covmn'
        if !strpos(" `kept' ", " 2 ") local m2 = `covud' - `covun'
        if !strpos(" `kept' ", " 3 ") {
            local m3 = `covmn'
            if "`sub'" == "1:m" local m3 = `covun'
        }
    }
    * _merge 4 and 5 exist only under update, so a keep() that removed them
    * from a plain merge removed nothing
    if "`oupd'" == "0" {
        if "`m4'" == "." local m4 = 0
        if "`m5'" == "." local m5 = 0
    }

    * ---------------- result shape ----------------
    * the scratch indicator is still in memory at this point; it is handed
    * over (or dropped) after the ledger has printed, so that examples() can
    * still read it, and k_out already accounts for that
    local nout = _N
    local kout = c(k)
    if "`onogen'" == "1" local kout = `kout' - 1

    * ---------------- coverage ----------------
    if "`covm'" == "." & "`m1'" != "." {
        if `nin' > 0 local covm = string(100 * (`nin' - `m1') / `nin', "%4.1f")
    }
    if "`covu'" == "." & "`m2'" != "." & "`nusing'" != "." {
        if `nusing' > 0 local covu = string(100 * (`nusing' - `m2') / `nusing', "%4.1f")
    }

    * ---------------- flags and severity ----------------
    local flags ""
    if "`sub'" == "m:m" {
        local flags "!! m:m pairs rows by row order within key (not a join)"
    }
    if "`oforce'" == "1" {
        local ff "!! force used"
        if "`kdrift'" == "1" local ff "!! force: `ktype'"
        local flags = cond("`flags'" == "", "`ff'", "`flags'; `ff'")
    }
    else if "`kdrift'" == "1" {
        local flags = cond("`flags'" == "", "!! key type drift: `ktype'", ///
            "`flags'; !! key type drift: `ktype'")
    }
    if "`oupd'" == "1" & "`orepl'" == "1" {
        local ff "update replace"
        if "`m5'" != "." {
            if `m5' > 0 local ff = trim(string(`m5', "%20.0fc")) + ///
                " nonmissing conflicts overwritten"
        }
        local flags = cond("`flags'" == "", "`ff'", "`flags'; `ff'")
    }
    foreach j of local kdrop {
        local lab "master-only"
        if "`j'" == "2" local lab "using-only"
        if "`j'" == "3" local lab "matched"
        if "`j'" == "4" local lab "missing-updated"
        if "`j'" == "5" local lab "conflict-updated"
        local ff ""
        if "`m`j''" == "." {
            local ff "`lab' dropped by keep(`okeep')"
        }
        else if `m`j'' > 0 {
            local ff = trim(string(`m`j'', "%20.0fc")) + " `lab' dropped by keep(`okeep')"
        }
        if "`ff'" != "" {
            local flags = cond("`flags'" == "", "`ff'", "`flags'; `ff'")
        }
    }
    if "`m1'" != "." {
        if `m1' > 0 & strpos(" `kept' ", " 1 ") {
            local ff = trim(string(`m1', "%20.0fc")) + " master-only kept"
            local flags = cond("`flags'" == "", "`ff'", "`flags'; `ff'")
        }
    }
    if `nin' > 0 {
        if `nout' > `nin' * 1.005 {
            local ff = "row multiplication x" + string(`nout' / `nin', "%4.2f")
            local flags = cond("`flags'" == "", "`ff'", "`flags'; `ff'")
        }
    }

    local unm = 0
    if "`m1'" != "." local unm = `m1'
    _mm_sev `unm' `nin'
    local sev "$MM_R_SEV"
    if "`sub'" == "m:m" | "`oforce'" == "1" | "`kdrift'" == "1" {
        if "`sev'" == "note" local sev "warn"
    }
    if "`oupd'" == "1" & "`orepl'" == "1" & "`sev'" == "note" local sev "warn"
    if "`sub'" == "m:m" & "`oforce'" == "1" local sev "stop"

    * ---------------- journal ----------------
    _mm_post , dofile(`"`dof'"') line(`mml') class(join) cmd(merge)          ///
        subtype(`"`sub'"') keys(`"`keys'"') master(work)                     ///
        usingfile(`"`ufd'"') result(work)                                    ///
        nin(`nin') kin(`kin') nusing(`nusing') kusing(`kusing')              ///
        nout(`nout') kout(`kout')                                            ///
        m1(`m1') m2(`m2') m3(`m3') m4(`m4') m5(`m5')                         ///
        dupmaster(`dupm') dupusing(`dupu') force(`oforce') opts(`"`opts'"')  ///
        severity(`sev') keytypes(`"`ktype'"') covermaster(`covm')            ///
        coverusing(`covu') flags(`"`flags'"')

    * ---------------- the ledger (PLAN section 5) ------------------------
    if "$MM_R_NOLED" == "" {
        di as txt "mergemap: merge `sub' `keys' using " as res `"`ufd'"' ///
            as txt "   (`dof' line `mml')"
        local kt = cond(`"`ktype'"' == ".", "", `"   `ktype'"')
        di as txt "    key: " as res `"`keys'"' as txt "`kt'"
        local nud "."
        if "`nusing'" != "." local nud = trim(string(`nusing', "%20.0fc"))
        local mtot "."
        if "`m3'" != "." {
            local mtot = `m3'
            if "`m4'" != "." local mtot = `mtot' + `m4'
            if "`m5'" != "." local mtot = `mtot' + `m5'
            local mtot = trim(string(`mtot', "%20.0fc"))
        }
        di as txt "    master " as res trim(string(`nin', "%20.0fc")) ///
            as txt " {c |} using " as res "`nud'" ///
            as txt " {c |} matched " as res "`mtot'" ///
            as txt " {c |} result " as res trim(string(`nout', "%20.0fc"))
        if "`covm'" != "." {
            di as txt "    coverage: " as res "`covm'%" as txt " of master matched, " ///
                as res "`covu'%" as txt " of using used"
        }
        if `"`topk'"' != "" {
            di as txt "    top unmatched keys: " as res `"`topk'"'
        }
        if `"`flags'"' != "" {
            di as txt "    " as res `"`flags'"'
        }
    }
    if "$MM_R_EX" != "" & "$MM_R_EX" != "0" {
        _mm_ex , keys(`"`keys'"') n($MM_R_EX)
    }

    * ---------------- hand the indicator variable over --------------------
    if "`onogen'" == "1" {
        qui drop _mm_merge_tmp
    }
    else {
        rename _mm_merge_tmp `target'
    }
    capture _return restore _mmret
end
