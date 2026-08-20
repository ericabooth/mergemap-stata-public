# mergemap: journal_pipeline.tsv - mermaid, erDiagram

Entities are datasets, attributes are the keys they were joined on, and the glyph carries the Stata subtype: `||--||` is 1:1, `}o--||` is m:1, `||--o{` is 1:m, `}o--o{` is m:m or joinby. A dotted line is a link that does not pair rows on a key: append, or frlink.

*mergemap _mm_rendertext 0.2.0 - journal journal_pipeline.tsv - rendered 20 Aug 2026 09:27:36 - Stata 19.5 MP*

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'14px','primaryColor':'#ffffff','primaryTextColor':'#202020','primaryBorderColor':'#606060','lineColor':'#606060','secondaryColor':'#f4f4f4','tertiaryColor':'#fafafa','clusterBkg':'#fbfbfb','clusterBorder':'#b0b0b0','edgeLabelBackground':'#ffffff','titleColor':'#202020'}}}%%
%% mergemap _mm_rendertext 0.2.0 - journal journal_pipeline.tsv - rendered 20 Aug 2026 09:27:36 - Stata 19.5 MP
erDiagram
  accTitle: keys and cardinality behind journal_pipeline.tsv
  accDescr {
    3 do-files, 8 dataset events, 9 joins and 5 filters, of which 4 are flagged. Boxes are datasets or the dataset in memory; edges carry the command, its keys and its counts. Two exclamation marks flag an event that needs attention.
  }
  raw_cps_2019 }o..o{ raw_cps_2020_x3 : "!! append x3"
  raw_cps_2019 }o--|| raw_county_key : "merge m:1 county"
  raw_participants ||--o{ raw_visits : "merge 1:m pid"
  MM_VISITS }o--|| out_county_wide : "merge m:1 county"
  MM_VISITS }o--o{ raw_staff_assign : "joinby m:m staff"
  MM_VISITS }o--|| raw_corrections : "!! merge m:1 pid visitid"
  MM_VISITS }o..|| frame_counties : "frlink m:1 county"
  MM_VISITS }o--o{ raw_schedules : "!! merge m:m staff"
  raw_cps_2019 {
    key county FK
  }
  raw_county_key {
    key county PK
  }
  raw_participants {
    key pid PK
  }
  raw_visits {
    key pid FK
  }
  MM_VISITS {
    key county FK
    key staff FK
    key pid FK
    key visitid FK
  }
  out_county_wide {
    key county PK
  }
  raw_staff_assign {
    key staff FK
  }
  raw_corrections {
    key pid PK
    key visitid PK
  }
  frame_counties {
    key county PK
    var povrate
    var slots
  }
  raw_schedules {
    key staff FK
  }
```
