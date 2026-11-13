# API reference

All names below are exported by `using MagNavSim`. Units: degrees for lon/lat,
nT for magnetic quantities, seconds for time. Full docstrings are available in
the Julia REPL with `?simulate_flight`, etc.

## Maps

### `MagneticMap(data, xmin, ymax, dx, dy)`
In-memory grid. `data[ix, iy]` with `iy = 1` the northernmost row; `xmin`, `ymax`
are the outer corner of the upper-left pixel; `dx`, `dy` are positive pixel sizes.
Build one from an array to run without any raster file (see
[`examples/noise_sweep.jl`](../examples/noise_sweep.jl)).

### `load_map(path) -> MagneticMap`
Read band 1 of a north-up lon/lat raster. Nodata → `NaN`.

### `sample_map(map, lon, lat; interpolation=:bilinear) -> Float64`
Value at a point. `interpolation` ∈ `:bilinear`, `:nearest`. Throws `DomainError`
outside the grid; returns `NaN` on nodata.

### `bounds(map) -> (lon_min, lon_max, lat_min, lat_max)`
Extent of pixel centres.

## Simulation

### `simulate_flight(map_or_path, start, stop; kwargs...) -> Dict`

| Keyword | Default | Meaning |
|---|---|---|
| `nsteps` | `200` | samples along the track (≥ 2) |
| `dt` | `1.0` | sample interval (s) |
| `noise_std` | `5.0` | white noise per axis (nT) |
| `tau` | `0.1` | sensor low-pass time constant (s) |
| `bias` | `(0,0,0)` | per-axis bias (nT) |
| `scale` | `(1,1,1)` | per-axis scale factor |
| `decl`, `incl` | `0.0`, `60.0` | field direction (°) |
| `interpolation` | `:bilinear` | map sampling |
| `seed` | `nothing` | integer seed (overrides `rng`) |
| `rng` | `default_rng()` | random number generator |

`start` and `stop` are `(lon, lat)` tuples.

Returned `Dict` keys:

| Key | Type | Description |
|---|---|---|
| `:time` | `Vector{Float64}` | sample times (s) |
| `:lons`, `:lats` | `Vector{Float64}` | track (°) |
| `:true` | `Vector{Float64}` | true scalar anomaly from the map (nT) |
| `:meas` | `Vector{Float64}` | scalar measurement (nT) |
| `:true_vec` | `Vector{SVector{3}}` | true anomaly vector, (N, E, D) nT |
| `:meas_vec` | `Vector{SVector{3}}` | measured vector (nT) |

### `simulate_synthetic_flight(start, stop; nsteps, noise_std, seed, rng) -> Dict`
Analytic field, no raster. Returns `:lons, :lats, :true, :meas`.

### `run_example(raster_path; plot_path=nothing, kwargs...) -> Dict`
Default San Francisco track with plotting; falls back to the synthetic field when
the raster is missing.

## Sensor

### `QuantumMagnetometer(; bias, scale, noise_std, tau, state)`
Immutable 3-axis sensor.

### `step_measure!(sensor, true_vector, R, dt; rng) -> (new_sensor, measurement)`
One time step. Despite the `!`, the sensor is immutable: use the returned copy.

### `anomaly_scalar_to_vector(anom; decl, incl, base_strength) -> SVector{3}`
Scalar anomaly → vector along the field direction.

## Output helpers

| Function | Purpose |
|---|---|
| `plot_results(sim; path=nothing)` | true vs measured plot plus error panel |
| `summarize(sim; raster=nothing)` | summary lines (`Vector{String}`) |
| `write_summary(path, lines)` | write summary text |
| `write_csv(path, sim)` | export to CSV |

## Data utilities

### `download_emag(url, dest_path; overwrite=false)`
HTTP download; skips when the file exists.

### `preprocess_emag(input, output; target_crs="EPSG:4326", resampling="bilinear")`
Reproject/warp a raster with GDAL.

## Command line

`MagNavSim.main(args)` backs `src/main.jl`; see `julia --project=. src/main.jl --help`.
