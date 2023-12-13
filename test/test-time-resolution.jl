@testset "Time resolution" begin
    @testset "compute_rp_partition" begin
        # regular
        partition1 = [1:4, 5:8, 9:12] # every 4 hours
        partition2 = [1:3, 4:6, 7:9, 10:12] # every 3 hours
        partition3 = [i:i for i ∈ 1:12] # hourly

        @testset "strategy greedy (default)" begin
            @test compute_rp_partition([partition1, partition2]) == partition1
            @test compute_rp_partition([partition1, partition2, partition3]) == partition1
            @test compute_rp_partition([partition2, partition3]) == partition2
        end

        @testset "strategy all" begin
            @test compute_rp_partition([partition1, partition2]; strategy = :all) ==
                  [1:3, 4:4, 5:6, 7:8, 9:9, 10:12]
            @test compute_rp_partition([partition1, partition2, partition3]; strategy = :all) ==
                  partition3
            @test compute_rp_partition([partition2, partition3]; strategy = :all) == partition3
        end

        # Irregular
        time_steps4 = [1:6, 7:9, 10:11, 12:12]
        time_steps5 = [1:2, 3:4, 5:12]

        @testset "strategy greedy (default)" begin
            @test compute_rp_partition([partition1, time_steps4]) == [1:6, 7:9, 10:12]
            @test compute_rp_partition([partition1, time_steps5]) == [1:4, 5:12]
            @test compute_rp_partition([time_steps4, time_steps5]) == [1:6, 7:12]
        end

        @testset "strategy all" begin
            @test compute_rp_partition([partition1, time_steps4]; strategy = :all) ==
                  [1:4, 5:6, 7:8, 9:9, 10:11, 12:12]
            @test compute_rp_partition([partition1, time_steps5]; strategy = :all) ==
                  [1:2, 3:4, 5:8, 9:12]
            @test compute_rp_partition([time_steps4, time_steps5]; strategy = :all) ==
                  [1:2, 3:4, 5:6, 7:9, 10:11, 12:12]
        end

        @testset "Bad strategy" begin
            @test_throws ErrorException compute_rp_partition(
                [partition1, partition2],
                strategy = :bad,
            )
        end
    end
end
