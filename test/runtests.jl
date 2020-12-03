using Test, Documenter
import Base.isapprox

using Results

using Clack

isapprox(lhs::Ok, rhs::Result)::Bool = is_ok(rhs) && isapprox(unwrap(lhs), unwrap(rhs))
isapprox(lhs::Err, rhs::Result)::Bool = is_err(rhs) && isapprox(lhs.err, rhs.err)

include("test_utils.jl")
include("test_types.jl")
include("test_parameters.jl")

@testset "Doctests" begin
	DocMeta.setdocmeta!(Results, :DocTestSetup, :(using Results))
	doctest(Results; manual = false)
end
