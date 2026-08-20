* runall.do -- the whole run-mode test battery.
* Run from tests/runmode/:  /usr/local/bin/stata-mp -b do runall.do
*
* Everything lands in one log, runall.log (a nested do does not open a log
* of its own).  Success check on that log:
*   - no line containing "FAIL"
*   - exactly one line starting with r(#, the r(601) that runmode_errors.do
*     provokes on purpose to prove a half-finished pipeline still leaves a
*     usable journal
* Each of the three do-files can also be run on its own, and then writes its
* own log; transparency.log and runmode_tests.log must be free of r( lines,
* runmode_errors.log is not.

clear all
set more off

display as txt _newline "================ building fixtures ================"
do makefx.do

display as txt _newline "================ transparency regression ================"
do transparency.do

display as txt _newline "================ run-mode behaviour ================"
do runmode_tests.do

display as txt _newline "================ deliberate failures ================"
do runmode_errors.do

display as txt _newline "================ run-mode battery complete ================"
