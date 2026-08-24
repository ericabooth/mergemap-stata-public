* build_gallery.do -- rebuild gallery.html from scratch.
*
* Run from gallery/:   do build_gallery.do
* Needs: mergemap (this package) and webdoc2
*        (net install webdoc2, from("https://raw.githubusercontent.com/ericabooth/webdoc2-stata-public/main/"))
* header.html in this folder is webdoc2's page theme; wdinit looks for it in
* the working directory, because net install does not place ancillary files.
*
* Author: Eric Booth

version 16
do gallery_prep.do
webdoc2 gallery.do, cleanup
display as result "build_gallery.do: wrote gallery.html"
