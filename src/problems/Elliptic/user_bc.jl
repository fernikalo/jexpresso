"""
    qibdy is an Array{Floats} of size `nvars`

    src/problem/PROBLEM_NAME/user_bc.jl contains a set of user-defined boundary conditions functions
    that can be modified as needed.

    The function defined in src/problem/PROBLEM_NAME/user_bc.jl 
    are called by the b.c. functions defined in src/kernel/custom_bcs.jl
    within a boundary-edge loop that detects the "tag" string defined in the user-generated *.msh file.

    For example:
    If some domain boundaries of gmsh file mymesh.msh are tagged as "inflow" and "no_slip", then the user
    creating the functions in user_bc.jl must define the behavior of the unknown or its derivatives
    on those boundaries.

    ```math
    if (tag === "inflow")
        qibdy[1] = 3.0
    elseif (tag === "fix_temperature")
        qibdy[2] = 300.0
    end
    return qibdy
    ```
    where  `qibdy[i=1:nvar]` is the value unknown `i`
    
"""
function user_bc_dirichlet!(q::AbstractFloat, gradq::AbstractFloat, x::AbstractFloat, y::AbstractFloat, t::Abstractfloat, tag::String) where TFloat <: Float64
    
    if (tag === "inflow")
        qibdy[1] = 3.0    #u
    elseif (tag === "fix_temperature")
        qibdy[2] = 300.0  #T
    end
    
    qibdy = 0.0
end

function user_bc_neumann!(q::AbstractFloat, gradq::AbstractFloat, x::AbstractFloat, y::AbstractFloat, t::Abstractfloat, tag::String) where TFloat <: Float64
    
    if (tag === "heat_flux")
        gradq[1] = 400.0
    end
    
    return gradq
end


function user_bc_robin!(q::AbstractFloat, gradq::AbstractFloat, x::AbstractFloat, y::AbstractFloat, t::Abstractfloat, tag::String) where TFloat <: Float64
    
    if (tag === "heat_flux")
        gradq[1] = 400.0
    elseif (tag === "fix_temperature")
        q[1] = 0.0
    end
    
    qibdy = 0.0
end
