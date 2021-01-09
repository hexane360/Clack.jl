module Clack

import Base: parse, getindex, setindex!, pop!, haskey
using Base.Iterators

using Maybe
using Results

import Results: try_pop!

include("Utils.jl")
include("Types.jl")
include("Parameters.jl")
include("macros.jl")
using .Utils
using .Types
using .Parameters
using .macros

export Parameter, Flag, Option, Argument, Command
export ParseType, IdType, BoolType, NumType, RangeType, ChoiceType, FuncType, TypeType, TupleType
export parse

"""Struct which describes a command to be parsed. Each command consists of
multiple parameters, which are parsed and returned in a dictionary."""
struct Command
	options::Array{Option}
	arguments::Array{Argument}
	flags::Array{Flag}
	params::Dict{Symbol, Parameter}
	long_opts::Dict{String, Parameter}
	short_opts::Dict{Char, Parameter}
	#f::Function
	function Command(param_list::Vararg{Parameter})
		options = []
		arguments = []
		flags = []
		params = Dict{Symbol, Parameter}()
		long_opts = Dict{String, Parameter}()
		short_opts = Dict{Char, Parameter}()
		for param in param_list #Iterators.flatten([options, arguments, flags])
			if haskey(params, param.name)
				error("Parameter name '$(param.name)' already in use")
			end
			params[param.name] = param

			if isa(param, Option)
				push!(options, param)
			elseif isa(param, Argument)
				push!(arguments, param)
			elseif isa(param, Flag)
				push!(flags, param)
			else
				error("Unknown parameter type $(typeof(param))")
			end

			for name in list_names(param)
				if haskey(long_opts, name)
					error("Parameter '--$(name)' already in use")
				end
				long_opts[name] = param
				#push!(long_params, name)
			end
			for name in list_short(param)
				if haskey(short_opts, name)
					error("Short parameter '-$(name)' already in use")
				end
				short_opts[name] = param
				#push!(short_params, short)
			end
		end
		new(options, arguments, flags, params, long_opts, short_opts)
	end
end

mutable struct ParseState
	command::Command
	args::Array{String}
	pos_args::Array{Argument}
	parsed::Dict{Symbol, Any}

	ParseState(c::Command, args::Array{String}) = new(
		c,
		reverse(args),
		reverse(c.arguments),
		#Dict(flatten((name => param for name in names(param))
		#             for param in flatten([c.options, c.arguments, c.flags]))),
		#Dict(flatten((name => param for name in short(param))
		#             for param in flatten([c.options, c.arguments, c.flags]))),
		Dict()
	)
end

setindex!(state::ParseState, value, param::Symbol) = setindex!(state.parsed, value, param)
getindex(state::ParseState, param::Symbol) = getindex(state.parsed, param)
haskey(state::ParseState, param::Symbol) = haskey(state.parsed, param)

peek(state::ParseState)::Maybe.T{String} = isempty(state.args) ? nothing : Some(state.args[end])
peek_pos(state::ParseState)::Maybe.T{Argument} = isempty(state.pos_args) ? nothing : Some(state.pos_args[end])

pop!(state::ParseState)::String = pop!(state.args)
"""Pop an `Argument` from the stack. Raises `ArgumentError` if stack is empty."""
pop_pos!(state::ParseState)::Argument = pop!(state.pos_args)

try_pop!(state::ParseState)::Maybe.T{String} = try_pop!(state.args)
try_pop!(state::ParseState, e)::Result{String} = try_pop!(state.args, e)
try_pop_pos!(state::ParseState)::Maybe.T{Argument} = try_pop!(state.pos_args)
try_pop_pos!(state::ParseState, e)::Result{Argument} = try_pop!(state.pos_args, e)
parse(c::Command, args::Array{String})::Result{Dict{Symbol, Any}, String} = parse(ParseState(c, args))
parse(c::Command)::Result{Dict{Symbol, Any}, String} = parse(c, ARGS)

function parse(state::ParseState)::Result{Dict{Symbol, Any}, String}
	parse_options = true
	@while_let arg = peek(state) begin
		if !startswith(arg, '-') || !parse_options
			#parse as positional arg
			@try_unwrap parse_positional(state)
		elseif arg == "--"
			#disable parsing of options and flags
			parse_options = false
			pop!(state)
		elseif startswith(arg, "--")
			#parse as long arg
			@try_unwrap parse_long(state)
		else
			#parse as short arg
			@try_unwrap parse_short(state)
		end
	end
	#check for missing args and fill defaults
    missing_params = String[]
	for (name, param) in state.command.params
		if haskey(state, name)
			continue
		end
		if required(param)
			push!(missing_params, "'$(param.name)'")
		else
			state[name] = default(param)
		end
	end
	if !isempty(missing_params)
		Err("Missing parameter$(plural(missing_params)) $(format_list(missing_params))")
	else
		Ok(state.parsed)
	end
end

"""Parse a positional argument"""
function parse_positional(state::ParseState)::Result{Tuple{}, String}
	#val = pop!(state)
	arg = @try_unwrap try_pop_pos!(state, () -> "Unexpected positional argument '$(pop!(state))'")
	state[arg.name] = @try_unwrap parse_type(arg.type, state, () -> String(arg.name))
	#state[arg.name] = @try_unwrap catch_result(() -> arg.type(peek))
	Ok(())
end

"""Parse a long option or flag"""
function parse_long(state::ParseState)::Result{Tuple{}, String}
	arg = pop!(state)
	#TODO --option=value support
	opt = @try_unwrap try_get(state.command.long_opts, arg[3:end], () -> "Unknown option '$arg'")

	state[opt.name] = if isa(opt, Flag)
		get_flag_value(opt, arg[3:end])
	else
		@try_unwrap parse_type(opt.type, state, () -> arg)
	end
	Ok(())
end

"""Parse a group of short options or flags"""
function parse_short(state::ParseState)::Result{Tuple{}, String}
	arg = pop!(state)
	opt = nothing
	option_c = nothing
	for c in arg[2:end]
		if option_c !== nothing
			return Err("Missing value for option '-$option_c'")
		end
		opt = @try_unwrap try_get(state.command.short_opts, c, () -> "Unknown option '-$c'")
		if isa(opt, Flag)
			state[opt.name] = get_flag_value(opt, c)
		else
			option_c = c
		end
	end
	if option_c !== nothing
		#val = @try_unwrap try_pop!(state, () -> "Missing value for option '-$option_c'")
		#@try_unwrap catch_result(() -> opt.type(val))
		state[opt.name] = @try_unwrap parse_type(opt.type, state, () -> "-$option_c")
	end
	Ok(())
end

"""Parse a `ParseType`"""
function parse_type(type::ParseType{T}, state::ParseState,
                    opt_name::Function)::Result{T, String} where {T}
	n = nargs(type)
	vals = []
	for _ in 1:n
		push!(vals, @try_unwrap try_pop!(state, () -> "Missing value for option '$(opt_name())'"))
	end
	catch_result(() -> type(vals...))
end

end # module
