* runall.do -- regenerate every artifact in gallery/ from scratch.
* Author: Eric Booth
*
* Run headless from this directory:
*   cd gallery && /usr/local/bin/stata-mp -b do runall.do
* then check the log:  grep '^r([0-9]' runall.log   (should print nothing)
*
* Steps
*   1. scan the real test do-files with the scanner prototype
*      (../src/mergemap.ado): six scenarios + the pipeline; journals land
*      in journals/.  The pipeline is scanned twice: via 00_master.do
*      (exercises nested-do recursion; includes class=flow rows) and as
*      the three numbered files directly (the contract-journal shape used
*      by the renders below).
*   2. run all four renderer prototypes over (i) the two contract
*      journals in ../proto/ and (ii) the scanner-emitted pipeline
*      journal, writing gallery-ready outputs into this directory.
*   3. shell out to make_gallery.sh to assemble the self-contained
*      gallery.html (base64-embedded PNGs, inlined text renders).
*
* Requirements: the ado files in ../src and ../proto/render_*/ (picked up
* via adopath below; nothing is installed), and the test do-files in
* ../tests/.  No dataset is needed -- scanning is static and the sample
* journals carry their own counts.

clear all
set more off
version 16

* Absolute, not relative: step 2f cd's into ../tests/pipeline to run the
* instrumented pipeline, and a relative adopath entry stops resolving the
* moment the working directory moves (_mm_run then reads as unrecognized).
local HERE `"`c(pwd)'"'
adopath + `"`HERE'/../src"'
adopath + `"`HERE'/../proto/render_smcl"'
adopath + `"`HERE'/../proto/render_html"'
adopath + `"`HERE'/../proto/render_twoway"'
adopath + `"`HERE'/../proto/render_text"' 

local SCANJ "../proto/journal_scan.tsv"     // contract journal, scan mode
local RUNJ  "../proto/journal_run.tsv"      // contract journal, run mode
local PIPEJ "journals/journal_pipeline.tsv" // emitted by step 1 below

* journals/ must exist before the first scan writes into it: on a fresh
* checkout the directory is absent and -mergemap, out(journals/...)- dies
* r(603) before anything else runs.
capture mkdir journals

* ================= 1. scanner over the real test files ==================

* six scenario do-files named in the integration brief
foreach s in s02_mergem1_keep s04_mergemm_force s09_append_loop ///
    s10_merge_loop s18_tempfile_chain s20_nested_do {
    mergemap ../tests/scenarios/`s'.do, out(journals/`s'.tsv) noreceipt
}

* pipeline via the master (recursion through do 01/02/03; flow rows kept)
mergemap ../tests/pipeline/00_master.do, ///
    out(journals/journal_master.tsv) noreceipt

* pipeline as three files, mirroring the contract journal; the scan and
* its default receipt are captured to .smcl and translated to ASCII for
* gallery section 1 (the receipt table is 118 cols wide, hence 120)
set linesize 120
translator set smcl2log linesize 120
capture log close _g
log using receipt_pipeline.smcl, replace smcl name(_g) nomsg
mergemap ../tests/pipeline/01_build.do ../tests/pipeline/02_panel.do ///
    ../tests/pipeline/03_analyze.do, out(`PIPEJ')
log close _g
translate receipt_pipeline.smcl receipt_pipeline.txt, ///
    translator(smcl2log) replace

* ================= 2a. SMCL diagrams (boxes + rail) =====================
* rendered at linesize 80; captured via named smcl log then translated
* to ASCII .txt (the C1 convention); forcesmcl because the run and
* pipeline journals both exceed the maxnodes(8) escalation default

set linesize 80
translator set smcl2log linesize 80
foreach st in boxes rail {
    foreach j in scan run pipe {
        if "`j'" == "scan" local jf "`SCANJ'"
        if "`j'" == "run"  local jf "`RUNJ'"
        if "`j'" == "pipe" local jf "`PIPEJ'"
        capture log close _g
        log using smcl_`st'_`j'.smcl, replace smcl name(_g) nomsg
        _mm_rendersmcl using `jf', style(`st') forcesmcl
        log close _g
        translate smcl_`st'_`j'.smcl smcl_`st'_`j'.txt, ///
            translator(smcl2log) replace
    }
}

* auto-escalation demo: a bare call on the run journal (10 join+transform
* events > 8) prints the compact receipt plus the defer-to-HTML notice
capture log close _g
log using smcl_escalation.smcl, replace smcl name(_g) nomsg
_mm_rendersmcl using `RUNJ'
log close _g
translate smcl_escalation.smcl smcl_escalation.txt, ///
    translator(smcl2log) replace

* ================= 2b. HTML + inline-SVG renderer =======================

_mm_renderhtml using `SCANJ', saving(html_vert_scan.html) replace
_mm_renderhtml using `RUNJ',  saving(html_vert_run.html) replace
_mm_renderhtml using `RUNJ',  saving(html_horiz_run.html) layout(horizontal) replace
_mm_renderhtml using `RUNJ',  saving(html_vert_run_details.html) details replace
_mm_renderhtml using `PIPEJ', saving(html_vert_pipe.html) replace
_mm_renderhtml using `PIPEJ', saving(html_vert_pipe_details.html) details replace

* ================= 2c. native twoway renderer ===========================
* writes <stub>.png (width 1600) and <stub>.svg

_mm_rendertw using `RUNJ',  saving(tw_vert_run)
_mm_rendertw using `RUNJ',  saving(tw_horiz_run) layout(horizontal)
_mm_rendertw using `SCANJ', saving(tw_vert_scan)
* The scanned pipeline carries 15 join/transform/filter events, past the
* native-graph renderer's readable cap, so it is drawn one page per do-file.
* That is exactly the case page(dofile) exists for.
_mm_rendertw using `PIPEJ', saving(tw_pipe) page(dofile)

* ================= 2d. mermaid / DOT text exports =======================
* writes <stub>_td.mmd/.md, <stub>_lr.mmd/.md, <stub>_tb.dot, <stub>_lr.dot

_mm_rendertext using `RUNJ',  saving(text_run) replace
_mm_rendertext using `SCANJ', saving(text_scan) replace
_mm_rendertext using `PIPEJ', saving(text_pipe) replace

* ================= 2e. teach-mode row-stack pictures ====================
* the shipped teach mode: capture two pictures the way a user sees them

set linesize 100
translator set smcl2log linesize 100
foreach t in m1 mm {
    local pic = cond("`t'" == "m1", "left", "mm")
    capture log close _g
    log using teach_merge_`t'.smcl, replace smcl name(_g) nomsg
    mergemap sql `pic'
    log close _g
    translate teach_merge_`t'.smcl teach_merge_`t'.txt, ///
        translator(smcl2log) replace
}
set linesize 80
translator set smcl2log linesize 80

* ================= 2f. round-2 material for section 8 ===================
* demo receipt, run-mode ledger and an embed fragment, captured the same way
* as the renders above so the gallery regenerates from nothing.

capture erase demo_receipt.smcl
shell rm -rf demo_out
set linesize 100
translator set smcl2log linesize 100
capture log close _g
log using demo_receipt.smcl, replace smcl name(_g) nomsg
mergemap demo, folder(demo_out)
log close _g
translate demo_receipt.smcl demo_receipt.txt, translator(smcl2log) replace

* run mode over the same pipeline the renders use.  It is expected to end
* with rc 9: the pipeline's deliberate m:m merge breaches the stop
* threshold, which is the behaviour the ledger is there to show.
* cd BEFORE opening the log and AFTER closing it: -cd- echoes the absolute
* path it landed in, and an emitted artifact should not carry this machine's
* directory layout.
cd ../tests/pipeline
capture log close _g
log using ../../gallery/runmode_ledger.smcl, replace smcl name(_g) nomsg
set sortseed 20260820
capture noisily _mm_run 00_master.do, ///
    out("../../gallery/journals/journal_runmode.tsv") noreceipt
log close _g
cd ../../gallery
translate runmode_ledger.smcl runmode_ledger.txt, translator(smcl2log) replace

* the embed fragment that section 8 inlines (and that
* tests/embedcheck/check_embed_scoping.py asserts is safely scoped)
_mm_renderhtml using `RUNJ', saving(embed_fragment.html) embed replace

set linesize 80

* ================= 3. assemble gallery.html =============================

!bash make_gallery.sh

di as txt "runall.do done -- open gallery.html"
