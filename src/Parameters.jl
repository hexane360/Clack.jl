module Parameters

using Maybe
using ..Types
using ..Utils
import ..Types: output_type

export Parameter, Flag, Option, Argument
export list_names, list_short, required, default


abstract type Parameter{T} end

struct Flag{T} <: Parameter{T}
	name::Symbol
	names::NTuple{2, Array{String}}
	short::NTuple{2, Maybe.T{Char}}
	default::Union{T, Nothing}
	required::Bool

	function Flag(name::Union{Symbol, String},
	              names::NTuple{2, Array{<:String}},
	              short::NTuple{2, Union{Char, Nothing}}=(nothing, nothing);
	              default=nothing, required::Bool=false)
		T = required ? Bool : promote_type(Bool, typeof(default))
		new{T}(to_symbol(name), names, to_maybe.(short), default, required)
	end
end

function Flag(name::Symbol,
              true_val::Union{AbstractArray{<:String}, String},
              false_val::Union{AbstractArray{<:String}, String, Nothing}=nothing,
              true_short::Union{Char, Nothing}=nothing,
              false_short::Union{Char, Nothing}=nothing;
              default=nothing, required::Bool=false)
	Flag(name, to_array.((true_val, false_val)),
	     (true_short, false_short), default=default, required=required)
end

function Flag(true_val::String,
              false_val::Union{AbstractArray{<:String}, String}=nothing,
              true_short::Union{Char, Nothing}=nothing,
              false_short::Union{Char, Nothing}=nothing;
              default=nothing, required::Bool=false)
	Flag(true_val, to_array.((true_val, false_val)),
	     (true_short, false_short), default=default, required=required)
end

struct Option{T, U <: T} <: Parameter{T}
	name::Symbol
	type::ParseType{U}
	names::Array{String}
	short::Maybe.T{Char}
	default::Union{T, Nothing}
	required::Bool
	function Option(type, name::Symbol, names::Array{<:String};
	                short::Union{Char, Nothing}=nothing,
	                default=nothing, required::Bool=false)
		parse_type = to_parse_type(type)
		#find the type of the converted ParseType
		U = output_type(parse_type)
		#and union it with the type of `default` to get the final type
		T = required ? U : promote_type(U, typeof(default))
		new{T, U}(name, parse_type, names, to_maybe(short), default, required)
	end
end

function Option(type, name::Union{Symbol, String},
                other_names::Vararg{String};
                short::Union{Char,Nothing}=nothing,
                default=nothing, required::Bool=false)
	names = [String(name)]
	append!(names, other_names)
	Option(type, to_symbol(name), names,
	       short=short, default=default, required=required)
end

struct Argument{T, U <: T} <: Parameter{T}
	name::Symbol
	type::ParseType{U}
	default::Union{T, Nothing}
	required::Bool
	function Argument(type, name::Union{Symbol, String};
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

list_names(flag::Flag)::Array{String} = vcat(flag.names...)
list_names(opt::Option)::Array{String} = opt.names
list_names(::Argument)::Array{String} = []

"""List the short option names recognized by a `Parameter`"""
function list_short end

list_short(flag::Flag)::Array{Char} = [s.value for s in flag.short if isa(s, Some)]
list_short(opt::Option)::Array{Char} = isa(opt.short, Some) ? [opt.short.value] : []
list_short(::Argument)::Array{Char} = []

"""Return whether a `Parameter` is required"""
required(param::Parameter)::Bool = param.required

"""Return the default value of a parameter"""
function default(param::Parameter{T})::T where {T}
	required(param) ? error("Parameter $(param.name) has no default value") : param.default
end

"""Return the type outputted by a parameter"""
function output_type(::Parameter{T})::Type{T} where {T} T end
"""Return the type outputted by a parameter type"""
function output_type(::Type{Parameter{T}})::Type{T} where {T} T end

"""Convert a nullable value to a Maybe type by wrapping non-null values in Some"""
function to_maybe(v::T)::Some{T} where {T} Some(v) end
function to_maybe(::Nothing)::Nothing nothing end

function to_array(::Nothing)::Array{Union{}}
	[]
end
function to_array(val::T)::Array{T} where {T}
	[val]
end
function to_array(arr::AbstractArray{T})::Array{T} where {T} Array(arr) end

to_symbol(s::Symbol)::Symbol = s
function to_symbol(s::String)::Symbol
	try
		Symbol(s)
	catch e
		error("'$s' is not a valid symbol/parameter name")
	end
end

end
