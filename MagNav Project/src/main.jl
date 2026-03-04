using Pkg
Pkg.activate(@__DIR__ * "/..")
Pkg.instantiate()

using MagNavSim

function main()
    println("MagNavSim runner")
    println("Please provide a path to a single-band EMAG/ANOMALY raster (GeoTIFF/NetCDF).")
    raster = readline()
    if isempty(raster)
        println("No path provided; exiting.")
        return
    end
    MagNavSim.run_example(raster)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
