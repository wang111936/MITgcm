using Test
using SargassumBOMB

function rk4_classic(rhs, q0, dt)
    k1 = rhs(q0)
    k2 = rhs(q0 .+ (0.5dt) .* k1)
    k3 = rhs(q0 .+ (0.5dt) .* k2)
    k4 = rhs(q0 .+ dt .* k3)
    return q0 .+ (dt / 6.0) .* (k1 .+ 2.0 .* k2 .+ 2.0 .* k3 .+ k4)
end

@testset "MITGCM-BOM P1-I06 affine RK4 oracle" begin
    @test Base.pkgversion(SargassumBOMB) == v"0.7.14"

    time_scale = 1200.0
    length_x = 1000.0
    length_y = 800.0
    x_ref = 0.0
    y_ref = 0.0
    u0 = 0.04length_x / time_scale
    ax = 0.20 / time_scale
    v0 = 0.03length_y / time_scale
    ay = -0.15 / time_scale
    rhs(q) = (u0 + ax * (q[1] - x_ref),
              v0 + ay * (q[2] - y_ref))

    exact = (x_ref + (u0 / ax) * expm1(ax * time_scale),
             y_ref + (v0 / ay) * expm1(ay * time_scale))
    step_counts = (4, 8, 16, 32)
    errors = map(step_counts) do nsteps
        q = (x_ref, y_ref)
        dt = time_scale / nsteps
        for _ in 1:nsteps
            q = rk4_classic(rhs, q, dt)
        end
        hypot((q[1] - exact[1]) / length_x,
              (q[2] - exact[2]) / length_y)
    end
    orders = log2.(errors[1:end-1] ./ errors[2:end])

    @test all(isfinite, errors)
    @test all(>(0.0), errors)
    @test all((3.5 .<= orders[2:3]) .& (orders[2:3] .<= 4.5))
end

println("P1-I06 JULIA RK4 PASS")
println("julia_version=", VERSION)
println("sargassumbomb_version=", Base.pkgversion(SargassumBOMB))
