*==============================================================================*
* page_mergemap.do  --  the webdoc2 page source.
*
* NOT run directly.  Driven by:   webdoc do page_mergemap.do, replace
* (test_mergemap_in_webdoc2.do does that, after writing the frag_*.html files.)
*
* Four ways to put a mergemap diagram into a webdoc2 report, one per section,
* plus the variants that were tested to pick a default.
*
* House rules that silently misparse otherwise:
*   1. wdinit name          -- bare name, NOT quoted
*   2. wdnavbar* / wdwidth  -- outside any wd/button block
*   3. no slash-star inside any wput text
*   4. no backticks or dollar signs inside any wput text
*==============================================================================*

wdinit mergemap_report, replace

wdnavbar mergemap in webdoc2
wdnavitem A. PNG        , href(#a-png-via-wdimg)
wdnavitem B. iframe     , href(#b-iframe-via-wdiframe)
wdnavitem C. Inline SVG , href(#c-inline-svg-in-the-page-dom)
wdnavitem D. SMCL text  , href(#d-smcl-text-as-a-code-block)
wdnavbarclose

* Page-level CSS written by test_mergemap_in_webdoc2.do, then mergemap's own
* stylesheet with every class renamed mm-* and every rule scoped to .mm-embed.
webdoc append "frag_page_css.html"
webdoc append "frag_mm_css.html"

* webdoc emits a bare <body>: without a column wrapper the report runs
* edge-to-edge and -wdwidth- has nothing to act on.
webdoc put <div class="mm-page">

wputh1 mergemap output inside a webdoc2 report
wdtoc Contents, depth(2)
wput Every embed below shows the same run-mode diagram over the same 20-event journal. The point of the page is to compare how each embed behaves at report width, how tall it gets, and whether the diagram and the Bootstrap shell fight over CSS.

*==============================================================================*
wputh1 A. PNG via wdimg
*==============================================================================*
wput wdimg links the file, it does not copy it. The src is resolved by the browser relative to the HTML file, so a relative path only survives if the report and the image move together.

wputh2 A1. Plain wdimg, no bound on height
wput The twoway PNG is 1600 by 5745 px. wdimg gives it max-width 100 percent and height auto, so in a 960 px column it renders about 3450 px tall. Nothing is clipped and nothing scrolls sideways, but one figure is now four screens.
wdimg ../../proto/render_twoway/tw_vert_run.png, alt(mergemap vertical diagram, twoway PNG)

wputh2 A2. Same PNG inside a bounded scroll box
wput The same image inside a div with max-height 70vh and overflow auto. The figure now costs two thirds of a screen and the reader scrolls inside it.
webdoc put <div class="mm-scroll">
wdimg ../../proto/render_twoway/tw_vert_run.png, alt(mergemap vertical diagram, twoway PNG, bounded)
webdoc put </div>

wputh2 A3. wdimg with a caption
wput With caption() the image is wrapped in figure and figcaption, which picks up the rounded corners and drop shadow from the webdoc2 header stylesheet.
wdimg ../../proto/render_twoway/tw_horiz_run.png, caption(Horizontal layout, twoway PNG. 12 nodes is about the practical ceiling for the twoway renderer.)

*==============================================================================*
wputh1 B. iframe via wdiframe
*==============================================================================*
wput wdiframe writes width and height into the HTML attributes, not into CSS. The attribute only understands pixels and percentages, so height(70vh) is silently dropped and the iframe falls back to the 150 px default. The class() option is the way out.

wputh2 B1. wdiframe default height, 800px
wput The self-contained mergemap HTML is about 2500 px tall. At the wdiframe default the diagram is cut off at the first third and the reader has to scroll inside the frame.
wdiframe ../../proto/render_html/html_vert_run.html

wputh2 B2. wdiframe with the height measured to fit
wput height(2600px) shows the whole diagram with no inner scrollbar, but the report has to know the diagram height in advance, and the frame cannot shrink when the diagram does.
wdiframe ../../proto/render_html/html_vert_run.html, height(2600px)

wputh2 B3. wdiframe sized by a CSS class
wput class(mm-frame-vh) plus a stylesheet rule of height 78vh. A class rule beats the presentational height attribute, so vh units work here even though they cannot be passed to height().
wdiframe ../../proto/render_html/html_vert_run.html, class(mm-frame-vh)

wputh2 B4. wdiframe asked for height auto
wput class(mm-frame-auto) sets height auto. An iframe is a replaced element, so auto does not shrink-wrap the document it holds: it falls back to the height attribute wdiframe wrote, or to the CSS default of 150 px. There is no pure-CSS auto-height for an iframe.
wdiframe ../../proto/render_html/html_vert_run.html, class(mm-frame-auto)

wputh2 B5. wdiframe with a visible border
wput The border option swaps the default borderless look for a 1 px rule.
wdiframe ../../proto/render_html/html_vert_scan.html, height(420px) border

*==============================================================================*
wputh1 C. Inline SVG in the page DOM
*==============================================================================*
wput These are real SVG nodes in the report, not frames. The fragments were sliced out of the mergemap HTML by the driver, which renamed every CSS class to mm-something, rewrote the marker ids, and rescoped mergemap's stylesheet under .mm-embed. Section F shows what happens without those three steps.

wputh2 C1. mergemap SVG, viewBox only, filling the column
wput width and height attributes removed, viewBox kept. The diagram scales to the column and keeps its aspect ratio. Native size is 880 by 2367.
webdoc put <div class="mm-embed">
webdoc append "frag_mm_svg.html"
webdoc put </div>

wputh2 C2. mergemap SVG at native size inside a bounded box
wput Same diagram with its width and height attributes left in place, inside a box with max-height 70vh. Text is at its designed size instead of being scaled up by the column.
webdoc put <div class="mm-embed mm-scroll">
webdoc append "frag_mm_svg_nat.html"
webdoc put </div>

wputh2 C3. Stata twoway SVG inlined
wput The twoway export from Stata 19.5. Its root tag is width 5.570in, height 20.000in, viewBox 0 0 4010 14400. The inch units are the problem, not a missing viewBox. Dropping the two attributes lets the viewBox drive the scaling.
webdoc put <div class="mm-embed mm-scroll">
webdoc append "frag_tw_svg.html"
webdoc put </div>

wputh2 C4. Horizontal diagram stretched to the column, the wrong way
wput The horizontal layout is 6802 by 439. Stretched to a 960 px column it renders about 62 px tall and the labels are unreadable.
webdoc put <div class="mm-embed">
webdoc append "frag_mm_svg_horiz_100.html"
webdoc put </div>

wputh2 C5. Horizontal diagram at native size in a sideways scroller
wput The same diagram with its width attribute intact inside a div with overflow-x auto. The report column never scrolls sideways, only the box does.
webdoc put <div class="mm-embed mm-xscroll">
webdoc append "frag_mm_svg_horiz.html"
webdoc put </div>

*==============================================================================*
wputh1 D. SMCL text as a code block
*==============================================================================*
wput The SMCL renderer writes a plain-text twin of every diagram. Escaping ampersand, less-than and greater-than and dropping it into a pre block is the cheapest embed there is, and it is the only one that survives a plain-text or Markdown export of the report.

wputh2 D1. ASCII diagram
wput 155 lines, longest line 79 characters. At 12.5 px monospace that is about 600 px wide, so it fits any report column without wrapping.
webdoc append "frag_pre_smcl.html"

wputh2 D2. Receipt table
wput The receipt that accompanies every diagram, from the escalation demo.
webdoc append "frag_pre_receipt.html"

*==============================================================================*
wputh1 E. Details blocks inside webdoc2
*==============================================================================*
wput mergemap uses native HTML details and summary for per-join detail, with no JavaScript. Bootstrap 5 restyles summary only lightly, so the disclosure triangles survive. These blocks are inside .mm-embed, which is where the scoped mergemap rules for details, summary and details pre apply.
webdoc put <div class="mm-embed">
webdoc append "frag_details.html"
webdoc put </div>

wputh2 E2. Details with no mm-embed wrapper
wput The same markup outside the wrapper gets Bootstrap defaults only, so it loses mergemap's border and grey summary bar.
webdoc put <details><summary>a plain details block, unscoped</summary><p>Body text inside a details element with no mergemap styling attached.</p></details>

*==============================================================================*
wputh1 F. What the collision demo shows
*==============================================================================*
wput collision_demo.html in this directory injects mergemap's HTML verbatim, stylesheet and all, into a webdoc2 page. Its body rule caps the whole report at 920 px and adds a 24 px margin, its h1 and h2 rules shrink the report headings, and the marker ids ag and aa appear twice because every mergemap file uses the same two.

wputh2 F1. A style block written straight from the do-file
wput A single webdoc put line carrying a style block with braces parses fine in a do-file, which matters because it is the shortest way to add a rule from Stata.
webdoc put <style>.mm-page h2 { scroll-margin-top: 80px; }</style>
wput The rule above was emitted by that one line.

webdoc put </div>

webdoc close
