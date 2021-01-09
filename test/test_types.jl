using Clack.Types
#ParseType, IdType, BoolType, ChoiceType, WrapType, TypeType, TupleType, NumType, RangeType
#to_parse_type, output_type, nargs

@testset "FuncType" begin
	ty = FuncType((a) -> Ok(a*"!"))
	#@test ty("works") == Ok("works!")
	@test nargs(ty) == 1
	@test hasmethod(ty, NTuple{nargs(ty), AbstractString})

	ty = FuncType((_) -> Err("error"))
	@test nargs(ty) == 1
	@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
end

@testset "TypeType" begin
	ty = TypeType(Symbol)
	@test ty("test") == Ok(:test)
	@test typeof(unwrap(ty("test"))) == output_type(ty) == Symbol
	@test nargs(ty) == 1
	@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
end

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
	@test typeof(unwrap(ty("T"))) == output_type(ty)
	@test nargs(ty) == 1
	@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
end

@testset "ChoiceType" begin
	ty = ChoiceType("a", "b", "c")
    @inferred Union{Ok{String}, Err{String}} ty("")
	@test ty("a") == Ok("a")
	@test ty("b") == Ok("b")
	@test ty("d") == Err("Unexpected value 'd', possible choices: a, b and c")
	@test typeof(unwrap(ty("a"))) == output_type(ty)
	@test nargs(ty) == 1
	@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
end

@testset "NumType" begin
	@testset "NumType{Int64}" begin
		ty = NumType{Int64}()
		@inferred Union{Ok{Int64}, Err{String}} ty("")
		@test ty("592830") == Ok(592830)
		@test ty("-9999") == Ok(-9999)
		@test ty("13.5") == Err("Unable to parse '13.5' as Int64")
		@test typeof(unwrap(ty("5"))) == output_type(ty)
		@test nargs(ty) == 1
		@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
	end

	@testset "NumType{Float64}" begin
		ty = NumType{Float64}()
		@inferred Union{Ok{Float64}, Err{String}} ty("")
		@test ty("13.5") ≈ Ok(13.5)
		@test typeof(unwrap(ty("13.5"))) == output_type(ty)
		@test nargs(ty) == 1
		@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
	end
end

@testset "RangeType" begin
	ty = RangeType(0:5)
	@test ty("5") == Ok(5)
	@test ty("6") == Err("Value '6' out of range 0:5")
	@test ty("f") == Err("Unable to parse 'f' as Int64")
	@test typeof(unwrap(ty("5"))) == output_type(ty)
	@test nargs(ty) == 1
	@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
end

@testset "ArrayType" begin
	ty = ArrayType(Int64, 1, 4, delimiter=';')
	@test ty("1") == Ok([1])
	@test ty("1;2;3") == Ok([1,2,3])
	@test ty("1;t;u") == Err("Unable to parse 't' as Int64")
	@test typeof(unwrap(ty("1"))) == output_type(ty)
	@test nargs(ty) == 1
	@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
end

@testset "TupleType" begin
	ty = TupleType(String, Int64, Float64)
	@test ty("1", "2", "0") == Ok(("1", 2, 0.0))
	@test ty("1", "fail", "0") == Err("Unable to parse 'fail' as Int64")
	@test typeof(unwrap(ty("1", "2", "0"))) == output_type(ty)
	@test nargs(ty) == 3
	@test hasmethod(ty, NTuple{nargs(ty), AbstractString})
end

@testset "to_parse_type" begin
	@test to_parse_type(Int64) == NumType{Int64}()
	@test to_parse_type(Complex{Int64}) == NumType{Complex{Int64}}()
	@test to_parse_type(Bool) == BoolType()
	@test to_parse_type(AbstractString) == IdType()
	#@test to_parse_type(1:5) == RangeType{Int64}(1:5)
	@test isa(to_parse_type((_) -> Ok(5)), FuncType{1, AbstractString, Int64})
end
