// node -r esm tex2chtml.js input.html output.html --css index.css

//  Get the command-line arguments
const fs = require("fs");
const { JSDOM } = require("jsdom");
var argv = require('minimist')(process.argv.slice(2))

//  Read the HTML file
const htmlfile = fs.readFileSync(argv._[0], 'utf8');
const dom = new JSDOM(htmlfile);
const { document } = dom.window;

// add viewport for better mathjax render
const head = document.querySelector("head");
const meta = document.createElement("meta");
meta.setAttribute("name", "viewport");
meta.setAttribute("content", "width=device-width, initial-scale=1, shrink-to-fit=no")
head.appendChild(meta);

// add css
const link = document.createElement("link");
link.setAttribute("type", "text/css");
link.setAttribute("rel", "stylesheet");
link.setAttribute("href", argv.css);
head.appendChild(link);

// figure caption always at end
Array.from(document.querySelectorAll("figure")).forEach(
  (figure) => {
    if (figure.children.length > 0 && figure.children[0].tagName == "FIGCAPTION") {
      figure.appendChild(figure.children[0])
    }
  }
);

// put footnotes underneath authors
// TODO

// convert plaintext links to anchor tags
// TODO

// biblio glutton?
// TODO

// escape math
Array.from(document.querySelectorAll(".ltx_equation .ltx_Math")).forEach(
  (math) => {
    math.className = "ltx_DisplayMath"; // disambiguate between inline math and breaking equations
    math.innerHTML = `\\[${math.innerHTML}\\]`;
  }
);
Array.from(document.querySelectorAll(".ltx_Math")).forEach(
  (math) => {
    math.innerHTML = `\\(${math.innerHTML}\\)`;
  }
);

// remove style from tables
Array.from(document.querySelectorAll(".ltx_block.ltx_align_center")).forEach(
  e => {
    e.style = "";
  }
);

// Configure MathJax
require('mathjax-full').init({
  options: {
    ignoreHtmlClass: 'ltx_page_main',
    processHtmlClass: 'ltx_Math|ltx_DisplayMath'
  },
  loader: {
    source: require('mathjax-full/components/src/source.js').source,
    load: ['adaptors/liteDOM', 'tex-chtml']
  },
  JSDOM: JSDOM,
  tex: {
    packages: ['autoload', 'base', 'require', 'ams', 'newcommand'],
    processRefs: false
  },
  chtml: {
    mtextInheritFont: true,
    matchFontHeight: false,
    exFactor: .44,
    fontURL: 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/output/chtml/fonts/woff-v2',
  },
  'adaptors/liteDOM': {
    fontSize: 16
  },
  startup: {
    document: dom.serialize(),
    ready() {
      const OutputJax = MathJax._.output.common.OutputJax.CommonOutputJax;
      const measureMetrics = OutputJax.prototype.measureMetrics;
      OutputJax.prototype.measureMetrics = function (node, getFamily) {
        const metrics = measureMetrics.call(this, node, getFamily);
        const [w, h] = this.adaptor.nodeSize(this.adaptor.childNode(node, 1));
        metrics.ex = (w ? h / 60 : metrics.em * this.options.exFactor);
        const scale = Math.max(this.options.minScale,
          this.options.matchFontHeight ?
          metrics.ex / this.font.params.x_height / metrics.em : 1);
        return metrics;
      }
      MathJax.startup.defaultReady();
    }
  }
});

//  Wait for MathJax to start up, and then typeset the math
MathJax.startup.promise.then(() => {
  const adaptor = MathJax.startup.adaptor;
  const html = MathJax.startup.document;
  if (html.math.toArray().length === 0) adaptor.remove(html.outputJax.chtmlStyles);
  const doctype = adaptor.doctype(html.document)
  const outer = adaptor.outerHTML(adaptor.root(html.document));
  fs.writeFileSync(argv._[1], doctype + "\n" + outer);
  // console.log(adaptor.doctype(html.document));
  // console.log(adaptor.outerHTML(adaptor.root(html.document)));
}).catch(err => console.log(err));
// fs.writeFileSync(argv._[1], dom.serialize());
