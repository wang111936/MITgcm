using Test
using SargassumBOMB

@testset "MITGCM-BOM Phase-1 Leeway RHS algebra" begin
    @test Base.pkgversion(SargassumBOMB) == v"0.7.14"

    water = (0.2, -0.4)
    wind = (2.5, -1.25)
    coefficient = 0.02
    drift = water .+ coefficient .* wind

    @test all(isapprox.(drift, (0.25, -0.425); rtol = 0.0,
                        atol = eps(Float64)))
    @test all(isapprox.(drift .* 86.4,
                        (water .* 86.4) .+
                        coefficient .* (wind .* 86.4);
                        rtol = 8eps(Float64), atol = 0.0))
    @test 1.0 * 86_400.0 / 1_000.0 == 86.4
end

println("P1-I04 JULIA RHS PASS")
println("julia_version=", VERSION)
println("sargassumbomb_version=", Base.pkgversion(SargassumBOMB))
