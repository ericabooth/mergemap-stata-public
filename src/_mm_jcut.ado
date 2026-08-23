*! version 0.5.0  23aug2026  Eric Booth
*! _mm_jcut -- cut a journal down before a renderer reads it.
*!
*! One implementation behind every option that hides events or shortens the
*! labels, so notransforms, nofilters, norowfilters, novarfilters,
*! notempfiles, joinsonly, filesonly, an -if- on the journal columns, and
*! paths()/root() behave the same in the Results window, HTML, PNG/SVG,
*! mermaid, DOT and text.  The input journal is never touched: the cut copy
*! is a tempfile and s(jfile) names it; when nothing was asked for, s(jfile)
*! is the input and no file is written.
*!
*! syntax:  _mm_jcut using journal.tsv [, IF(string) noTRANSforms noFILters
*!              noROWfilters noVARfilters noTEMPfiles JOINSonly FILESonly
*!              PATHS(string) ROOT(string) Quietly]
*!
*! The -if- arrives in an option, if(exp), because -syntax [if]- validates
*! the expression against the data in memory and the journal is not there
*! yet; the caller parses the user's "if exp" off the command line itself.
*! It is evaluated with the count columns as numbers, so "line < 400" and
*! "n_out < 1000" work, and the text columns as text, so
*! strpos(dofile, "build") and class == "join" work.
*!
*! s(jfile)   the journal to draw      s(note)   one line on what was hidden
*! s(N_in)    events read              s(N_out)  events left
*! s(n_transforms) s(n_rowfilters) s(n_varfilters) s(n_tempfiles) s(n_if)
*!            how many each rule removed (a row counts once, under the first
*!            rule that took it, in the order listed)

program define _mm_jcut, sclass
    version 16
    syntax using/ [, IF(string asis) noTRANSforms noFILters noROWfilters     ///
        noVARfilters noTEMPfiles JOINSonly FILESonly PATHS(string)          ///
        ROOT(string asis) Quietly]
    sreturn clear
    sreturn local jfile `"`using'"'
    sreturn local note ""

    * ---- the shorthands ----------------------------------------------
    if "`filesonly'" != "" {
        local joinsonly "joinsonly"
        local tempfiles "notempfiles"
    }
    if "`joinsonly'" != "" {
        local transforms "notransforms"
        local filters    "nofilters"
    }
    if "`filters'" == "nofilters" {
        local rowfilters "norowfilters"
        local varfilters "novarfilters"
    }

    * ---- paths(): full | base | parent | # components ------------------
    local depth = 0
    if `"`paths'"' != "" {
        local p = strlower(strtrim(`"`paths'"'))
        if "`p'" == "full" local depth = 0
        else if inlist("`p'", "base", "basename", "file", "filename", "name") local depth = 1
        else if inlist("`p'", "parent", "dir", "folder") local depth = 2
        else {
            capture confirm integer number `p'
            if _rc local depth = -1
            else   local depth = `p'
            if `depth' < 1 {
                di as err "paths() must be full, base, parent, or the number" ///
                    " of trailing path components to keep (1 = base, 2 = parent)"
                exit 198
            }
        }
    }
    local root = strtrim(`"`root'"')
    * strip a quote the user may have wrapped a path in
    if substr(`"`root'"', 1, 1) == char(34) & substr(`"`root'"', -1, 1) == char(34) {
        local root = substr(`"`root'"', 2, strlen(`"`root'"') - 2)
    }

    local ifexp = strtrim(`"`if'"')
    if strlower(substr(`"`ifexp'"', 1, 3)) == "if " local ifexp = strtrim(substr(`"`ifexp'"', 4, .))

    local any = ("`transforms'" != "" | "`rowfilters'" != "" | "`varfilters'" != "" ///
        | "`tempfiles'" != "" | `"`ifexp'"' != "" | `depth' > 0 | `"`root'"' != "")
    if !`any' exit

    * ---- load ------------------------------------------------------------
    _mm_jload using `"`using'"', frame(_mmcut)
    local ifrc = 0
    local ntr = 0
    local nrow = 0
    local nvar = 0
    local ntmp = 0
    local nif = 0
    frame _mmcut {
        quietly count
        local N0 = r(N)
        foreach v in subtype usingfile result master loop_first loop_last {
            capture confirm variable `v'
            if _rc quietly gen str1 `v' = "."
        }

        * ---- which rows each rule takes ----
        * tempfile traffic: scan and run both write tempfile:<name> for a
        * save to, a use of, or a join against a tempfile.  A raw path under
        * this machine's c(tmpdir) is accepted too, for run journals written
        * before 0.5.0, when merge recorded the resolved path.
        quietly gen byte mm_tmp = strpos(usingfile, "tempfile:") == 1 ///
            | strpos(result, "tempfile:") == 1 | subtype == "tempfile"
        local td `"`c(tmpdir)'"'
        if `"`td'"' != "" {
            quietly replace mm_tmp = 1 if strpos(usingfile, `"`td'"') == 1 ///
                | strpos(result, `"`td'"') == 1
        }
        quietly gen byte mm_drop = 0
        if "`transforms'" != "" {
            quietly count if class == "transform" & !mm_drop
            local ntr = r(N)
            quietly replace mm_drop = 1 if class == "transform"
        }
        if "`rowfilters'" != "" {
            quietly count if class == "filter" & subtype == "if" & !mm_drop
            local nrow = r(N)
            quietly replace mm_drop = 1 if class == "filter" & subtype == "if"
        }
        if "`varfilters'" != "" {
            quietly count if class == "filter" & subtype != "if" & !mm_drop
            local nvar = r(N)
            quietly replace mm_drop = 1 if class == "filter" & subtype != "if"
        }
        if "`tempfiles'" != "" {
            quietly count if mm_tmp & !mm_drop
            local ntmp = r(N)
            quietly replace mm_drop = 1 if mm_tmp
        }
        quietly drop if mm_drop
        quietly drop mm_tmp mm_drop

        * ---- the if, evaluated on a typed copy and brought back by row ----
        if `"`ifexp'"' != "" {
            quietly count
            local nbefore = r(N)
            quietly gen long mm_row = _n
            capture frame drop _mmcutn
            frame copy _mmcut _mmcutn
            frame _mmcutn {
                foreach v in seq line n_in k_in n_using k_using n_out k_out   ///
                    m1 m2 m3 m4 m5 dup_master dup_using force loop_n         ///
                    cover_master cover_using {
                    capture confirm variable `v'
                    if !_rc quietly destring `v', replace force
                }
                capture quietly gen byte mm_keep = (`ifexp')
                local ifrc = _rc
                if `ifrc' {
                    di as err `"mergemap: could not evaluate if `ifexp'"'
                    di as err "    use the journal's column names: dofile line class cmd subtype keys"
                    di as err "    master usingfile result n_in k_in n_using k_using n_out k_out"
                    di as err "    m1-m5 dup_master dup_using force opts loop_n severity flags"
                    di as err "    (text columns compare as text, count columns as numbers)"
                }
                else quietly keep mm_row mm_keep
            }
            if !`ifrc' {
                quietly frlink 1:1 mm_row, frame(_mmcutn)
                quietly frget mm_keep, from(_mmcutn)
                quietly keep if mm_keep == 1
                quietly drop mm_row mm_keep _mmcutn
                quietly count
                local nif = `nbefore' - r(N)
            }
            frame drop _mmcutn
        }
        * a frame cannot be dropped from inside its own block: leave the
        * block first, then drop and exit with the if's own error code
        if `ifrc' local N1 = .

        * ---- shorten the labels ----
        if `depth' > 0 | `"`root'"' != "" {
            foreach v in usingfile result master loop_first loop_last {
                mata: _mm_shortpaths("`v'", st_local("root"), `depth')
            }
        }

        if !`ifrc' {
            quietly count
            local N1 = r(N)
            tempfile jcut
            local jcut `"`jcut'.tsv"'
            quietly export delimited using `"`jcut'"', delimiter(tab) replace datafmt
        }
    }
    frame drop _mmcut
    if `ifrc' exit `ifrc'

    * ---- report ----
    local parts ""
    local sep ""
    if `ntr' > 0 {
        local parts `"`parts'`sep'`=trim(string(`ntr', "%20.0fc"))' transforms"'
        local sep ", "
    }
    if `nrow' > 0 | `nvar' > 0 {
        local f = `nrow' + `nvar'
        local parts `"`parts'`sep'`=trim(string(`f', "%20.0fc"))' filters"'
        if `nrow' > 0 & `nvar' > 0 {
            local parts `"`parts' (`=trim(string(`nrow', "%20.0fc"))' on rows, `=trim(string(`nvar', "%20.0fc"))' on variables)"'
        }
        else if `nrow' > 0 local parts `"`parts' on rows"'
        else               local parts `"`parts' on variables"'
        local sep ", "
    }
    if `ntmp' > 0 {
        local parts `"`parts'`sep'`=trim(string(`ntmp', "%20.0fc"))' tempfile events"'
        local sep ", "
    }
    if `nif' > 0 {
        local parts `"`parts'`sep'`=trim(string(`nif', "%20.0fc"))' by the if"'
        local sep ", "
    }
    local note ""
    if `"`parts'"' != "" {
        local note `"hidden: `parts'; `=trim(string(`N1', "%20.0fc"))' of `=trim(string(`N0', "%20.0fc"))' events drawn"'
    }
    else if `N1' < `N0' {
        local note `"`=trim(string(`N1', "%20.0fc"))' of `=trim(string(`N0', "%20.0fc"))' events drawn"'
    }
    if `"`note'"' != "" & "`quietly'" == "" di as txt "mergemap: `note'"
    if `"`root'"' != "" & "`quietly'" == "" {
        di as txt `"mergemap: paths shown relative to `root'"'
    }
    sreturn local jfile `"`jcut'"'
    sreturn local note  `"`note'"'
    sreturn local N_in  `N0'
    sreturn local N_out `N1'
    sreturn local n_transforms `ntr'
    sreturn local n_rowfilters `nrow'
    sreturn local n_varfilters `nvar'
    sreturn local n_tempfiles  `ntmp'
    sreturn local n_if         `nif'
end

* ------------------------------------------------------------------ mata
* Shorten one column of labels in place.  A value that is not a path
* ("work", ".", "", "tempfile:x", "frame:x") is left alone.  Both separators
* are honoured and the original separators are kept: the result is always
* a trailing substring of what was there, never a rewritten path.
*
*   root  : "" or a directory name (no separator) or a path prefix (with).
*           A name cuts everything up to and including the first component
*           that matches it; a prefix cuts that prefix when the path starts
*           with it.  Either way a path that does not contain it is left
*           as it was.
*   depth : 0 = keep all; k > 0 = keep the last k components.
mata:
void _mm_shortpaths(string scalar var, string scalar root, real scalar depth)
{
    real scalar    i, n, k, p, q, j, rlen, isname
    string colvector v
    string scalar  s, t, nr, low

    k = st_varindex(var)
    v = st_sdata(., k)
    n = rows(v)
    rlen = strlen(root)
    isname = (rlen > 0 & strpos(root, "/") == 0 & strpos(root, char(92)) == 0)
    nr = subinstr(root, char(92), "/", .)
    for (i = 1; i <= n; i++) {
        s = v[i]
        if (s == "" | s == "." | s == "work") continue
        if (substr(s, 1, 9) == "tempfile:" | substr(s, 1, 6) == "frame:") continue
        t = subinstr(s, char(92), "/", .)
        if (strpos(t, "/") == 0) continue
        /* ---- root ---- */
        if (rlen > 0) {
            if (isname) {
                /* first component equal to root, bounded by separators */
                p = 0
                if (substr(t, 1, rlen + 1) == nr + "/") p = 1
                else {
                    q = strpos(t, "/" + nr + "/")
                    if (q > 0) p = q + 1
                }
                if (p > 0) {
                    s = substr(s, p + rlen + 1, .)
                    t = substr(t, p + rlen + 1, .)
                }
            }
            else {
                /* a prefix; tolerate a trailing separator on the prefix */
                if (substr(nr, -1, 1) == "/") nr = substr(nr, 1, strlen(nr) - 1)
                if (substr(t, 1, strlen(nr) + 1) == nr + "/") {
                    s = substr(s, strlen(nr) + 2, .)
                    t = substr(t, strlen(nr) + 2, .)
                }
            }
        }
        /* ---- depth: last k components ---- */
        if (depth > 0) {
            j = 0
            for (p = strlen(t); p >= 1; p--) {
                if (substr(t, p, 1) == "/") {
                    j++
                    if (j == depth) {
                        s = substr(s, p + 1, .)
                        break
                    }
                }
            }
        }
        v[i] = s
    }
    st_sstore(., k, v)
}
end
