using Clack.Utils

@testset "utils" begin

	@testset "format_list" begin
		@test format_list([]) == ""
		@test format_list(["1"]) == "1"
		@test format_list(["1", "2"]) == "1 and 2"
		@test format_list(["1", "2", "3"]) == "1, 2 and 3"
	end

end
