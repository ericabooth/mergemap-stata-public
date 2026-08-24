* gallery_prep.do -- everything the gallery needs that must run OUTSIDE the
* webdoc build.  Run mode rewrites do-files and controls how they execute,
* and webdoc do does the same to the document, so the two are kept apart:
* this file writes the run-mode journal, and gallery.do (built with webdoc2)
* only reads it.
*
* Run from gallery/:   do gallery_prep.do
* or let build_gallery.do call it for you.
*
* Author: Eric Booth

version 16
clear all

* the worked example: three small do-files that read Stata's auto data,
* trim it, join it, and save a summary -- the same files mergemap demo shows
* a first-time user
capture noisily mergemap demo, folder(gdemo) replace

* run them with instrumentation, so the gallery has observed counts, a
* _merge breakdown, and coverage to draw
mergemap run gdemo/01_cars.do gdemo/02_join.do gdemo/03_report.do, ///
    out(gallery_run.tsv) noreceipt

display as result "gallery_prep.do: wrote gallery_run.tsv"
