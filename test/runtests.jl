using Test, Documenter
import Base.isapprox

using Results: Result, Ok, Err, is_ok, is_err
using Results: try_peek, unwrap

using Clack

isapprox(lhs::Ok, rhs::Result)::Bool = is_ok(rhs) && isapprox(unwrap(lhs), unwrap(rhs))
isapprox(lhs::Err, rhs::Result)::Bool = is_err(rhs) && isapprox(lhs.err, rhs.err)

@testset "Clack" begin

	include("test_utils.jl")
	include("test_types.jl")
	include("test_parameters.jl")
	include("test_macros.jl")

	@testset "parse" begin
		c = Command(Argument(:p1, Int, required=true),
		            Argument(:p2, Int, default=-1),
		            Option(:int, Int, 'i'),
		            Flag(:good, "on", "off", required=true))

		@test parse_cmd(c, ["5", "-i", "2", "--off", "10"]) == Ok(Dict(
			:p1 => 5,
			:p2 => 10,
			:int => 2,
			:good => false
		))

		@test parse_cmd(c, ["15", "--on"]) == Ok(Dict(
			:p1 => 15,
			:p2 => -1,
			:int => nothing,
			:good => true
		))

		@test parse_cmd(c) == Err("Missing parameters 'good' and 'p1'")
	end

	DocMeta.setdocmeta!(Clack, :DocTestSetup, :(using Clack))
	doctest(Clack; manual = false)

end
