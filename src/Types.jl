module Types

using Results
using FunctionWrappers: FunctionWrapper

using ..Util

export ParseType, BoolType, ChoiceType, WrapType, TypeType, TupleType, NumType, RangeType
#export ToParseType

abstract type ParseType{T} end

function output_type(::ParseType{T}) where {T} T end

#const ToParseType = Union{ParseType,
#                          Type,
#                          Tuple{ToParseType},
#                          FunctionWrapper{T, Tuple{String}},
#                          FunctionWrapper{Result{T, String}, Tuple{String}}}

to_parse_type(p::ParseType)::ParseType = p
to_parse_type(::Type{Bool})::BoolType = BoolType()
to_parse_type(t::Type)::TypeType = TypeType{t}()
to_parse_type(tup::Tuple{Vararg{Any}})::TupleType =  TupleType(map(to_parse_type, tup))
function to_parse_type(::Type{T})::NumType where {T <: Number} NumType{T}() end
function to_parse_type(f::Function)::FuncType FuncType(f) end
#function to_parse_type(f::FunctionWrapper{T, Tuple{String}})::FuncType{T} where {T} FuncType(f) end
#function to_parse_type(f::FunctionWrapper{Result{T, String}, Tuple{String}})::FuncType{T} where {T} FuncType(f) end

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

struct ChoiceType{T} <: ParseType{T}
    choices::Dict{String, T}
end
function (c::ChoiceType{T})(s::String)::Result{T, String} where {T}
    if s ∈ c.choices
        Ok(s[c.choices])
    else
        Err("Unexpected value $s, possible choices: ")
    end
end

struct FuncType{T} <: ParseType{T}
    f::FunctionWrapper{Result{T, String}, Tuple{String}}

    function FuncType(f::Function)
        if !hasmethod(f, Tuple{String})
            error("Parse function not callable with type 'String'")
        end
        ret_types = Base.return_types(f, Tuple{String})
        # strip result types from inference
        T = Union{strip_result_type(ret_types)...}
        new{T}(f)
    end
end
function (f::FuncType{T})(s::String)::Result{T, String} where {T}
    catch_result(() -> f.f(s))
end

struct TypeType{T} <: ParseType{T}
    function TypeType{T}() where {T}
        hasmethod(T, Tuple{String}) ? new{T}() : error("Type $T has no String constructor")
    end
    TypeType(U) = TypeType{U}()
end
function (::TypeType{T})(s::String)::Result{T, String} where {T}
    catch_result(() -> T(s))
end

struct NumType{T <: Number} <: ParseType{T} end
function (::NumType{T})(s::String)::Result{T, String} where {T}
    catch_result(() -> parse(T, s))
end

struct RangeType{T <: Number} <: ParseType{T}
    range::AbstractRange{T}
end
function (r::RangeType{T})(s::String)::Result{T, String} where {T}
    num = @try_unwrap NumType{T}()(s)
    if !(minimum(r.range) <= num <= maximum(r.range))
        return Err("Number '$num' out of range $(minimum(r.range)):$(maximum(r.range))")
    end
    Ok(num)
end

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

struct WrapType{T, U} <: ParseType{U}
    ty::ParseType{T}
    f::FunctionWrapper{Result{U, String}, Tuple{T}}

    function WrapType(ty::ParseType{T}, f::Function) where {T}
        if !hasmethod(f, Tuple{T})
            error("Wrapping function not callable with type '$T'")
        end
        ret_types = Base.return_types(f, Tuple{T})
        # strip result types from inference
        U = Union{strip_result_type(ret_types)...}
        new{T, U}(ty, f)
    end
end
function WrapType(ty, f::Function) where {U}
    ty = to_parse_type(ty)
    WrapType{output_type(ty), U}(ty, f)
end
function (p::WrapType{T})(s::String)::Result{T, String} where {T}
    val = @try_unwrap p.ty(s)
    p.f(val)
end

struct TupleType{T} <: ParseType{T}
    types::Tuple{Vararg{ParseType}}

    function TupleType(types::Tuple{Vararg{ParseType}})
        T = Tuple{map(output_type, types)...}
        new{T}(types)
    end
end
function (tup::TupleType{T})(stack::Array{String})::Result{T, <:Any} where {T}
    result = ()
    for ty in tup.types
        if isempty(stack)
            return Err("Missing argument")
        end
        result = tuple(result..., @try_unwrap ty(pop!(stack)))
    end
    Ok(result)::Ok{T}
end

end
