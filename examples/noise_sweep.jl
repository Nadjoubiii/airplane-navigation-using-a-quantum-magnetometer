# Library-style use that needs no raster file: build a map from an array,
# then compare sensor noise levels over the same flight.
# Usage: julia --project=. examples/noise_sweep.jl
using MagNavSim
using Statistics

# A synthetic 1°x1° world patch on a 0.05° grid with a smooth anomaly pattern.
lons = range(-123.0, -121.0; step=0.05)
lats = range(39.0, 37.0; step=-0.05)   # north -> south, as in GeoTIFFs
data = [60 * sin(3 * (lon + 123)) * cos(2 * (lat - 37)) for lon in lons, lat in lats]
amap = MagneticMap(data, first(lons) - 0.025, first(lats) + 0.025, 0.05, 0.05)

println("noise (nT)   RMS measurement error (nT)")
for noise in (0.1, 1.0, 5.0, 20.0)
    sim = simulate_flight(amap, (-122.5, 37.6), (-121.5, 38.6); nsteps=500, noise_std=noise, seed=42)
    rms = sqrt(mean(abs2, sim[:meas] .- sim[:true]))
    println(rpad(noise, 12), round(rms; digits=3))
end
