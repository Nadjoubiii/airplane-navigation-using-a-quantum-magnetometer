# Physical and numerical model

This document describes exactly what MagNavSim computes, so results can be
interpreted (and the simplifications judged) correctly.

## 1. Background: magnetic-anomaly navigation

The Earth's crust has magnetised rocks that perturb the main geomagnetic field by
tens to thousands of nT on scales of kilometres. The perturbation is fixed in
space, so a vehicle that measures the field and knows the anomaly map can
estimate its position (map matching). The achievable position accuracy depends
on how well the sensor resolves the anomaly relative to its own noise, which
is why quantum magnetometers (optically pumped, NV-diamond, ...) are of interest.

MagNavSim is the **forward model**: *map + track + sensor → measurements*. It does
not yet include a navigation filter (see [Roadmap](../README.md#roadmap)).

## 2. Pipeline

```
 EMAG2 raster ──► MagneticMap ──► sample along track ──► scalar anomaly B(t)
                                                              │
                              unit field direction û(decl, incl)
                                                              ▼
                               true vector  b(t) = B(t)·û
                                                              │
                                    QuantumMagnetometer.step_measure!
                                                              ▼
                              measured vector m(t) ──► scalar  m_s(t) = m(t)·û
```

## 3. Magnetic map

* **Source**: EMAG2 v3 (NOAA NCEI), 2 arc-minute (≈0.0333°) total-intensity
  anomaly, upward continued to 4 km above geoid. Any single-band, north-up
  lon/lat raster readable by GDAL works.
* **Layout**: arrays from GDAL are `(nx, ny)`; row `iy = 1` is the northernmost.
  `MagneticMap` stores `data[ix, iy]` in that layout and keeps the geotransform
  (`xmin`, `ymax`, `dx`, `dy`).
* **Pixel centres**: the GeoTIFF origin is the outer corner of the first pixel,
  so pixel `i` is centred at `xmin + (i − ½)·dx`.
* **Longitude convention**: EMAG2 spans longitudes 0°…360°. When a grid spans
  360° it is treated as periodic, so both `-122.5` and `237.5` address the same
  cell. For regional grids, queries outside the extent raise `DomainError`.
* **Nodata**: EMAG2 marks missing data with `-3.4028235e38`. These cells become
  `NaN` on load. A flight that crosses one aborts with an error rather than
  silently feeding garbage to the sensor.
* **Interpolation**: bilinear by default (`:nearest` available). Latitude is
  clamped at the edges, longitude wraps on global grids.

## 4. Trajectory

The track is a straight line **in lon/lat space** with `nsteps` equally spaced
samples, `dt` seconds apart. This is not a great-circle path and ground speed
is not constant in metres; it is adequate for small regions and sensor trade
studies. Altitude is not modelled (EMAG2 is a fixed-altitude product).

## 5. Field direction and anomaly vector

The scalar anomaly `B` (nT) is assumed to be a small perturbation along the main
field direction, the standard total-field approximation (|ΔB| ≪ |B₀|):

```
û = [cos(incl)·cos(decl),  cos(incl)·sin(decl),  sin(incl)]   (north, east, down)
b = B · û / base_strength
```

`simulate_flight` uses `base_strength = 1`, so `b` is in nT. `decl`/`incl` are
constants (defaults 0° and 60°), not looked up from a field model such as IGRF.

## 6. Quantum magnetometer model

For each sample, with `R` the body→sensor rotation (identity in
`simulate_flight`):

```
v      = R · b                       rotate into sensor frame
v_s    = scale ∘ v + bias            per-axis scale factor and bias (nT)
v_n    = v_s + σ · N(0, I)           white Gaussian noise, σ = noise_std (nT/axis)
x_k    = x_{k-1} + α (v_n − x_{k-1}) first-order low-pass,  α = dt / (τ + dt)
```

The output `m = x_k` is the measured vector, and the scalar measurement is the
projection `m_s = m · û`.

Consequences worth knowing:

* With independent noise of σ per axis, the scalar noise before filtering is
  also σ (since |û| = 1). The low-pass reduces it by roughly
  `sqrt(α / (2 − α))`; for the defaults (`dt = 1`, `τ = 0.1`, α ≈ 0.91) this
  is ≈ 0.92σ.
* If `dt ≫ τ` the filter is nearly transparent; if `τ ≫ dt` the sensor
  averages noise but smears short-wavelength anomalies.
* The filter starts at the first noiseless reading, so there is no start-up
  transient.
* Noise is white and Gaussian. Colored (1/f) noise, heading error, and
  platform magnetic interference are **not** modelled.

## 7. Reproducibility

Pass `seed=<int>` (or `--seed N` on the CLI) for identical noise realisations.
Without a seed, the global RNG is used.

## 8. Known limitations

| Limitation | Effect |
|---|---|
| Straight lon/lat track, no altitude | Not a realistic flight profile |
| Constant `decl`/`incl` | Field direction not location-dependent |
| Identity body→sensor rotation | No attitude or heading error |
| White Gaussian noise only | No drift or 1/f noise |
| No navigation filter | Cannot yet estimate position error |
| EMAG2 is 2′ upward-continued | Fine-scale anomalies are not represented |
