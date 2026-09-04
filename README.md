# zemax-lens-analyzer

MATLAB toolkit to read Zemax (`.zmx`) sequential lens files and analyze geometric imaging behavior.

## Implemented functionality

- `parseZmxFile(filePath)`
  - Parses sequential `.zmx` files (UTF-16LE BOM, UTF-8/ASCII fallback).
  - Extracts surface data (`CURV`, `DISZ`, `GLAS`, `DIAM`, `CONI`, `TYPE`, `PARM`) and system data (`ENPD`, `WAVL/WAVM`, `XFLN/YFLN` or `FLDX/FLDY`, stop/object/image indices where available).
  - Ignores unknown keywords for robust forward compatibility.

- `traceSequentialRays(lensData, rays, Name,Value...)`
  - Non-paraxial sequential trace using Snell refraction per surface.
  - Supports planar and conic/spherical surfaces.
  - Includes built-in refractive-index table for AIR/BK7/F2/SF11 with fallback index for unknown glass names.

- `plotLensLayout2D(lensData, surfaceRange, Name,Value...)`
  - 2D y-z cross-section of surfaces and representative traced rays.

- `plotLensLayout3D(lensData, surfaceRange, Name,Value...)`
  - 3D revolved surface layout and traced 3D rays.

- `plotSpotDiagram(lensData, fieldPoint, Name,Value...)`
  - Geometric spot diagram for one or more field points with centroid and RMS radius display.

- `plotRmsSpotColormap(lensData, Name,Value...)`
  - Grid-sampled RMS spot radius map across the field.

- `rmsSpotToGaussianFWHM(rmsRadius)` / `gaussianFWHMToRmsSpot(fwhm)`
  - Conversion for isotropic 2D Gaussian approximation.

## Quick start

```matlab
addpath('src');
lensData = parseZmxFile('tests/data/sample_lens.zmx');

figure;
plotLensLayout2D(lensData, []);

figure;
plotSpotDiagram(lensData, [0 0; 5 0], 'PupilSamples', 15);

figure;
plotRmsSpotColormap(lensData, 'GridSize', [11 11]);
```

## Tests

Run focused checks with:

```matlab
run('tests/run_tests.m');
run_tests;
```
