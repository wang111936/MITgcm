using Test
using SargassumBOMB

function rk2_midpoint(rhs, q0, dt)
    k1 = rhs(q0)
    qmid = q0 .+ (0.5dt) .* k1
    k2 = rhs(qmid)
    return q0 .+ dt .* k2
end

@testset "MITGCM-BOM P1-I05 affine RK2 oracle" begin
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
            q = rk2_midpoint(rhs, q, dt)
        end
        hypot((q[1] - exact[1]) / length_x,
              (q[2] - exact[2]) / length_y)
    end
    orders = log2.(errors[1:end-1] ./ errors[2:end])

    @test all(isfinite, errors)
    @test all(>(0.0), errors)
    @test all((1.8 .<= orders[2:3]) .& (orders[2:3] .<= 2.2))
end

println("P1-I05 JULIA RK2 PASS")
println("julia_version=", VERSION)
println("sargassumbomb_version=", Base.pkgversion(SargassumBOMB))
