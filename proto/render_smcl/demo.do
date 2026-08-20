* demo.do -- driver for the SMCL diagram renderer prototype (_mm_rendersmcl.ado)
* Author: Eric Booth
*
* Renders BOTH v2 contract journals (../journal_scan.tsv, ../journal_run.tsv)
* in BOTH styles (boxes = default, rail = compact) at linesize 80 AND 120,
* captures each to a named .smcl log, and translates it to plain-text .txt
* for the gallery.  Also demonstrates the maxnodes(8) auto-escalation notice
* (the receipt itself now belongs to mergemap.ado, not to this renderer) and
* smoke-tests the options.
*
* Every emitted .txt is width-checked: no line may exceed the linesize it was
* rendered at, which is the alignment regression this prototype keeps failing
* when box arithmetic drifts.
*
* Run headless from this directory:
*   cd proto/render_smcl && /usr/local/bin/stata-mp -b do demo.do

adopath + "../../src"
clear all
set more off

* ---- width checker ----------------------------------------------------
* reads a file without ever expanding its contents (the journals carry
* literal backticks and dollar signs, so `"`line'"' would detonate)
capture program drop _rsm_wcheck
program define _rsm_wcheck
    args fn w
    tempname fh
    local over 0
    local maxw 0
    file open `fh' using "`fn'", read text
    file read `fh' line
    while r(eof) == 0 {
        local n : length local line
        if `n' > `maxw' local maxw `n'
        if `n' > `w' local over = `over' + 1
        file read `fh' line
    }
    file close `fh'
    if `over' > 0 di as err "WIDTH FAIL `fn': `over' line(s) over `w' (max `maxw')"
    else di as txt "width ok `fn': max `maxw' <= `w'"
end

* ---- gallery renders, both journals x both styles x 80 and 120 --------
foreach w in 80 120 {
    set linesize `w'
    translator set smcl2log linesize `w'
    foreach st in boxes rail {
        foreach jm in scan run {
            local stub smcl_`st'_`jm'
            if `w' == 120 local stub smcl_`st'_`jm'_120
            capture log close _mm
            log using `stub'.smcl, replace smcl name(_mm) nomsg
            _mm_rendersmcl using ../journal_`jm'.tsv, style(`st') forcesmcl
            log close _mm
            translate `stub'.smcl `stub'.txt, translator(smcl2log) replace
            _rsm_wcheck `stub'.txt `w'
        }
    }
}

* ---- wide render: wrap() buys real width at linesize 120 ---------------
set linesize 120
translator set smcl2log linesize 120
capture log close _mm
log using smcl_wide120.smcl, replace smcl name(_mm) nomsg
_mm_rendersmcl using ../journal_run.tsv, style(boxes) forcesmcl wrap(56)
log close _mm
translate smcl_wide120.smcl smcl_wide120.txt, translator(smcl2log) replace
_rsm_wcheck smcl_wide120.txt 120

* ---- auto-escalation: the notice only, no receipt ----------------------
* both contract journals carry 12 join+transform+filter events, over the
* maxnodes(8) default, so a bare call defers the diagram to HTML.  The
* receipt that used to print here now belongs to mergemap.ado.
set linesize 80
translator set smcl2log linesize 80
capture log close _mm
log using smcl_escalation.smcl, replace smcl name(_mm) nomsg
_mm_rendersmcl using ../journal_scan.tsv
_mm_rendersmcl using ../journal_run.tsv
_mm_rendersmcl using ../journal_run.tsv, style(rail)
_mm_rendersmcl using ../journal_run.tsv, layout(horizontal) forcesmcl
_mm_rendersmcl using ../journal_run.tsv, maxnodes(20) style(rail) nocounts
log close _mm
translate smcl_escalation.smcl smcl_escalation.txt, translator(smcl2log) replace
_rsm_wcheck smcl_escalation.txt 80

* ---- option smoke test: compact / nocounts / nokeys / noellipsis -------
capture log close _mm
log using smcl_options.smcl, replace smcl name(_mm) nomsg
_mm_rendersmcl using ../journal_run.tsv, style(boxes) forcesmcl compact
_mm_rendersmcl using ../journal_run.tsv, style(boxes) forcesmcl noellipsis nokeys
_mm_rendersmcl using ../journal_run.tsv, style(rail) forcesmcl nocounts notransforms
_mm_rendersmcl using ../journal_scan.tsv, style(rail) forcesmcl wrap(20) maxnodes(20)
_mm_rendersmcl using ../journal_scan.tsv, style(boxes) forcesmcl wrap(60)
log close _mm
translate smcl_options.smcl smcl_options.txt, translator(smcl2log) replace
_rsm_wcheck smcl_options.txt 80

* ---- the outputs the round-1 gallery carried that are now superseded ---
capture erase smcl_width120.smcl
capture erase smcl_width120.txt

di as txt "demo.do completed"
