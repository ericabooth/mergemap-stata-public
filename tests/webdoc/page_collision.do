*==============================================================================*
* page_collision.do  --  deliberate-failure page.
*
* NOT run directly.  Driven by:   webdoc do page_collision.do, replace
*
* Injects mergemap's HTML verbatim -- its <style> block unchanged, its <svg>
* fragments unchanged -- into a webdoc2 page, so the damage can be measured
* instead of argued about:
*
*   body { max-width: 920px; margin: 24px; }   caps the whole REPORT
*   h1 / h2 rules                              shrink the REPORT headings
*   svg { max-width: 100%; height: auto; }     hits every svg on the page
*   details / summary / details pre            restyle the REPORT
*   marker id="ag" / id="aa"                   duplicated across diagrams
*==============================================================================*

wdinit collision_demo, replace

webdoc put <div class="mm-page">

wputh1 Collision demo, do not copy this
wputh2 A second-level heading, for comparison with the report
wput This page injects mergemap prototype HTML verbatim. Compare the heading sizes and the page width against mergemap_report.html, which prefixes and scopes the same stylesheet.

webdoc put <p id="probe-para">Probe paragraph.</p>

* --- mergemap's stylesheet, unmodified ------------------------------------
webdoc append "frag_raw_style.html"

wputh2 First diagram, vertical
webdoc append "frag_raw_svg_v.html"

wputh2 Second diagram, horizontal, same marker ids
webdoc append "frag_raw_svg_h.html"

webdoc put </div>

webdoc close
