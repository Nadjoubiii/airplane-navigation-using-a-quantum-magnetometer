"""
Result handling: plotting, summaries, and CSV export.
"""

"""
    plot_results(sim; path=nothing)

Plot true vs measured anomaly along the track and the measurement error
underneath. Saves the figure to `path` when given. Returns the plot.
"""
function plot_results(sim::AbstractDict; path::Union{Nothing,AbstractString}=nothing)
    p1 = plot(sim[:lons], sim[:true]; label="True anomaly", ylabel="Anomaly (nT)", legend=:best)
    plot!(p1, sim[:lons], sim[:meas]; label="Measured (noisy)")
    p2 = plot(sim[:lons], sim[:meas] .- sim[:true]; label="Measured - true", xlabel="Longitude (deg)", ylabel="Error (nT)", color=:red)
    plt = plot(p1, p2; layout=(2, 1), size=(800, 600))
    if path !== nothing
        mkpath(dirname(abspath(path)))
        savefig(plt, path)
    end
    return plt
end

"""
    summarize(sim; raster=nothing) -> Vector{String}

Human-readable run summary (one line per entry).
"""
function summarize(sim::AbstractDict; raster::Union{Nothing,AbstractString}=nothing)
    err = sim[:meas] .- sim[:true]
    lines = String[
        "MagNavSim Run Summary",
        "Timestamp (UTC): " * string(Dates.now(Dates.UTC)),
        "Raster: " * (raster === nothing ? "none (synthetic field)" : abspath(raster)),
        "Samples: " * string(length(sim[:meas])),
        "Start (lon, lat): (" * string(sim[:lons][1]) * ", " * string(sim[:lats][1]) * ")",
        "End (lon, lat): (" * string(sim[:lons][end]) * ", " * string(sim[:lats][end]) * ")",
        "True anomaly min/max (nT): " * string(minimum(sim[:true])) * " / " * string(maximum(sim[:true])),
        "Measured anomaly mean/std (nT): " * string(mean(sim[:meas])) * " / " * string(std(sim[:meas])),
        "Measurement error mean/RMS (nT): " * string(mean(err)) * " / " * string(sqrt(mean(abs2, err))),
        "Vector channels: true_vec=" * string(haskey(sim, :true_vec)) * ", meas_vec=" * string(haskey(sim, :meas_vec)),
    ]
    return lines
end

"""
    write_summary(path, lines) -> path

Write summary `lines` to `path`, creating parent directories as needed.
"""
function write_summary(path::AbstractString, lines::AbstractVector{<:AbstractString})
    mkpath(dirname(abspath(path)))
    open(io -> write(io, join(lines, "\n") * "\n"), path, "w")
    return path
end

"""
    write_csv(path, sim) -> path

Export a simulation result as CSV. Columns: `lon, lat, true_nT, meas_nT`, plus
`time_s` and the `true_{x,y,z}` / `meas_{x,y,z}` vector components when present.
"""
function write_csv(path::AbstractString, sim::AbstractDict)
    mkpath(dirname(abspath(path)))
    n = length(sim[:meas])
    has_vec = haskey(sim, :true_vec) && haskey(sim, :meas_vec)
    has_time = haskey(sim, :time)
    open(path, "w") do io
        cols = String[]
        has_time && push!(cols, "time_s")
        append!(cols, ["lon", "lat", "true_nT", "meas_nT"])
        has_vec && append!(cols, ["true_x", "true_y", "true_z", "meas_x", "meas_y", "meas_z"])
        println(io, join(cols, ","))
        for i in 1:n
            row = Any[]
            has_time && push!(row, sim[:time][i])
            append!(row, [sim[:lons][i], sim[:lats][i], sim[:true][i], sim[:meas][i]])
            has_vec && append!(row, [sim[:true_vec][i]..., sim[:meas_vec][i]...])
            println(io, join(row, ","))
        end
    end
    return path
end
