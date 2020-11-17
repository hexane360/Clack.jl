using Test

using Results

using Clack
using Clack: BoolType, format_list

@testset "BoolType" begin
    ty = BoolType()
    @inferred Union{Ok{Bool}, Err{String}} ty("")
    @inferred Union{Ok{Bool}, Err{String}} ty("t")
    @test ty("t") == Ok(true)
    @test ty("T") == Ok(true)
    @test ty("f") == Ok(false)
    @test ty("FaLsE") == Ok(false)
    @test ty("5") == Err("Unable to parse '5' as Bool")
    @test ty("") == Err("Unable to parse '' as Bool")
end

@testset "format_list" begin
    @test format_list([]) == ""
    @test format_list(["1"]) == "1"
    @test format_list(["1", "2"]) == "1 and 2"
    @test format_list(["1", "2", "3"]) == "1, 2 and 3"
end

@testset "Positional Args" begin
    c = Command([Option("dontuse", nothing, identity)],
                [Argument("pos1", identity), Argument("pos2", identity)], true)

    @test Dict(5 => "test") == Dict(5 => "test")
    @test parse(c, ["--dontuse", "test"]) == Ok(Dict{String,Any}("dontuse" => "test"))
    @test parse(c, ["--", "--dontuse", "test"]) == Ok(Dict{String,Any}("pos1" => "--dontuse", "pos2" => "test"))
end
