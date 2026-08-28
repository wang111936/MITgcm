using SargassumBOMB

function emit(name, xy, k)
    ics = InitialConditions(tspan = (0.0, 1.0), ics = xy)
    value = SargassumBOMB.ΔL(ics; k = k)
    println(name, '\t', k, '\t', repr(value))
end

println("fixture\tjulia_k_including_self\tliteral_delta_l")
emit("line-even", [0.0 2.0 5.0 9.0; 0.0 0.0 0.0 0.0], 2)
emit("unit-square", [0.0 1.0 0.0 1.0; 0.0 0.0 1.0 1.0], 2)
