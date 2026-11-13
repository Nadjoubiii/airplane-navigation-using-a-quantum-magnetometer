# Minimal run: default San Francisco track over the EMAG2 raster.
# Usage: julia --project=. examples/simple_run.jl
using MagNavSim

const SAMPLE_RASTER = joinpath(@__DIR__, "..", "EMAG2_V3_UpCont_DataTiff.tif")
const OUT_DIR = joinpath(@__DIR__, "..", "outputs")

println("Running simple example with raster: ", SAMPLE_RASTER)
sim = MagNavSim.run_example(SAMPLE_RASTER; seed=1, plot_path=joinpath(OUT_DIR, "simple_run.png"))
println("Simulation finished. Returned keys: ", sort!(collect(keys(sim))))
println("Plot written to ", joinpath(OUT_DIR, "simple_run.png"))
