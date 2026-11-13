"""
Command-line interface used by `src/main.jl`.
"""

const CLI_USAGE = """
MagNavSim - magnetic-anomaly navigation flight simulator

Usage:
  julia --project=. src/main.jl [options]

Options:
  --raster PATH     Single-band anomaly raster (GeoTIFF/NetCDF).
                    Default: EMAG2_V3_UpCont_DataTiff.tif in the project root.
  --synthetic       Skip the raster and use the built-in analytic field.
  --start LON,LAT   Track start in degrees.   Default: -122.5,37.6
  --end LON,LAT     Track end in degrees.     Default: -121.5,38.6
  --steps N         Number of samples.        Default: 300
  --dt SECONDS      Sample interval.          Default: 1.0
  --noise NT        Sensor noise per axis.    Default: 3.0
  --tau SECONDS     Sensor low-pass constant. Default: 0.1
  --seed N          Seed for reproducible noise.
  --outdir DIR      Output directory.         Default: <project>/outputs
  --no-plot         Do not write the PNG plot.
  -h, --help        Show this help.

Outputs (in --outdir): last_run_summary.txt, flight.csv, flight.png
"""

Base.@kwdef mutable struct CLIOptions
    raster::String = joinpath(pkgdir(@__MODULE__), "EMAG2_V3_UpCont_DataTiff.tif")
    synthetic::Bool = false
    start::Tuple{Float64,Float64} = DEFAULT_START
    stop::Tuple{Float64,Float64} = DEFAULT_STOP
    steps::Int = 300
    dt::Float64 = 1.0
    noise::Float64 = 3.0
    tau::Float64 = 0.1
    seed::Union{Nothing,Int} = nothing
    outdir::String = joinpath(pkgdir(@__MODULE__), "outputs")
    plot::Bool = true
    help::Bool = false
end

function _parse_lonlat(s::AbstractString, flag::AbstractString)
    parts = split(s, ',')
    length(parts) == 2 || throw(ArgumentError("$flag expects LON,LAT (e.g. -122.5,37.6), got '$s'"))
    lon, lat = tryparse(Float64, strip(parts[1])), tryparse(Float64, strip(parts[2]))
    (lon === nothing || lat === nothing) && throw(ArgumentError("$flag expects numeric LON,LAT, got '$s'"))
    return (lon, lat)
end

function _parse_num(T::Type, s::AbstractString, flag::AbstractString)
    v = tryparse(T, s)
    v === nothing && throw(ArgumentError("$flag expects a number, got '$s'"))
    return v
end

"""
    parse_cli(args) -> CLIOptions

Parse command-line arguments (`--key value` or `--key=value`). Throws
`ArgumentError` on unknown flags or malformed values.
"""
function parse_cli(args::AbstractVector{<:AbstractString})
    opts = CLIOptions()
    args = collect(String, args)
    i = 1
    while i <= length(args)
        arg = args[i]
        flag, inline = occursin('=', arg) ? Tuple(split(arg, '='; limit=2)) : (arg, nothing)
        function value()
            inline !== nothing && return String(inline)
            i += 1
            i <= length(args) || throw(ArgumentError("$flag requires a value"))
            return args[i]
        end
        if flag in ("-h", "--help")
            opts.help = true
        elseif flag == "--synthetic"
            opts.synthetic = true
        elseif flag == "--no-plot"
            opts.plot = false
        elseif flag == "--raster"
            opts.raster = value()
        elseif flag == "--outdir"
            opts.outdir = value()
        elseif flag == "--start"
            opts.start = _parse_lonlat(value(), flag)
        elseif flag == "--end"
            opts.stop = _parse_lonlat(value(), flag)
        elseif flag == "--steps"
            opts.steps = _parse_num(Int, value(), flag)
        elseif flag == "--dt"
            opts.dt = _parse_num(Float64, value(), flag)
        elseif flag == "--noise"
            opts.noise = _parse_num(Float64, value(), flag)
        elseif flag == "--tau"
            opts.tau = _parse_num(Float64, value(), flag)
        elseif flag == "--seed"
            opts.seed = _parse_num(Int, value(), flag)
        else
            throw(ArgumentError("unknown option '$arg' (try --help)"))
        end
        i += 1
    end
    return opts
end

"""
    main(args=ARGS) -> Int

Run a simulation from command-line `args`, print a summary, and write
`last_run_summary.txt`, `flight.csv` and `flight.png` into the output directory.
Returns a process exit code.
"""
function main(args::AbstractVector{<:AbstractString}=ARGS)
    opts = try
        parse_cli(args)
    catch e
        e isa ArgumentError || rethrow()
        println(stderr, "error: ", e.msg)
        return 2
    end
    if opts.help
        print(CLI_USAGE)
        return 0
    end
    # Allow headless plotting (CI, servers) without a display.
    haskey(ENV, "GKSwstype") || (ENV["GKSwstype"] = "100")

    use_raster = !opts.synthetic && isfile(opts.raster)
    if !opts.synthetic && !use_raster
        @warn "Raster not found; using the synthetic field instead. Pass --raster PATH to use real data." raster = opts.raster
    end

    sim = try
        if use_raster
            println("Loading raster: ", opts.raster)
            simulate_flight(opts.raster, opts.start, opts.stop; nsteps=opts.steps, dt=opts.dt,
                            noise_std=opts.noise, tau=opts.tau, seed=opts.seed)
        else
            simulate_synthetic_flight(opts.start, opts.stop; nsteps=opts.steps, noise_std=opts.noise, seed=opts.seed)
        end
    catch e
        e isa Union{ArgumentError,DomainError} || e isa ErrorException || rethrow()
        println(stderr, "error: ", sprint(showerror, e))
        return 1
    end

    lines = summarize(sim; raster=use_raster ? opts.raster : nothing)
    println("\n" * join(lines, "\n"))
    summary_path = write_summary(joinpath(opts.outdir, "last_run_summary.txt"), lines)
    csv_path = write_csv(joinpath(opts.outdir, "flight.csv"), sim)
    println("\nSummary saved to: ", summary_path)
    println("Data saved to:    ", csv_path)
    if opts.plot
        plot_path = joinpath(opts.outdir, "flight.png")
        plot_results(sim; path=plot_path)
        println("Plot saved to:    ", plot_path)
    end
    return 0
end
