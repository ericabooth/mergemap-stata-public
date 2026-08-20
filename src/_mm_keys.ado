*! version 0.2.0  20aug2026  Eric Booth
*! _mm_keys -- duplicate counts, coverage, and top-k unmatched keys for a
*! join, computed in Mata with a hash table.
*!
*! Why Mata and not duplicates/contract/merge.  Stata's sort is not stable:
*! ties are broken from the sort seed, and every sort advances it.  A
*! diagnostic sort anywhere -- even inside a scratch frame -- therefore
*! changes how the USER's later sorts break ties, and a collapse (mean)
*! downstream then differs in the low bits.  Saving c(sortseed) and setting
*! it back does not undo this: the state string round-trips unchanged, but
*! setting it still shifts the next sort (measured directly).  So run mode
*! must not sort at all.  Mata's hashing does the same work deterministically
*! and touches nothing.
*!
*! Reads the key variables of the data in memory and of frame _mmuk.  Neither
*! is modified.
*!
*! Output globals: MM_R_DUPM MM_R_DUPU   obs minus distinct key values
*!                 MM_R_COVMN MM_R_COVMD master rows matched / master rows
*!                 MM_R_COVUN MM_R_COVUD using rows matched / using rows
*!                 MM_R_COVM MM_R_COVU   the two percentages
*!                 MM_R_TOPK             most frequent unmatched master keys

program define _mm_keys
    version 16
    syntax , keys(string) [k(integer 3)]
    foreach g in DUPM DUPU COVM COVU COVMN COVMD COVUN COVUD {
        global MM_R_`g' "."
    }
    global MM_R_TOPK ""
    if `"`keys'"' == "" | `"`keys'"' == "." exit
    capture frame _mmuk: qui count
    if _rc exit
    foreach v of local keys {
        capture confirm variable `v'
        if _rc exit
    }
    capture mata: _mm_kcalc("`keys'", `k')
end

version 16
mata:

string colvector _mm_kvec(string rowvector vars)
{
    real scalar    j, n, i, idx
    string colvector out, s
    real colvector   x

    n = st_nobs()
    out = J(n, 1, "")
    if (n == 0) return(out)
    for (j = 1; j <= cols(vars); j++) {
        idx = st_varindex(vars[j])
        if (idx == .) return(J(0, 1, ""))
        if (st_isstrvar(idx)) {
            s = st_sdata(., idx)
        }
        else {
            x = st_data(., idx)
            s = J(n, 1, "")
            for (i = 1; i <= n; i++) {
                if (x[i] == .) s[i] = "."
                else s[i] = strofreal(x[i], "%21x")
            }
        }
        out = out :+ (char(31) :+ s)
    }
    return(out)
}

string scalar _mm_klab(string rowvector vars, real scalar row)
{
    real scalar   j, idx
    string scalar s
    s = ""
    for (j = 1; j <= cols(vars); j++) {
        idx = st_varindex(vars[j])
        if (j > 1) s = s + " "
        if (st_isstrvar(idx)) s = s + st_sdata(row, idx)
        else s = s + strofreal(st_data(row, idx))
    }
    return(s)
}

void _mm_kcalc(string scalar keystr, real scalar topk)
{
    string rowvector vars
    string colvector km, ku, uk
    string scalar    cur, lab
    transmorphic     A, B, U
    real scalar      i, j, nb, covmn, covun, c, best, bi
    real rowvector   counts, reps

    vars = tokens(keystr)
    km   = _mm_kvec(vars)
    cur  = st_framecurrent()
    st_framecurrent("_mmuk")
    ku = _mm_kvec(vars)
    st_framecurrent(cur)
    if (rows(km) == 0 | rows(ku) == 0) return

    A = asarray_create("string", 1)
    asarray_notfound(A, 0)
    for (i = 1; i <= rows(km); i++) asarray(A, km[i], asarray(A, km[i]) + 1)
    B = asarray_create("string", 1)
    asarray_notfound(B, 0)
    for (i = 1; i <= rows(ku); i++) asarray(B, ku[i], asarray(B, ku[i]) + 1)

    covmn = 0
    for (i = 1; i <= rows(km); i++) {
        if (asarray(B, km[i]) > 0) covmn = covmn + 1
    }
    covun = 0
    for (i = 1; i <= rows(ku); i++) {
        if (asarray(A, ku[i]) > 0) covun = covun + 1
    }

    st_global("MM_R_DUPM",  strofreal(rows(km) - asarray_elements(A), "%18.0g"))
    st_global("MM_R_DUPU",  strofreal(rows(ku) - asarray_elements(B), "%18.0g"))
    st_global("MM_R_COVMN", strofreal(covmn,     "%18.0g"))
    st_global("MM_R_COVMD", strofreal(rows(km),  "%18.0g"))
    st_global("MM_R_COVUN", strofreal(covun,     "%18.0g"))
    st_global("MM_R_COVUD", strofreal(rows(ku),  "%18.0g"))
    st_global("MM_R_COVM",  strofreal(100 * covmn / rows(km), "%4.1f"))
    st_global("MM_R_COVU",  strofreal(100 * covun / rows(ku), "%4.1f"))

    /* the most frequent master keys with no partner in the using file */
    U = asarray_create("string", 1)
    asarray_notfound(U, 0)
    for (i = 1; i <= rows(km); i++) {
        if (asarray(B, km[i]) == 0) {
            if (asarray(U, km[i]) == 0) asarray(U, km[i], i)
        }
    }
    uk = asarray_keys(U)
    nb = rows(uk)
    if (nb == 0) return
    counts = J(1, nb, 0)
    reps   = J(1, nb, 0)
    for (j = 1; j <= nb; j++) {
        counts[j] = asarray(A, uk[j])
        reps[j]   = asarray(U, uk[j])
    }
    lab = ""
    for (c = 1; c <= min((topk, nb)); c++) {
        best = -1
        bi   = 0
        for (j = 1; j <= nb; j++) {
            if (counts[j] > best) {
                best = counts[j]
                bi   = j
            }
        }
        if (bi == 0) break
        if (lab != "") lab = lab + ", "
        lab = lab + _mm_klab(vars, reps[bi]) + " (" + strofreal(best, "%18.0gc") + ")"
        counts[bi] = -1
    }
    st_global("MM_R_TOPK", lab)
}

end
