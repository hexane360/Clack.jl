module Types

using FunctionWrappers: FunctionWrapper
using DataStructures: OrderedDict
using Results

using ..Utils

export ParseType, IdType, BoolType, NumType, RangeType, ChoiceType, FuncType, TypeType, TupleType
export to_parse_type, output_type, nargs

abstract type ParseType{T} end

"""Return the type produced by a `ParseType` or `Parameter`"""
function output_type end

function output_type(::ParseType{T})::Type{T} where {T} T end
function output_type(::Type{ParseType{T}})::Type{T} where {T} T end

#const ToParseType = Union{ParseType,
#                          Type,
#                          Tuple{ToParseType},
#                          FunctionWrapper{T, Tuple{String}},
#                          FunctionWrapper{Result{T, String}, Tuple{String}}}

"""Convert a type or tuple of types to a `ParseType` which produces it"""
function to_parse_type end

to_parse_type(p::ParseType)::ParseType = p
to_parse_type(::Type{Bool})::BoolType = BoolType()
to_parse_type(::Type{String})::IdType = IdType()
to_parse_type(f::Function)::FuncType = FuncType(f)
function to_parse_type(tup::T)::TupleType where {T <: Tuple} TupleType(map(to_parse_type, tup)) end
function to_parse_type(::Type{T})::NumType where {T <: Number} NumType{T}() end
function to_parse_type(::Type{T})::TypeType where {T} TypeType{T}() end
#function to_parse_type(f::FunctionWrapper{T, Tuple{String}})::FuncType{T} where {T} FuncType(f) end
#function to_parse_type(f::FunctionWrapper{Result{T, String}, Tuple{String}})::FuncType{T} where {T} FuncType(f) end

"""Identity `ParseType`"""
struct IdType <: ParseType{String} end
function (::IdType)(s::String)::Result{String, Union{}} Ok(s) end

"""`ParseType` which produces a `Bool`"""
struct BoolType <: ParseType{Bool} end
function (::BoolType)(s::String)::Result{Bool, String}
	if lowercase(s) ∈ ["yes", "y", "true", "t", "1"]
		Ok(true)
	elseif lowercase(s) ∈ ["no", "n", "false", "f", "0"]
		Ok(false)
	else
		Err("Unable to parse '$s' as Bool")
	end
end

"""`ParseType` which allows one of a set of choices."""
struct ChoiceType{T} <: ParseType{T}
	choices::OrderedDict{String, T}
end
function ChoiceType(choices::Vararg{String})::ChoiceType{String}
	dict = OrderedDict{String, String}()
	for choice in choices
		if haskey(dict, choice)
			error("Choice '$choice' is already in use")
		end
		dict[choice] = choice
	end
	ChoiceType{String}(dict)
end

function (c::ChoiceType{T})(s::String)::Result{T, String} where {T}
	if s ∈ keys(c.choices)
		Ok(c.choices[s])
	else
		Err("Unexpected value '$s', possible choices: $(format_list(keys(c.choices)))")
	end
end

"""`ParseType` which wraps another `ParseType` with a function."""
struct FuncType{N, T, U} <: ParseType{U}
	ty::ParseType{T}
	f::FunctionWrapper{Result{U, String}, NTuple{N, T}}

	function FuncType(f::Function, ty::ParseType{T}=IdType(); nargs=1) where {T}
		if !hasmethod(f, NTuple{nargs, T})
			error("Parse function not callable with type '$T'")
		end
		ret_types = Base.return_types(f, NTuple{nargs, T})
		# strip result types from inference
		U = Union{strip_result_type(ret_types)...}
		new{nargs, T, U}(ty, f)
	end
end
FuncType(f::Function, ty) = FuncType(f, to_parse_type(ty))
function (p::FuncType{N, T, U})(s::Vararg{String, N})::Result{U, String} where {N, T, U}
	val = @try_unwrap p.ty(s...)
	p.f(val)
end

"""`ParseType` which calls a type constructor to parse a value."""
struct TypeType{T} <: ParseType{T}
	function TypeType{T}() where {T}
		hasmethod(T, Tuple{String}) ? new{T}() : error("Type $T has no String constructor")
	end
	TypeType(U) = TypeType{U}()
end
function (::TypeType{T})(s::String)::Result{T, String} where {T}
	catch_result(() -> T(s))
end

"""`ParseType` which parses numerical values."""
struct NumType{T <: Number} <: ParseType{T} end
function (::NumType{T})(s::String)::Result{T, String} where {T}
	map_err((_) -> "Unable to parse '$s' as $T",
	        catch_result(() -> parse(T, s)))
end

"""`ParseType` which allows one of a range of numerical values."""
struct RangeType{T <: Number} <: ParseType{T}
	min::Union{T, Nothing}
	max::Union{T, Nothing}
end
function RangeType(r::AbstractRange{T})::RangeType{T} where {T <: Number}
	RangeType(minimum(r), maximum(r))
end
function (r::RangeType{T})(s::String)::Result{T, String} where {T}
	num = @try_unwrap NumType{T}()(s)
	if r.min !== nothing && r.min > num || r.max !== nothing && num > r.max
		Err("Value '$num' out of range $(r.min):$(r.max)")
	else
		Ok(num)
	end
end

"""Return the passed type with one layer of `Result` values stripped."""
function strip_result_type end

function strip_result_type(ty::Union)::Array{Type}
	collect(Iterators.flatten(map(strip_result_type, Base.uniontypes(ty))))
end
function strip_result_type(ty::Type{Ok{T}})::Array{Type} where {T}
	[T]
end
function strip_result_type(::Type{Err{E}})::Array{Type} where {E}
	[]
end
strip_result_type(ty::Type)::Array{Type} = [ty]
strip_result_type(a::Array)::Array{Type} = collect(Iterators.flatten(map(strip_result_type, a)))



"""`ParseType` which parses multiple arguments in sequence."""
struct TupleType{T} <: ParseType{T}
	types::Tuple{Vararg{ParseType}}

	function TupleType(types::Tuple{Vararg{ParseType}})
		T = Tuple{map(output_type, types)...}
		new{T}(types)
	end
end

function (tup::TupleType{T})(args::Vararg{String})::Result{T, String} where {T}
	result = ()
	if length(args) != length(tup.types)
		error("Expected $(length(tup.types)) values, got $(length(args)) values instead")
	end
	vals = []
	for (ty, val) in zip(tup.types, args)
		push!(vals, @try_unwrap(ty(val)))
	end
	Ok(tuple(vals...))::Ok{T}
end

nargs(::ParseType)::Int = 1
nargs(t::TupleType)::Int = length(t.types)

end
