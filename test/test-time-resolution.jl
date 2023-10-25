@testset "Time resolution" begin
    @testset "resolution_matrix" begin
        rp_periods = [1:4, 5:8, 9:12]
        time_steps = [1:4, 5:8, 9:12]
        expected = [
            1.0 0.0 0.0
            0.0 1.0 0.0
            0.0 0.0 1.0
        ]
        @test resolution_matrix(rp_periods, time_steps) == expected

        time_steps = [1:3, 4:6, 7:9, 10:12]
        expected = [
            1.0 1/3 0.0 0.0
            0.0 2/3 2/3 0.0
            0.0 0.0 1/3 1.0
        ]
        @test resolution_matrix(rp_periods, time_steps) == expected

        time_steps = [1:6, 7:9, 10:10, 11:11, 12:12]
        expected = [
            2/3 0.0 0.0 0.0 0.0
            1/3 2/3 0.0 0.0 0.0
            0.0 1/3 1.0 1.0 1.0
        ]
        @test resolution_matrix(rp_periods, time_steps) == expected
    end

    @testset "compute_rp_periods" begin
        # regular
        time_steps1 = [1:4, 5:8, 9:12] # every 4 hours
        time_steps2 = [1:3, 4:6, 7:9, 10:12] # every 3 hours
        time_steps3 = [i:i for i ∈ 1:12] # hourly

        @test compute_rp_periods([time_steps1, time_steps2]) == time_steps1
        @test compute_rp_periods([time_steps1, time_steps2, time_steps3]) == time_steps1
        @test compute_rp_periods([time_steps2, time_steps3]) == time_steps2

        # Irregular
        time_steps4 = [1:6, 7:9, 10:11, 12:12]
        time_steps5 = [1:2, 3:4, 5:12]
        @test compute_rp_periods([time_steps1, time_steps4]) == [1:6, 7:9, 10:12]
        @test compute_rp_periods([time_steps1, time_steps5]) == [1:4, 5:12]
        @test compute_rp_periods([time_steps4, time_steps5]) == [1:6, 7:12]
    end
end
