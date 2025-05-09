# Run from project folder with
#
#   julia --project=. utils/scripts/model-mps-update.jl
#
include("model-mps-common.jl")

root_folder = joinpath(@__DIR__, "..", "..")

# Reset folder
mps_folder = joinpath(root_folder, "benchmark", "model-mps-folder")
if isdir(mps_folder)
    chmod(mps_folder, 0o777) # Change permission: all users have read, write, and execute permissions.
    rm(mps_folder; force = true, recursive = true)
end
mkdir(mps_folder)

test_inputs = joinpath(root_folder, "test", "inputs")

# Create .mps for test files
for folder in filter(isdir, readdir(test_inputs; join = true))
    @info "Create mps for $folder in $mps_folder"
    create_mps(folder, mps_folder)
end
