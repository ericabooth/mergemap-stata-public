#!/bin/bash
# make_gallery.sh -- assemble the self-contained gallery.html from the
# artifacts that runall.do renders into this directory.  Called by
# runall.do (step 3); can also be run on its own once those files exist.
#
# Everything is embedded: PNGs as base64 data URIs, text renders inside
# <pre>, one twoway SVG inlined, mermaid/DOT as escaped code blocks.  The
# only external references are relative links to the standalone HTML
# renderer outputs sitting next to this page.

set -euo pipefail
cd "$(dirname "$0")"

out=gallery.html

# html-escape a file to stdout
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$1"; }
# base64 a file as one long line
b64() { base64 -i "$1" | tr -d '\n'; }

need() {
    for f in "$@"; do
        [ -f "$f" ] || { echo "make_gallery.sh: missing input $f" >&2; exit 1; }
    done
}

need receipt_pipeline.txt smcl_escalation.txt \
     smcl_boxes_scan.txt smcl_boxes_run.txt smcl_boxes_pipe.txt \
     smcl_rail_scan.txt smcl_rail_run.txt smcl_rail_pipe.txt \
     html_vert_scan.html html_vert_run.html html_horiz_run.html \
     html_vert_run_details.html html_vert_pipe.html html_vert_pipe_details.html \
     tw_vert_scan.png tw_vert_run.png tw_horiz_run.png \
     tw_pipe_01_build.png tw_pipe_02_panel.png tw_pipe_03_analyze.png \
     tw_pipe_01_build.svg \
     text_scan_td.mmd text_run_td.mmd text_pipe_td.mmd \
     text_run_tb.dot text_pipe_tb.dot \
     teach_merge_m1.txt teach_merge_mm.txt \
     demo_receipt.txt runmode_ledger.txt embed_fragment.html \
     text_run_er.mmd \
     journals/journal_pipeline.tsv

{
cat <<'HDR'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>mergemap renderer gallery</title>
<style>
  :root { --accent: #4a6d8c; --rule: #c8c8c8; --dim: #666; }
  html { box-sizing: border-box; } *, *:before, *:after { box-sizing: inherit; }
  body { font-family: Georgia, "Times New Roman", serif; color: #1a1a1a;
         background: #fff; margin: 0; padding: 2rem 1rem 4rem;
         line-height: 1.45; }
  main { max-width: 1080px; margin: 0 auto; }
  h1 { font-size: 1.7rem; margin: 0 0 .3rem; }
  h2 { font-size: 1.25rem; margin: 2.8rem 0 .4rem; padding-top: 1rem;
       border-top: 3px solid var(--accent); }
  h3 { font-size: 1rem; margin: 1.6rem 0 .35rem;
       font-family: Helvetica, Arial, sans-serif; }
  p  { margin: .35rem 0 .8rem; max-width: 72ch; }
  .caption { color: var(--dim); font-style: italic; max-width: 78ch; }
  nav { font-family: Helvetica, Arial, sans-serif; font-size: .9rem;
        margin: 1rem 0 0; }
  nav a { margin-right: .9rem; color: var(--accent); }
  a { color: var(--accent); }
  pre { background: #fafafa; border: 1px solid var(--rule);
        padding: .8rem 1rem; overflow-x: auto; font-size: .78rem;
        line-height: 1.25;
        font-family: "SF Mono", Menlo, Consolas, "Courier New", monospace; }
  code { font-family: "SF Mono", Menlo, Consolas, "Courier New", monospace; }
  figure { margin: 1rem 0 1.8rem; }
  figcaption { font-family: Helvetica, Arial, sans-serif; font-size: .82rem;
               color: var(--dim); margin: .3rem 0 .5rem; }
  img { max-width: 100%; height: auto; border: 1px solid var(--rule); }
  .scroll { overflow-x: auto; border: 1px solid var(--rule); }
  .scroll img { max-width: none; border: 0; display: block; }
  .svgwrap svg { max-width: 100%; height: auto; border: 1px solid var(--rule); }
  ul.files { font-family: Helvetica, Arial, sans-serif; font-size: .9rem; }
  ul.files li { margin: .25rem 0; }
  details > summary { cursor: pointer; font-family: Helvetica, Arial,
        sans-serif; font-size: .9rem; color: var(--accent); margin: .6rem 0; }
</style>
</head>
<body>
<main>
<h1>mergemap renderer gallery</h1>
<p>Prototype output review for the mergemap package: one static scanner
(<code>src/mergemap.ado</code>) and four renderers
(SMCL, HTML+SVG, native <code>twoway</code>, mermaid/DOT text), all driven
from the same 29-column journal contract. Three inputs appear throughout:
the contract <strong>scan</strong> journal (counts unknown, the package
default), the contract <strong>run</strong> journal (counts observed), and
the <strong>pipeline</strong> journal the scanner itself emitted from the
real test do-files in <code>tests/pipeline/</code>. Regenerate everything
with <code>runall.do</code> (see <code>README.md</code>).</p>
<nav>
<a href="#s1">1 Receipt</a> <a href="#s2">2 SMCL boxes</a>
<a href="#s3">3 SMCL rail</a> <a href="#s4">4 HTML/SVG</a>
<a href="#s5">5 twoway PNG</a> <a href="#s6">6 mermaid/DOT</a>
<a href="#s7">7 Teach mode</a>
</nav>
HDR

# ---------------------------------------------------------------- 1 receipt
cat <<'S1'
<h2 id="s1">1. Receipt</h2>
<p class="caption">What to evaluate: is the table scannable at a glance?
File and line numbers must match the source do-files exactly; long paths
truncate with a middle ellipsis; the flags column must surface every
<code>!!</code> warning without color. The first capture is the scanner
receipt printed by a real scan of the three pipeline do-files (nothing
executed); the second shows the SMCL renderer refusing to draw an
oversized diagram: its compact 80-column receipt plus the notice deferring
to the HTML renderer.</p>
<figure>
<figcaption>Scanner receipt, printed after scanning tests/pipeline/01-03
(captured to SMCL, translated at 120 columns: receipt_pipeline.txt)</figcaption>
<pre>
S1
esc receipt_pipeline.txt
cat <<'S1B'
</pre>
</figure>
<figure>
<figcaption>SMCL auto-escalation on the run journal: 10 join+transform
events exceed maxnodes(8), so the renderer prints its receipt and defers
(smcl_escalation.txt)</figcaption>
<pre>
S1B
esc smcl_escalation.txt
cat <<'S1C'
</pre>
</figure>
S1C

# ---------------------------------------------------------------- 2 boxes
cat <<'S2'
<h2 id="s2">2. SMCL diagram, boxes style</h2>
<p class="caption">What to evaluate: boxes and arrows only, master chain
down a left spine, using files boxed to the right of each join, the
<code>_merge</code> breakdown under the join line with dropped categories
in parentheses, loop stacks as one double-topped card, saves marked
[saved], tempfiles [tempfile]. Scan mode must stay informative with no
counts at all; flags must be impossible to miss.</p>
S2
for v in scan run pipe; do
    case $v in
      scan) t="Contract scan journal (no counts)";;
      run)  t="Contract run journal (counts observed)";;
      pipe) t="Scanner-emitted pipeline journal (scan of tests/pipeline/01-03)";;
    esac
    printf '<h3>%s</h3>\n<figure>\n<figcaption>smcl_boxes_%s.txt</figcaption>\n<pre>\n' "$t" "$v"
    esc "smcl_boxes_$v.txt"
    printf '</pre>\n</figure>\n'
done

# ---------------------------------------------------------------- 3 rail
cat <<'S3'
<h2 id="s3">3. SMCL diagram, rail style</h2>
<p class="caption">What to evaluate: the compact alternative to boxes; node
names on a vertical rail, one line per join carrying keys and counts,
transforms indented and dim. Judge whether the compression stays readable
and whether it beats boxes for a quick console check.</p>
S3
for v in scan run pipe; do
    case $v in
      scan) t="Contract scan journal";;
      run)  t="Contract run journal";;
      pipe) t="Scanner-emitted pipeline journal";;
    esac
    printf '<h3>%s</h3>\n<figure>\n<figcaption>smcl_rail_%s.txt</figcaption>\n<pre>\n' "$t" "$v"
    esc "smcl_rail_$v.txt"
    printf '</pre>\n</figure>\n'
done

# ---------------------------------------------------------------- 4 html
cat <<'S4'
<h2 id="s4">4. HTML with inline SVG</h2>
<p class="caption">What to evaluate: each link opens a fully self-contained
page (inline CSS and SVG, no JavaScript, works offline). Check the boxes
and connector labels, the single muted-blue accent reserved for flags and
arrowheads, middle-ellipsis on long labels, the horizontal variant for
slides, and the pure-HTML <code>&lt;details&gt;</code> ledger blocks
(tidylog-style per-join accounting) in the details variants. The vertical
pages must not scroll horizontally.</p>
<ul class="files">
<li><a href="html_vert_scan.html">html_vert_scan.html</a> - contract scan journal, vertical</li>
<li><a href="html_vert_run.html">html_vert_run.html</a> - contract run journal, vertical</li>
<li><a href="html_horiz_run.html">html_horiz_run.html</a> - contract run journal, horizontal (slide layout)</li>
<li><a href="html_vert_run_details.html">html_vert_run_details.html</a> - run journal with expandable per-join ledgers</li>
<li><a href="html_vert_pipe.html">html_vert_pipe.html</a> - scanner-emitted pipeline journal, vertical</li>
<li><a href="html_vert_pipe_details.html">html_vert_pipe_details.html</a> - pipeline journal with ledgers</li>
</ul>
S4

# ---------------------------------------------------------------- 5 twoway
cat <<'S5'
<h2 id="s5">5. Native twoway graph (PNG/SVG)</h2>
<p class="caption">What to evaluate: one <code>twoway</code> call drew each
diagram (pci boxes, pcarrowi arrows, text labels), so this is what Stata
can produce for Word or slides with no external tools. Text must fit
inside boxes, arrows must meet box edges, loop stacks read as one card,
frame links are dashed, and the single accent color marks only
<code>!!</code> flags. The horizontal run diagram scrolls sideways inside
its frame by design.</p>
S5

printf '<h3>Contract scan journal, vertical</h3>\n<figure>\n<figcaption>tw_vert_scan.png</figcaption>\n<img alt="twoway diagram, scan journal, vertical" src="data:image/png;base64,%s"/>\n</figure>\n' "$(b64 tw_vert_scan.png)"
printf '<h3>Contract run journal, vertical</h3>\n<figure>\n<figcaption>tw_vert_run.png</figcaption>\n<img alt="twoway diagram, run journal, vertical" src="data:image/png;base64,%s"/>\n</figure>\n' "$(b64 tw_vert_run.png)"
printf '<h3>Scanner-emitted pipeline, one page per do-file</h3>\n<p class="caption">The scanned pipeline carries 15 join, transform and filter events, past the point where a single native-graph image stays readable. <code>page(dofile)</code> splits it so each page fits a printed page.</p>\n'
for pg in tw_pipe_01_build tw_pipe_02_panel tw_pipe_03_analyze; do
  printf '<figure>\n<figcaption>%s.png</figcaption>\n<img alt="twoway diagram page %s" src="data:image/png;base64,%s"/>\n</figure>\n' "$pg" "$pg" "$(b64 $pg.png)"
done
printf '<h3>Contract run journal, horizontal (slide layout)</h3>\n<figure>\n<figcaption>tw_horiz_run.png (scrolls sideways)</figcaption>\n<div class="scroll"><img alt="twoway diagram, run journal, horizontal" src="data:image/png;base64,%s"/></div>\n</figure>\n' "$(b64 tw_horiz_run.png)"

cat <<'S5B'
<details><summary>SVG export of the first pipeline page, inlined (tw_pipe_01_build.svg)</summary>
<figure class="svgwrap">
S5B
sed -n '/<svg/,$p' tw_pipe_01_build.svg
cat <<'S5C'
</figure>
</details>
S5C

# ---------------------------------------------------------------- 6 text
cat <<'S6'
<h2 id="s6">6. Mermaid and DOT text exports</h2>
<p class="caption">What to evaluate: syntax correctness by eye (nothing is
rendered locally; that is the point). One subgraph per do-file, edge
labels carrying command, keys, options, and counts, dashed edges for
dropped/unmatched paths and frame links, loop stacks as a single node,
<code>!!</code> flags kept in node text. Paste a mermaid block into
GitHub, Quarto, VS Code, or mermaid.live to render it; DOT renders on any
online Graphviz viewer. LR (horizontal) variants of each file sit next to
this page.</p>
<h3>Mermaid, contract scan journal (flowchart TD)</h3>
<figure>
<figcaption>text_scan_td.mmd</figcaption>
<pre><code>
S6
esc text_scan_td.mmd
cat <<'S6B'
</code></pre>
</figure>
<h3>Mermaid, contract run journal (flowchart TD)</h3>
<figure>
<figcaption>text_run_td.mmd</figcaption>
<pre><code>
S6B
esc text_run_td.mmd
cat <<'S6C'
</code></pre>
</figure>
<h3>Mermaid, scanner-emitted pipeline journal (flowchart TD)</h3>
<figure>
<figcaption>text_pipe_td.mmd</figcaption>
<pre><code>
S6C
esc text_pipe_td.mmd
cat <<'S6D'
</code></pre>
</figure>
<h3>DOT, contract run journal (rankdir=TB)</h3>
<figure>
<figcaption>text_run_tb.dot</figcaption>
<pre><code>
S6D
esc text_run_tb.dot
cat <<'S6E'
</code></pre>
</figure>
<h3>DOT, scanner-emitted pipeline journal (rankdir=TB)</h3>
<figure>
<figcaption>text_pipe_tb.dot</figcaption>
<pre><code>
S6E
esc text_pipe_tb.dot
cat <<'S6F'
</code></pre>
</figure>
S6F

# ---------------------------------------------------------------- 7 teach
cat <<'S7'
<h2 id="s7">7. Teach mode (mergemap sql prototype)</h2>
<p class="caption">What to evaluate: the jOOQ-style row-stack picture - two
key-labeled stacks, the operator, the result stack with padded and
dropped rows in parentheses, the size rule, and the SQL/dplyr/pandas
equivalence line. The m:m case must read as a warning: it pairs rows by
order within key, it is not a join; joinby is the true many-to-many.</p>
<figure>
<figcaption>merge m:1 with keep(1 3), i.e. a left join (teach_merge_m1.txt)</figcaption>
<pre>
S7
esc teach_merge_m1.txt
cat <<'S7B'
</pre>
</figure>
<figure>
<figcaption>merge m:m, the warning case (teach_merge_mm.txt)</figcaption>
<pre>
S7B
esc teach_merge_mm.txt
cat <<'S7C'
</pre>
</figure>
S7C

# ---------------------------------------------------------------- 8 v2
cat <<'S8'
<h2 id="s8">8. What round 2 added</h2>
<p class="caption">What to evaluate: whether someone who has never seen this
package could start with <code>mergemap demo</code> and understand what came
back; whether the run-mode ledger says something a receipt cannot; and whether
the embed fragment is safe to drop into a report written by someone else.</p>

<h3>mergemap demo, the no-setup starting point</h3>
<p class="caption">Writes three do-files built only from <code>sysuse auto</code>
and <code>sysuse census</code>, scans them, and prints the receipt. Nothing is
downloaded, and the generated files really run. Note the headline count, the
filter events, and flag text that wraps onto a second line instead of being cut
mid-word.</p>
<figure>
<figcaption>demo_receipt.txt</figcaption>
<pre>
S8
esc demo_receipt.txt
cat <<'S8B'
</pre>
</figure>

<h3>Run mode, the ledger a scan cannot produce</h3>
<p class="caption">Scanning reads the code; running executes it and reports what
actually happened: observed key storage types, match counts, coverage as a share
of each side, and the most frequent unmatched key values. That last line is what
separates "500 rows failed to match" from "one key failed to match 500 times".</p>
<figure>
<figcaption>runmode_ledger.txt, excerpt from the instrumented pipeline</figcaption>
<pre>
S8B
esc runmode_ledger.txt
cat <<'S8C'
</pre>
</figure>

<h3>erDiagram export, cardinality in mermaid's own notation</h3>
<p class="caption">A second mermaid flavour in which the merge keys become
attributes and Stata's <code>1:1</code>, <code>m:1</code> and <code>1:m</code> map
onto mermaid's crow's-foot glyphs. Renders on GitHub unchanged.</p>
<figure>
<figcaption>text_run_er.mmd</figcaption>
<pre>
S8C
esc text_run_er.mmd
cat <<'S8D'
</pre>
</figure>

<h3>Embed fragment, safe to drop into another page</h3>
<p class="caption">Not a page: a scoped stylesheet plus an SVG carrying only a
<code>viewBox</code>. Every selector is prefixed <code>.mm-</code> and every id is
namespaced, because in testing a full page's <code>body</code> and heading rules
silently restyled the host report around it, and two diagrams on one page shared
arrowhead ids so recolouring the first changed the second. The fragment below is
rendered inline in this page, which is itself the test.</p>
<figure class="svgwrap">
S8D
cat embed_fragment.html
cat <<'S8E'
</figure>
S8E

cat <<'TAIL'
</main>
</body>
</html>
TAIL
} > "$out"

echo "make_gallery.sh: wrote $out ($(wc -c < "$out" | tr -d ' ') bytes)"
