using Test

include("../../kernel/abstractTypes.jl")
include("../../kernel/mesh/mesh.jl")
include("../../kernel/mesh/metric_terms.jl")
include("../../kernel/basis/basis_structs.jl")

include("../AbstractProblems.jl")


function build_rhs(SD::NSD_2D, QT::Inexact, AP::Adv2D, q, ψ, dψ, ω, mesh::St_mesh, metrics::St_metrics, M, f)

    N   = mesh.nop
    ngl = N+1
    
    rhs_el = zeros(ngl*ngl,mesh.nelem)
    for iel=1:mesh.nelem
        for i=1:N+1
            for j=1:N+1
                
                ip_el = i + (j-1)*(N + 1)
                                
                u  = q.qnel[i,j,iel,2]
                v  = q.qnel[i,j,iel,3]
                
                dqdξ = 0
                dqdη = 0
                for k = 1:N+1
                    dqdξ = dqdξ + dψ[k,i]*q.qnel[k,j,iel,1]
                    dqdη = dqdη + dψ[k,j]*q.qnel[i,k,iel,1]
                end
                dqdx = dqdξ*metrics.dξdx[i,j,iel] + dqdη*metrics.dηdx[i,j,iel]
                dqdy = dqdξ*metrics.dξdy[i,j,iel] + dqdη*metrics.dηdy[i,j,iel]

                rhs_el[ip_el, iel] = ω[i]*ω[j]*metrics.Je[i,j,iel]*(u*dqdx + v*dqdy)
            end
        end
    end
    #show(stdout, "text/plain", el_matrices.D)

    return rhs_el
end



function build_rhs(SD::NSD_1D, QT::Inexact, PT::Wave1D, mesh::St_mesh, metrics::St_metrics, M, el_mat, f)

    #
    # Linear RHS in flux form: f = u*q
    #  
    rhs = zeros(mesh.npoin)
    fe  = zeros(mesh.ngl)
    for iel=1:mesh.nelem
        for i=1:mesh.ngl
            I = mesh.conn[i,iel]
            fe[i] = f[I]
        end
        for i=1:mesh.ngl
            I = mesh.conn[i,iel]
            for j=1:mesh.ngl
                rhs[I] = rhs[I] - el_mat.D[i,j,iel]*fe[j]
            end
        end
    end

    # M⁻¹*rhs where M is diagonal
    rhs .= rhs./M
    
    return rhs
end

function build_rhs(SD::NSD_1D, QT::Exact, PT::Wave1D, mesh::St_mesh, metrics::St_metrics, M, el_mat, f)

    #
    # Linear RHS in flux form: f = u*q
    #
    
    rhs = zeros(mesh.npoin)
    fe  = zeros(mesh.ngl)
    for iel=1:mesh.nelem
        for i=1:mesh.ngl
            I = mesh.conn[i,iel]
            fe[i] = f[I]
        end
        for i=1:mesh.ngl
            I = mesh.conn[i,iel]
            for j=1:mesh.ngl
                rhs[I] = rhs[I] - el_mat.D[i,j,iel]*fe[j]
            end
        end
    end
    
    # M⁻¹*rhs where M is not full
    rhs = M\rhs
    
    return rhs
end
