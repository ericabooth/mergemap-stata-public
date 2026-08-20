* runall.do -- rebuild the raw data, run all 21 scenarios, run the pipeline
* Run from tests/:  /usr/local/bin/stata-mp -b do runall.do
* Success check: runall.log must contain no lines starting with r(#
* (s04/s05/s08/s09 need force or update options and run clean WITH them).

clear all
capture mkdir raw
capture mkdir out
local mmroot = c(pwd)

display as txt _newline "---- building raw datasets (maketestdata.do) ----"
do maketestdata.do

cd scenarios
local scen s01_merge11 s02_mergem1_keep s03_merge1m s04_mergemm_force   ///
    s05_update s06_joinby s07_cross s08_append_gen s09_append_loop     ///
    s10_merge_loop s11_frames s12_collapse_merge s13_reshape_merge     ///
    s14_contract_merge s15_xpose s16_fillin_expand s17_dups_isid       ///
    s18_tempfile_chain s19_preserve s20_nested_do s21_filters
foreach s of local scen {
    display as txt _newline "---- running `s'.do ----"
    do `s'.do
}
cd ..

cd pipeline
display as txt _newline "---- running the pipeline (00_master.do) ----"
do 00_master.do
cd ..

* ---- scan the pipeline with the scanner itself --------------------------
* Nothing is executed by this step; it checks that the v2 journal comes back
* with 34 columns and that the filters added to 01_build.do and 03_analyze.do
* show up as filter events.
capture which mergemap
if _rc {
    capture adopath + `"`mmroot'/../src"'
    capture which mergemap
}
if _rc {
    display as txt _newline "mergemap.ado not found on the ado-path; scan step skipped"
}
else {
    display as txt _newline "---- scanning the pipeline with mergemap (nothing executed) ----"
    cd pipeline
    mergemap 00_master.do, out(../out/pipeline_journal.tsv)
    cd ..
    capture frame drop _mmchk
    frame create _mmchk
    frame _mmchk {
        qui import delimited using "out/pipeline_journal.tsv", delimiter(tab) ///
            varnames(1) stringcols(_all) bindquote(nobind) clear
        local ncol = c(k)
        qui count if strtrim(class) == "filter"
        local nfilt = r(N)
        qui count if strtrim(class) == "join"
        local njoin = r(N)
    }
    frame drop _mmchk
    display as txt "journal: `ncol' columns, `njoin' joins, `nfilt' filter events"
    assert `ncol'  == 34
    assert `nfilt' >= 3
    assert `njoin' >= 4
}

display as txt _newline "runall complete: all scenarios and the pipeline ran"
