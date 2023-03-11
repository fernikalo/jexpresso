using DifferentialEquations
using LinearAlgebra
using DiffEqBase
using OrdinaryDiffEq: SplitODEProblem, solve, IMEXEuler
import SciMLBase

include("../abstractTypes.jl")
include("../infrastructure/element_matrices.jl")
include("../../io/plotting/jeplots.jl")
include("../../io/diagnostics.jl")

mutable struct RK_Integrator{TFloat}
  a::Array{TFloat}
  b::Array{TFloat}
  c::Array{TFloat}
end

function buildRKIntegrator(RKtype::RK3, TFloat)

    RKcoef = RK_Integrator{TFloat}(zeros(TFloat,3),zeros(TFloat,3),zeros(TFloat,3))
    
    RKcoef.a=[0.0 -5/9 -153/128]
    RKcoef.b=[0.0 1/3 3/4]
    RKcoef.c=[1/3 15/16 8/15]
    
    return RKcoef
end


function buildRKIntegrator!(RKtype::RK5, TFloat)

    RKcoef = RK_Integrator{TFloat}(zeros(TFloat,5),zeros(TFloat,5),zeros(TFloat,5))
    
    RKcoef.a = [TFloat(0),
                TFloat(-567301805773)  / TFloat(1357537059087),
                TFloat(-2404267990393) / TFloat(2016746695238),
                TFloat(-3550918686646) / TFloat(2091501179385),
                TFloat(-1275806237668) / TFloat(842570457699 )]

    RKcoef.b = [TFloat(1432997174477) / TFloat(9575080441755 ),
                TFloat(5161836677717) / TFloat(13612068292357),
                TFloat(1720146321549) / TFloat(2090206949498 ),
                TFloat(3134564353537) / TFloat(4481467310338 ),
                TFloat(2277821191437) / TFloat(14882151754819)]

    RKcoef.c = [TFloat(0),
                TFloat(1432997174477) / TFloat(9575080441755),
                TFloat(2526269341429) / TFloat(6820363962896),
                TFloat(2006345519317) / TFloat(3224310063776),
                TFloat(2802321613138) / TFloat(2924317926251)]

    return RKcoef

end

function rhs!(RHS, q, params, time)

    T       = Float64
    TD      = params.TD
    SD      = params.SD
    QT      = params.QT
    PT      = params.PT
    BCT     = params.BCT
    neqns   = params.neqns
    basis   = params.basis
    mesh    = params.mesh
    metrics = params.metrics
    inputs  = params.inputs
    ω       = params.ω
    M       = params.M

    #
    # rhs[ngl,ngl,nelem]
    #
    rhs_el      = build_rhs(SD, QT, PT, neqns, q.qn, basis.ψ, basis.dψ, ω, mesh, metrics, T)
    rhs_diff_el = build_rhs_diff(SD, QT, PT, neqns, q.qn, basis.ψ, basis.dψ, ω, inputs[:νx], inputs[:νy], mesh, metrics, T)
    
    apply_boundary_conditions!(rhs_el, q.qn, mesh, inputs, SD, QT, metrics, basis.ψ, basis.dψ, ω,time, BCT, neqns)
    
    RHS = DSSijk_rhs(SD, rhs_el + inputs[:δvisc]*rhs_diff_el, mesh.connijk, mesh.nelem, mesh.npoin, mesh.nop, T)
    
    divive_by_mass_matrix!(RHS, M, QT)
    
    apply_periodicity!(rhs_el, q.qn, mesh, inputs, SD, QT, metrics, basis.ψ, basis.dψ, ω, time, BCT, neqns)

    return RHS
end



function time_loop!(TD,
                    SD,
                    QT,
                    PT,
                    mesh::St_mesh,
                    metrics::St_metrics,
                    basis, ω,
                    qp,
                    M, L, 
                    Nt, Δt,
                    neqns, 
                    inputs::Dict,
                    BCT,
                    OUTPUT_DIR::String,
                    T)

    it_interval    = inputs[:diagnostics_interval]
    it_diagnostics = 1

    #
    # RK
    #
    time = inputs[:tinit]
    for it = 1:Nt
        if (mod(it, it_interval) == 0 || it == Nt)
            @printf "   Solution at t = %.6f sec\n" time
            for ieq = 1:length(qp.qn[1,:])
                @printf "      min/max(q[%d]) = %.6f %.6f\n" ieq minimum(qp.qn[:,ieq]) maximum(qp.qn[:,ieq])
            end

            mass_conservation(qp)
            
            title = @sprintf "Tracer: final solution at t=%6.4f" time
            jcontour(SD, mesh.x, mesh.y, qp.qn[:,1], title, string(OUTPUT_DIR, "/it.", it_diagnostics, ".png"))
            it_diagnostics = it_diagnostics + 1
            
        end
            
        rk!(qp, TD, SD, QT, PT, mesh, metrics, basis, ω, M, L, Δt, neqns, inputs, BCT, time, T)
  
        time += Δt
    end
    
    #Plot final solution
    title = @sprintf "Tracer: final solution at t=%6.4f" inputs[:tend]
    jcontour(SD, mesh.x, mesh.y, qp.qn[:,1], title, string(OUTPUT_DIR, "/it", "end", ".png"))

    plot_error(SD, mesh.x, qp.qn[:,1], qp.qe[:,1], string(OUTPUT_DIR, "/FINAL-error.png"))
    
end

function rk!(q::St_SolutionVars,
             TD,
             SD,
             QT,
             PT,
             mesh::St_mesh,
             metrics::St_metrics,
             basis, ω,
             M, L, Δt,
             neqns, 
             inputs::Dict,
             BCT,
             time,
             T)

    
    params = (;T, TD, SD, QT, PT, BCT, neqns, basis, mesh, metrics, inputs, ω, M)
    
    RHS    = zeros(mesh.npoin)
    dq     = zeros(mesh.npoin, neqns)
    RKcoef = buildRKIntegrator!(TD, T)

    #
    # RHS[npoin] = DSS(rhs)
    #
    for ieqn=1:neqns
        
        for s = 1:length(RKcoef.a)
            
            RHS = rhs!(RHS, q, params, time)
            
            for I=1:mesh.npoin
                dq[I, ieqn] = RKcoef.a[s]*dq[I, ieqn] + Δt*RHS[I]
                q.qn[I, ieqn] = q.qn[I, ieqn] + RKcoef.b[s]*dq[I, ieqn]
            end

        end #stages
    end
    
end
