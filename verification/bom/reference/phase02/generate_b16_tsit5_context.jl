#!/usr/bin/env julia

using OrdinaryDiffEqTsit5

include(joinpath(@__DIR__, "generate_b16_golden.jl"))

const CONTEXT_SOLVER = "Tsit5"
const CONTEXT_ABSTOL = 1.0e-12
const CONTEXT_RELTOL = 1.0e-12

function validate_context_lock(source_root, project_file, manifest_file)
    VERSION == LOCKED_JULIA || error("wrong Julia version: $(VERSION)")
    source_head = readchomp(`git -C $source_root rev-parse HEAD`)
    source_head == LOCKED_COMMIT || error("wrong SargassumBOMB commit")
    physics_file = joinpath(source_root, "src", "physics.jl")
    sha256_file(physics_file) == LOCKED_PHYSICS_SHA ||
        error("physics.jl checksum mismatch")
    sha256_file(project_file) == LOCKED_PROJECT_SHA ||
        error("Project checksum mismatch")
    sha256_file(manifest_file) == LOCKED_MANIFEST_SHA ||
        error("Manifest checksum mismatch")
end

function tsit5_trajectory(coeff, params, particle)
    id, x0, y0 = particle
    t0 = params["t_start_s"]
    tend = params["t_end_s"]
    save_dt = params["fixed_dt_s"]
    function rhs!(du, state, unused, time)
        du[1], du[2], _ = julia_rhs(
            coeff, params, state[1], state[2], time)
        return nothing
    end
    problem = ODEProblem(rhs!, [x0, y0], (t0, tend))
    solution = solve(problem, Tsit5();
                     abstol=CONTEXT_ABSTOL,
                     reltol=CONTEXT_RELTOL,
                     saveat=t0:save_dt:tend)
    length(solution.t) == round(Int, (tend-t0)/save_dt)+1 ||
        error("unexpected Tsit5 save count for particle $id")
    return solution
end

function write_tsit5_context(path, coeff, params, particles)
    open(path, "w") do io
        println(io,
                "particle_id,time_s,x_m,y_m,path_m,solver,abstol,reltol,gating")
        for particle in particles
            id = particle[1]
            solution = tsit5_trajectory(coeff, params, particle)
            path_length = 0.0
            previous = solution.u[1]
            for (index, time) in enumerate(solution.t)
                state = solution.u[index]
                if index > 1
                    path_length += hypot(
                        state[1]-previous[1], state[2]-previous[2])
                end
                @printf(io,
                        "%d,%.17e,%.17e,%.17e,%.17e,%s,%.17e,%.17e,false\n",
                        id, time, state[1], state[2], path_length,
                        CONTEXT_SOLVER, CONTEXT_ABSTOL, CONTEXT_RELTOL)
                previous = state
            end
        end
    end
end

function context_main()
    length(ARGS) == 5 || error(
        "usage: generate_b16_tsit5_context.jl OUTPUT PHASE02 SOURCE PROJECT MANIFEST")
    output_file, phase_dir, source_root, project_file, manifest_file = ARGS
    validate_context_lock(source_root, project_file, manifest_file)
    coeff = load_fields(joinpath(phase_dir, "input_fields_v1.csv"))
    particles = load_particles(joinpath(phase_dir, "input_particles_v1.csv"))
    params = TOML.parsefile(joinpath(phase_dir, "input_parameters_v1.toml"))
    params["schema"] == "MITGCM-BOM-B16-v1" ||
        error("wrong parameter schema")
    params["bom"]["equation_mode"] == "JULIA" ||
        error("wrong equation mode")
    mkpath(dirname(output_file))
    write_tsit5_context(output_file, coeff, params, particles)
end

context_main()
