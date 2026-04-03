# Example usage of the MagNavSim module.
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

using MagNavSim

const SAMPLE_RASTER = joinpath(@__DIR__, "..", "EMAG2_V3_UpCont_DataTiff.tif")

println("Running simple example with raster: ", SAMPLE_RASTER)
sim = MagNavSim.run_example(SAMPLE_RASTER)
println("Simulation finished. Returned keys: ", keys(sim))
