# MagNavSim

Lightweight Julia simulation scaffold for map-based magnetic navigation using EMAG-style anomaly grids and a custom sensor model.

Quickstart

1. Open the project folder in Julia and activate the project:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

2. Edit `examples/simple_run.jl` to point `SAMPLE_RASTER` at your local EMAG tile (GeoTIFF/NetCDF).

3. Run the example:

```sh
julia --project=examples examples/simple_run.jl
```

Notes

- The code uses `ArchGDAL` to read raster values. Ensure GDAL is available in your environment. The `MagNav` package you installed can be used to add more realistic sensor models and navigation filters; this scaffold intentionally keeps sensor and dynamics simple so we can iterate.
- Next steps I can take: (1) add an EMAG2 downloader and preprocessor, (2) implement a quantum magnetometer model, (3) add a particle filter/EKF using `MagNav`.
