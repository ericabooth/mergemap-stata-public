#!/bin/sh
# check.sh -- diff scanner journals against frozen expected fixtures
# usage: run runtests.do and dev/devtests.do first (from src/), then:
#        sh dev/check.sh
# t1-t7 come from runtests.do; t8-t10 (filters, macro paths and cd, clobber)
# come from dev/devtests.do.
cd "$(dirname "$0")" || exit 1
fail=0
for t in t1 t2 t3 t4 t5 t6 t8 t9 t10; do
    if diff -q "${t}_expected.tsv" "${t}_journal.tsv" >/dev/null 2>&1; then
        echo "PASS  ${t}"
    else
        echo "FAIL  ${t}"
        diff "${t}_expected.tsv" "${t}_journal.tsv"
        fail=1
    fi
done
if diff -q t7_expected.tsv t7_multi.tsv >/dev/null 2>&1; then
    echo "PASS  t7 (multi-file)"
else
    echo "FAIL  t7 (multi-file)"
    diff t7_expected.tsv t7_multi.tsv
    fail=1
fi
exit $fail
