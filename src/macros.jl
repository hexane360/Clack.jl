module macros

using MacroTools
using Maybe

using ..Commands
using ..Parameters: Argument, Option, Flag

export @command

macro unesc(e) e end

#struct Command end

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

	#TODO handle splatted arguments
    #TODO handle default arguments
    #TODO check types on function definition
	argmap = [:(arg_dict[$(QuoteNode(name))]) for (name, type, splat, default) in args]
	kwmap = [:($name = arg_dict[$(QuoteNode(name))]) for (name, type, splat, default) in kwargs]
	[
		esc(fdef),
		esc(:($func_name(arg_dict::$(@macroexpand @unesc Dict)) = $func_name($(argmap...); $(kwmap...)))),
		esc(:($func_cmd = $(@macroexpand @unesc Command)($(params...); func=$func_name))),
	]
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
