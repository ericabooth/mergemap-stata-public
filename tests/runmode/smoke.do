* smoke.do -- run mode over the full test pipeline, ledger and receipt on.
* Not an assertion test; it exists so a human can read what run mode prints.
* Run from tests/runmode/:  /usr/local/bin/stata-mp -b do smoke.do
clear all
set more off
adopath + "../../src"
cd ../pipeline
set sortseed 20260820
capture noisily _mm_run 00_master.do, out("../runmode/smoke_journal.tsv") examples(2)
display as txt "mergemap run returned rc = " _rc
cd ../runmode
