**What:** compare computers with V8's benchmarking tools.

**How:** copy and paste the following (using a specific version of node, and
outputting the OS version at the end):

```
export NODENV_VERSION=14.18.1 \
  && cd \
  && git clone --quiet https://github.com/v8/web-tooling-benchmark.git || true \
  && cd web-tooling-benchmark \
  && echo $NODENV_VERSION > .nvmrc \
  && echo $NODENV_VERSION > .node-version \
  && npm --quiet install \
  && node dist/cli.js; \
  echo "Node version: $(node -v)"; \
  (sw_vers &> /dev/null && echo "OS: $(sw_vers -productName) $(sw_vers -productVersion)") || (printf "OS: " && cat /etc/*release 2>/dev/null | grep 'PRETTY_NAME.*' | sed 's/.*="\(.*\)"/\1/')
```

Note: make sure other memory and CPU consuming apps are closed (e.g Docker).

**Results:** we care about the `Geometric mean: n.nn runs/s` line, the node
version and the OS.

Feel free to run the test with other versions of node, but have at least one
result with the version above.

## Macbook Pro Late 2013 13"

- CPU: 2,6 GHz Dual-Core Intel Core i5
- RAM: 8 GB 1600 MHz DDR3

```
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
Node version: v14.18.1
OS: macOS 11.6.1
```

```
Geometric mean:  5.46 runs/s
Node version: v17.0.1
OS: macOS 11.6.1
```

## Macbook Pro 2019 16"

- CPU: 2,3 GHz 8-Core Intel Core i9
- RAM: 16 GB 2667 MHz DDR4

```
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
```

## Macbook Air M1 2020

- M1, 8 CPU cores & 8 GPU cores
- RAM: 16Gb

```
Running Web Tooling Benchmark v0.5.3…
-------------------------------------
         acorn: 20.76 runs/s
         babel: 14.03 runs/s
  babel-minify: 19.42 runs/s
       babylon: 19.98 runs/s
         buble: 10.11 runs/s
          chai: 26.91 runs/s
  coffeescript: 13.95 runs/s
        espree:  3.94 runs/s
       esprima: 15.28 runs/s
        jshint: 18.77 runs/s
         lebab: 17.65 runs/s
       postcss: 10.57 runs/s
       prepack: 14.19 runs/s
      prettier: 11.50 runs/s
    source-map: 14.51 runs/s
        terser: 34.34 runs/s
    typescript: 15.96 runs/s
     uglify-js: 11.09 runs/s
-------------------------------------
Geometric mean: 21.27 runs/s
Node version: v14.18.1
OS: macOS 12.0.1
```

```
Geometric mean: 14.90 runs/s
Node version: v12.16.1
OS: macOS 11.2.0
```

```
Geometric mean: 20.33 runs/s
Node version: v17.0.1
OS: macOS 12.0.1
```

## Mac Mini M1 2020

- M1, 8 CPU cores & 8 GPU cores
- RAM: 8Gb

```
Running Web Tooling Benchmark v0.5.3…
-------------------------------------
         acorn: 27.97 runs/s
         babel: 21.79 runs/s
  babel-minify: 28.30 runs/s
       babylon: 28.23 runs/s
         buble: 12.46 runs/s
          chai: 40.09 runs/s
  coffeescript: 18.25 runs/s
        espree:  7.88 runs/s
       esprima: 19.14 runs/s
        jshint: 28.56 runs/s
         lebab: 28.24 runs/s
       postcss: 16.65 runs/s
       prepack: 20.10 runs/s
      prettier: 16.99 runs/s
    source-map: 19.52 runs/s
        terser: 52.60 runs/s
    typescript: 23.74 runs/s
     uglify-js: 15.20 runs/s
-------------------------------------
Geometric mean: 21.70 runs/s
Node version: v14.15.4
OS: macOS 12.0.1
```

## Macbook Pro M1 Pro 2021

- M1, 10 CPU cores & 16 GPU cores
- RAM: 16Gb

```
Running Web Tooling Benchmark v0.5.3…
-------------------------------------
         acorn: 27.78 runs/s
         babel: 21.29 runs/s
  babel-minify: 28.93 runs/s
       babylon: 28.60 runs/s
         buble: 11.82 runs/s
          chai: 39.66 runs/s
  coffeescript: 16.68 runs/s
        espree:  7.59 runs/s
       esprima: 20.40 runs/s
        jshint: 28.62 runs/s
         lebab: 28.32 runs/s
       postcss: 17.01 runs/s
       prepack: 19.19 runs/s
      prettier: 15.87 runs/s
    source-map: 18.71 runs/s
        terser: 49.65 runs/s
    typescript: 23.36 runs/s
     uglify-js: 14.50 runs/s
-------------------------------------
Geometric mean: 21.25 runs/s
Node version: v14.18.1
OS: macOS 12.0.1
```
