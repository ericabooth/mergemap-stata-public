# mergemap: journal_pipeline.tsv - mermaid, vertical

Boxes are datasets; the spine is the dataset in memory. A slim rounded node is a row filter. `!!` marks an event that needs attention.

*mergemap _mm_rendertext 0.2.0 - journal journal_pipeline.tsv - rendered 21 Aug 2026 08:33:32 - Stata 19.5 MP - git main@057d6df*

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'14px','primaryColor':'#ffffff','primaryTextColor':'#202020','primaryBorderColor':'#606060','lineColor':'#606060','secondaryColor':'#f4f4f4','tertiaryColor':'#fafafa','clusterBkg':'#fbfbfb','clusterBorder':'#b0b0b0','edgeLabelBackground':'#ffffff','titleColor':'#202020'}}}%%
%% mergemap _mm_rendertext 0.2.0 - journal journal_pipeline.tsv - rendered 21 Aug 2026 08:33:32 - Stata 19.5 MP - git main@057d6df
flowchart TD
  accTitle: mergemap data-flow map of journal_pipeline.tsv
  accDescr {
    3 do-files, 8 dataset events, 9 joins and 5 filters, of which 4 are flagged. Boxes are datasets or the dataset in memory; edges carry the command, its keys and its counts. Two exclamation marks flag an event that needs attention.
  }
  classDef default fill:#ffffff,stroke:#606060,color:#202020;
  classDef mmfilter fill:#f4f4f4,stroke:#909090,color:#202020;
  classDef mmnote fill:#fafafa,stroke:#b0b0b0,color:#404040;
  classDef mmwarn fill:#ffffff,stroke:#4a6d8c,stroke-width:2.5px,color:#202020;
  classDef mmstop fill:#ffffff,stroke:#4a6d8c,stroke-width:4px,color:#202020;
  subgraph sg1["01_build.do"]
    d7["../raw/cps_2019.dta"]
    d8["x3: ../raw/cps_2020.dta ... ../raw/cps_2022.dta"]
    s2["work<br/>!! force used"]
    d6["../raw/county_key.dta"]
    s3["work<br/>keep(1 3): using-only will be dropped"]
    s4(["drop if missing(hours)"])
    s5["collapse (mean) wage hours, by(county year)"]
    d3["../out/county_panel.dta [saved]"]
  end
  subgraph sg2["02_panel.do"]
    d9["../raw/participants.dta"]
    s8["duplicates drop force<br/>!! duplicate rows on the key will be dropped"]
    d12["../raw/visits.dta"]
    s9["work"]
    s10(["drop vars _merge"])
    d1["$MM_VISITS [saved]<br/>path built from a macro<br/>run mode resolves it"]
    s13["reshape wide wage hours, i(county) j(year)"]
    d4["../out/county_wide.dta [saved]"]
  end
  subgraph sg3["03_analyze.do"]
    s16["work<br/>keep(1 3): using-only will be dropped"]
    d11["../raw/staff_assign.dta"]
    s17["work"]
    d5["../raw/corrections.dta"]
    s18["work<br/>!! update replace"]
    s19(["drop vars _merge"])
    d13["frame:counties"]
    s20["work"]
    s21["work"]
    s22(["keep if date #60;= mdy(6, 30, 2024)"])
    d10["../raw/schedules.dta"]
    s23["work<br/>!! m:m pairs rows by row order within key (not a join)<br/>!! force used"]
    s24(["drop vars _merge"])
    d2["../out/analysis_file.dta [saved]"]
  end
  d7 -- "append<br/>force" --> s2
  d8 --> s2
  s2 -- "merge m:1 county<br/>keep(1 3) nogenerate" --> s3
  d6 -. "using-only dropped by keep(1 3)" .-> s3
  s3 --> s4
  s4 --> s5
  s5 --> d3
  d9 --> s8
  s8 -- "merge 1:m pid" --> s9
  d12 --> s9
  s9 --> s10
  s10 --> d1
  d3 --> s13
  s13 --> d4
  d1 -- "merge m:1 county<br/>keep(1 3) nogenerate" --> s16
  d4 -. "using-only dropped by keep(1 3)" .-> s16
  s16 -- "joinby m:m staff<br/>unmatched(none)" --> s17
  d11 --> s17
  s17 -- "merge m:1 pid visitid" --> s18
  d5 --> s18
  s18 --> s19
  s19 -- "frlink m:1 county<br/>frame(counties) generate(cnty)" --> s20
  d13 -.-> s20
  s20 -- "frget<br/>povrate slots, from(cnty)" --> s21
  d13 -.-> s21
  s21 --> s22
  s22 -- "merge m:m staff<br/>force" --> s23
  d10 --> s23
  s23 --> s24
  s24 --> d2
  class s2 mmwarn;
  class s4 mmfilter;
  class s8 mmwarn;
  class s10 mmfilter;
  class s18 mmwarn;
  class s19 mmfilter;
  class s22 mmfilter;
  class s23 mmwarn;
  class s24 mmfilter;
  linkStyle 0,1,7,18,19,26,27 stroke:#4a6d8c,stroke-width:2px;
```
