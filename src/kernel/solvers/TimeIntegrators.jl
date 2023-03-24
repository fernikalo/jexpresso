using LinearAlgebra
using DiffEqBase
using OrdinaryDiffEq
using OrdinaryDiffEq: SplitODEProblem, solve, IMEXEuler
using SnoopCompile
import SciMLBase
using WriteVTK

include("../abstractTypes.jl")
include("../../io/write_output.jl")

function time_loop!(SD,
                    QT,
                    PT,
                    mesh::St_mesh,
                    metrics::St_metrics,
                    basis, ω,
                    qp::St_SolutionVars,
                    M,
                    De, Le,
                    Nt, Δt,
                    neqns, 
                    inputs::Dict,
                    OUTPUT_DIR::String,
                    T)
    
    #
    # ODE: solvers come from DifferentialEquations.j;
    #
    #Initialize
    u      = zeros(T, mesh.npoin);
    u     .= qp.qn[:,1];
    tspan  = (inputs[:tinit], inputs[:tend])    
    params = (; T, SD, QT, PT, neqns, basis, ω, mesh, metrics, inputs, M, De, Le)
    prob   = ODEProblem(rhs!,
                        u,
                        tspan,
                        params);
    
    println(" # Solving ODE ................................")
    @info " " inputs[:ode_solver] inputs[:tinit] inputs[:tend] inputs[:Δt]
    
    @time    solution = solve(prob,
                              inputs[:ode_solver],
                              dt = Δt,
                              save_everystep=false,
                              saveat = range(T(0.), Nt*T(Δt), length=inputs[:ndiagnostics_outputs]),
                              progress = true,
                              progress_message = (dt, u, p, t) -> t)
    println(" # Solving ODE  ................................ DONE")
    
    return solution
    
end
