using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

using MagNavSim
using Statistics
using Dates

const DEFAULT_RASTER = joinpath(@__DIR__, "..", "EMAG2_V3_UpCont_DataTiff.tif")
const OUTPUT_DIR = joinpath(@__DIR__, "..", "outputs")

function build_summary(sim::Dict, raster::AbstractString)
    n = length(sim[:meas])
    true_min = minimum(sim[:true])
    true_max = maximum(sim[:true])
    meas_mean = mean(sim[:meas])
    meas_std = std(sim[:meas])
    first_pt = (sim[:lons][1], sim[:lats][1])
    last_pt = (sim[:lons][end], sim[:lats][end])

    return [
        "MagNavSim Run Summary",
        "Timestamp (UTC): " * string(Dates.now(Dates.UTC)),
        "Raster: " * abspath(raster),
        "Samples: " * string(n),
        "Start (lon, lat): (" * string(first_pt[1]) * ", " * string(first_pt[2]) * ")",
        "End (lon, lat): (" * string(last_pt[1]) * ", " * string(last_pt[2]) * ")",
        "True anomaly min/max (nT): " * string(true_min) * " / " * string(true_max),
        "Measured anomaly mean/std (nT): " * string(meas_mean) * " / " * string(meas_std),
        "Vector channels: true_vec=" * string(haskey(sim, :true_vec)) * ", meas_vec=" * string(haskey(sim, :meas_vec)),
    ]
end

function write_summary(lines::Vector{String})
    mkpath(OUTPUT_DIR)
    out_path = joinpath(OUTPUT_DIR, "last_run_summary.txt")
    open(out_path, "w") do io
        write(io, join(lines, "\n") * "\n")
    end
    return out_path
end

function main()
    println("MagNavSim runner")
    println("Please provide a path to a single-band EMAG/ANOMALY raster (GeoTIFF/NetCDF).")
    println("Press Enter to use default: ", DEFAULT_RASTER)
    raster = try
        readline()
    catch e
        if e isa EOFError
            ""
        else
            rethrow(e)
        end
    end
    if isempty(raster)
        raster = DEFAULT_RASTER
        println("Using default raster: ", raster)
    end
    sim = MagNavSim.run_example(raster)
    summary_lines = build_summary(sim, raster)
    println("\n" * join(summary_lines, "\n"))
    summary_path = write_summary(summary_lines)
    println("Summary saved to: ", summary_path)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
