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
function to_parse_type(t::Type)::ParseType
    if t == Bool
        BoolType()
    elseif t <: Number
        NumType{t}()
    else
        TypeType{t}()
    end
end
function to_parse_type(tup::Tuple{Vararg{Any}})::ParseType
    mapped = map(to_parse_type, tup)
    output_types = Tuple{map(output_type, mapped)...}
    TupleType{output_types}(mapped)
end
function to_parse_type(f::FunctionWrapper{T, Tuple{String}})::FuncType{T} where {T} FuncType(f) end
function to_parse_type(f::FunctionWrapper{Result{T, String}, Tuple{String}})::FuncType{T} where {T} FuncType(f) end

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
    f::Union{FunctionWrapper{T, Tuple{String}},
             FunctionWrapper{Result{T, String}, Tuple{String}}}
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
    if num < minimum(r.range) || num > maximum(r.range)
        return Err("Number '$num' out of range $(minimum(r.range)):$(maximum(r.range))")
    end
    Ok(num)
end

struct WrapType{T, U} <: ParseType{U}
    ty::ParseType{T}
    f::FunctionWrapper{Result{U, String}, Tuple{T}}

    function WrapType(ty::ParseType{T}, f::FunctionWrapper{Result{U, String}, Tuple{T}}) where {T, U}
        new{T, U}(ty, f)
    end
end
function WrapType(ty, f::FunctionWrapper{Result{U, String}, Tuple{Any}}) where {U}
    ty = to_parse_type(ty)
    WrapType{output_type(ty), U}(ty, f)
end
function (p::WrapType{T})(s::String)::Result{T, String} where {T}
    val = @try_unwrap p.ty(s)
    p.f(val)
end

struct TupleType{T} <: ParseType{T}
    types::Tuple{Vararg{ParseType}}
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
