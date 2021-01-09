module Types

using FunctionWrappers: FunctionWrapper
using DataStructures: OrderedDict
using Results

using ..Utils

export ParseType, BoolType, NumType, RangeType, ChoiceType
export IdType, FuncType, TypeType
export ArrayType, TupleType
export to_parse_type, output_type, nargs

abstract type ParseType{T} end

"""Return the type produced by a `ParseType` or `Parameter`"""
function output_type end

function output_type(::ParseType{T})::Type{T} where {T} T end
function output_type(::Type{ParseType{T}})::Type{T} where {T} T end

#const ToParseType = Union{ParseType,
#                          Type,
#                          Tuple{ToParseType},
#                          FunctionWrapper{T, Tuple{AbstractString}},
#                          FunctionWrapper{Result{T, String}, Tuple{AbstractString}}}

"""Convert a type or tuple of types to a `ParseType` which produces it"""
function to_parse_type end

to_parse_type(p::ParseType)::ParseType = p
to_parse_type(::Type{Bool})::BoolType = BoolType()
to_parse_type(::Type{AbstractString})::IdType = IdType()
to_parse_type(f::Function)::FuncType = FuncType(f)
function to_parse_type(tup::T)::TupleType where {T <: Tuple} TupleType(tup...) end
function to_parse_type(::Type{T})::NumType where {T <: Number} NumType{T}() end
function to_parse_type(::Type{T})::Union{} where {T <: ParseType} error("Uninstantiated ParseType `$T` passed as parameter type") end
function to_parse_type(::Type{T})::TypeType where {T} TypeType{T}() end
function to_parse_type(u::Union)::UnionType UnionType(get_union_types(u)...) end
#function to_parse_type(f::FunctionWrapper{T, Tuple{String}})::FuncType{T} where {T} FuncType(f) end
#function to_parse_type(f::FunctionWrapper{Result{T, String}, Tuple{String}})::FuncType{T} where {T} FuncType(f) end

get_union_types(u::Union) = [u.a; get_union_types(u.b)]
get_union_types(u) = [u]

"""Identity `ParseType`"""
struct IdType <: ParseType{AbstractString} end
function (::IdType)(s::AbstractString)::Result{AbstractString, Union{}} Ok(s) end

"""`ParseType` which produces a `Bool`"""
struct BoolType <: ParseType{Bool} end
function (::BoolType)(s::AbstractString)::Result{Bool, String}
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
	choices::OrderedDict{AbstractString, T}
end
function ChoiceType(choices::Vararg{T})::ChoiceType{T} where {T <: AbstractString}
	dict = OrderedDict{T, T}()
	for choice in choices
		if haskey(dict, choice)
			error("Choice '$choice' is already in use")
		end
		dict[choice] = choice
	end
	ChoiceType{T}(dict)
end

function (c::ChoiceType{T})(s::AbstractString)::Result{T, String} where {T}
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
function (p::FuncType{N, T, U})(s::Vararg{AbstractString, N})::Result{U, String} where {N, T, U}
	val = @try_unwrap p.ty(s...)
	p.f(val)
end


"""`ParseType` which calls a type constructor to parse a value."""
struct TypeType{T} <: ParseType{T}
	function TypeType{T}() where {T}
		hasmethod(T, Tuple{AbstractString}) ? new{T}() : error("Type $T has no AbstractString constructor")
	end
	TypeType(U) = TypeType{U}()
end
function (::TypeType{T})(s::AbstractString)::Result{T, String} where {T}
	catch_result(() -> T(s))
end

"""`ParseType` which parses numerical values."""
struct NumType{T <: Number} <: ParseType{T} end
NumType(T) = NumType{T}()
function (::NumType{T})(s::AbstractString)::Result{T, String} where {T}
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
function (r::RangeType{T})(s::AbstractString)::Result{T, String} where {T}
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

"""`ParseType` which parses a delimited array of homogenous values."""
struct ArrayType{T} <: ParseType{Array{T,1}}
	ty::ParseType{T}
	min::Union{Int, Nothing}
	max::Union{Int, Nothing}
	delim::Union{Char, Array{Char}}
	function ArrayType(ty::ParseType,
	                   min::Union{Int, Nothing} = nothing,
	                   max::Union{Int,Nothing} = nothing;
	                   delimiter::Union{Char, Array{Char}} = ',')
		if nargs(ty) > 1
			error("`ArrayType` doesn't support composite inner types.")
		end
		T = output_type(ty)
		new{T}(ty, min, max, delimiter)
	end
end
function ArrayType(ty,
                   min::Union{Int, Nothing} = nothing,
                   max::Union{Int, Nothing} = nothing;
                   delimiter::Union{Char, Array{Char}} = ',')
	ArrayType(to_parse_type(ty), min, max, delimiter=delimiter)
end

function (self::ArrayType{T})(arg::AbstractString)::Result{Array{T,1}, String} where {T}
	args = split(arg, self.delim)
	if self.min !== nothing && self.min > length(args)
		error("Expected at least {self.min} argument(s), got {length(args)} instead")
	end
	if self.max !== nothing && length(args) > self.max
		error("Expected at most {self.max} argument(s), got {length(args)} instead")
	end
	try_collect(map(self.ty, args))::Result{Array{T,1}, String}
end

"""`ParseType` which parses multiple heterogenous values in a single parameter."""
struct TupleType{T <: Tuple} <: ParseType{T}
	types::Tuple{Vararg{ParseType}}

	function TupleType(types::Vararg{ParseType})
		T = Tuple{map(output_type, types)...}
		new{T}(types)
	end
end
#TupleType(types...) = TupleType(Tuple(map(to_parse_type, types)))
TupleType(types...) = TupleType(collect(map(to_parse_type, types))...)

function (tup::TupleType{T})(args::Vararg{AbstractString})::Result{T, String} where {T}
	result = ()
	if length(args) != length(tup.types)
		error("Expected $(length(tup.types)) values, got $(length(args)) values instead")
	end
	vals = []
	#map((vals) -> tuple(vals...), try_collect(map((f, v) -> f(v), tup.types, args)))
	for (ty, val) in zip(tup.types, args)
		push!(vals, @try_unwrap(ty(val)))
	end
	Ok(tuple(vals...))::Ok{T}
end

struct UnionType{T, U} <: ParseType{T}
	types::Array{ParseType}

	function UnionType(types::Vararg{ParseType})
		for ty in types
			if nargs(ty) != 1
				error("Composite types are not yet supported for 'UnionType'")
			end
		end
		T = Union{map(output_type, types)...}
		U = Union{Err{String}, map((ty) -> Ok{output_type(ty)}, types)...}
		new{T, U}(collect(types))
	end
end
UnionType(types...) = UnionType(collect(map(to_parse_type, types))...)

function (self::UnionType{T, U})(arg::AbstractString)::U where {T, U}
	for ty in self.types
		result = ty(arg)
		if is_ok(result)
			return result
		end
	end
	list = format_list(map((t) -> "'$t'", map(output_type, self.types)), conj="or")
	Err("Unable to parse '$arg'. Expected one of $list")
end

nargs(::ParseType)::Int = 1
nargs(t::TupleType)::Int = length(t.types)
nargs(::FuncType{N}) where {N} = N

end
