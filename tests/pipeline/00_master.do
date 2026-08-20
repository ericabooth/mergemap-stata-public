* 00_master.do -- run the mergemap test pipeline end to end
* Usage (from tests/pipeline/):  /usr/local/bin/stata-mp -b do 00_master.do
* Requires tests/raw/ built by ../maketestdata.do (or via ../runall.do,
* which runs everything).
*
* Hand-off design: the visit-level file passes from 02_panel.do to
* 03_analyze.do through a real tempfile whose path is published in global
* MM_VISITS. The tempfile is declared HERE, not in 02, because Stata
* erases a tempfile when the do-file that declared it ends -- declared in
* 02 it would be gone before 03 runs; declared here it lives until this
* master finishes. Chosen over re-saving to ../out/ because all three
* do-files run inside this single Stata session, so a true tempfile works
* and exercises tempfile provenance end to end.

clear all
tempfile __visits
global MM_VISITS "`__visits'"

do 01_build.do
do 02_panel.do
do 03_analyze.do

global MM_VISITS ""
display as txt "pipeline complete: see ../out/analysis_file.dta"
