* runtests.do -- exercise the mergemap scanner prototype on the dev suite
* run from src/:  /usr/local/bin/stata-mp -b do runtests.do
version 16
clear all
set linesize 120

mergemap dev/t1_ugly.do, out(dev/t1_journal.tsv)
mergemap scan dev/t2_loops.do, out(dev/t2_journal.tsv)
mergemap dev/t3_delimit.do, out(dev/t3_journal.tsv)
mergemap dev/t4_tempfile.do, out(dev/t4_journal.tsv)
mergemap dev/t5_nested.do, out(dev/t5_journal.tsv)
mergemap dev/t6_cmds.do, out(dev/t6_journal.tsv)

* multi-file scan: seq continuity + noreceipt
mergemap dev/t4_tempfile.do dev/t5_nested.do, out(dev/t7_multi.tsv) noreceipt

* default out() name goes to cwd
mergemap dev/t1_ugly.do, noreceipt
capture erase journal.tsv

* receipt must also render the contract journals (scan AND run mode),
* including from a narrow linesize start state
set linesize 80
mergemap receipt "../proto/journal_scan.tsv"
mergemap receipt "../proto/journal_run.tsv"
assert c(linesize) == 80
set linesize 120

di as txt "runtests done"
