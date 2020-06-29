curl 'http://localhost:5000/query' -X POST \
     --header 'Content-Type: application/json' \
     --header 'Accept: application/json' \
     --data $'"{\\n    \\"query\\": \\"let main = p\u03bb .\\\\n              df :  \ud835\udd44 [L\u221e , U | \u2605 , \ud835\udc1d \u2115 \u2237 \ud835\udc1d \u2115 \u2237 [] ]\\\\n              \u21d2\\\\n  let \u03b5 = \u211d\u207a[1.0] in\\\\n  let \u03b4 = \u211d\u207a[0.00001] in\\\\n  gauss[\u211d\u207a[1.0], \u03b5, \u03b4] <df> { real (rows df) }\\\\nin main\\"\\n}\\n"'
