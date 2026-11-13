"""
Flight simulation: fly a straight lon/lat track over a magnetic anomaly map and
record what a quantum magnetometer would measure.
"""

const DEFAULT_START = (-122.5, 37.6)  # near San Francisco
const DEFAULT_STOP  = (-121.5, 38.6)  # north-east of the start

"""
    simulate_flight(map_or_path, start, stop; kwargs...) -> Dict

Fly a straight line in lon/lat from `start` to `stop` (both `(lon, lat)` in
degrees), sample the anomaly map along the track, and pass the true anomaly
vector through the [`QuantumMagnetometer`](@ref) model.

`map_or_path` is a [`MagneticMap`](@ref) or a path to a raster file (loaded with
[`load_map`](@ref)). For repeated runs, load the map once and pass it in.

# Keyword arguments
- `nsteps=200`: number of samples along the track (>= 2).
- `dt=1.0`: sample interval in seconds.
- `noise_std=5.0`: white noise per axis (nT).
- `tau=0.1`: sensor low-pass time constant (s).
- `bias=(0,0,0)`, `scale=(1,1,1)`: per-axis sensor bias (nT) and scale factor.
- `decl=0.0`, `incl=60.0`: main-field declination/inclination (degrees).
- `interpolation=:bilinear`: `:bilinear` or `:nearest` map sampling.
- `seed=nothing`: integer seed for a reproducible run (overrides `rng`).
- `rng=Random.default_rng()`: random number generator for the sensor noise.

# Returns
A `Dict` with keys
- `:time`: sample times (s)
- `:lons`, `:lats`: track coordinates (degrees)
- `:true`: true scalar anomaly from the map (nT)
- `:meas`: scalar measurement, i.e. the measured vector projected on the field direction (nT)
- `:true_vec`, `:meas_vec`: true and measured 3-axis vectors (`SVector{3,Float64}`, nT)
"""
function simulate_flight(m::MagneticMap, start::Tuple{<:Real,<:Real}, stop::Tuple{<:Real,<:Real};
                         nsteps::Int=200, dt::Real=1.0, noise_std::Real=5.0, tau::Real=0.1,
                         bias=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0),
                         decl::Real=0.0, incl::Real=60.0, interpolation::Symbol=:bilinear,
                         seed::Union{Nothing,Integer}=nothing, rng::AbstractRNG=Random.default_rng())
    nsteps >= 2 || throw(ArgumentError("nsteps must be at least 2"))
    dt > 0 || throw(ArgumentError("dt must be positive"))
    noise_std >= 0 || throw(ArgumentError("noise_std must be non-negative"))
    tau >= 0 || throw(ArgumentError("tau must be non-negative"))
    rng = seed === nothing ? rng : MersenneTwister(seed)

    lons = collect(range(Float64(start[1]), Float64(stop[1]); length=nsteps))
    lats = collect(range(Float64(start[2]), Float64(stop[2]); length=nsteps))
    times = collect(range(0.0; step=Float64(dt), length=nsteps))

    unit_field = anomaly_scalar_to_vector(1.0; decl=Float64(decl), incl=Float64(incl), base_strength=1.0)
    bias_v = SVector{3,Float64}(bias...)
    scale_v = SVector{3,Float64}(scale...)
    R_identity = SMatrix{3,3,Float64}(I)

    true_vals = Vector{Float64}(undef, nsteps)
    meas = Vector{Float64}(undef, nsteps)
    true_vec = Vector{SVector{3,Float64}}(undef, nsteps)
    meas_vec = Vector{SVector{3,Float64}}(undef, nsteps)

    sensor = nothing
    for i in 1:nsteps
        v = sample_map(m, lons[i], lats[i]; interpolation=interpolation)
        isnan(v) && error("flight track crosses nodata at lon=$(lons[i]), lat=$(lats[i])")
        tv = anomaly_scalar_to_vector(v; decl=Float64(decl), incl=Float64(incl), base_strength=1.0)
        if sensor === nothing
            # Start the low-pass filter at the first noiseless reading to avoid a startup transient.
            sensor = QuantumMagnetometer(bias=bias_v, scale=scale_v,
                                         noise_std=SVector{3,Float64}(noise_std, noise_std, noise_std),
                                         tau=Float64(tau), state=scale_v .* tv .+ bias_v)
        end
        sensor, mv = step_measure!(sensor, tv, R_identity, Float64(dt); rng=rng)
        true_vals[i] = v
        meas[i] = dot(mv, unit_field)
        true_vec[i] = tv
        meas_vec[i] = mv
    end

    return Dict(:time => times, :lons => lons, :lats => lats, :true => true_vals,
                :meas => meas, :true_vec => true_vec, :meas_vec => meas_vec)
end

simulate_flight(raster_path::AbstractString, start::Tuple{<:Real,<:Real}, stop::Tuple{<:Real,<:Real}; kwargs...) =
    simulate_flight(load_map(raster_path), start, stop; kwargs...)

"""
    simulate_synthetic_flight(start, stop; nsteps=200, noise_std=5.0, seed=nothing, rng=...) -> Dict

Smoke-test flight over an analytic anomaly field (no raster needed). Returns
`:lons`, `:lats`, `:true`, and `:meas` (true plus white Gaussian noise).
"""
function simulate_synthetic_flight(start::Tuple{<:Real,<:Real}, stop::Tuple{<:Real,<:Real};
                                   nsteps::Int=200, noise_std::Real=5.0,
                                   seed::Union{Nothing,Integer}=nothing, rng::AbstractRNG=Random.default_rng())
    nsteps >= 2 || throw(ArgumentError("nsteps must be at least 2"))
    rng = seed === nothing ? rng : MersenneTwister(seed)
    lons = collect(range(Float64(start[1]), Float64(stop[1]); length=nsteps))
    lats = collect(range(Float64(start[2]), Float64(stop[2]); length=nsteps))
    true_vals = [80.0 * sin(8.0 * (lon - start[1])) + 40.0 * cos(6.0 * (lat - start[2])) for (lon, lat) in zip(lons, lats)]
    meas = true_vals .+ noise_std .* randn(rng, nsteps)
    return Dict(:lons => lons, :lats => lats, :true => true_vals, :meas => meas)
end

"""
    run_example(raster_path; plot_path=nothing, kwargs...) -> Dict

Run [`simulate_flight`](@ref) over the default San Francisco track
(`DEFAULT_START` -> `DEFAULT_STOP`, 300 samples, 3 nT noise) and plot the result.
Falls back to [`simulate_synthetic_flight`](@ref) with a warning when
`raster_path` does not exist. Extra `kwargs` override the defaults and are
forwarded to the simulator. If `plot_path` is given the figure is saved there.
"""
function run_example(raster_path::AbstractString; plot_path::Union{Nothing,AbstractString}=nothing, kwargs...)
    opts = merge((nsteps=300, noise_std=3.0), NamedTuple(kwargs))
    sim = if isfile(raster_path)
        simulate_flight(raster_path, DEFAULT_START, DEFAULT_STOP; opts...)
    else
        @warn "Raster file not found; ran synthetic demo instead" raster_path
        simulate_synthetic_flight(DEFAULT_START, DEFAULT_STOP; nsteps=opts.nsteps, noise_std=opts.noise_std,
                                  seed=get(opts, :seed, nothing))
    end
    plt = plot_results(sim; path=plot_path)
    isinteractive() && display(plt)
    return sim
end
