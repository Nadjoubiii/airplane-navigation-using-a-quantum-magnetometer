# MagNavSim

MagNavSim is a Julia project for simulating magnetic navigation flight data.
It uses a real-world magnetic anomaly map (EMAG2 raster) and a simple quantum magnetometer model to generate noisy measurements along a flight path.

## Quick Start

Run these from the project folder:

```powershell
Set-Location "C:\Users\user\Desktop\MagNav Project"
julia --project=. -e "using Pkg; Pkg.instantiate()"
julia --project=. src/main.jl
```

After the run, check the summary file:

- outputs/last_run_summary.txt

## What This Project Does

1. Loads a single-band magnetic anomaly raster (GeoTIFF or NetCDF).
2. Simulates a straight-line trajectory from start to end coordinates.
3. Samples map anomaly values along the trajectory.
4. Runs a 3-axis magnetometer measurement model with noise and low-pass dynamics.
5. Produces scalar and vector magnetic measurement outputs.
6. Prints and saves a final run summary.

## Repository Layout

```text
MagNav Project/
  Project.toml
  Manifest.toml
  README.md
  EMAG2_V3_UpCont_DataTiff.tif       # Example default real map file
  outputs/
     last_run_summary.txt             # Generated after each main run
  examples/
     simple_run.jl
  src/
     MagNavSim.jl
     quantum_sensor.jl
     emag_downloader.jl
     main.jl
```

## Prerequisites

Install the following before running:

1. Julia 1.8 or newer (recommended: latest stable).
2. Git (if you are cloning the project).
3. Internet access the first time (for package download).

Notes:

- ArchGDAL and GDAL binaries are handled through Julia packages in normal setups.
- Windows PowerShell commands are shown below; they also work similarly in macOS/Linux shells.

## Download The Project

Option A: Clone with Git

```powershell
git clone <your-repo-url> "MagNav Project"
cd "MagNav Project"
```

Option B: Download ZIP from your repository host

1. Download ZIP.
2. Extract it.
3. Open a terminal in the extracted folder.

## Download EMAG2 Data (Single-Band Raster)

Recommended source: NOAA EMAG2 magnetic anomaly grid.

1. Open NOAA EMAG2 data page:
    https://www.ncei.noaa.gov/products/magnetic-anomaly-grid-emag2
2. Download a GeoTIFF tile or global file.
3. Place the file in the project root.

For the current project defaults, use this file name in the project root:

- EMAG2_V3_UpCont_DataTiff.tif

If you use a different name or location, you can still run by entering the full path when prompted.

## First-Time Setup

From the project root:

```powershell
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

This installs all dependencies from Project.toml and Manifest.toml.

## Run Commands

### 1. Main Runner (Recommended)

```powershell
julia --project=. src/main.jl
```

Behavior:

- Prompts for a raster path.
- Press Enter to use the default EMAG2 file in project root.
- Runs the simulation.
- Prints final summary in terminal.
- Writes summary to outputs/last_run_summary.txt.

### 2. Quick Example Runner

```powershell
julia --project=. examples/simple_run.jl
```

Behavior:

- Uses default EMAG2 raster path from the examples script.
- Runs simulation and prints returned data keys.

## Output Explanation

The simulation returns a dictionary with these keys:

1. :lons
    Longitude of each simulated sample.
2. :lats
    Latitude of each simulated sample.
3. :true
    True scalar anomaly sampled from EMAG2 map (nT).
4. :meas
    Scalar measurement from magnetometer model after noise/dynamics.
5. :true_vec
    True 3-axis magnetic vector (derived from scalar anomaly and field direction).
6. :meas_vec
    3-axis measured vector from sensor model.

## Summary File Explanation

Each main run writes:

- outputs/last_run_summary.txt

It contains:

1. Run timestamp (UTC).
2. Raster file used (absolute path).
3. Number of samples.
4. Start and end coordinates.
5. True anomaly min and max.
6. Measured anomaly mean and standard deviation.
7. Whether vector channels were generated.

## Typical End-to-End Workflow

```powershell
Set-Location "C:\Users\user\Desktop\MagNav Project"
julia --project=. -e "using Pkg; Pkg.instantiate()"
julia --project=. src/main.jl
```

Then inspect:

- Terminal summary output.
- outputs/last_run_summary.txt.

## Troubleshooting

1. main.jl exits quickly with no visible plot
    This is normal in non-interactive terminal runs. Use the summary file for verification.

2. Raster not found
    Ensure EMAG2_V3_UpCont_DataTiff.tif exists in project root, or provide a full raster path when prompted.

3. Package installation issues
    Re-run:
    julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.resolve()"

4. Slow first run
    Julia precompilation can take time once; later runs are faster.

## Key Entry Points

- src/main.jl: user-facing runner with prompt, summary printing, and summary file writing.
- src/MagNavSim.jl: simulation engine and map sampling.
- src/quantum_sensor.jl: magnetometer model.
- examples/simple_run.jl: minimal scripted run.
