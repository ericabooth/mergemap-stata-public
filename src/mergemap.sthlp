{smcl}
{* *! version 0.3.1  20aug2026  Eric Booth}{...}
{vieweralsosee "[D] merge" "help merge"}{...}
{vieweralsosee "[D] append" "help append"}{...}
{vieweralsosee "[D] joinby" "help joinby"}{...}
{vieweralsosee "[D] frlink" "help frlink"}{...}
{viewerjumpto "Quick start" "mergemap##quickstart"}{...}
{viewerjumpto "Installation" "mergemap##install"}{...}
{viewerjumpto "Syntax" "mergemap##syntax"}{...}
{viewerjumpto "Description" "mergemap##description"}{...}
{viewerjumpto "Reading the receipt" "mergemap##receipt"}{...}
{viewerjumpto "Scan mode versus run mode" "mergemap##modes"}{...}
{viewerjumpto "Drawing the map" "mergemap##draw"}{...}
{viewerjumpto "Options" "mergemap##options"}{...}
{viewerjumpto "Examples" "mergemap##examples"}{...}
{viewerjumpto "Joins in Stata and SQL" "mergemap##sql"}{...}
{viewerjumpto "Flags and what to do about them" "mergemap##flags"}{...}
{viewerjumpto "Putting a map in a document" "mergemap##embed"}{...}
{viewerjumpto "Limitations" "mergemap##limits"}{...}
{viewerjumpto "Stored results" "mergemap##results"}{...}
{title:Title}

{phang}
{bf:mergemap} {hline 2} Map the merges, appends, and joins across your do-files

{marker quickstart}{...}
{title:Quick start}

{pstd}
If you have never run {bf:mergemap}, start here. This writes three small example
do-files into a new folder, scans them, and shows you the output:{p_end}

{phang2}{stata "mergemap demo":. mergemap demo}{p_end}

{pstd}
Then point it at your own work. Give it your do-files in the order you run them:{p_end}

{phang2}{cmd:. mergemap 01_clean.do 02_merge.do 03_analyze.do}{p_end}

{pstd}
or point it at a folder and let it take the {cmd:.do} files in name order:{p_end}

{phang2}{cmd:. mergemap build/}{p_end}

{pstd}
Nothing is executed. {bf:mergemap} reads your code the way you would read it and
prints a numbered receipt of every join it found. Then draw it:{p_end}

{phang2}{cmd:. mergemap draw}{p_end}

{pstd}
which renders the map in the Results window when it fits, and writes it as a
self-contained HTML page when it does not.{p_end}

{marker install}{...}
{title:Installation}

{pstd}
From a local clone:{p_end}

{phang2}{cmd:. net install mergemap, from("/path/to/mergemap") replace}{p_end}

{pstd}
{cmd:mergemap} needs Stata 16 or later and nothing else: no Python, no LaTeX, and no
external programs.{p_end}

{pstd}
The test battery is an ancillary file, so {helpb net install} does not place it.
{helpb net get:net get mergemap} puts it in the current directory if you want to run
it.{p_end}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mergemap} [{cmd:scan}] {it:{help filename:dofile}} [{it:dofile} ...] [{cmd:,}
{opt out(filename)} {opt fold:er(path)} {opt noreceipt}]

{p 8 17 2}
{cmd:mergemap check} {it:dofile} [{it:dofile} ...] [{cmd:,} {opt out(filename)}
{opt fold:er(path)}]

{p 8 17 2}
{cmd:mergemap run} {it:dofile} [{it:dofile} ...] [{cmd:,} {opt out(filename)}
{opt fold:er(path)} {opt ex:amples(#)} {opt nochecks} {opt warn(#)} {opt stop(#)}]

{p 8 17 2}
{cmd:mergemap draw} [{it:journalfile}] [{cmd:,} {opt exp:ort(target)}
{opt sav:ing(filename)} {it:draw_options}]

{p 8 17 2}
{cmd:mergemap sql} [{it:picture}]

{p 8 17 2}
{cmd:mergemap demo} [{it:foldername}] [{cmd:,} {opt fold:er(path)} {opt replace}]

{p 8 17 2}
{cmd:mergemap receipt} {it:journalfile} [{cmd:,} {opt check}]

{p 8 17 2}
{cmd:mergemap list} [{it:journalfile}] [{cmd:,} {opt full}]

{p 8 17 2}
{cmd:mergemap detail} {it:#} [{it:journalfile}] [{cmd:,} {opt teach}]

{p 8 17 2}
{cmd:mergemap export} [{it:journalfile}] [{cmd:,} {opt f:ormat(dta|csv)}
{opt sav:ing(filename)} {opt replace}]

{p 8 17 2}
{cmd:mergemap clear}

{pstd}
{it:dofile} may be a file name, a folder, or a pattern such as {cmd:0*.do}.
Folders and patterns expand to their {cmd:.do} files in name order, and a missing
{cmd:.do} extension is supplied for you.{p_end}

{synoptset 26 tabbed}{...}
{synopthdr:subcommand}
{synoptline}
{synopt :{opt demo}}write a worked example, scan it, and show the output{p_end}
{synopt :{opt scan}}read do-files without running them {it:(the default)}{p_end}
{synopt :{opt check}}show only the events that carry a flag{p_end}
{synopt :{opt run}}run the do-files and record what actually happened{p_end}
{synopt :{opt draw}}draw the map: Results window, HTML, PNG/SVG, mermaid, DOT{p_end}
{synopt :{opt sql}}teach a join form as a row-pairing picture{p_end}
{synopt :{opt receipt}}reprint the receipt from a saved journal{p_end}
{synopt :{opt list}}the journal as a table; {opt full} for every column{p_end}
{synopt :{opt detail} {it:#}}everything known about one event; {opt teach} draws it{p_end}
{synopt :{opt export}}the journal as a dataset, {cmd:.dta} or {cmd:.csv}{p_end}
{synopt :{opt clear}}forget the remembered journal; files are never touched{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:mergemap} answers one question: how did this dataset get built? It reads a
sequence of do-files, finds every {helpb merge}, {helpb append}, {helpb joinby},
{helpb cross}, {helpb frlink}, and {helpb frget}, along with the steps that change
the shape of the data around them ({helpb reshape}, {helpb collapse},
{helpb contract}, {helpb xpose}, {helpb fillin}, {helpb duplicates}) and the steps
that change how many rows you have ({cmd:keep if}, {cmd:drop if}), and reports them
in the order your code performs them.{p_end}

{pstd}
Filters are included for a reason. When a dataset ends up smaller than expected, the
merge usually gets the blame and a {cmd:drop if} three lines later is usually the
culprit. Showing both in one picture is the point.{p_end}

{pstd}
It does not write joins for you and it does not change your code. It describes work
you have already done, which makes it useful in three moments: when you inherit
someone else's project and need to see the shape of it, when a merge went wrong and
you need to find where, and when you need a record of a data pipeline for a report
or an appendix.{p_end}

{marker receipt}{...}
{title:Reading the receipt}

{pstd}
Every run prints a receipt first. It is a numbered index of what was found, one row
per event, in the order the code performs them:{p_end}

{p 8 8 2}{c TLC}{hline 72}{c TRC}{p_end}
{p 8 8 2}{c |} {space 1}# {space 1}file{space 11}line{space 1}command{space 5}subtype{space 2}keys{space 6}using{space 12}F{space 1}flags{space 1}{c |}{p_end}
{p 8 8 2}{c BLC}{hline 72}{c BRC}{p_end}

{phang2}
{bf:#} is the event number, and the order the events happen in.{p_end}

{phang2}
{bf:file} and {bf:line} say where in your code the event happens, so you can go fix
it.{p_end}

{phang2}
{bf:command} and {bf:subtype} are the Stata command and its form: {cmd:merge} with
{cmd:m:1}, {cmd:reshape} with {cmd:wide}, and so on.{p_end}

{phang2}
{bf:keys} lists the variables the join matches on. Blank means the command does not
take a key ({cmd:append}, {cmd:xpose}).{p_end}

{phang2}
{bf:using} is the file, tempfile, or frame being brought in.{p_end}

{phang2}
{bf:F} marks {cmd:force}. Any mark in this column deserves a look: {cmd:force} tells
Stata to proceed through a type mismatch it would otherwise refuse.{p_end}

{phang2}
{bf:flags} is the short version of anything suspicious. See
{help mergemap##flags:Flags and what to do about them}.{p_end}

{marker modes}{...}
{title:Scan mode versus run mode}

{pstd}
{bf:Scan mode} is the default and it is safe: {cmd:mergemap} reads your do-files as
text and never executes them. It works on code that will not currently run, on
someone else's project, and on files whose data you do not have. What it cannot know
is anything that only exists at run time, so there are no observation counts, no
match counts, and no duplicate-key checks.{p_end}

{pstd}
{bf:Run mode} executes your do-files with instrumentation around each join and
records what actually happened: observations in and out, the {cmd:_merge}
breakdown, whether the key had duplicates on either side, and whether the observed
cardinality matched the one you declared. Your results are unchanged; the wrappers
call the real commands and pass your options through untouched.{p_end}

{pstd}
Use scan when you want the shape. Use run when you want the truth.{p_end}

{marker draw}{...}
{title:Drawing the map}

{pstd}
{cmd:mergemap draw} turns the most recent journal into a picture. With no
argument it draws whatever the last {cmd:mergemap}, {cmd:mergemap run}, or
{cmd:mergemap demo} recorded, in this session or a later one; name a journal
file to draw something older.{p_end}

{pstd}
{opt export()} picks the medium:{p_end}

{synoptset 22 tabbed}{...}
{synopt :{opt export(smcl)}}the Results window; the default{p_end}
{synopt :{opt export(html)}}a self-contained page: no internet, no JavaScript{p_end}
{synopt :{opt export(png)}}a picture through Stata's own graph engine{p_end}
{synopt :{opt export(svg)}}the same drawing, scalable{p_end}
{synopt :{opt export(mermaid)}}text that GitHub, Quarto, and VS Code render{p_end}
{synopt :{opt export(dot)}}Graphviz text{p_end}
{synopt :{opt export(erdiagram)}}mermaid's entity-relationship flavour, keys as attributes{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{bf:Reading it.} A box is a dataset: a file, a frame, or the data in memory at
that point. {bf:[saved]} marks a file your code writes; {bf:[tempfile]} marks a
temporary file, shown with the do-file and line that created it. A stacked box
labelled {cmd:x4:} is a loop drawn once, naming its first and last file
({opt noellipsis} expands it). Filters appear as slim nodes on the spine, because
a {cmd:drop if} explains a shrinking dataset at least as often as any merge.
Arrows are the flow of data; joined-in files enter from the side. Counts in
parentheses were dropped from the result, and {cmd:!!} marks anything worth a
look, always as text, never as colour alone.{p_end}

{pstd}
{bf:When the Results window is too small.} A window is a fixed-width space, so
past {opt maxnodes(#)} events (default 8), or whenever {opt layout(horizontal)}
is asked for, the SMCL drawing steps aside: {cmd:draw} writes the HTML page
instead, prints a clickable link, and opens it in GUI sessions unless
{opt noopen}. {opt forcesmcl} overrides the count. A PNG too dense for one
readable image is split into one page per do-file on its own.{p_end}

{marker options}{...}
{title:Options}

{dlgtab:Which files to read}

{synoptset 26 tabbed}{...}
{synopt :{opt fold:er(path)}}read the {cmd:.do} files in {it:path}, in name order{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
You will usually not need {opt folder()}: a folder passed as the argument does the
same thing, so {cmd:mergemap build/} and {cmd:mergemap, folder(build)} are
equivalent.{p_end}

{dlgtab:What to write}

{synoptset 26 tabbed}{...}
{synopt :{opt out(filename)}}write the journal here; default {cmd:journal.tsv}{p_end}
{synopt :{opt noreceipt}}skip the receipt table{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
The journal is a tab-separated file with one line per event. It is the record
everything else is built from, and it is worth keeping: it can be read straight
back into Stata with {helpb import delimited}, or reprinted with
{cmd:mergemap receipt}.{p_end}

{dlgtab:How loudly to complain}

{synoptset 26 tabbed}{...}
{synopt :{opt warn(#)}}mark an event {bf:warn} past this many unmatched rows{p_end}
{synopt :{opt stop(#)}}mark it {bf:stop}, and return an error, past this many{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Both take either a count ({cmd:warn(500)}) or a share between 0 and 1
({cmd:warn(.05)}, the default). Two percent unmatched is worth a note and forty
percent is a crisis; one warning symbol cannot say which, so {cmd:mergemap} sorts
events into {bf:note}, {bf:warn} and {bf:stop}. A {bf:stop} makes
{cmd:mergemap run} exit with an error, which lets you put it in a master do-file
as a gate rather than a report.{p_end}

{dlgtab:Run mode only}

{synoptset 26 tabbed}{...}
{synopt :{opt ex:amples(#)}}list {it:#} sample rows per join, showing the keys and {cmd:_merge}{p_end}
{synopt :{opt nochecks}}skip the duplicate-key check on using files, which is faster on large files{p_end}
{synoptline}
{p2colreset}{...}

{dlgtab:Draw only}

{synoptset 26 tabbed}{...}
{synopt :{opt sav:ing(filename)}}where to write; sensible defaults per medium{p_end}
{synopt :{opt style(boxes|rail)}}full boxes (default) or the compact rail{p_end}
{synopt :{opt lay:out(vertical|horizontal)}}down the page (default) or across it{p_end}
{synopt :{opt maxnodes(#)}}how much SMCL will attempt before handing over to HTML{p_end}
{synopt :{opt forcesmcl}}draw in the Results window regardless of size{p_end}
{synopt :{opt compact}}one line per box{p_end}
{synopt :{opt nocounts} {opt nokeys} {opt notransforms} {opt noellipsis}}leave things out{p_end}
{synopt :{opt det:ails}}per-join ledgers folded into the HTML page{p_end}
{synopt :{opt embed}}HTML as a fragment for someone else's page; see below{p_end}
{synopt :{opt acc:ent(hex)}}the one colour used for flags and arrowheads{p_end}
{synopt :{opt page(dofile)}}PNG/SVG as one image per do-file{p_end}
{synopt :{opt wrap(#)}}label wrap width{p_end}
{synopt :{opt replace}}overwrite existing output files{p_end}
{synopt :{opt noopen}}write the HTML but do not open the browser{p_end}
{synoptline}
{p2colreset}{...}

{dlgtab:Demo only}

{synoptset 26 tabbed}{...}
{synopt :{opt fold:er(path)}}write the example here; default {cmd:mergemap_demo}{p_end}
{synopt :{opt replace}}overwrite an existing example folder{p_end}
{synoptline}
{p2colreset}{...}

{marker examples}{...}
{title:Examples}

{pstd}{bf:See it work, with no setup}{p_end}
{phang2}{stata "mergemap demo":. mergemap demo}{p_end}

{pstd}{bf:Map the do-files you run, in the order you run them}{p_end}
{phang2}{cmd:. mergemap 01_clean.do 02_merge.do 03_analyze.do}{p_end}

{pstd}{bf:Map a whole folder, in name order}{p_end}
{phang2}{cmd:. mergemap build/}{p_end}
{phang2}{cmd:. mergemap 0*.do}{p_end}

{pstd}{bf:Just tell me what looks wrong}{p_end}
{phang2}{cmd:. mergemap check build/}{p_end}

{pstd}{bf:Keep the journal somewhere I choose, and skip the table}{p_end}
{phang2}{cmd:. mergemap build/, out(audit/joins.tsv) noreceipt}{p_end}

{pstd}{bf:Run it for real and get the counts}{p_end}
{phang2}{cmd:. mergemap run 01_clean.do 02_merge.do 03_analyze.do}{p_end}

{pstd}{bf:Run it and show me five example rows per join}{p_end}
{phang2}{cmd:. mergemap run build/, examples(5)}{p_end}

{pstd}{bf:Use it as a gate: stop the master do-file if a join loses too much}{p_end}
{phang2}{cmd:. mergemap run build/, warn(.02) stop(.10)}{p_end}

{pstd}{bf:Skip the duplicate-key check on very large using files}{p_end}
{phang2}{cmd:. mergemap run build/, nochecks}{p_end}

{pstd}{bf:Draw what I just scanned}{p_end}
{phang2}{cmd:. mergemap draw}{p_end}

{pstd}{bf:A figure for a report}{p_end}
{phang2}{cmd:. mergemap draw, export(png) saving(figures/pipeline) replace}{p_end}

{pstd}{bf:A figure for a slide, wider than it is tall}{p_end}
{phang2}{cmd:. mergemap draw, export(html) layout(horizontal) saving(pipeline.html) replace}{p_end}

{pstd}{bf:The compact look, forced into the Results window}{p_end}
{phang2}{cmd:. mergemap draw, style(rail) forcesmcl}{p_end}

{pstd}{bf:Text I can paste into a GitHub README or a Quarto document}{p_end}
{phang2}{cmd:. mergemap draw, export(mermaid) saving(pipeline) replace}{p_end}

{pstd}{bf:A fragment for a webdoc2 report, with the per-join ledgers folded in}{p_end}
{phang2}{cmd:. mergemap draw, export(html) saving(pipe_frag.html) embed details replace}{p_end}

{pstd}{bf:Show me what a joinby actually does to row counts}{p_end}
{phang2}{stata "mergemap sql joinby":. mergemap sql joinby}{p_end}

{pstd}{bf:Reprint a receipt from a journal I saved earlier}{p_end}
{phang2}{cmd:. mergemap receipt audit/joins.tsv}{p_end}

{pstd}{bf:The journal as a table, then one event in depth, drawn with its counts}{p_end}
{phang2}{cmd:. mergemap list}{p_end}
{phang2}{cmd:. mergemap detail 4, teach}{p_end}

{pstd}{bf:The journal as a dataset, to audit or graph yourself}{p_end}
{phang2}{cmd:. mergemap export, saving(joins.dta) replace}{p_end}

{marker sql}{...}
{title:Joins in Stata and SQL}

{pstd}
If you have met joins in SQL, R, or Python, this table maps them onto Stata. It is
also the fastest way to see what Stata's forms actually do.{p_end}

{synoptset 34}{...}
{synopthdr:Stata}
{synoptline}
{synopt :{cmd:merge 1:1} {it:k} {cmd:using} B}full outer join; every row from both sides{p_end}
{synopt :{cmd:merge 1:1} {it:k} {cmd:using} B{cmd:, keep(3)}}inner join; matched rows only{p_end}
{synopt :{cmd:merge 1:1} {it:k} {cmd:using} B{cmd:, keep(1 3)}}left join; all master rows{p_end}
{synopt :{cmd:merge 1:1} {it:k} {cmd:using} B{cmd:, keep(2 3)}}right join; all using rows{p_end}
{synopt :{cmd:merge 1:1} {it:k} {cmd:using} B{cmd:, keep(1)}}anti join; master rows with no match{p_end}
{synopt :{cmd:merge m:1} {it:k} {cmd:using} B}a lookup; many rows pull one row each{p_end}
{synopt :{cmd:merge 1:m} {it:k} {cmd:using} B}a fan-out; one row becomes many{p_end}
{synopt :{cmd:merge m:m} {it:k} {cmd:using} B}{bf:not a join}; see below{p_end}
{synopt :{cmd:joinby} {it:k} {cmd:using} B}the real many-to-many; all pairs within key{p_end}
{synopt :{cmd:cross using} B}cross join; every row against every row{p_end}
{synopt :{cmd:append using} B}union; stacks rows, matching variables by name{p_end}
{synopt :{cmd:frlink m:1} {it:k}{cmd:, frame(}B{cmd:)}}declares the relationship; moves nothing yet{p_end}
{synopt :{cmd:frget} {it:v}{cmd:, from(}{it:link}{cmd:)}}pulls columns along that relationship{p_end}
{synopt :{cmd:collapse (mean)} {it:x}{cmd:, by(}{it:k}{cmd:)}}aggregate; one row per group{p_end}
{synopt :{cmd:reshape long}/{cmd:wide}}unpivot and pivot{p_end}
{synoptline}

{pstd}
Each row of that table has a picture. {cmd:mergemap sql} alone prints the table
with the pictures linked; {cmd:mergemap sql joinby} (or {cmd:left}, {cmd:inner},
{cmd:full}, {cmd:fanout}, {cmd:append}, {cmd:cross}, {cmd:mm}) draws one form as
two small row stacks, the operator, and the result, with the size rule
underneath.{p_end}

{pstd}
And the pictures connect back to your own work: {cmd:mergemap detail} {it:#}{cmd:,}
{cmd:teach} draws event {it:#} from the journal in the same style, with the toy
rows replaced by that join's observed counts. When the event was only scanned,
there are no counts yet, so the generic picture for its form appears instead and
says why.{p_end}

{pstd}
Venn diagrams are a popular way to explain joins and they are the wrong picture. A
join is not a set operation on shared elements; it is every pairing of rows from two
tables, filtered by a condition. That is why a join can return {it:more} rows than
either input, which no Venn diagram can show. {cmd:mergemap} draws rows and arrows
for this reason.{p_end}

{marker flags}{...}
{title:Flags and what to do about them}

{phang}
{bf:!! m:m} {space 2}{cmd:merge m:m} is not a join. It pairs the first master row
having a key with the first using row having that key, the second with the second,
and so on, which depends on the order your data happen to be in. If you want all
pairings, use {helpb joinby}. If you meant a lookup, use {cmd:m:1}. If you did not
know your key had duplicates, run {cmd:duplicates report} on it.{p_end}

{phang}
{bf:!! force} {space 2}{opt force} lets Stata push past a type mismatch, for example
a variable stored as a string in one file and numeric in the other. The merge
succeeds and the values may be wrong. Check the variable named in the flag.{p_end}

{phang}
{bf:!! declared/observed} {space 2}You wrote {cmd:1:1} but the data behaved like
{cmd:m:1}, or similar. In run mode {cmd:mergemap} names an example key value so you
can look at it directly.{p_end}

{phang}
{bf:!! unmatched} {space 2}Rows did not find a partner. This is often fine and
sometimes the whole bug. The flag reports which side they came from and how many.{p_end}

{phang}
{bf:!! dropped} {space 2}A {opt keep()} option removed rows from the result. The
count appears in parentheses so you can see what left.{p_end}

{phang}
{bf:!! type} {space 2}The key is stored differently on the two sides, for example
{cmd:id: str6 vs long}. Stata will refuse the merge, or {opt force} will let it
through and the match will be wrong. This is the quietest way a merge fails.{p_end}

{phang}
{bf:!! also saved by} {space 2}Two do-files write the same file. Whichever runs
last wins, which is rarely what anyone intended.{p_end}

{phang}
{bf:!! stale} {space 2}A saved dataset is older than something it was built from,
so it does not reflect the current code or the current inputs. {cmd:mergemap} only
reports this; rebuilding is {helpb project:project}'s job.{p_end}

{marker coverage}{...}
{title:Counts, and why coverage is better}

{pstd}
In run mode each join reports how the rows resolved, and also what share of each
side took part: {it:94% of master matched, 61% of the crosswalk never used}. Raw
counts do not tell you whether 500 unmatched rows are a rounding error or a
catastrophe, and they do not tell you that most of a lookup table went unused,
which usually means the key is wrong. Shares do.{p_end}

{pstd}
{cmd:mergemap} also reports the most common unmatched key values, because 500
unmatched rows spread over 500 keys is a different problem from 500 rows sharing
one key.{p_end}

{marker embed}{...}
{title:Putting a map in a document}

{pstd}
For Word or LaTeX, use {cmd:draw, export(png)} or {cmd:export(svg)} and insert
the file as a figure. Vertical layout suits a page; horizontal suits a slide; a
long pipeline is better as one image per do-file, which {opt page(dofile)}
produces and a dense one produces on its own.{p_end}

{pstd}
For an HTML report, {cmd:export(html)} writes a self-contained page: no internet,
no JavaScript, nothing to install. Inside a {cmd:webdoc} or {cmd:webdoc2} report,
add {opt embed} to get a fragment instead: a stylesheet scoped so it cannot
restyle the report around it, and a drawing that scales with the text column.
Drop it into the document body and it flows and prints with the report.{p_end}

{pstd}
For a README, a wiki, or a Quarto document, {cmd:export(mermaid)} and
{cmd:export(dot)} write text that renders with nothing installed: GitHub, Quarto,
and VS Code draw mermaid natively, and online viewers cover DOT for anyone
without Graphviz. {cmd:export(erdiagram)} writes mermaid's entity-relationship
flavour, where the merge keys become attributes and the cardinalities become
crow's-foot glyphs.{p_end}

{pstd}
A horizontal diagram is wider than any text column. Let it keep its own width and
scroll sideways rather than shrinking to fit; squeezed into a column its labels
fall below two pixels.{p_end}

{marker limits}{...}
{title:Limitations}

{pstd}
These are boundaries of the approach, not bugs. Knowing them is part of using the
tool honestly.{p_end}

{phang2}
In scan mode, anything built at run time stays unresolved. A file name assembled
from a macro appears as it is written in your code, and a loop over a list built
from a directory listing cannot be counted. Both are flagged rather than guessed at.
Run mode resolves them.{p_end}

{phang2}
A join performed inside a command you wrote yourself, or built up as text and
executed, is invisible to the scanner. It sees code, not intentions.{p_end}

{phang2}
{cmd:mergemap run} rewrites your do-files into temporary copies with instrumented
command names, keeping your line numbers. It does not alter your files. If a
do-file uses {cmd:#delimit ;}, the scan is best-effort and says so.{p_end}

{phang2}
Do not nest {cmd:mergemap run} inside {cmd:webdoc do}. Both take control of how a
do-file is executed.{p_end}

{marker results}{...}
{title:Stored results}

{pstd}{cmd:mergemap} stores the following in {cmd:r()}:{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N_events)}}number of events recorded{p_end}
{synopt:{cmd:r(N_joins)}}number of joins{p_end}
{synopt:{cmd:r(N_flags)}}number of flagged events{p_end}
{synopt:{cmd:r(N_stop)}}number of events at severity {bf:stop}{p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(journal)}}path to the journal file{p_end}
{synopt:{cmd:r(files)}}do-files scanned{p_end}
{synopt:{cmd:r(output)}}after {cmd:draw}: the file it wrote{p_end}
{synopt:{cmd:r(file)}}after {cmd:export}: the dataset it wrote{p_end}
{p2colreset}{...}

{marker related}{...}
{title:Related commands}

{pstd}
{cmd:mergemap} describes joins that have already been written. These commands do
neighbouring jobs, and for some questions one of them is the better tool.{p_end}

{phang2}
{bf:Before you combine files.} {cmd:precombine} (Chatfield, {it:Stata Journal}
15(3), and cited in {bf:[D] merge}) compares two or more datasets you are about to
combine: which variables they share, which are unique to one file, and whether their
value-label code sets agree. That is a pre-flight check; {cmd:mergemap} is a map of
the flight afterwards. Use both.{p_end}

{phang2}
{bf:To manage a project's build.} {cmd:project} (Picard) tracks which do-files
depend on which files and re-runs only what changed. {cmd:mergemap} reports when an
output looks stale but never rebuilds anything; that is {cmd:project}'s job.{p_end}

{phang2}
{bf:To assert a specific number of dropped observations.} {cmd:iedropone} (DIME's
{cmd:ietoolkit}) drops observations and errors unless exactly the expected number
went. {cmd:mergemap} reports what happened; {cmd:iedropone} enforces what should.{p_end}

{phang2}
{bf:For participant-flow figures.} {cmd:flowchart} (Dodd) draws CONSORT and PRISMA
diagrams of how subjects were included and excluded. It needs LaTeX and it charts
people, not datasets.{p_end}

{phang2}
{bf:For a row-flow picture.} {cmd:sankey} (Naqvi) draws flow widths from
{cmd:from}/{cmd:to}/{cmd:value} data, which {cmd:mergemap} can export.{p_end}

{phang2}
{bf:Note on merge wrappers.} If your code uses {cmd:mmerge}, {cmd:dmerge},
{cmd:mergeall}, {cmd:pullin}, or a merge command of your own, {cmd:mergemap} will
see the wrapper and not the join inside it. It reads code, not intentions.{p_end}

{title:Also see}

{psee}
Manual: {manlink D merge}, {manlink D append}, {manlink D joinby}, {manlink D frlink}

{psee}
Help: {manhelp merge D}, {manhelp append D}, {manhelp joinby D},
{manhelp frlink D}, {manhelp frget D}, {manhelp reshape D}, {manhelp collapse D}

{title:Author}

{pstd}Eric Booth{break}
{cmd:eric.a.booth@gmail.com}{p_end}
