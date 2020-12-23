To run this benchmark:

```
cd \
  && git clone https://github.com/v8/web-tooling-benchmark.git \
  && cd web-tooling-benchmark \
  && npm install \
  && node dist/cli.js
```

## Macbook Pro Late 2013 13"

- CPU: 2,6 GHz Dual-Core Intel Core i5
- RAM: 8 GB 1600 MHz DDR3

Running Web Tooling Benchmark v0.5.3…
-------------------------------------
         acorn:  6.84 runs/s
         babel:  7.25 runs/s
  babel-minify:  8.93 runs/s
       babylon:  7.98 runs/s
         buble:  4.47 runs/s
          chai: 13.05 runs/s
  coffeescript:  6.24 runs/s
        espree:  2.92 runs/s
       esprima:  6.47 runs/s
        jshint:  8.53 runs/s
         lebab:  9.74 runs/s
       postcss:  5.13 runs/s
       prepack:  6.57 runs/s
      prettier:  6.16 runs/s
    source-map:  8.37 runs/s
        terser: 13.95 runs/s
    typescript:  7.31 runs/s
     uglify-js:  4.63 runs/s
-------------------------------------
Geometric mean:  7.01 runs/s

## Macbook Pro 2019 16"

- CPU: 2,3 GHz 8-Core Intel Core i9
- RAM: 16 GB 2667 MHz DDR4

Running Web Tooling Benchmark v0.5.3…
-------------------------------------
         acorn: 11.92 runs/s
         babel:  8.89 runs/s
  babel-minify: 12.58 runs/s
       babylon: 11.78 runs/s
         buble:  7.73 runs/s
          chai: 17.59 runs/s
  coffeescript:  8.89 runs/s
        espree:  3.89 runs/s
       esprima:  9.17 runs/s
        jshint: 10.50 runs/s
         lebab: 13.38 runs/s
       postcss:  7.45 runs/s
       prepack:  8.03 runs/s
      prettier:  8.08 runs/s
    source-map: 10.45 runs/s
        terser: 18.68 runs/s
    typescript:  8.94 runs/s
     uglify-js:  5.98 runs/s
-------------------------------------
Geometric mean:  9.60 runs/s
