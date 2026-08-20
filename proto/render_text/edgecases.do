* edgecases.do -- _mm_rendertext cases the two contract journals do not contain.
* Builds small v2 journals on the fly and asserts what the renderer does with
* them. Run headless:  stata-mp -b do edgecases.do
*
* covered here:
*   a "<" inside a filter condition (mermaid would read it as an html tag)
*   a path longer than wrap(), which must get a middle-ellipsis
*   a macro-built path, which must read as a designed boundary not a bug
*   severity=stop with no flag text of its own
*   lifecycle=overwrite on a save
*   an unknown 35th column, which a v2 renderer must ignore rather than die
*   a v1 journal (column 9 headed "using"), which must be refused by name
*   a journal missing the late columns entirely, which must still render
*   the git branch/commit in the provenance line
adopath + "../../src"
version 16
clear all

local HDR "seq|dofile|line|class|cmd|subtype|keys|master|usingfile|result"
local HDR "`HDR'|n_in|k_in|n_using|k_using|n_out|k_out|m1|m2|m3|m4|m5"
local HDR "`HDR'|dup_master|dup_using|force|opts|loop_n|loop_first|loop_last"
local HDR "`HDR'|severity|keytypes|cover_master|cover_using|lifecycle|flags"
local HDR "`HDR'|futurecol"

* @BT@ and @Q@ stand in for a backtick and a single quote; they are turned
* into the real characters inside the file-write expression, so the macro
* expander never sees them (a macro holding a backtick is re-scanned)
capture program drop _row
program define _row
    args fh s
    local t = char(9)
    local line : subinstr local s "|" "`t'", all
    file write `fh' (subinstr(subinstr(`"`macval(line)'"', "@BT@", ///
        char(96), .), "@Q@", char(39), .)) _n
end

tempname fh
file open `fh' using edge_journal.tsv, write text replace
_row `fh' "`HDR'"
_row `fh' "1|e1.do|3|source|use|.|.|.|data/very/long/path/that/exceeds/the/wrap/width/input_extract_2019.dta|work|.|.|.|.|.|.|.|.|.|.|.|.|.|0|clear|.|.|.|note|.|.|.|read|.|x"
_row `fh' "2|e1.do|5|join|merge|m:1|id|work|raw/@BT@region@Q@/lookup.dta|work|.|.|.|.|.|.|.|.|.|.|.|.|.|0|.|.|.|.|note|.|.|.|.|.|x"
_row `fh' "3|e1.do|7|filter|keep|if|.|work|.|work|.|.|.|.|.|.|.|.|.|.|.|.|.|0|if wage < 100 & hours > 20|.|.|.|note|.|.|.|.|.|x"
_row `fh' "4|e1.do|9|join|merge|1:1|id|work|raw/other.dta|work|.|.|.|.|.|.|.|.|.|.|.|.|.|0|.|.|.|.|stop|.|.|.|.|.|x"
_row `fh' "5|e1.do|11|note|sxpose|.|.|work|.|work|.|.|.|.|.|.|.|.|.|.|.|.|.|0|.|.|.|.|warn|.|.|.|.|sxpose is an SSC dependency|x"
_row `fh' "6|e1.do|13|save|save|.|.|work|.|built/out.dta|.|.|.|.|.|.|.|.|.|.|.|.|.|0|replace|.|.|.|note|.|.|.|overwrite|also saved by e2.do line 4|x"
file close `fh'

_mm_rendertext using edge_journal.tsv, saving(edge) format(all) layout(vertical) ///
    replace

* ---- a v1 journal must be refused by name, not read positionally ----------
file open `fh' using edge_v1.tsv, write text replace
local V1 : subinstr local HDR "usingfile" "using", all
_row `fh' "`V1'"
_row `fh' "1|e1.do|3|source|use|.|.|.|a.dta|work|.|.|.|.|.|.|.|.|.|.|.|.|.|0|clear|.|.|.|note|.|.|.|read|.|x"
file close `fh'
capture _mm_rendertext using edge_v1.tsv, saving(edge_v1) format(mermaid) ///
    layout(vertical) replace
local rc1 = _rc

* ---- a short journal (v2 names, but stopping at column 25) must render ----
file open `fh' using edge_short.tsv, write text replace
local SH "seq|dofile|line|class|cmd|subtype|keys|master|usingfile|result"
local SH "`SH'|n_in|k_in|n_using|k_using|n_out|k_out|m1|m2|m3|m4|m5"
local SH "`SH'|dup_master|dup_using|force|opts"
_row `fh' "`SH'"
_row `fh' "1|e1.do|3|source|use|.|.|.|a.dta|work|.|.|.|.|.|.|.|.|.|.|.|.|.|0|clear"
_row `fh' "2|e1.do|5|join|merge|1:1|id|work|b.dta|work|.|.|.|.|.|.|.|.|.|.|.|.|.|0|."
file close `fh'
capture _mm_rendertext using edge_short.tsv, saving(edge_short) ///
    format(mermaid) layout(vertical) replace
local rc2 = _rc

* ---- provenance picks up a git work tree without shelling out ------------
local pwd0 "`c(pwd)'"
capture mkdir edge_git
capture mkdir edge_git/.git
capture mkdir edge_git/.git/refs
capture mkdir edge_git/.git/refs/heads
file open `fh' using edge_git/.git/HEAD, write text replace
file write `fh' ("ref: refs/heads/topic-branch") _n
file close `fh'
file open `fh' using edge_git/.git/refs/heads/topic-branch, write text replace
file write `fh' ("0123456789abcdef0123456789abcdef01234567") _n
file close `fh'
cd edge_git
_mm_rendertext using ../edge_journal.tsv, saving(gitprov) format(mermaid) ///
    layout(vertical) replace
cd "`pwd0'"

* ---- assertions ----------------------------------------------------------
capture program drop _rtcheck
program define _rtcheck
    args label want file pat
    tempname fh
    local hits = 0
    file open `fh' using "`file'", read text
    file read `fh' ln
    while r(eof) == 0 {
        if strpos(`"`macval(ln)'"', `"`macval(pat)'"') > 0 local ++hits
        file read `fh' ln
    }
    file close `fh'
    local got = cond(`hits' > 0, "yes", "no")
    di as txt "  " %-6s cond("`got'" == "`want'", "PASS", "FAIL") ///
        " `label'  (`file': `hits' hits)"
end

di as txt "edge-case checks:"
_rtcheck "less-than escaped for mermaid" yes edge_td.mmd "wage #60; 100"
_rtcheck "raw < never reaches a mermaid label" no edge_td.mmd "wage < 100"
_rtcheck "greater-than left alone (html-safe)" yes edge_td.mmd "hours > 20"
_rtcheck "DOT keeps the literal <" yes edge_tb.dot "wage < 100"
_rtcheck "long path gets a middle ellipsis" yes edge_td.mmd "data/very/long/p"
_rtcheck "long path is actually shortened" no edge_td.mmd ///
    "width/input_extract_2019.dta"
_rtcheck "macro path reads as a boundary" yes edge_td.mmd ///
    "path built from a macro"
_rtcheck "macro path survives into the label" yes edge_td.mmd "region"
_rtcheck "stop severity is text, not colour" yes edge_td.mmd "!! stop"
_rtcheck "stop node gets the heavier stroke class" yes edge_td.mmd ///
    "class s4 mmstop"
_rtcheck "warn note carries !!" yes edge_td.mmd "!! sxpose"
_rtcheck "lifecycle overwrite is visible" yes edge_td.mmd "[saved, overwrites]"
_rtcheck "clobber flag on the save node" yes edge_td.mmd "also saved by e2.do"
_rtcheck "unknown 35th column ignored" no edge_td.mmd "futurecol"

di as txt ""
di as txt "  " %-6s cond(`rc1' == 459, "PASS", "FAIL") ///
    " v1 journal refused by name (rc = `rc1', want 459)"
di as txt "  " %-6s cond(`rc2' == 0, "PASS", "FAIL") ///
    " short v2 journal still renders (rc = `rc2')"
_rtcheck "git branch and commit in the provenance line" yes ///
    edge_git/gitprov_td.mmd "git topic-branch@0123456"

* ---- clean up the fixtures ----------------------------------------------
foreach f in edge_journal.tsv edge_v1.tsv edge_short.tsv ///
    edge_td.mmd edge_td.md edge_er.mmd edge_er.md edge_tb.dot ///
    edge_short_td.mmd edge_short_td.md ///
    edge_git/gitprov_td.mmd edge_git/gitprov_td.md {
    capture erase "`f'"
}
capture erase edge_git/.git/refs/heads/topic-branch
capture erase edge_git/.git/HEAD
capture rmdir edge_git/.git/refs/heads
capture rmdir edge_git/.git/refs
capture rmdir edge_git/.git
capture rmdir edge_git

di as txt ""
di as txt "_mm_rendertext edge cases complete"
