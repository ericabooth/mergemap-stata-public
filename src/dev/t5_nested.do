* t5: nested do-file recursion
use raw/participants, clear
do dev/t5_child.do
save built/t5_out, replace
