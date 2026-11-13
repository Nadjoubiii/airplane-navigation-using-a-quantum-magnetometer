"""
    MagNavSim

Simulation platform for magnetic-anomaly navigation with a quantum
magnetometer. See the README for an overview and `docs/` for the model and API.

Typical use:

```julia
using MagNavSim
sim = simulate_flight("EMAG2_V3_UpCont_DataTiff.tif", (-122.5, 37.6), (-121.5, 38.6); seed=1)
```
"""
module MagNavSim

using ArchGDAL
using Dates
using Distributions
using LinearAlgebra
using Plots
using Random
using StaticArrays
using Statistics

include("emag_downloader.jl")
include("quantum_sensor.jl")

using .EmagDownloader
using .QuantumSensor

include("magnetic_map.jl")
include("simulation.jl")
include("output.jl")
include("cli.jl")

export MagneticMap, load_map, sample_map, bounds,
       simulate_flight, simulate_synthetic_flight, run_example,
       plot_results, summarize, write_summary, write_csv,
       download_emag, preprocess_emag,
       QuantumMagnetometer, anomaly_scalar_to_vector, step_measure!

end # module
