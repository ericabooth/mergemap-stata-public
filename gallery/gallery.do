*--------------------------------------------------------------------*
* gallery.do -- everything mergemap produces, one section per output,
* with the Stata code that made each one in a collapsible panel.
*
* Build with build_gallery.do (it runs gallery_prep.do first, then
* webdoc2 gallery.do, cleanup).  The page this writes is gallery.html.
*
* Author: Eric Booth
*--------------------------------------------------------------------*

wdinit gallery, replace
wdwidth 1100px
* the browser-tab title (webdoc's default is the file name)
webdoc put <script>document.title = "mergemap gallery";</script>

wdnavbar mergemap gallery
wdnavdropdown Sections
    wdnavdropdownitem The receipt          , href(#the-receipt)
    wdnavdropdownitem Results window       , href(#the-map-in-the-results-window)
    wdnavdropdownitem HTML page            , href(#the-map-as-an-html-page)
    wdnavdropdownitem PNG figure           , href(#the-map-as-a-png-figure)
    wdnavdropdownitem Mermaid and DOT      , href(#the-map-as-text-mermaid-and-dot)
    wdnavdropdownitem Run mode             , href(#run-mode-observed-counts)
    wdnavdropdownitem Merge forms          , href(#what-each-merge-form-does)
    wdnavdropdownitem Long maps            , href(#when-a-map-is-too-long)
wdnavdropdownclose
wdnavitem GitHub , href(https://github.com/ericabooth/mergemap-stata-public)
wdnavbarclose

wputh1 What this page shows
wput mergemap reads a series of Stata do-files and reports every merge, append, joinby, cross, frlink and frget in them, along with the keep and drop statements that change the row count around them. It executes nothing unless you ask it to. This page walks through each thing it produces, on a worked example of three small do-files that read Stata's auto data, trim it, join it, and save a summary. Every section shows the Stata code that made it; click a grey panel to unfold the code and its output.
wput Install and make the worked example yourself with:
button
display as text "net install mergemap, from(" _char(34) "https://raw.githubusercontent.com/ericabooth/mergemap-stata-public/main/" _char(34) ") replace"
display as text "mergemap demo"
buttonclose

wputh1 The receipt
wput Point mergemap at do-files and it prints the receipt: a numbered table with one row per thing it found, in the order the code performs them, each with the file and line to go look at. Nothing is executed; the code is read as text. The same record is also written to a small tab-separated file called the journal, which every later command reads back.
wd
mergemap gdemo/01_cars.do gdemo/02_join.do gdemo/03_report.do, out(gallery_scan.tsv)
wdclose

wputh1 The map in the Results window
wput mergemap draw turns the most recent journal into a drawing. Small maps render right in the Results window; past eight join, reshape, and filter events, or for wide layouts, it writes an HTML page instead. Here the Results-window drawing is forced so you can see its style: boxes are datasets, arrows are the flow of data, joined-in files enter from the side, and slim boxes are keep and drop steps.
wd
mergemap draw gallery_scan.tsv, forcesmcl maxnodes(99)
wdclose

wputh1 The map as an HTML page
wput The HTML page is a single self-contained file: no internet connection, no JavaScript, no external assets. Hover any box for the full record of that event. The page below is embedded from the file the code panel writes; it scrolls in place.
button
mergemap draw gallery_scan.tsv, export(html) saving(g_map.html) replace noopen
buttonclose
wdiframe g_map.html, height(620px)
wput A horizontal layout of the same map suits slides and wide screens:
button
mergemap draw gallery_scan.tsv, export(html) saving(g_map_h.html) layout(horizontal) replace noopen
buttonclose
wdiframe g_map_h.html, height(560px)

wputh1 The map as a PNG figure
wput For a paper or a Word document, export(png) draws the map through Stata's own graph engine, so it needs nothing installed and matches your other figures' resolution handling. An SVG twin is written alongside each PNG. A map too dense for one readable image splits itself into one page per do-file, which is what happens here:
button
mergemap draw gallery_scan.tsv, export(png) saving(g_map) replace
buttonclose
wdimg g_map_01_cars.png, caption(Page one of the split: the first do-file's part of the map, as a PNG through Stata's graph engine.)
wdimg g_map_02_join.png, caption(Page two: the second do-file, where the joins happen.)

wputh1 The map as text: mermaid and DOT
wput Mermaid and DOT are plain-text diagram languages: the export is a small text file naming the boxes and arrows, and other software draws it. Mermaid text renders by itself when pasted into GitHub, Quarto, VS Code, or mermaid.live, which makes it the right export when you want the map inside a README or a wiki instead of as an image file. DOT is the same idea in Graphviz's language. The diagram below is the mermaid export of the demo map, drawn live by this page:
button
mergemap draw gallery_scan.tsv, export(mermaid) saving(g_map) replace
type g_map_td.mmd
buttonclose
* render the mermaid text live on this page: the diagram file is read line
* by line into the document, wrapped in a pre block the mermaid library
* (loaded once, below) turns into a drawing in the browser
webdoc put <div style="background:#ffffff;border:1px solid #e4e4e4;border-radius:6px;padding:10px;margin:12px 0;overflow-x:auto;">
webdoc put <pre class="mermaid" style="background:none;border:none;margin:0;">
tempname mmfh
file open `mmfh' using "g_map_td.mmd", read text
file read `mmfh' mmline
while r(eof) == 0 {
    webdoc put `macval(mmline)'
    file read `mmfh' mmline
}
file close `mmfh'
webdoc put </pre>
webdoc put </div>
webdoc put <script type="module">import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs"; mermaid.initialize({startOnLoad:true, theme:"neutral"});</script>
wput And the DOT version of the same map, as text:
button
mergemap draw gallery_scan.tsv, export(dot) saving(g_map) replace
type g_map_tb.dot
buttonclose

wputh1 Run mode: observed counts
wput Everything above came from a scan, which reads code and never executes it, so it cannot know how many rows matched. Run mode executes the do-files with instrumentation around each join and records what actually happened: rows in and out, the _merge breakdown, duplicate keys, and what share of each side took part. Your results are unchanged; the wrappers call the real commands and pass every option through. The journal below was written before this page was built, by gallery_prep.do, because run mode and webdoc2 (the package that builds this page) both need control of how a do-file executes, so the two are kept apart.
wput The receipt from the run, now with counts:
button
mergemap receipt gallery_run.tsv
buttonclose
wput The same map, drawn with the counts in it:
button
mergemap draw gallery_run.tsv, export(html) saving(g_map_run.html) replace noopen
buttonclose
wdiframe g_map_run.html, height(680px)
wput One event in depth, straight from the journal:
button
mergemap detail 6 gallery_run.tsv
buttonclose

wputh1 What each merge form does
wput mergemap sql is for the moments when you, a student, or a collaborator from the R or Python side needs to see what a Stata merge form does to rows. It prints a table matching each Stata form to its name in SQL, dplyr, and pandas, and draws any form as a worked example: two toy tables, the command, and the result, with the rule for how many rows come out. The subcommand is named sql because that is where the shared join vocabulary comes from; nothing about it requires SQL, and it never touches your data.
button
mergemap sql
buttonclose
wput One form drawn as a worked example. The m:m case reads as a warning on purpose: merge m:m pairs rows by the order they happen to be in, and joinby is the true many-to-many:
button
mergemap sql joinby
buttonclose
wput The same diagram is available for your own joins: mergemap detail with the draw option takes one event from the journal and draws its row pairing with the observed counts in place of the toy rows.
button
mergemap detail 6 gallery_run.tsv, draw
buttonclose

wputh1 When a map is too long
wput A real build can record thousands of events, and most of them are not joins. The journal and the receipt always keep every event; the drawing is where you choose what to look at. Each option hides one kind of event, the options combine, and draw prints a line saying exactly what it hid. filesonly leaves the joins between named files; an if on the journal's own columns cuts any way the record can be sliced; paths(base) and root() shorten long file paths in the labels.
button
mergemap draw gallery_run.tsv, filesonly export(html) saving(g_map_files.html) replace noopen
buttonclose
wdiframe g_map_files.html, height(430px)
wput The record itself is never cut. Export it whole, as a dataset or as a three-sheet Excel workbook (every event; the joins with their counts; every keep and drop with the rows it removed), sortable and filterable in Excel:
button
mergemap export gallery_run.tsv, saving(g_journal.xlsx) replace
buttonclose

wput This page was generated by gallery.do in the mergemap repository, using the webdoc2 package. See the README for installation and the help file (help mergemap) for every option.
