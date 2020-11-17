module Util

using Maybe
using Results

import Base: push!

export try_pop!, catch_result, format_list

function try_pop!(a::Array{T})::Maybe.T{T} where {T}
    empty(a) ? nothing : pop!(a)
end

function try_pop!(a::Array{T}, e::E)::Result{T, E} where {T, E}
    to_result(try_pop!(a), e)
end

function catch_result(r::Ok{T})::Ok{T} where {T} r end
function catch_result(r::Err{E})::Err{E} where {E} r end
function catch_result(v::Any)::Ok Ok(v) end
function catch_result(f::Function)::Result
    try
        catch_result(f())
    catch e
        Err(string(e))
    end
end

function format_list(list::Array)::String
    if length(list) == 0
        ""
    elseif length(list) == 1
        string(list[1])
    else
        formatted = join(list[1:end-1], ", ")
        "$formatted and $(list[end])"
    end
end

end
