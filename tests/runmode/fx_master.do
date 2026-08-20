* fx_master.do -- fixture that calls a child do-file, so the recursive
* rewrite of do/run is exercised.
clear all
do fx_child.do
save fxdata/out_master.dta, replace
