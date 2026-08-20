* s11_frames.do -- frame create + frlink m:1 + frget + fralias add
* counties_frame lacks a few live counties, so some observations stay
* unlinked (link variable missing). The alias variable is dropped before
* saving because alias variables cannot be saved.
* Run from tests/scenarios/. Reads ../raw/, writes ../out/.

use ../raw/participants.dta, clear
capture frame drop counties
frame create counties
frame counties: use ../raw/counties_frame.dta
frlink m:1 county, frame(counties)
frget povrate, from(counties)
fralias add slots, from(counties)
summarize povrate slots
drop slots
drop counties
save ../out/s11_with_frame_vars.dta, replace
