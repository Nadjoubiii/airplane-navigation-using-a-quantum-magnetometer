module QuantumSensor

using LinearAlgebra
using Random
using Distributions

export QuantumMagnetometer, anomaly_scalar_to_vector, step_measure!

"Simple quantum magnetometer model (3-axis) with bias, scale, noise, and first-order low-pass dynamics." 
struct QuantumMagnetometer
    bias::SVector{3,Float64}
    scale::SVector{3,Float64}
    noise_std::SVector{3,Float64}
    tau::Float64 # time constant for low-pass
    state::SVector{3,Float64} # previous filtered measurement
end

QuantumMagnetometer(;bias=zero(SVector{3,Float64}(0.0,0.0,0.0)), scale=one(SVector{3,Float64}(1.0,1.0,1.0)), noise_std=one(SVector{3,Float64}(1.0,1.0,1.0)), tau=0.01) =
    QuantumMagnetometer(bias, scale, noise_std, tau, SVector{3,Float64}(0.0,0.0,0.0))

"Convert a scalar total-intensity anomaly (nT) to a vector perturbation using local field direction.
decl and incl are degrees. base_strength is the local main field magnitude (nT)." 
function anomaly_scalar_to_vector(anom::Float64; decl::Float64=0.0, incl::Float64=60.0, base_strength::Float64=50000.0)
    d = deg2rad(decl)
    i = deg2rad(incl)
    ux = cos(i)*cos(d)
    uy = cos(i)*sin(d)
    uz = sin(i)
    # Treat anomaly scalar as perturbation along main field direction
    return anom * SVector{3,Float64}(ux, uy, uz) ./ base_strength
end

"Step the sensor: given true_vector (3,) in same units (nT), body_to_sensor rotation R (3x3), and dt.
Returns noisy, biased, filtered measurement.
`R` rotates vectors from body -> sensor frame.
"""
function step_measure!(sens::QuantumMagnetometer, true_vector::SVector{3,Float64}, R::SMatrix{3,3,Float64}, dt::Float64)
    # rotate true vector into sensor frame
    v_sensor = R * true_vector
    # apply scale and bias
    v_scaled = sens.scale .* v_sensor .+ sens.bias
    # add white Gaussian noise
    rng = MersenneTwister()
    noise = SVector{3,Float64}(rand(rng, Normal(0.0, sens.noise_std[1])), rand(rng, Normal(0.0, sens.noise_std[2])), rand(rng, Normal(0.0, sens.noise_std[3])))
    v_noisy = v_scaled .+ noise
    # first-order low-pass filter: x_new = x_old + (dt/tau)*(v_noisy - x_old)
    alpha = dt / (sens.tau + dt)
    new_state = sens.state .+ alpha .* (v_noisy .- sens.state)
    # update state in-place by returning a new sensor with updated state
    return QuantumMagnetometer(sens.bias, sens.scale, sens.noise_std, sens.tau, new_state), new_state
end

end # module
