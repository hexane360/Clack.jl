import Base.isequal

using MacroTools: @q, @expand, prewalk, rmlines

using Clack.macros: @command

strip_lines(ex) = prewalk(rmlines, ex)

function isequal(expr1::Expr, expr2::Expr)
	expr1.head == expr2.head && \
		length(expr1.args) == length(expr2.args) &&
		all(map(isequal, expr1.args, expr2.args))
end

isequal(ref::GlobalRef, expr::Expr) = string(ref) == string(expr)
isequal(expr::Expr, ref::GlobalRef) = string(ref) == string(expr)
isequal(ref::GlobalRef, sym::Symbol) = string(ref) == string(sym)
isequal(sym::Symbol, ref::GlobalRef) = string(ref) == string(sym)

@testset "macros" begin
	@testset "simple_command" begin
		@test @expand(
			@command begin
			Argument(:arg1, String, required=true)
			Option(:arg2, Int, required=true)
			function test(arg1, arg2::Int) 5 end
			end
		) |> strip_lines == @q begin
			function test(arg1, arg2::Int) 5 end
			test(arg_dict::Clack.macros.Dict) = test(arg_dict[:arg1], arg_dict[:arg2];)
			test_cmd = Clack.macros.Command(Argument(:arg1, String, required=true), Option(:arg2, Int, required=true); func=test)
		end

		@command begin
			Argument(:arg1, String, required=true)
			Option(:arg2, Int, required=true)
			test(arg1::String, arg2::Int) = arg1 * string(arg2)
		end

		@test call_cmd(test_cmd, ["--arg2", "5", "test"]) == Ok("test5")
	end

end

#TODO test for preserving docstrings
