module Parameters

import Results
using Results: try_peek, unwrap_or, to_option

using ..Types
using ..Utils
import ..Types: output_type

export Parameter, Flag, Option, Argument
export list_names, list_short, required, default, get_flag_value

"""
Type representing a generic parameter to a command.
All Parameters have the following fields: `name`, `default`, `required`.
However, these accessor functions should usually be used instead:
`list_names`, `list_short`, `default`, `required`
"""
abstract type Parameter{T} end

struct Flag{T} <: Parameter{T}
	name::Symbol
	names::NTuple{2, Array{AbstractString}}
	short::NTuple{2, Results.Option{Char}}
	default::Union{T, Bool, Nothing}
	values::NTuple{2, T}
	required::Bool

	function Flag(name::Symbol,
	              names::NTuple{2, Array{<:AbstractString}},
	              short::NTuple{2, Union{Char, Nothing}}=(nothing, nothing);
	              values::NTuple{2}=(true, false),
	              default=nothing, required::Bool=false)
		# get possible output types (if names[i] is empty then that that branch is impossible)
		T = promote_type(length(names[1]) > 0 ? typeof(values[1]) : Union{},
		                 length(names[2]) > 0 ? typeof(values[2]) : Union{})
		# add possible default type.
		if !required
			T = if isa(default, Bool)
				# a bool gets converted to the equivalent value
				promote_type(T, default ? values[1] : values[2])
			else
				promote_type(T, typeof(default))
			end
		end
		new{T}(name, names, to_option.(short), default, values, required)
	end
end

get_flag_value(flag::Flag, name::AbstractString) = (name ∈ flag.names[1]) ? flag.values[1] : flag.values[2]
get_flag_value(flag::Flag, short::Char) = (Some(short) === flag.short[1]) ? flag.values[1] : flag.values[2]

function Flag(name::Symbol,
              false_name::Union{AbstractArray{AbstractString}, AbstractString};
              short::NTuple{2, Union{Char, Nothing}}=(nothing, nothing),
              values::NTuple{2}=(true, false),
              default=nothing, required::Bool=false)
	Flag(name, ([string(name)], to_array(false_name)), short;
	     values=values, default=default, required=required)
end

function Flag(name::Symbol,
              true_name::Union{AbstractArray{AbstractString}, AbstractString},
              false_name::Union{AbstractArray{AbstractString}, AbstractString};
              short::NTuple{2, Union{Char, Nothing}}=(nothing, nothing),
              values::NTuple{2}=(true, false),
              default=nothing, required::Bool=false)
	Flag(name, to_array.((true_name, false_name)), short;
	     values=values, default=default, required=required)
end

function Flag(name::Symbol,
              true_name::Union{AbstractArray{AbstractString}, AbstractString},
              false_name::Union{AbstractArray{AbstractString}, AbstractString},
              true_short::Union{Char, Nothing},
              false_short::Union{Char, Nothing}=nothing,
              values::NTuple{2}=(true, false),
              default=nothing, required::Bool=false)
	Flag(name, to_array.((true_name, false_name)), to_option.((true_short, false_short));
	     values=values, default=default, required=required)
end

struct Option{T, U <: T} <: Parameter{T}
	name::Symbol
	type::ParseType{U}
	names::Array{AbstractString}
	short::Results.Option{Char}
	default::Union{T, Nothing}
	required::Bool
	function Option(name::Symbol, type, names::Array{<:AbstractString};
	                short::Union{Char, Nothing}=nothing,
	                default=nothing, required::Bool=false)
		parse_type = to_parse_type(type)
		#find the type of the converted ParseType
		U = output_type(parse_type)
		#and union it with the type of `default` to get the final type
		T = required ? U : promote_type(U, typeof(default))
		new{T, U}(name, parse_type, names, to_option(short), default, required)
	end
end

function Option(name::Symbol, type,
                other_names::Vararg{Union{AbstractString, Char}};
                default=nothing, required::Bool=false)
	names = [String(name)]
	append!(names, filter(x -> !isa(x, Char), other_names))
	short = try_peek(filter(x->isa(x, Char), other_names)) |> to_nullable
	Option(name, type, names, short=short, default=default, required=required)
end



struct Argument{T, U <: T} <: Parameter{T}
	name::Symbol
	type::ParseType{U}
	default::Union{T, Nothing}
	required::Bool
	function Argument(name::Symbol, type;
	                  default=nothing,
	                  required::Bool=false)
		parse_type = to_parse_type(type)
		#find the type of the converted ParseType
		U = output_type(parse_type)
		#and union it with the type of `default` to get the final type
		T = required ? U : promote_type(U, typeof(default))
		new{T, U}(to_symbol(name), parse_type, default, required)
	end
end

"""List the option names recognized by a `Parameter`"""
function list_names end

list_names(flag::Flag)::Array{AbstractString} = vcat(flag.names...)
list_names(opt::Option)::Array{AbstractString} = opt.names
list_names(::Argument)::Array{AbstractString} = []

"""List the short option names recognized by a `Parameter`"""
function list_short end

list_short(flag::Flag)::Array{Char} = [s.value for s in flag.short if isa(s, Some)]
list_short(opt::Option)::Array{Char} = isa(opt.short, Some) ? [opt.short.value] : []
list_short(::Argument)::Array{Char} = []

"""Return whether a `Parameter` is required"""
required(param::Parameter)::Bool = param.required

"""Return the default value of a `Parameter`"""
function default(param::Parameter{T})::T where {T}
	required(param) ? error("Parameter $(param.name) has no default value") : param.default
end

function default(flag::Flag{T})::T where {T}
	if required(flag) error("Parameter $(flag.name) has no default value") end
	if isa(flag.default, Bool)
		flag.default ? flag.values[1] : flag.values[2]
	else
		flag.default
	end
end

"""Return the type outputted by a `Parameter`"""
function output_type(::Parameter{T})::Type{T} where {T} T end
"""Return the type outputted by a `Parameter` type"""
function output_type(::Type{Parameter{T}})::Type{T} where {T} T end

end
