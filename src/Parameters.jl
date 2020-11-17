module Parameters

using Maybe
using ..Types

export Parameter, Flag, Option, Argument

abstract type Parameter{T} end

struct Flag <: Parameter{Bool}
    name::String
    names::Tuple{Array{String}, Array{String}}
    short::Tuple{Maybe.T{Char}, Maybe.T{Char}}
end

struct Option{T} <: Parameter{T}
    name::String
    display_names::Array{String}
    short::Maybe.T{Char}
    type::ParseType{T}
end

struct Argument{T} <: Parameter{T}
    name::String
    type::ParseType{T}
end

end
