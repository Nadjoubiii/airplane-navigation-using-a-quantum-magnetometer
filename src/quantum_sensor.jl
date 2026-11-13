module QuantumSensor

using LinearAlgebra
using Random
using Distributions
using StaticArrays

export QuantumMagnetometer, anomaly_scalar_to_vector, step_measure!

"""
    QuantumMagnetometer(; bias, scale, noise_std, tau)

Simple 3-axis quantum magnetometer model with per-axis `bias` and `scale`
factor, white Gaussian noise (`noise_std`, nT per axis), and a first-order
low-pass response with time constant `tau` (s). `state` holds the previous
filtered output; the struct is immutable, so [`step_measure!`](@ref) returns an
updated copy.
"""
struct QuantumMagnetometer
    bias::SVector{3,Float64}
    scale::SVector{3,Float64}
    noise_std::SVector{3,Float64}
    tau::Float64 # time constant for low-pass
    state::SVector{3,Float64} # previous filtered measurement
end

QuantumMagnetometer(;bias=SVector{3,Float64}(0.0,0.0,0.0), scale=SVector{3,Float64}(1.0,1.0,1.0), noise_std=SVector{3,Float64}(1.0,1.0,1.0), tau=0.01, state=SVector{3,Float64}(0.0,0.0,0.0)) =
    QuantumMagnetometer(bias, scale, noise_std, tau, state)

"""
    anomaly_scalar_to_vector(anom; decl=0.0, incl=60.0, base_strength=50000.0)

Convert a scalar total-intensity anomaly `anom` (nT) into a vector along the
local main-field direction (`decl`, `incl` in degrees, x = north, y = east,
z = down), divided by `base_strength`. With `base_strength = 1.0` the result
is the anomaly vector in nT.
"""
function anomaly_scalar_to_vector(anom::Float64; decl::Float64=0.0, incl::Float64=60.0, base_strength::Float64=50000.0)
    d = deg2rad(decl)
    i = deg2rad(incl)
    ux = cos(i)*cos(d)
    uy = cos(i)*sin(d)
    uz = sin(i)
    # Treat anomaly scalar as perturbation along main field direction
    return anom * SVector{3,Float64}(ux, uy, uz) ./ base_strength
end

"""
    step_measure!(sens, true_vector, R, dt; rng=Random.default_rng()) -> (new_sensor, measurement)

Advance the sensor by `dt` seconds. `true_vector` is the field in nT, `R` rotates
body -> sensor frame. Applies scale, bias, white noise drawn from `rng`, then the
low-pass filter. Returns the updated sensor and the filtered measurement.
"""
function step_measure!(sens::QuantumMagnetometer, true_vector::SVector{3,Float64}, R::SMatrix{3,3,Float64}, dt::Float64; rng::AbstractRNG=Random.default_rng())
    # rotate true vector into sensor frame
    v_sensor = R * true_vector
    # apply scale and bias
    v_scaled = sens.scale .* v_sensor .+ sens.bias
    # add white Gaussian noise
    noise = sens.noise_std .* SVector{3,Float64}(randn(rng), randn(rng), randn(rng))
    v_noisy = v_scaled .+ noise
    # discrete first-order low-pass filter: x_new = x_old + alpha*(v_noisy - x_old)
    alpha = dt / (sens.tau + dt)
    new_state = sens.state .+ alpha .* (v_noisy .- sens.state)
    # update state in-place by returning a new sensor with updated state
    return QuantumMagnetometer(sens.bias, sens.scale, sens.noise_std, sens.tau, new_state), new_state
end

end # module
