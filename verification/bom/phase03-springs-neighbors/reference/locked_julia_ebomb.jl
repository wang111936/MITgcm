using SargassumBOMB

spring = BOMBSpring(2.0, 1.0)
value = spring.k(2.3)
value_hex = uppercase(string(reinterpret(UInt64, value), base = 16, pad = 16))

println("fixture\tA_per_s2\tL_km\td_km\tdelta_m\tstiffness_per_s2\tstiffness_hex")
println("ebomb-200m\t2.0\t1.0\t2.3\t200.0\t", repr(value), '\t', value_hex)
