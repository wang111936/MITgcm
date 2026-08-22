using Dates
using Test
using SargassumBOMB

@testset "MITGCM-BOM locked Julia reference smoke" begin
    @test Base.pkgversion(SargassumBOMB) == v"0.7.14"

    eqr = EquirectangularReference(lon0 = -75.0, lat0 = 10.0)
    lonlat = [-80.0 -75.0 -60.0; 5.0 10.0 20.0]
    xy = sph2xy(lonlat; eqr = eqr)
    round_trip = xy2sph(xy; eqr = eqr)
    @test isapprox(round_trip, lonlat; atol = 1.0e-12, rtol = 0.0)

    instant = DateTime(2024, 2, 29, 12)
    @test time2datetime(datetime2time(instant)) == instant
    @test ymwplusweek((2018, 10, 2), 12) == (2019, 1, 2)

    clumps = [1.0 3.0; 2.0 4.0]
    @test com(clumps) == [2.0, 3.0]
    @test collect(vec2range([0.0, 0.5, 1.0])) == [0.0, 0.5, 1.0]

    @test γ_sphere(100.0; eqr = eqr, geometry = false) == 1.0
    @test τ_sphere(100.0; eqr = eqr, geometry = false) == 0.0
end

println("P0.5 JULIA SMOKE PASS")
println("julia_version=", VERSION)
println("sargassumbomb_version=", Base.pkgversion(SargassumBOMB))
