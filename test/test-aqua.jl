@testitem "Aqua.jl" setup = [CommonSetup] begin
    using Aqua
    Aqua.test_all(TulipaEnergyModel)
end
