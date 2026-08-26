#!/usr/bin/env julia

using Printf
using SHA
using TOML

const LOCKED_JULIA = v"1.10.12"
const LOCKED_COMMIT = "156557359185e4413ce82829f3ed26a4eb8c6283"
const LOCKED_PHYSICS_SHA = "1acef9ed3c8d13646c95799565387a4add76e839827cea1c0e745ced73f1885d"
const LOCKED_PROJECT_SHA = "12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d"
const LOCKED_MANIFEST_SHA = "86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695"

sha256_file(path) = bytes2hex(sha256(read(path)))

function csv_rows(path)
    lines = readlines(path)
    length(lines) >= 2 || error("empty CSV: $path")
    return [split(strip(line), ',') for line in lines[2:end] if !isempty(strip(line))]
end

function load_fields(path)
    coeff = zeros(Float64, 3, 2, 4)
    seen = falses(3, 2)
    for row in csv_rows(path)
        length(row) == 6 || error("invalid field row")
        source = parse(Int, row[1])
        component = parse(Int, row[2])
        1 <= source <= 3 || error("invalid source code")
        1 <= component <= 2 || error("invalid component code")
        !seen[source, component] || error("duplicate source/component")
        coeff[source, component, :] .= parse.(Float64, row[3:6])
        seen[source, component] = true
    end
    all(seen) || error("incomplete field coefficient matrix")
    return coeff
end

function load_particles(path)
    particles = Tuple{Int64,Float64,Float64}[]
    for row in csv_rows(path)
        length(row) == 3 || error("invalid particle row")
        push!(particles, (parse(Int64, row[1]),
                          parse(Float64, row[2]),
                          parse(Float64, row[3])))
    end
    length(particles) == 3 || error("B16 requires exactly three particles")
    length(unique(first.(particles))) == 3 || error("duplicate particle ID")
    return particles
end

function source_value(coeff, source, x, y, t)
    east = coeff[source, 1, 1] + coeff[source, 1, 2]*x +
           coeff[source, 1, 3]*y + coeff[source, 1, 4]*t
    north = coeff[source, 2, 1] + coeff[source, 2, 2]*x +
            coeff[source, 2, 3]*y + coeff[source, 2, 4]*t
    return east, north
end

function source_self(coeff, source, x, y, t)
    east, north = source_value(coeff, source, x, y, t)
    deast = coeff[source, 1, 4] + east*coeff[source, 1, 2] +
            north*coeff[source, 1, 3]
    dnorth = coeff[source, 2, 4] + east*coeff[source, 2, 2] +
             north*coeff[source, 2, 3]
    return deast, dnorth
end

function julia_rhs(coeff, params, x, y, t)
    alpha = params["bom"]["alpha"]
    tau = params["bom"]["tau_days"]*86400.0
    rvalue = params["bom"]["r"]
    sigma = params["bom"]["sigma"]
    fcori = params["bom"]["f_per_day"]/86400.0
    tau_sphere = params["bom"]["tau_sphere_m_inv"]

    base_e, base_n = source_value(coeff, 1, x, y, t)
    stokes_e, stokes_n = source_value(coeff, 2, x, y, t)
    wind_e, wind_n = source_value(coeff, 3, x, y, t)
    dbase_e, dbase_n = source_self(coeff, 1, x, y, t)
    dstokes_e, dstokes_n = source_self(coeff, 2, x, y, t)
    dwind_e, dwind_n = source_self(coeff, 3, x, y, t)

    v_e = base_e + sigma*stokes_e
    v_n = base_n + sigma*stokes_n
    dv_e = dbase_e + sigma*dstokes_e
    dv_n = dbase_n + sigma*dstokes_n
    u_e = (1.0-alpha)*v_e + alpha*wind_e
    u_n = (1.0-alpha)*v_n + alpha*wind_n
    du_e = (1.0-alpha)*dv_e + alpha*dwind_e
    du_n = (1.0-alpha)*dv_n + alpha*dwind_n
    omega = coeff[1, 2, 2] - coeff[1, 1, 3]
    c_v = fcori + omega/3.0
    c_u = fcori + tau_sphere*u_e + rvalue*omega/3.0
    rot_v_e = -(rvalue*c_v)*v_n
    rot_v_n =  (rvalue*c_v)*v_e
    rot_u_e = c_u*u_n
    rot_u_n = -c_u*u_e
    inert_e = rvalue*dv_e + rot_v_e - du_e + rot_u_e
    inert_n = rvalue*dv_n + rot_v_n - du_n + rot_u_n
    drift_e = u_e + tau*inert_e
    drift_n = u_n + tau*inert_n
    diag = (base_e, base_n, stokes_e, stokes_n, wind_e, wind_n,
            v_e, v_n, u_e, u_n, dv_e, dv_n, du_e, du_n,
            omega, fcori, tau_sphere, c_v, c_u,
            rot_v_e, rot_v_n, rot_u_e, rot_u_n,
            inert_e, inert_n, drift_e, drift_n)
    return drift_e, drift_n, diag
end

function rk2_step(coeff, params, x, y, t, dt)
    k1x, k1y, _ = julia_rhs(coeff, params, x, y, t)
    k2x, k2y, _ = julia_rhs(coeff, params,
                             x+0.5*dt*k1x, y+0.5*dt*k1y,
                             t+0.5*dt)
    return x+dt*k2x, y+dt*k2y
end

function rk4_step(coeff, params, x, y, t, dt)
    k1x, k1y, _ = julia_rhs(coeff, params, x, y, t)
    k2x, k2y, _ = julia_rhs(coeff, params,
                             x+0.5*dt*k1x, y+0.5*dt*k1y,
                             t+0.5*dt)
    k3x, k3y, _ = julia_rhs(coeff, params,
                             x+0.5*dt*k2x, y+0.5*dt*k2y,
                             t+0.5*dt)
    k4x, k4y, _ = julia_rhs(coeff, params,
                             x+dt*k3x, y+dt*k3y, t+dt)
    return x + dt*(k1x+2.0*k2x+2.0*k3x+k4x)/6.0,
           y + dt*(k1y+2.0*k2y+2.0*k3y+k4y)/6.0
end

function write_rhs(path, coeff, params, particles)
    names = ("vbase_e", "vbase_n", "vs_e", "vs_n", "vw_e", "vw_n",
             "v_e", "v_n", "u_e", "u_n", "dv_e", "dv_n", "du_e", "du_n",
             "omega", "f_cori", "tau_sphere", "c_v", "c_u",
             "rot_v_e", "rot_v_n", "rot_u_e", "rot_u_n",
             "inert_e", "inert_n", "drift_e", "drift_n")
    open(path, "w") do io
        println(io, join(("particle_id", "time_s", "x_m", "y_m",
                          "rhs_x_m_s", "rhs_y_m_s", names...), ','))
        for time in (0.0, 43200.0, 86400.0), (id, x, y) in particles
            rhsx, rhsy, diag = julia_rhs(coeff, params, x, y, time)
            @printf(io, "%d,%.17e,%.17e,%.17e,%.17e,%.17e", id, time, x, y, rhsx, rhsy)
            for value in diag
                @printf(io, ",%.17e", value)
            end
            println(io)
        end
    end
end

function write_trajectory(path, stepper, coeff, params, particles)
    t0 = params["t_start_s"]
    tend = params["t_end_s"]
    dt = params["fixed_dt_s"]
    nsteps = round(Int, (tend-t0)/dt)
    states = [(id, x, y, 0.0) for (id, x, y) in particles]
    open(path, "w") do io
        println(io, "particle_id,time_s,x_m,y_m,path_m")
        for istep in 0:nsteps
            time = t0 + istep*dt
            for (id, x, y, path_length) in states
                @printf(io, "%d,%.17e,%.17e,%.17e,%.17e\n",
                        id, time, x, y, path_length)
            end
            istep == nsteps && break
            updated = Tuple{Int64,Float64,Float64,Float64}[]
            for (id, x, y, path_length) in states
                xnew, ynew = stepper(coeff, params, x, y, time, dt)
                path_new = path_length + hypot(xnew-x, ynew-y)
                push!(updated, (id, xnew, ynew, path_new))
            end
            states = updated
        end
    end
end

function main()
    length(ARGS) == 5 || error("usage: generate_b16_golden.jl OUTPUT PHASE02 SOURCE PROJECT MANIFEST")
    output_dir, phase_dir, source_root, project_file, manifest_file = ARGS
    VERSION == LOCKED_JULIA || error("wrong Julia version: $(VERSION)")
    source_head = readchomp(`git -C $source_root rev-parse HEAD`)
    source_head == LOCKED_COMMIT || error("wrong SargassumBOMB commit")
    physics_file = joinpath(source_root, "src", "physics.jl")
    sha256_file(physics_file) == LOCKED_PHYSICS_SHA || error("physics.jl checksum mismatch")
    sha256_file(project_file) == LOCKED_PROJECT_SHA || error("Project checksum mismatch")
    sha256_file(manifest_file) == LOCKED_MANIFEST_SHA || error("Manifest checksum mismatch")
    physics_text = read(physics_file, String)
    occursin("Dv_xDt  = WATER_ITP.x.fields[:DDt_x](x, y, t) + σ * STOKES_ITP.x.fields[:DDt_x](x, y, t)", physics_text) || error("locked Dv order missing")
    occursin("ω       = WATER_ITP.x.fields[:vorticity](x, y, t)", physics_text) || error("locked base vorticity order missing")

    fields_file = joinpath(phase_dir, "input_fields_v1.csv")
    particles_file = joinpath(phase_dir, "input_particles_v1.csv")
    parameters_file = joinpath(phase_dir, "input_parameters_v1.toml")
    coeff = load_fields(fields_file)
    particles = load_particles(particles_file)
    params = TOML.parsefile(parameters_file)
    params["schema"] == "MITGCM-BOM-B16-v1" || error("wrong parameter schema")
    params["bom"]["equation_mode"] == "JULIA" || error("wrong equation mode")
    params["fixed_dt_s"] == 900.0 || error("wrong fixed step")
    mkpath(output_dir)
    write_rhs(joinpath(output_dir, "golden_rhs_julia_v1.csv"), coeff, params, particles)
    write_trajectory(joinpath(output_dir, "golden_traj_julia_rk2_v1.csv"),
                     rk2_step, coeff, params, particles)
    write_trajectory(joinpath(output_dir, "golden_traj_julia_rk4_v1.csv"),
                     rk4_step, coeff, params, particles)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
