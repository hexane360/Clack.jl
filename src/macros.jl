module macros

using MacroTools
using Maybe

using ..Parameters: Argument, Option, Flag

export @command

macro unesc(e) e end

struct Command end

macro command(block::Expr)
	#dump(block)
	if block.head != :block
		error("@command must start with a block.")
	end

	output = []
	params = []
	for expr in block.args
		if isa(expr, LineNumberNode)
			continue
		elseif expr.head == :call
			push!(params, expr)
		else
			func = expr
			append!(output, make_command(expr, params))
			params = []
		end
	end
	Expr(:block, output...)
end

function make_command(fdef, params)::Array{Expr}
	func = splitdef(fdef)
	args = [splitarg(a) for a in func[:args]]
	kwargs = [splitarg(a) for a in func[:kwargs]]

	func_name = func[:name]
	func_cmd = Symbol(func_name, "_cmd")

	argmap = [:(arg_dict[$(QuoteNode(name))]) for (name, type, splat, default) in args]
	kwmap = [:($name = arg_dict[$(QuoteNode(name))]) for (name, type, splat, default) in kwargs]
	[
		esc(:($func_cmd = $(@macroexpand @unesc Command)($(params...)))),
		esc(:($func_name(arg_dict::$(@macroexpand @unesc Dict)) = $func_name($(argmap...); $(kwmap...)))),
		esc(fdef)
	]
end

# todo handle splatted arguments
struct Arg
	name::Symbol
	type::Maybe.T{Expr}
	default::Maybe.T{Expr}
	keyword::Bool
end

struct Func
	name::Symbol
	arguments::Array{Arg}
	type::Maybe.T{Expr}
	body::Expr
end

#@command begin
#	Argument()
#	Option()
#	function test()
#	end
#end
# test_cmd = Command(
#   Argument(),
#   Option(),
# )
# test(dict) = test(dict[a], dict[b]; c=dict[c], d=dict[d])
# test()
# end

end
