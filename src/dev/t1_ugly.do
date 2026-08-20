* t1: comments, continuations, prefixes, strings
use raw/base, clear
/* block comment
   spanning lines /* nested */ still inside */
merge 1:1 id ///
    using raw/lookup, ///
    keep(1 3) nogenerate
di "do not merge using fake.dta here"    // string + trailing comment
cap noi append using raw/extra // appended
qui merge m:m id using raw/dups, force
save built/t1_out, replace
