#!/usr/bin/env python3
"""Assert a mergemap embed fragment cannot restyle the page it is dropped into.

Usage:  python3 check_embed_scoping.py frag.html

The fragment is injected verbatim into someone else's HTML, so every CSS
selector it carries must be scoped under a .mm- class and every id must be
namespaced.  A bare element selector (body, h1, pre, svg) would silently
restyle the host report -- which is what happened during the webdoc2 testing
that motivated embed mode: mergemap's own body{max-width:920px} capped the
whole report, and its h1/h2 rules shrank the report's own headings.
"""
import re, sys

path = sys.argv[1] if len(sys.argv) > 1 else "frag.html"
s = open(path).read()
fail = []

sels = 0
for block in re.findall(r"<style[^>]*>(.*?)</style>", s, re.S):
    block = re.sub(r"/\*.*?\*/", "", block, flags=re.S)
    for m in re.finditer(r"([^{}]+)\{[^{}]*\}", block):
        sel = m.group(1).strip()
        if not sel or sel.startswith("@"):
            continue
        for part in (p.strip() for p in sel.split(",")):
            if not part:
                continue
            sels += 1
            if not part.startswith(".mm-"):
                fail.append("unscoped selector: " + part)

for i in set(re.findall(r'id="([^"]+)"', s)):
    if not i.startswith("mm-"):
        fail.append("un-namespaced id: " + i)

if re.search(r"<svg[^>]*\s(width|height)=", s):
    fail.append("svg carries width/height; embed mode must use viewBox alone")
if "<html" in s.lower() or "<body" in s.lower():
    fail.append("fragment carries a page wrapper")
if "<script" in s.lower():
    fail.append("fragment carries script")

print("checked %d selectors in %s" % (sels, path))
if fail:
    print("FAIL")
    for f in fail:
        print("  " + f)
    sys.exit(1)
print("PASS: fragment is fully scoped")
