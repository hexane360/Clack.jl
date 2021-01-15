module Clack

include("Utils.jl")
include("Types.jl")
include("Parameters.jl")
include("Commands.jl")
include("macros.jl")
using .Utils
using .Types
using .Parameters
using .Commands
using .macros

export Parameter, Flag, Option, Argument
export Command, call_cmd, parse_cmd
export ParseType, IdType, BoolType, NumType, RangeType, ChoiceType, FuncType, TypeType, TupleType

end # module
