*! mmcmp -- run one merge plainly and again through _mm_merge, and compare.
*! The sort seed is pinned before each half: Stata's sort is not stable, so
*! without it even two plain runs of the same merge can leave the rows in a
*! different order.  Results land in globals SIGA, SIGB, CFRC.
program define mmcmp
    version 16
    args opts
    global MM_R_JRN ""
    set sortseed 31415
    use fxdata/master.dta, clear
    capture noisily merge 1:1 id using fxdata/lookup.dta, `opts'
    quietly datasignature
    global SIGA = r(datasignature)
    quietly save cmpA.dta, replace
    set sortseed 31415
    use fxdata/master.dta, clear
    capture noisily _mm_merge #9:1# 1:1 id using fxdata/lookup.dta, `opts'
    quietly datasignature
    global SIGB = r(datasignature)
    capture noisily cf _all using cmpA.dta
    global CFRC = _rc
end
