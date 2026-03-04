# Example usage of the MagNavSim module.
using Pkg
Pkg.activate("..")
Pkg.instantiate()

using MagNavSim

const SAMPLE_RASTER = "path/to/emag_tile.tif" # replace with your EMAG2/EMAG raster

println("Running simple example with raster: ", SAMPLE_RASTER)
sim = MagNavSim.run_example(SAMPLE_RASTER)
println("Simulation finished. Returned keys: ", keys(sim))
