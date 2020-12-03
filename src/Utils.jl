module Utils

using Maybe
using Results

import Base: push!

export catch_result, format_list, filter_none, plural

# function try_pop!(a::AbstractArray{T})::Maybe.T{T} where {T}
# 	isempty(a) ? nothing : Some(pop!(a))
# end

# try_pop!(a, e)::Result = to_result(try_pop!(a), e)

# function try_get(d::AbstractDict{K, V}, k::K)::Maybe.T{V} where {K, V}
# 	haskey(d, k) ? Some(d[k]) : nothing
# end

# try_get(d, k, e)::Result = to_result(try_get(d, k), e)

"""
Wraps a function that *should* return a result, making the following substitutions:
	- Bare `T`s wrapped as `Ok{T}` before returning
	- Exceptions are returned as Err{E}
"""
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

"""Formats a list of values in a human-readable format."""
function format_list(list::AbstractArray)::String
	if length(list) == 0
		""
	elseif length(list) == 1
		string(list[1])
	else
		formatted = join(list[1:end-1], ", ")
		"$formatted and $(list[end])"
	end
end
format_list(list)::String = format_list(collect(list))

function plural(list::AbstractArray)::String
	length(list) == 1 ? "" : "s"
end

"""Filters `nothing` values from an iterator."""
function filter_none(itr)
	map((s) -> isa(s, Some) ? s.value : s,
	    Iterators.filter((v) -> !isnothing(v), itr))
end

end # module
