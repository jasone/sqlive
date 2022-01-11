#!/bin/bash

rm -f docs_body.html

markdown docs.md > docs_body.html

rm -f docs.html
touch docs.html

cat docs_header.html >> docs.html
cat docs_body.html | sed 's/<code/<pre><code class="hljs"/g' | sed 's/<\/code>/<\/code><\/pre>/g' >> docs.html
cat docs_footer.html >> docs.html

cp docs.html  ../
