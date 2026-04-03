
module MagNavSim

using ArchGDAL
using Random
using Distributions
using Plots
using StaticArrays
using LinearAlgebra

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
    return ArchGDAL.read(raster_path) do ds
        band = ArchGDAL.getband(ds, 1)
        gt = ArchGDAL.getgeotransform(ds)
        xmin, pixelw, _, ymax, _, pixelh = gt
        px = Int(round((lon - xmin) / pixelw))
        py = Int(round((lat - ymax) / pixelh))
        arr = ArchGDAL.read(band)
        ny, nx = size(arr)
        ix = clamp(px, 1, nx)
        iy = clamp(py, 1, ny)
        Float64(arr[iy, ix])
    end
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
    true_vec = SVector{3,Float64}[]
    meas_vec = SVector{3,Float64}[]

    decl = 0.0
    incl = 60.0
    unit_field = anomaly_scalar_to_vector(1.0; decl=decl, incl=incl, base_strength=1.0)
    sensor = QuantumMagnetometer(noise_std=SVector{3,Float64}(noise_std, noise_std, noise_std), tau=0.1)
    R_identity = SMatrix{3,3,Float64}(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    dt = 1.0

    ArchGDAL.read(raster_path) do ds
        band = ArchGDAL.getband(ds, 1)
        gt = ArchGDAL.getgeotransform(ds)
        xmin, pixelw, _, ymax, _, pixelh = gt
        arr = ArchGDAL.read(band)
        ny, nx = size(arr)

        for (lon, lat) in zip(lons, lats)
            px = Int(round((lon - xmin) / pixelw))
            py = Int(round((lat - ymax) / pixelh))
            ix = clamp(px, 1, nx)
            iy = clamp(py, 1, ny)
            v = Float64(arr[iy, ix])

            tv = anomaly_scalar_to_vector(v; decl=decl, incl=incl, base_strength=1.0)
            sensor, mv = step_measure!(sensor, tv, R_identity, dt)

            push!(true_vals, v)
            push!(meas, dot(mv, unit_field))
            push!(true_vec, tv)
            push!(meas_vec, mv)
        end
    end

    return Dict(
        :lons=>collect(lons),
        :lats=>collect(lats),
        :true=>true_vals,
        :meas=>meas,
        :true_vec=>true_vec,
        :meas_vec=>meas_vec,
    )
end

"""
Run a synthetic trajectory when no raster is available.
This keeps the package usable out-of-the-box for smoke tests.
"""
function simulate_synthetic_flight(start::Tuple{Float64,Float64}, stop::Tuple{Float64,Float64}; nsteps::Int=200, noise_std::Float64=5.0)
    lons = range(start[1], stop[1], length=nsteps)
    lats = range(start[2], stop[2], length=nsteps)
    true_vals = [80.0 * sin(8.0 * (lon - start[1])) + 40.0 * cos(6.0 * (lat - start[2])) for (lon, lat) in zip(lons, lats)]
    rng = MersenneTwister()
    noise_dist = Normal(0.0, noise_std)
    meas = [v + rand(rng, noise_dist) for v in true_vals]
    return Dict(:lons=>collect(lons), :lats=>collect(lats), :true=>true_vals, :meas=>meas)
end

function run_example(raster_path::AbstractString)
    start = (-122.5, 37.6) # near San Francisco
    stop  = (-121.5, 38.6) # northeast
    sim = isfile(raster_path) ?
        simulate_flight(raster_path, start, stop; nsteps=300, noise_std=3.0) :
        simulate_synthetic_flight(start, stop; nsteps=300, noise_std=3.0)
    plt = plot(sim[:lons], sim[:true], label="True anomaly", xlabel="Longitude", ylabel="Anomaly (nT)")
    plot!(sim[:lons], sim[:meas], label="Measured (noisy)")
    if isinteractive()
        display(plt)
    end
    if !isfile(raster_path)
        @warn "Raster file not found; ran synthetic demo instead" raster_path
    end
    return sim
end

end # module
