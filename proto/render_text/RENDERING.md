# Rendering the mergemap text exports (zero-install paths)

The text renderer reads a mergemap journal (schema v2, 34 columns) and emits
four interchange formats:

| extension | contents | produced by |
|---|---|---|
| `.mmd` | mermaid flowchart source | `rendertext ..., format(mermaid)` |
| `.md` | the same flowchart inside a fenced ` ```mermaid ` block | `rendertext ..., format(mermaid)` |
| `_er.mmd` / `_er.md` | mermaid **erDiagram**: keys and cardinality | `rendertext ..., format(er)` |
| `.dot` | Graphviz DOT digraph | `rendertext ..., format(dot)` |

`format(all)` writes all four. Nothing below requires installing a diagram
engine. Every path works on macOS and Windows (and Linux where noted).

## What the flowchart shows

A box is a dataset: a file on disk, a `tempfile`, a frame, or the dataset in
memory. The spine down the middle is the data in memory as it changes; boxes
hanging off it are the files being read, joined in, or written out. The
command, its keys, its options and its counts ride on the **edges**, so the
boxes stay short.

Three conventions carry the diagnostics:

- **`!!` marks anything that needs attention.** Both `warn` and `stop`
  severities print it, and a `stop` event additionally prints a line reading
  `!! stop`. The accent colour (`#4a6d8c`) is applied to the same nodes and to
  the edges reaching them, but it is never the only signal: the marker
  survives a monochrome printout, a log file, and a reader who does not
  distinguish colours.
- **A slim rounded node is a row filter** (`keep if`, `drop if`, `drop`,
  `keep`). It carries the condition and, in run mode, the row change:
  `drop if missing(wage)` / `removed 6,519 rows (3.1%), 203,115 remaining`.
  Filters get their own shape because most row loss happens there, not in the
  joins.
- **Dashed edges are rows that do not arrive**: a `keep()` that drops the
  using-only rows, or a frame view-link (`frlink`/`frget`/`fralias`), which
  links rather than combines.

In scan mode every count is unknown, so the count lines are omitted rather
than printed as `.`. A collapsed loop is one stacked node
(`x3: raw/cps_2020.dta ... raw/cps_2022.dta`). A path built from a macro says
so in the box: `path built from a macro; run mode resolves it`.

## What the erDiagram shows

The erDiagram flavour is the same journal read as structure rather than as
flow. Datasets become entities, the variables they were joined on become
attributes, and the Stata subtype becomes a mermaid cardinality glyph:

| Stata | mermaid | reading |
|---|---|---|
| `1:1` | `\|\|--\|\|` | one row here, one row there |
| `m:1` | `}o--\|\|` | many rows here, one row there |
| `1:m` | `\|\|--o{` | one row here, many rows there |
| `m:m`, `joinby`, `cross` | `}o--o{` | many on both sides |
| `append` | `}o..o{` | stacked, no key |
| `frlink` | `}o..\|\|` | linked, rows not combined |

A dotted line (`..`) is therefore a link that does not pair rows on a key.
Attributes are marked `PK` on whichever side holds the key uniquely and `FK`
on the other; the attribute's type is the real storage type when run mode has
read it off the file (`str5 county PK`), and the placeholder `key` when scan
mode has not (`key county PK`).

The entity on the master side of a join is the last **named** dataset the
data in memory came from: the file it was `use`d from, or the last file it
was saved to. A chain of joins onto one working dataset therefore renders as
a star around that dataset, which is usually what the analyst has in mind. It
does mean an entity named after the first file of an `append` stands in for
the whole stack; the `append` relationship next to it says so.

## Theming, accessibility, and what is deliberately absent

Every mermaid file opens with an `%%{init: ...}%%` directive carrying an
explicit `theme: base` palette, so the diagram looks the same on GitHub, in
mermaid.live, in Quarto and in VS Code instead of inheriting whatever theme
the host applies. Below it come `accTitle:` and an `accDescr { }` block, which
give screen readers a title and a one-paragraph summary of the diagram.
Node emphasis is applied through `classDef`/`class` and edge emphasis through
`linkStyle`.

There are **no `click ... href` links** in any emitted file. GitHub renders
mermaid inside a framed context whose content-security policy blocks them, so
a deep link back to a do-file line would be a headline feature that silently
dies in the venue the mermaid export exists to serve (DECISIONS 18a). SMCL
`{stata}`/`{view}` links already cover the in-Stata case and SVG `<title>`
tooltips cover HTML.

Every file also opens with a provenance comment giving the renderer
version, the journal name, a timestamp, the Stata version and edition, and
the git branch and short commit when the working directory sits inside a
repository. The git lookup
reads `.git/HEAD` and the ref file (or `packed-refs`) directly, with no shell
call, so it behaves the same on every platform and under `-b` batch. The DOT
export repeats the line as a graph label at the bottom of the picture, and
the `.md` wrappers repeat it under the heading, so an exported figure is
datable rather than anonymous.

### Version floor

GitHub pins mermaid near **10.0.2**, so the emitted syntax stays inside what
that release parses: no `block-beta`, and `-beta` suffixes kept where the
diagram type requires them. Everything non-obvious that the renderer emits
was checked against the 10.0.2 parser itself: the stadium node shape used for
filters, `linkStyle` with a comma-separated index list, `classDef`, and
`accTitle`/`accDescr { }` in **both** the flowchart and the erDiagram
grammars, along with `PK`/`FK` attribute keys and quoted relationship labels.

One escaping rule follows from the same source. Mermaid renders node labels
as HTML, so a `<` inside a filter condition (`keep if wage < 100`) would be
read as the start of a tag. The renderer rewrites `<` as mermaid's own entity
form `#60;` in mermaid output only; the DOT export keeps the literal
character, which is correct there.

## Mermaid (`.mmd` / `_er.mmd` / `.md`)

1. **GitHub** (macOS, Windows, any browser). Commit or paste the `.md` file --
   GitHub renders fenced ` ```mermaid ` blocks natively in READMEs, issues,
   pull requests, gists, and file previews. Nothing to install.
2. **mermaid.live** (any browser). Open <https://mermaid.live>, paste the
   contents of the `.mmd` file into the editor. Instant render, plus PNG/SVG
   download. Good for a one-off look at a diagram someone mailed you.
3. **Quarto** (macOS, Windows). If Quarto is already on the machine (it ships
   with recent RStudio and many data-team setups), a ` ```{mermaid} ` block in
   any `.qmd` renders to HTML/PDF/Word with no additional install -- Quarto
   bundles mermaid.js. Change the fence in the `.md` from ` ```mermaid ` to
   ` ```{mermaid} ` or `{{< include >}}` the `.mmd` file.
4. **VS Code** (macOS, Windows). The built-in Markdown preview renders
   mermaid fences once the free "Markdown Preview Mermaid Support" extension
   is added (one click, no admin rights). Open the `.md`, press
   Cmd+Shift+V / Ctrl+Shift+V.

## DOT (`.dot`)

Graphviz itself is OPTIONAL. If it happens to be installed
(`dot -Tsvg diagram.dot -o diagram.svg`), use it; otherwise:

1. **Online viewers** (any browser, nothing to install). Paste the `.dot`
   contents into any of:
   - <https://dreampuf.github.io/GraphvizOnline/> (renders in-browser via WASM;
     SVG/PNG export)
   - <https://edotor.net>
   - <https://sketchviz.com> (hand-drawn style)
2. **Quarto** (macOS, Windows). ` ```{dot} ` blocks render natively, same
   zero-extra-install story as mermaid above.
3. **VS Code**. The "Graphviz Interactive Preview" extension renders `.dot`
   files in-editor without a system Graphviz.

Installing Graphviz later (macOS: `brew install graphviz`; Windows:
`winget install graphviz`) unlocks local batch conversion, but no mergemap
feature depends on it.

## Opening an HTML/diagram file from inside Stata

`view browse` works in GUI Stata but fails under console/batch (rc 199), so
hand the file to the operating system instead. The OS switch keys off
`c(os)`:

```stata
local f "mergemap.html"                    // or any exported file
if "`c(os)'" == "MacOSX" {
    !open "`f'"
}
else if "`c(os)'" == "Windows" {
    winexec cmd /c start "" "`f'"
}
else {                                     // Unix/Linux
    !xdg-open "`f'"
}
```

Notes:

- On Windows the empty `""` after `start` is the (required) window-title
  argument; without it a quoted path is eaten as the title.
- `winexec` returns immediately and does not block Stata; `!`/`shell` on
  macOS with `open` also returns immediately because `open` itself forks.
- In GUI Stata you can try `view browse "file://`f'"` first and fall back to
  the switch above when `_rc != 0`.
- The same switch opens `.svg`/`.png` exports in the default viewer, and a
  `.mmd` file in whatever editor the OS associates with it.

## Regenerating and testing

`demo.do` renders both contract journals into all four formats, both layouts,
and then runs 32 assertions over what it wrote. `edgecases.do` builds small
journals covering what the contract journals do not contain -- a `<` in a
filter condition, an over-long path, a macro-built path, `severity=stop` with
no flag text, `lifecycle=overwrite`, an unknown 35th column, a v1 journal
that must be refused, a short journal that must still render, and the git
provenance lookup -- and runs 17 more. Both are headless:

```
stata-mp -b do demo.do
stata-mp -b do edgecases.do
grep -n "^r([0-9]" demo.log edgecases.log      # must find nothing
```

`mmsql.do` is a separate teach-mode prototype (PLAN section 7). It prints
jOOQ-style row-stack pictures for `merge m:1` and the `merge m:m` warning
case, captures them to `.smcl`, and translates them to ASCII `.txt`. It is
not part of the renderer and stays a prototype.
