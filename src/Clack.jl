module Clack

using Maybe
using Results

import Base: parse

include("Util.jl")
include("Types.jl")
include("Parameters.jl")
using .Util
using .Types
using .Parameters

export Option, Argument, Command
export ParseType, BoolType, ChoiceType
export parse

struct Command
    options::Array{Option}
    arguments::Array{Argument}
    intersperse_args::Bool
    #f::Function
end

function parse(c::Command, args::Array{String})::Result{Dict{String, Any}, String}
    arg_stack = reverse(args)
    names = Dict()
    short_names = Dict()
    for opt in c.options
        names[opt.name] = opt
        if isa(opt.short, Some)
            short_names[opt.short.value] = opt
        end
    end
    pos_arg_stack = reverse(c.arguments)

    parse_options = true
    parsed = Dict{String, Any}()
    while !isempty(arg_stack)
        peek = arg_stack[end]
        if !startswith(peek, '-') || !parse_options
            #parse as positional arg
            if isempty(pos_arg_stack)
                return Err("Unexpected positional argument '$peek'")
            end
            arg = pop!(pos_arg_stack)
            parsed[arg.name] = @try_unwrap catch_result(() -> arg.type(peek))
        elseif peek == "--"
            parse_options = false
        elseif startswith(peek, "--")
            #parse as long arg
            if !haskey(names, peek[3:end])
                return Err("Unknown option '$peek'")
            end
            opt = names[peek[3:end]]
            pop!(arg_stack)
            if isempty(arg_stack)
                return Err("Missing value for option '$(opt.name)'")
            end
            parsed[opt.name] = @try_unwrap catch_result(() -> opt.type(arg_stack[end]))
        else
            #parse as short arg
        end
        pop!(arg_stack)
    end
    #check for missing args
    Ok(parsed)
end

function parse(c::Command)::Result{Function}
    parse(c, ARGS)
end

end # module
