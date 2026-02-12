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
# This array should contain the metrics to be included in the experiment run.
# Available values are: [
#     "obj_value",
#     "num_constraints",
#     "num_constraints_presolve",
#     "LP_gap",
#     "LP_gap_presolve",
#     "model_creation_time",
#     "model_solve_time"
# ]
metrics = [
    "obj_value",
    # "num_constraints",
    # "num_constraints_presolve",
    "LP_gap",
    # "LP_gap_presolve",
    # "model_creation_time",
    # "model_solve_time",
    # "model_create_time_std",
    # "model_solve_time_std",
]
experiment_inputs_dir = "debugging/experiment-inputs"
experiment_results_dir = "debugging/experiment-results"

# after how many seconds to stop taking samples (at least one sample will always be taken)
create_model_timeout = 86400 # seconds
run_model_timeout = 86400 #seconds

### LIST OF NAMES OF CASE STUDIES TO RUN
case_studies_to_run = ["2var-E2", "3var-E2", "2var-0T", "3var-0T"]
# case_studies_to_run = ["3var-E2"]

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

        if resultP2[] != 0.0 # we want to be at node 0 (root)
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
        res = obj.constant

        num_vars = length(terms)

        ## The line below initialises all the values to some 6.3e-310
        ## I want an array of zeros, so I use `fill` instead. They have the same type, but I will keep this here in case we need to change it.
        # resultP4 = Vector{Cdouble}(undef, num_vars)

        resultP4 = fill(Cdouble(0.0), num_vars)

        Gurobi.GRBcbget(cb_data, cb_where, Gurobi.GRB_CB_MIPNODE_REL, resultP4)

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

# CREATE THE BENCHMARK SUITE
const SUITE = BenchmarkGroup()
SUITE["create_model"] = BenchmarkGroup()
SUITE["run_model"] = BenchmarkGroup()

for case in case_studies_to_run
    input_folder = joinpath(pwd(), "$experiment_inputs_dir/$case")

    # Benchmark of creating the model
    if "model_creation_time" in metrics
        SUITE["create_model"]["$case"] = @benchmarkable begin
            create_model!(energy_problem)
        end samples = create_model_num_samples evals = create_model_num_evals seconds =
            create_model_timeout setup =
            (energy_problem = EnergyProblem(input_setup($input_folder)))
    end

    if "model_solve_time" in metrics
        key = "$case"
        # Benchmark of running the model
        SUITE["run_model"]["$case"] = @benchmarkable begin
            solve_model!(energy_problem)
        end samples = run_model_num_samples evals = run_model_num_evals seconds =
            run_model_timeout setup = begin
            energy_problem = create_model!(EnergyProblem(input_setup($input_folder)))

            if use_random_seeds
                JuMP.set_optimizer_attribute(energy_problem.model, "seed", Int(rand(1:2e6)))
            end
        end
    end
end

results_of_run = undef

if "model_creation_time" in metrics || "model_solve_time" in metrics
    results_of_run = run(SUITE; verbose = true)
end

# Save run times
if results_of_run != undef
    BenchmarkTools.save("$experiment_results_dir/runtimes.json", results_of_run)
end

metrics_dict = Dict()

for case in case_studies_to_run
    # "obj_value",
    # "num_constraints",
    # "num_constraints_presolve",
    # "LP_gap",
    # "LP_gap_presolve",
    # "model_creation_time",
    # "model_solve_time"

    metrics_results = []

    input_folder = joinpath(pwd(), "$experiment_inputs_dir/$case")

    energy_problem = EnergyProblem(input_setup(input_folder))
    create_model!(energy_problem)

    if "LP_gap_presolve" in metrics
        ran_already[] = false
        LP_relaxation[] = -1

        global energy_problem_cb
        energy_problem_cb = energy_problem

        JuMP.set_optimizer_attribute(
            energy_problem.model,
            Gurobi.CallbackFunction(),
            root_relaxation_callback,
        )
    end

    solve_model!(energy_problem)

    if "obj_value" in metrics
        obj_value = energy_problem.objective_value
        push!(metrics_results, obj_value)
    end

    if "num_constraints" in metrics
        num_constraints_before_presolve =
            num_constraints(energy_problem.model; count_variable_in_set_constraints = false)
        push!(metrics_results, num_constraints_before_presolve)
    end

    if "num_constraints_presolve" in metrics
        backend_reference = unsafe_backend(energy_problem.model)

        presolved_pointer = Ref{Ptr{Cvoid}}()
        GRBpresolvemodel(backend_reference, presolved_pointer)

        presolved_model_reference = presolved_pointer[]

        num_constraints_after_presolve_pointer = Ref{Cint}()
        Gurobi.GRBgetintattr(
            presolved_model_reference,
            "NumConstrs",
            num_constraints_after_presolve_pointer,
        )

        num_constraints_after_presolve = num_constraints_after_presolve_pointer[]
        push!(metrics_results, num_constraints_after_presolve)
    end

    if "LP_gap" in metrics
        relax_integrality(energy_problem.model)
        optimize!(energy_problem.model)

        LP_relaxation_before_presolve = objective_value(energy_problem.model)

        println("GUROBI SPECIAL VALUE: " * string(LP_relaxation_before_presolve))

        push!(metrics_results, metrics_results[1] / LP_relaxation_before_presolve)
    end

    if "LP_gap_presolve" in metrics
        actual_presolve_LP_relaxation = metrics_results[1]

        if LP_relaxation[] > 0.0
            actual_presolve_LP_relaxation = LP_relaxation[]
        end

        push!(metrics_results, metrics_results[1] / actual_presolve_LP_relaxation)
    end

    if "model_creation_time" in metrics
        creation_time = mean(results_of_run["create_model"][case]).time / 1e9

        push!(metrics_results, creation_time)
    end

    if "model_solve_time" in metrics
        solve_time = mean(results_of_run["run_model"][case]).time / 1e9

        push!(metrics_results, solve_time)
    end

    if "model_create_time_std" in metrics
        creation_time_std = std(results_of_run["create_model"][case]).time / 1e9

        push!(metrics_results, creation_time_std)
    end

    if "model_solve_time_std" in metrics
        solve_time_std = std(results_of_run["run_model"][case]).time / 1e9

        push!(metrics_results, solve_time_std)
    end

    metrics_dict[case] = metrics_results
end

open("$experiment_results_dir/results.csv", "w") do io
    columns = "case," * join(metrics, ",")
    println(io, columns)

    for (key, value) in metrics_dict
        to_print = "$key," * join(value, ",")
        println(io, to_print)
    end
end
