using BenchmarkTools
using TulipaEnergyModel
using TulipaIO
using DuckDB
using JuMP
using Gurobi

### INSTRUCTIONS

# 1. Copy the case study input files into the `experiment-inputs` directory
# 2. Run the script
# 3. In the `experiment-results` folder, runtimes.json will contain the BenchmarkTools output,
#   and obj.csv will contain the objective values and potentially LP relaxations

### SETUP
run_case_studies_name_check = true # set to `true` if you want to run a function which checks whether each case study exists
use_random_seeds = true # set to `true` if you want the solver to use a random seed each time it solves an energy problem instance
calculate_LP_relaxation = true # set to `true` if you want to store the LP relaxation values for each case study
experiment_inputs_dir = "debugging/experiment-inputs"
experiment_results_dir = "debugging/experiment-results"

### LIST OF NAMES OF CASE STUDIES TO RUN
case_studies_to_run = ["basic", "3var-E2", "3var-E3", "2var-E2", "2var-0T", "3var-0T"]

### BENCHMARK PARAMETERS

# number of samples to run
create_model_num_samples = 2
run_model_num_samples = 2

# this should be kept to 1
create_model_num_evals = 1
run_model_num_evals = 1

### Global variables
global energy_problem_cb = undef
ran_already = Ref(false)
LP_relaxation = Ref(-1.0)
global LP_relaxation_values = Dict()

# after how many seconds to stop taking samples (at least one sample will always be taken)
create_model_timeout = 86400 # seconds
run_model_timeout = 86400 #seconds

function root_relaxation_callback(cb_data, cb_where::Cint)
    if ran_already[]
        return nothing
    end

    if cb_where == Gurobi.GRB_CB_MIPNODE
        resultP = Ref{Cint}()
        Gurobi.GRBcbget(cb_data, cb_where, Gurobi.GRB_CB_MIPNODE_STATUS, resultP)

        if resultP[] != Gurobi.GRB_OPTIMAL
            return  # Solution is something other than optimal.
        end

        resultP2 = Ref{Cdouble}(41)

        Gurobi.GRBcbget(cb_data, cb_where, Gurobi.GRB_CB_MIPNODE_NODCNT, resultP2)

        if resultP2[] != 0.0
            return nothing
        end

        resultP3 = Ref{Cint}(41)

        Gurobi.GRBcbget(cb_data, cb_where, Gurobi.GRB_CB_MIPNODE_STATUS, resultP3)

        if resultP3[] != Gurobi.GRB_OPTIMAL
            return nothing
        end

        ran_already[] = true

        obj = JuMP.objective_function(energy_problem_cb.model)
        terms = obj.terms

        num_vars = length(terms)

        ## The line below initialises all the values to some 6.3e-310
        ## I want an array of zeros, so I use `fill` instead. They have the same type, but I will keep this here in case we need to change it.
        # resultP4 = Vector{Cdouble}(undef, num_vars)

        resultP4 = fill(Cdouble(0.0), num_vars)

        println("startttt")
        println(typeof(resultP4))

        Gurobi.GRBcbget(cb_data, cb_where, Gurobi.GRB_CB_MIPNODE_REL, resultP4)

        res = obj.constant

        for (coeff, var_val) in zip(collect(values(terms)), resultP4)
            res += coeff * var_val
        end

        LP_relaxation[] = res
    end
    return nothing
end

# checks whether each case study in `case_studies_to_run` exists in the experiment-inputs directory
function check_case_study_names(case_studies_to_run)
    existing_case_studies = readdir(joinpath(pwd(), experiment_inputs_dir))

    for case in case_studies_to_run
        if !(case in existing_case_studies)
            throw(
                "The case study with name '$case' does not exist in the $experiment_inputs_dir folder. To disable this check, set `run_case_studies_name_check` to `false`",
            )
        end
    end
end

if run_case_studies_name_check
    check_case_study_names(case_studies_to_run)
end

# DB connection helper
function input_setup(input_folder)
    connection = DBInterface.connect(DuckDB.DB)

    TulipaIO.read_csv_folder(
        connection,
        input_folder;
        schemas = TulipaEnergyModel.schema_per_table_name,
    )
    return connection
end

global energy_problem_solved = Dict()

# CREATE THE BENCHMARK SUITE
const SUITE = BenchmarkGroup()
SUITE["create_model"] = BenchmarkGroup()
SUITE["run_model"] = BenchmarkGroup()

for case in case_studies_to_run
    input_folder = joinpath(pwd(), "$experiment_inputs_dir/$case")

    # Benchmark of creating the model
    SUITE["create_model"]["$case"] = @benchmarkable begin
        create_model!(energy_problem)
    end samples = create_model_num_samples evals = create_model_num_evals seconds =
        create_model_timeout setup =
        (energy_problem = EnergyProblem(input_setup($input_folder)))

    key = "$case"
    # Benchmark of running the model
    SUITE["run_model"]["$case"] = @benchmarkable begin
        solve_model!(energy_problem)
    end samples = run_model_num_samples evals = run_model_num_evals seconds = run_model_timeout setup =
        begin
            energy_problem = create_model!(EnergyProblem(input_setup($input_folder)))

            global energy_problem_cb
            energy_problem_cb = energy_problem

            if calculate_LP_relaxation
                ran_already[] = false
                LP_relaxation[] = -1

                JuMP.set_optimizer_attribute(
                    energy_problem.model,
                    Gurobi.CallbackFunction(),
                    root_relaxation_callback,
                )
            end

            if use_random_seeds
                JuMP.set_optimizer_attribute(energy_problem.model, "seed", Int(rand(1:2e6)))
            end
        end teardown = (global energy_problem_solved;
    energy_problem_solved[$key] = energy_problem.objective_value;
    global LP_relaxation_values;
    LP_relaxation_values[$key] = LP_relaxation[];
    ran_already[] = false)

    LP_relaxation_values[case] = LP_relaxation[]
end

results_of_run = run(SUITE; verbose = true)

# Save run times
BenchmarkTools.save("$experiment_results_dir/runtimes.json", results_of_run)

if calculate_LP_relaxation
    open("$experiment_results_dir/obj.csv", "w") do io
        println(io, "case_study,lp_relaxation_obj,obj")

        for (key, value) in LP_relaxation_values
            obj = energy_problem_solved[key]
            println(io, "$key,$value,$obj")
        end
    end
else
    open("$experiment_results_dir/obj.csv", "w") do io
        println(io, "case_study,obj")

        for (key, value) in energy_problem_solved
            println(io, "$key,$value")
        end
    end
end
# println(energy_problem_solved)

# println(energy_problem_solved["basic"])

# # Save optimal solution
# for (key, value) in energy_problem_solved
#     debugFolder = joinpath(pwd(), "debugging\\results")
#     exportFolder = mkpath(joinpath(debugFolder, key))
#     save_solution!(value)
#     export_solution_to_csv_files(exportFolder, value)
#     filePath = joinpath(exportFolder, "objective_value.txt")
# end
