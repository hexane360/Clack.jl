using Test, Documenter
import Base.isapprox

using Results

using Clack

isapprox(lhs::Ok, rhs::Result)::Bool = is_ok(rhs) && isapprox(unwrap(lhs), unwrap(rhs))
isapprox(lhs::Err, rhs::Result)::Bool = is_err(rhs) && isapprox(lhs.err, rhs.err)

include("test_utils.jl")
include("test_types.jl")
include("test_parameters.jl")

@testset "parse" begin
	c = Command(Argument(Int, :p1, required=true),
	            Argument(Int, :p2, default=-1),
	            Option(Int, :int, short='i'),
	            Flag(:good, "on", "off", required=true))

	@test parse(c, ["5", "-i", "2", "--off", "10"]) == Ok(Dict(
		:p1 => 5,
		:p2 => 10,
		:int => 2,
		:good => false
	))

	@test parse(c, ["15", "--on"]) == Ok(Dict(
		:p1 => 15,
		:p2 => -1,
		:int => nothing,
		:good => true
	))

	@test parse(c) == Err("Missing parameters 'good' and 'p1'")
end

@testset "Doctests" begin
	DocMeta.setdocmeta!(Results, :DocTestSetup, :(using Results))
	doctest(Results; manual = false)
end
