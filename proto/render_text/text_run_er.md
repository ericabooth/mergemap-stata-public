# mergemap: journal_run.tsv - mermaid, erDiagram

Entities are datasets, attributes are the keys they were joined on, and the glyph carries the Stata subtype: `||--||` is 1:1, `}o--||` is m:1, `||--o{` is 1:m, `}o--o{` is m:m or joinby. A dotted line is a link that does not pair rows on a key: append, or frlink.

*mergemap rendertext 0.2.0 - journal journal_run.tsv - rendered 19 Aug 2026 23:55:36 - Stata 19.5 MP*

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'14px','primaryColor':'#ffffff','primaryTextColor':'#202020','primaryBorderColor':'#606060','lineColor':'#606060','secondaryColor':'#f4f4f4','tertiaryColor':'#fafafa','clusterBkg':'#fbfbfb','clusterBorder':'#b0b0b0','edgeLabelBackground':'#ffffff','titleColor':'#202020'}}}%%
%% mergemap rendertext 0.2.0 - journal journal_run.tsv - rendered 19 Aug 2026 23:55:36 - Stata 19.5 MP
erDiagram
  accTitle: keys and cardinality behind journal_run.tsv
  accDescr {
    3 do-files, 8 dataset events, 9 joins and 2 filters, of which 5 are flagged. Boxes are datasets or the dataset in memory; edges carry the command, its keys and its counts. Two exclamation marks flag an event that needs attention.
  }
  raw_cps_2019 }o..o{ raw_cps_2020_x3 : "append x3"
  raw_cps_2019 }o--|| xwalk_county_key : "merge m:1 county, 99.7% of master matched"
  raw_participants ||--o{ raw_visits : "merge 1:m pid, 96.5% of master matched"
  tempfile___visits }o--|| built_county_wide : "merge m:1 county, 99.8% of master matched"
  tempfile___visits }o--o{ raw_staff_assign : "!! joinby m:m staff, 100.0% of master matched"
  tempfile___visits ||--|| raw_corrections : "!! merge 1:1 pid visitid, 0.9% of master matched"
  tempfile___visits }o..|| frame_counties : "frlink m:1 county, 99.8% of master matched"
  tempfile___visits }o--o{ raw_schedules : "!! merge m:m staff, 99.5% of master matched"
  raw_cps_2019 {
    str5 county FK
  }
  xwalk_county_key {
    str5 county PK
  }
  raw_participants {
    long pid PK
  }
  raw_visits {
    long pid FK
  }
  tempfile___visits {
    str5 county FK
    byte staff FK
    long pid PK
    key visitid PK
  }
  built_county_wide {
    str5 county PK
  }
  raw_staff_assign {
    byte staff FK
  }
  raw_corrections {
    long pid PK
    key visitid PK
  }
  frame_counties {
    str5 county PK
    var povrate
    var slots
  }
  raw_schedules {
    key staff FK
  }
```
