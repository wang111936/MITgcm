#!/usr/bin/env julia

using Printf
using SHA
using TOML

length(ARGS) == 6 || error(
    "usage: generate_p52_reference.jl OUTPUT.csv B16_GENERATOR PHASE02 SOURCE PROJECT MANIFEST")

output_file, generator_file, phase_dir, source_root, project_file, manifest_file = ARGS
include(generator_file)

VERSION == LOCKED_JULIA || error("wrong Julia version: $(VERSION)")
readchomp(`git -C $source_root rev-parse HEAD`) == LOCKED_COMMIT ||
    error("wrong SargassumBOMB commit")
sha256_file(joinpath(source_root, "src", "physics.jl")) == LOCKED_PHYSICS_SHA ||
    error("physics.jl checksum mismatch")
sha256_file(project_file) == LOCKED_PROJECT_SHA || error("Project checksum mismatch")
sha256_file(manifest_file) == LOCKED_MANIFEST_SHA || error("Manifest checksum mismatch")

coeff = load_fields(joinpath(phase_dir, "input_fields_v1.csv"))
particles = load_particles(joinpath(phase_dir, "input_particles_v1.csv"))
params = TOML.parsefile(joinpath(phase_dir, "input_parameters_v1.toml"))
params["schema"] == "MITGCM-BOM-B16-v1" || error("wrong parameter schema")
params["bom"]["equation_mode"] == "JULIA" || error("wrong equation mode")

names = (
    "vbase_e", "vbase_n", "vs_e", "vs_n", "vw_e", "vw_n",
    "v_e", "v_n", "u_e", "u_n", "dv_e", "dv_n", "du_e", "du_n",
    "omega", "f_cori", "tau_sphere", "c_v", "c_u",
    "rot_v_e", "rot_v_n", "rot_u_e", "rot_u_n",
    "inert_e", "inert_n", "drift_e", "drift_n",
)
t0 = params["t_start_s"]
tend = params["t_end_s"]
dt = params["fixed_dt_s"]
nsteps = round(Int, (tend - t0) / dt)
states = [(id, x, y) for (id, x, y) in particles]
states_ref = Ref(states)

mkpath(dirname(output_file))
open(output_file, "w") do io
    println(io, join((
        "time_index", "particle_id", "time_s", "x_m", "y_m",
        "rhs_x_m_s", "rhs_y_m_s", names...), ','))
    for istep in 0:nsteps
        time = t0 + istep * dt
        for (id, x, y) in states_ref[]
            rhsx, rhsy, diag = julia_rhs(coeff, params, x, y, time)
            @printf(io, "%d,%d,%.17e,%.17e,%.17e,%.17e,%.17e",
                    istep, id, time, x, y, rhsx, rhsy)
            for value in diag
                @printf(io, ",%.17e", value)
            end
            println(io)
        end
        istep == nsteps && break
        states_ref[] = [
            let updated = rk4_step(coeff, params, x, y, time, dt)
                (id, updated[1], updated[2])
            end
            for (id, x, y) in states_ref[]
        ]
    end
end

println("P5-J01 JULIA COMPONENT REFERENCE PASS rows=$((nsteps + 1) * length(particles))")
