using Test
using MagNavSim
using StaticArrays
using Statistics
using Random
using ArchGDAL

# Small global-style grid: 36 x 18 cells of 10 degrees, value = ix + 100*iy.
function toy_map()
    nx, ny = 36, 18
    data = [Float32(ix + 100 * iy) for ix in 1:nx, iy in 1:ny]
    return MagneticMap(data, -5.0, 90.0, 10.0, 10.0), data
end

@testset "MagneticMap" begin
    m, data = toy_map()
    @test m.global_lon
    @test size(m) == (36, 18)

    # Pixel centres: ix=1 is lon 0, iy=1 is lat 85.
    @test sample_map(m, 0.0, 85.0; interpolation=:nearest) == data[1, 1]
    @test sample_map(m, 20.0, 65.0; interpolation=:nearest) == data[3, 3]
    @test sample_map(m, 20.0, 65.0) ≈ data[3, 3]

    # Longitude wrap: -120 and 240 are the same place.
    @test sample_map(m, -120.0, 25.0) ≈ sample_map(m, 240.0, 25.0)

    # Bilinear midpoint between four cells is their mean.
    @test sample_map(m, 5.0, 80.0) ≈ mean(data[1:2, 1:2])

    # Wrap across the seam between the last and first column.
    @test sample_map(m, 355.0, 85.0) ≈ (data[36, 1] + data[1, 1]) / 2

    @test_throws DomainError sample_map(m, 0.0, 95.0)
    @test_throws ArgumentError sample_map(m, 0.0, 0.0; interpolation=:cubic)
end

@testset "MagneticMap non-global bounds" begin
    m = MagneticMap(ones(10, 10), 0.0, 10.0, 1.0, 1.0)
    @test !m.global_lon
    @test sample_map(m, 5.0, 5.0) ≈ 1.0
    @test_throws DomainError sample_map(m, 20.0, 5.0)
    @test_throws DomainError sample_map(m, 5.0, 20.0)
end

@testset "load_map" begin
    path = joinpath(mktempdir(), "toy.tif")
    nx, ny = 36, 18
    vals = Float32[ix + 100 * iy for ix in 1:nx, iy in 1:ny]
    vals[2, 2] = -3.4028235f38 # nodata marker
    ArchGDAL.create(path; driver=ArchGDAL.getdriver("GTiff"), width=nx, height=ny, nbands=1, dtype=Float32) do ds
        ArchGDAL.setgeotransform!(ds, [-5.0, 10.0, 0.0, 90.0, 0.0, -10.0])
        band = ArchGDAL.getband(ds, 1)
        ArchGDAL.setnodatavalue!(band, -3.4028234663852886e38)
        ArchGDAL.write!(band, vals)
    end
    m = load_map(path)
    @test size(m) == (nx, ny)
    @test m.global_lon
    @test sample_map(m, 20.0, 65.0; interpolation=:nearest) == vals[3, 3]
    @test isnan(sample_map(m, 10.0, 75.0; interpolation=:nearest))
    @test_throws ArgumentError load_map(joinpath(dirname(path), "missing.tif"))
end

@testset "QuantumMagnetometer" begin
    R = SMatrix{3,3,Float64}(1, 0, 0, 0, 1, 0, 0, 0, 1)
    v = SVector{3,Float64}(10.0, -5.0, 2.0)

    # Noise-free, no filtering lag (tau = 0): output equals scale*v + bias.
    s = QuantumMagnetometer(bias=SVector(1.0, 2.0, 3.0), scale=SVector(2.0, 1.0, 1.0),
                            noise_std=SVector(0.0, 0.0, 0.0), tau=0.0)
    _, out = step_measure!(s, v, R, 1.0)
    @test out ≈ SVector(21.0, -3.0, 5.0)

    # Low-pass: step response moves a fraction dt/(tau+dt) toward the input.
    s = QuantumMagnetometer(noise_std=SVector(0.0, 0.0, 0.0), tau=1.0)
    s, out = step_measure!(s, v, R, 1.0)
    @test out ≈ 0.5 .* v
    _, out = step_measure!(s, v, R, 1.0)
    @test out ≈ 0.75 .* v

    # Same seed -> same noise.
    s = QuantumMagnetometer(noise_std=SVector(3.0, 3.0, 3.0), tau=0.0)
    _, a = step_measure!(s, v, R, 1.0; rng=MersenneTwister(7))
    _, b = step_measure!(s, v, R, 1.0; rng=MersenneTwister(7))
    @test a == b

    # Scalar anomaly -> unit field vector has the right direction and magnitude.
    u = anomaly_scalar_to_vector(1.0; decl=0.0, incl=60.0, base_strength=1.0)
    @test sqrt(sum(abs2, u)) ≈ 1.0
    @test u[3] ≈ sin(deg2rad(60))
end

@testset "simulate_flight" begin
    m, _ = toy_map()
    start, stop = (-120.0, 20.0), (-100.0, 40.0)

    sim = simulate_flight(m, start, stop; nsteps=50, noise_std=0.0, tau=0.0, seed=1)
    @test length(sim[:meas]) == 50
    @test sim[:lons][1] == -120.0 && sim[:lats][end] == 40.0
    @test sim[:time][2] - sim[:time][1] == 1.0
    # Zero noise and no lag: measurement equals the true anomaly.
    @test sim[:meas] ≈ sim[:true]
    # The truth must actually vary along the track (regression for the old constant-value bug).
    @test length(unique(sim[:true])) > 1

    a = simulate_flight(m, start, stop; nsteps=50, noise_std=5.0, seed=3)
    b = simulate_flight(m, start, stop; nsteps=50, noise_std=5.0, seed=3)
    c = simulate_flight(m, start, stop; nsteps=50, noise_std=5.0, seed=4)
    @test a[:meas] == b[:meas]
    @test a[:meas] != c[:meas]
    @test a[:true] == c[:true]

    @test_throws ArgumentError simulate_flight(m, start, stop; nsteps=1)
    @test_throws ArgumentError simulate_flight(m, start, stop; dt=0.0)
    @test_throws DomainError simulate_flight(m, (0.0, 0.0), (0.0, 120.0))

    nodata_map = MagneticMap(fill(NaN32, 36, 18), -5.0, 90.0, 10.0, 10.0)
    @test_throws ErrorException simulate_flight(nodata_map, start, stop)
end

@testset "synthetic flight" begin
    sim = simulate_synthetic_flight((0.0, 0.0), (1.0, 1.0); nsteps=20, noise_std=2.0, seed=1)
    @test length(sim[:true]) == 20
    @test sim[:meas] != sim[:true]
end

@testset "output" begin
    m, _ = toy_map()
    sim = simulate_flight(m, (-120.0, 20.0), (-100.0, 40.0); nsteps=10, seed=1)
    dir = mktempdir()

    lines = summarize(sim; raster="toy.tif")
    @test any(startswith("Samples: 10"), lines)
    @test isfile(write_summary(joinpath(dir, "sub", "s.txt"), lines))

    csv = write_csv(joinpath(dir, "f.csv"), sim)
    rows = readlines(csv)
    @test length(rows) == 11
    @test rows[1] == "time_s,lon,lat,true_nT,meas_nT,true_x,true_y,true_z,meas_x,meas_y,meas_z"
    @test length(split(rows[2], ',')) == 11

    png = joinpath(dir, "p.png")
    plot_results(sim; path=png)
    @test isfile(png)
end

@testset "CLI" begin
    o = MagNavSim.parse_cli(String[])
    @test o.steps == 300 && o.plot && !o.synthetic && o.seed === nothing

    o = MagNavSim.parse_cli(["--steps", "50", "--noise=1.5", "--start", "-10,20", "--end=30,40", "--seed", "9", "--no-plot", "--synthetic"])
    @test o.steps == 50 && o.noise == 1.5 && o.start == (-10.0, 20.0) && o.stop == (30.0, 40.0)
    @test o.seed == 9 && !o.plot && o.synthetic

    @test MagNavSim.parse_cli(["--help"]).help
    @test_throws ArgumentError MagNavSim.parse_cli(["--bogus"])
    @test_throws ArgumentError MagNavSim.parse_cli(["--steps"])
    @test_throws ArgumentError MagNavSim.parse_cli(["--steps", "abc"])
    @test_throws ArgumentError MagNavSim.parse_cli(["--start", "1"])

    dir = mktempdir()
    code = redirect_stdout(devnull) do
        MagNavSim.main(["--synthetic", "--steps", "20", "--seed", "1", "--outdir", dir])
    end
    @test code == 0
    @test all(isfile, joinpath.(dir, ["last_run_summary.txt", "flight.csv", "flight.png"]))

    redirect_stderr(devnull) do
        @test MagNavSim.main(["--nonsense"]) == 2
    end
end
