# AGENTS.md

This file provides guidance to AI coding assistants working on TulipaEnergyModel.jl.
It applies to any coding agent (for example, Copilot, Claude, or similar tools).

For full developer documentation, see `docs/src/90-contributing/91-developer.md`.

## Architecture

Julia package for modeling and optimization of electric energy systems. Uses DuckDB for data handling, JuMP for optimization modeling, and HiGHS as the default solver. Part of the Tulipa ecosystem (TulipaIO, TulipaBuilder, TulipaClustering).

### Source Structure

- `src/TulipaEnergyModel.jl` — Main module; all `using` statements live here
- `src/structures.jl` — Core types: `EnergyProblem`, `TulipaVariable`, `TulipaConstraint`, `TulipaExpression`
- `src/run-scenario.jl` — High-level `run_scenario` entry point
- `src/create-model.jl` — `create_model!` / `create_model`
- `src/solve-model.jl` — `solve_model!` / `solve_model` / `save_solution!`
- `src/objective.jl` — Objective function construction
- `src/model-preparation.jl` — Data massage before model creation
- `src/data-preparation.jl` — `populate_with_defaults!`
- `src/data-validation.jl` — Input validation
- `src/io.jl` — `create_internal_tables!` / `export_solution_to_csv_files`
- `src/input-schemas.jl` + `src/input-schemas.json` — Table schema definitions
- `src/model-parameters.jl` — `ModelParameters` struct
- `src/solver-parameters.jl` — Solver parameter handling
- `src/utils.jl` — Utility functions
- `src/variables/` (7 files) — Variable creation (flows, investments, storage, etc.)
- `src/constraints/` (16 files) — Constraint creation (capacity, energy, transport, etc.)
- `src/expressions/` (3 files) — Expression creation (storage, intersection, multi-year)
- `src/rolling-horizon/` (4 files) — Rolling horizon implementation
- `src/sql/` (3 SQL files) — SQL templates for creating tables

**Dynamic includes:** The main module uses a loop to include all `.jl` files from `variables/`, `constraints/`, and `expressions/` directories. New files
added to these directories are automatically included.

### Pipeline Flow

**All-in-one:** `run_scenario(connection)`

**High-level** (using `EnergyProblem` struct):

1. `EnergyProblem(connection)` — creates internal tables, computes variable/constraint indices
2. `create_model!(energy_problem)` — builds the JuMP model
3. `solve_model!(energy_problem)` — solves the optimization
4. `save_solution!(energy_problem)` — stores results back in DuckDB

**Low-level** (without `EnergyProblem`, for finer control):

1. `create_internal_tables!(connection)` — data preparation
2. `compute_variables_indices(connection)` / `compute_constraints_indices(connection)` — index computation
3. `prepare_profiles_structure(connection)` — profile setup
4. `create_model(connection, variables, constraints, profiles, model_parameters)` — builds model
5. `solve_model(model)` — solves the optimization
6. `save_solution!(connection, model, variables, constraints)` — stores results

See `test/test-pipeline.jl` for examples of both levels.

## Performance Requirements

Apply these guidelines with judgement. Not every function is performance-critical. Focus optimization efforts on hot paths and frequently called code.
If necessary, check the [Julia Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/).
To investigate performance issues, check the "Investigating performance issues" section in docs/src/90-contributing/91-developer.md.

### Anti-Patterns to Avoid

#### Type instability

Functions must return consistent concrete types. Check with `@code_warntype`.

- Bad: `f(x) = x > 0 ? 1 : 1.0`
- Good: `f(x) = x > 0 ? 1.0 : 1.0`

#### Abstract field types

Struct fields must have concrete types or be parameterized.

- Bad: `struct Foo; data::AbstractVector; end`
- Good: `struct Foo{T<:AbstractVector}; data::T; end`

#### Untyped containers

- Bad: `Vector{Any}()`, `Vector{Real}()`
- Good: `Vector{Float64}()`, `Vector{Int}()`

#### Non-const globals

- Bad: `THRESHOLD = 0.5`
- Good: `const THRESHOLD = 0.5`

#### Unnecessary allocations

- Use views instead of copies (`@view`, `@views`)
- Pre-allocate arrays instead of `push!` in loops
- Use in-place operations (functions ending with `!`)

#### Captured variables

When creating anonymous functions inside a local scope, don't use variables from that local scope.

#### Splatting penalty

Avoid splatting (`...`) in performance-critical code.

#### Abstract return types

Avoid returning `Union` types or abstract types.

### Best Practices

- Use `@inbounds` when bounds are verified. Be sure when doing this because it might cause crashes.
- Use broadcasting (dot syntax) for element-wise operations
- Avoid `try-catch` in hot paths
- Use function barriers to isolate type instability

## Code Conventions

Linting and formatting: Use `pre-commit` (which includes formatting checks) before committing.

**CRITICAL:** This list should be kept in sync with `docs/src/90-contributing/91-developer.md`.

Lightweight rules (see developer docs for full details):

- Naming: `CamelCase` for classes/modules, `snake_case` for functions/variables, `kebab-case` for file names and doc reference tags
- Imports: prefer `using Package: A, B, C`; avoid bare `using Package`; centralize `using` declarations in `src/TulipaEnergyModel.jl`
- Returns: explicitly state what a function returns; use explicit `return`
- Constructors: use `function foo()` not `foo() = ...`
- Globals: `UPPER_CASE` for constants
- Exports: define exports in the source file that owns the public functions
- Comments: complete sentences, prefer why over how
- Markdown docs: tables must satisfy MD060 column alignment

## Documentation Practices and Requirements

Framework: [Diataxis](https://diataxis.fr/)

Docstring requirements:

- Scope: all elements of public interface
- Include: function signatures and arguments list
- Automation: `DocStringExtensions.TYPEDSIGNATURES` (`TYPEDFIELDS` used sparingly)
- See also: add links for functions with same name (multiple dispatch)

## Design Principles

- Elegance and concision in both interface and implementation
- Fail fast with actionable error messages rather than hiding problems
- Validate invariants explicitly in subtle cases
- Avoid over-adherence to backwards compatibility for internal helpers

## Contribution Workflow

Branch naming: `feature/description` or `fix/description`

1. Create feature branch
2. Follow style guide and run formatter
3. Follow the style guide and run pre-commit when committing
4. Ensure tests pass
5. Submit pull request

**CRITICAL**: When making commits, always add a co-authored line with the tool name, the agent model, and the relevant e-mail. For instance "Co-Authored-By: Claude Code (claude-sonnet-4-6) <noreply@anthropic.com>"

## Development Commands

**CRITICAL:** Always use `julia --project=<env>` when running Julia code. **NEVER** use bare `julia` or `julia --project` without specifying the environment.

**CRITICAL:** Use the testing filters to avoid running too many tests at once.

## Testing Strategy

Uses [TestItemRunner.jl](https://github.com/julia-vscode/TestItemRunner.jl) with `@testitem`, `@testsnippet`, `@testmodule` — **not** standard `@testset`.
 Test inputs are in `test/inputs/`.

Never run the full test suite unless you are explicitly asked to. Instead, run only the tests you created or modified; for example, for `test-model.jl` run `julia --project=test test/runtests.jl --file test-model`.

### Shared Setup (in `test/utils.jl`)

- `@testsnippet CommonSetup` — imports all standard libraries, defines `INPUT_FOLDER`, fixture helpers (`_tiny_fixture`, `_storage_fixture`, `_multi_year_
fixture`)
- `@testmodule TestData` — provides `TestData.simplest_data` dict for minimal test data

### Available Tags (from `TAGS_DATA` in `test/runtests.jl`)

- **Test types:** `:unit`, `:integration`, `:validation`
- **Complexity:** `:fast`, `:slow`
- **Feature areas:** `:case_study`, `:data_validation`, `:data_preparation`, `:io`, `:pipeline`

### Writing New Tests

```julia
@testitem "Description" setup = [CommonSetup] tags = [:unit, :fast] begin
    @test result == expected
end
```

New tags must be added to `TAGS_DATA` in `test/runtests.jl`. Target: 100% test coverage.

### MPS Regression Testing

MPS files in `benchmark/model-mps-folder/` serve as regression tests for the optimization model. The `CompareMPS.yml` workflow runs automatically on PRs.

- If your change intentionally modifies the model, update MPS files: `julia --project=. utils/scripts/model-mps-update.jl`
- To check without updating: `julia --project=. utils/scripts/model-mps-compare.jl`
- If MPS comparison fails unexpectedly, investigate using the compare script log

## Troubleshooting

### Type instability in the code

- Symptom: Poor performance, many allocations
- Diagnosis: `@code_warntype` on suspect function
- Solution: See performance anti-patterns above

### Pre-commit or formatter fails

- Symptom: `pre-commit run -a` returns one or more failures
- Solution: Apply the reported fixes, including formatter rules from `.JuliaFormatter.toml`, and run `pre-commit run -a` again

### Test failures

- Symptom: Tests fail unexpectedly
- Solution: `julia --project=test -e 'using Pkg; Pkg.instantiate()'`
