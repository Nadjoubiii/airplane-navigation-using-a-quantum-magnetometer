
module MagNavSim

using ArchGDAL
using Random
using Distributions
using Plots

include("emag_downloader.jl")
include("quantum_sensor.jl")

using .EmagDownloader
using .QuantumSensor

export simulate_flight, run_example, download_emag, preprocess_emag, QuantumMagnetometer, anomaly_scalar_to_vector, step_measure!

"""
Read a single-band raster value nearest to (lon, lat).
This is a small helper that assumes the raster geotransform is in lon/lat.
"""
function read_raster_value(raster_path::AbstractString, lon::Float64, lat::Float64)
    ArchGDAL.registerdrivers()
    ds = ArchGDAL.open(raster_path)
    band = ArchGDAL.getband(ds, 1)
    gt = ArchGDAL.getgeotransform(ds)
    xmin, pixelw, _, ymax, _, pixelh = gt
    px = Int(round((lon - xmin) / pixelw))
    py = Int(round((lat - ymax) / pixelh))
    arr = ArchGDAL.read(band)
    ny, nx = size(arr)
    ix = clamp(px, 1, nx)
    iy = clamp(py, 1, ny)
    return Float64(arr[iy, ix])
end

"""
Simulate a straight-line flight from `start` to `stop` and sample magnetic anomaly from `raster_path`.
start/stop are (lon, lat) tuples. Returns a Dict with positions, true anomalies, and noisy measurements.
"""
function simulate_flight(raster_path::AbstractString, start::Tuple{Float64,Float64}, stop::Tuple{Float64,Float64}; nsteps::Int=200, noise_std::Float64=5.0)
    lons = range(start[1], stop[1], length=nsteps)
    lats = range(start[2], stop[2], length=nsteps)
    true_vals = Float64[]
    meas = Float64[]
    rng = MersenneTwister()
    noise_dist = Normal(0.0, noise_std)
    for (lon, lat) in zip(lons, lats)
        v = read_raster_value(raster_path, lon, lat)
        push!(true_vals, v)
        push!(meas, v + rand(rng, noise_dist))
    end
    return Dict(:lons=>collect(lons), :lats=>collect(lats), :true=>true_vals, :meas=>meas)
end

function run_example(raster_path::AbstractString)
    start = (-122.5, 37.6) # near San Francisco
    stop  = (-121.5, 38.6) # northeast
    sim = simulate_flight(raster_path, start, stop; nsteps=300, noise_std=3.0)
    plt = plot(sim[:lons], sim[:true], label="True anomaly", xlabel="Longitude", ylabel="Anomaly (nT)")
    plot!(sim[:lons], sim[:meas], label="Measured (noisy)")
    display(plt)
    return sim
end

end # module
