# [Developer Documentation](@id developer)

Welcome to TulipaEnergyModel.jl developer documentation. Here is how you can
contribute to our Julia-based toolkit for modeling and optimization of electric
energy systems.

```@contents
Pages = ["91-developer.md"]
Depth = [2, 3]
```

## Before You Begin

Before you can start contributing, please read our [Contributing Guidelines](@ref contributing).

Also make sure that you have installed the
required software, and that it is properly configured. You only need to do this
once.

### Installing Software

To contribute to TulipaEnergyModel.jl, you need the following:

1. [Julia](https://julialang.org) programming language.
1. [Git](https://git-scm.com) for version control.
1. [VSCode](https://code.visualstudio.com) or any other editor. For VSCode, we recommend
   to install a few extensions. You can do it by pressing `Ctrl + Shift + X` (or `⇧ + ⌘ + X` on MacOS) and searching by the extension name:
   - [Julia for Visual Studio Code](https://www.julia-vscode.org)
   - [Git Graph](https://marketplace.visualstudio.com/items?itemName=mhutchie.git-graph)
1. [EditorConfig](https://editorconfig.org) for consistent code formatting.
   In VSCode, it is available as
   [an extension](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig).
1. [pre-commit](https://pre-commit.com) to run the linters and formatters.
   - To install pre-commit, you will first need [Python](https://www.python.org/) with pip (included by default in recent Python versions).

   You can install `pre-commit` globally using

   ```bash
   pip install --user pre-commit
   ```

   If you prefer to create a local environment with it, do the following:

   ```bash
   python -m venv env

   # Windows
   source env/Scripts/activate # in bash
   env/Scripts/Activate.ps1 # in powershell

   # Linux or macOS
   . env/bin/activate

   pip install --upgrade pip setuptools pre-commit
   ```

   For every subsequent use, you don't have to install, just activate the environment:

   ```bash
   source env/Scripts/activate # in bash
   env/Scripts/Activate.ps1 # in powershell
   ```

1. [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl) for code
   formatting.

   To install it, open a Julia REPL, for example, by typing in the command line:

   ```bash
   julia
   ```

   > **Note:** `julia` must be part of your environment variables to call it from the command line.

   Then press `]` to enter package mode and enter the following:

   ```julia
   pkg> activate
   pkg> add JuliaFormatter
   ```

   In VSCode, you can activate "Format on Save" for `JuliaFormatter`:
   - Open VSCode Settings (`Ctrl + ,`)
   - In "Search Settings", type "Format on Save" and tick the first result:

   ![Screenshot of Format on Save option](./images/FormatOnSave.png)

1. [Prettier](https://prettier.io/) for markdown formatting.
   In VSCode, it is available as
   [an extension](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode).

   Having enabled "Format on Save" for `JuliaFormatter` in the previous step will also enable "Format on Save" for `Prettier`, provided that `Prettier` is set as the default formatter for markdown files. To do so, in VSCode, open any markdown file, right-click on any area of the file, choose "Format Document With...", click "Configure Default Formatter..." situated at the bottom of the drop-list list at the top of the screen, and then choose `Prettier - Code formatter` as the default formatter. Once you are done, you can double-check it by again right-clicking on any area of the file and choosing "Format Document With...", and you should see `Prettier - Code formatter (default)`.

1. [LocalCoverage](https://github.com/JuliaCI/LocalCoverage.jl) for coverage
   testing. You can install it the same way you installed `JuliaFormatter`,
   that is, by opening Julia REPL in the package mode and typing:

   ```julia
   pkg> activate
   pkg> add LocalCoverage
   ```

### Forking the Repository

Any changes should be done in a [fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo). You can fork this repository directly on GitHub:

![Screenshot of Fork button on GitHub](./images/Fork.png)

After that, clone your fork and add this repository as upstream:

```bash
git clone https://github.com/your-name/TulipaEnergyModel.jl                   # use the fork URL
git remote add upstream https://github.com/TulipaEnergy/TulipaEnergyModel.jl  # use the original repository URL
```

Check that your origin and upstream are correct:

```bash
git remote -v
```

You should see something similar to:
![Screenshot of remote names, showing origin and upstream](./images/Remotes.png)

If your names are wrong, use this command (with the relevant names) to correct it:

```bash
git remote set-url [name] [url]
```

### Configuring Git

Because operating systems use different line endings for text files, you need to configure Git to ensure code consistency across different platforms. You can do this with the following commands:

```bash
cd /path/to/TulipaEnergyModel.jl
git config --unset core.autocrlf         # disable autocrlf in the EnergyModel repo
git config --global core.autocrlf false  # explicitly disable autocrlf globally
git config --global --unset core.eol     # disable explicit file-ending globally
git config core.eol lf                   # set Linux style file-endings in EnergyModel
```

### Activating and Testing the Package

Start Julia REPL either via the command line or in the editor.

In the terminal, do:

```bash
cd /path/to/TulipaEnergyModel.jl  # change the working directory to the repo directory if needed
julia                             # start Julia REPL
```

In VSCode, first open your cloned fork as a new project. Then open the command palette with `Ctrl + Shift + P` (or `⇧ + ⌘ + P` on MacOS) and use the command called `Julia: Start REPL`.

In a Julia REPL, enter the package mode by pressing `]`.

In the package mode, first activate and instantiate the project, then run the
tests to ensure that everything is working as expected:

```bash
pkg> activate .   # activate the project
pkg> instantiate  # instantiate to install the required packages
pkg> test         # run the tests
```

### Configuring Linting and Formatting

With `pre-commit` installed, activate it as a pre-commit hook:

```bash
pre-commit install
```

To run the linting and formatting manually, enter the command below:

```bash
pre-commit run -a
```

Do it once now to make sure that everything works as expected.

Now, you can only commit if all the pre-commit tests pass.

> **Note:**
> On subsequent occasions when you need to run pre-commit in a new shell, you
> will need to activate the Python virtual environment. If so, do the following:
>
> ```bash
> . env/bin/activate  # for Windows the command is: . env/Scripts/activate
> pre-commit run -a
> ```

## Code format and guidelines

This section will list the guidelines for code formatting **not enforced** by JuliaFormatter.
We will try to follow these during development and reviews.

- Naming
  - `CamelCase` for classes and modules,
  - `snake_case` for functions and variables, and
  - `kebab-case` for file names.
- Use `using` instead of `import`, in the following way:
  - Don't use pure `using Package`, always list all necessary objects with `using Package: A, B, C`.
  - List obvious objects, e.g., `using JuMP: @variable`, since `@variable` is obviously from JuMP in this context, or `using Graph: SimpleDiGraph`, because it's a constructor with an obvious name.
  - For other objects inside `Package`, use `using Package: Package` and explicitly call `Package.A` to use it, e.g., `DataFrames.groupby`.
  - List all `using` in <src/TulipaEnergyModel.jl>.
- Explicitly state what a function will `return`; if returning nothing, simply use `return`.

## Contributing Workflow

When the software is installed and configured, and you have forked the
TulipaEnergyModel.jl repository, you can start contributing to it.

We use the following workflow for all contributions:

1. Make sure that your fork is up to date
2. Create a new branch
3. Implement the changes
4. Run the tests
5. Run the linter
6. Commit the changes
7. Repeat steps 3-6 until all necessary changes are done
8. Make sure that your fork is still up to date
9. Create a pull request

Below you can find detailed instructions for each step.

### 1. Make Sure That Your Fork Is Up to Date

Fetch from org remote, fast-forward your local main:

```bash
git switch main
git fetch --all --prune
git merge --ff-only upstream/main
```

> **Warning**:
> If you have a conflict on your main, it will appear now. You can delete
> your old `main` branch using
>
> ```bash
> git reset --hard upstream/main
> ```

### 2. Create a New Branch

Create a branch to address the issue:

```bash
git switch -c <branch_name>
```

- If there is an associated issue, add the issue number to the branch name,
  for example, `123-short-description` for issue \#123.
- If there is no associated issue **and the changes are small**, add a prefix such as "typo", "hotfix", "small-refactor", according to the type of update.
- If the changes are not small and there is no associated issue, then create the issue first, so we can properly discuss the changes.

> **Note:**
> Always branch from `main`, i.e., the main branch of your own fork.

### 3. Implement the Changes

Implement your changes to address the issue associated with the branch.

### 4. Run the Tests

In Julia:

```bash
TulipaEnergyModel> test
```

To run the tests with code coverage, you can use the `LocalCoverage` package:

```julia
julia> using LocalCoverage
# ]
pkg> activate .
# <backspace>
julia> cov = generate_coverage()
```

This will run the tests, track line coverage and print a report table as output.
Note that we want to maintain 100% test coverage. If any file does not show 100%
coverage, please add tests to cover the missing lines.

If you are having trouble reaching 100% test coverage, you can set your pull
request to 'draft' status and ask for help.

### 5. Run the Linter

In the bash/git bash terminal, run pre-commit:

```bash
. env/bin/activate # if necessary (for Windows the command is: . env/Scripts/activate)
pre-commit run -a
```

If any of the checks failed, find in the pre-commit log what the issues are and
fix them. Then, add them again (`git add`), rerun the tests & linter, and commit.

### 6. Commit the Changes

When the test are passing, commit the changes and push them to the remote
repository. Use:

```bash
git commit -am "A short but descriptive commit message" # Equivalent to: git commit -a -m "commit msg"
git push -u origin <branch_name>
```

When writing the commit message:

- use imperative, present tense (Add feature, Fix bug);
- have informative titles;
- if necessary, add a body with details.

> **Note:**
> Try to create "atomic git commits". Read
> [_The Utopic Git History_](https://blog.esciencecenter.nl/the-utopic-git-history-d44b81c09593)
> to learn more.

### 7. Make Sure That Your Fork Is Still Up to Date

If necessary, fetch any `main` updates from upstream and rebase your branch into
`origin/main`. For example, do this if it took some time to resolve the issue
you have been working on. If you don't resolve conflicts locally, you will
get conflicts in your pull request.

Do the following steps:

```bash
git switch main                  # switch to the main branch
git fetch --all --prune          # fetch the updates
git merge --ff-only upstream/main  # merge as a fast-forward
git switch <branch_name>         # switch back to the issue branch
git rebase main <branch_name>    # rebase it
```

If it says that you have conflicts, resolve them by opening the file(s) and
editing them until the code looks correct to you. You can check the changes
with:

```bash
git diff             # Check that changes are correct.
git add <file_name>
git diff --staged    # Another way to check changes, i.e., what you will see in the pull request.
```

Once the conflicts are resolved, commit and push.

```bash
git status # Another way to show that all conflicts are fixed.
git rebase --continue
git push --force origin <branch_name>
```

### 8. Create a Pull Request

When there are no more conflicts and all the test are passing, create a pull
request to merge your remote branch into the org main. You can do this on
GitHub by opening the branch in your fork and clicking "Compare & pull request".

![Screenshot of Compare & pull request button on GitHub](./images/CompareAndPR.png)

Fill in the pull request details:

1. Describe the changes.
2. List the issue(s) that this pull request closes.
3. Fill in the collaboration confirmation.
4. (Optional) Choose a reviewer.
5. When all of the information is filled in, click "Create pull request".

![Screenshot of the pull request information](./images/PRInfo.png)

You pull request will appear in the list of pull requests in the
TulipaEnergyModel.jl repository, where you can track the review process.

Sometimes reviewers request changes. After pushing any changes,
the pull request will be automatically updated. Do not forget to re-request a
review.

Once your reviewer approves the pull request, you need to merge it with the
main branch using "Squash and Merge".
You can also delete the branch that originated the pull request by clicking the button that appears after the merge.
For branches that were pushed to the main repo, it is recommended that you do so.

## Building the Documentation Locally

Following the latest suggestions, we recommend using `LiveServer` to build the documentation.

> **Note**:
> Ensure you have the package `Revise` installed in your global environment
> before running `servedocs`.

Here is how you do it:

1. Run `julia --project=docs` in the package root to open Julia in the environment of the docs.
1. If this is the first time building the docs
   1. Press `]` to enter `pkg` mode
   1. Run `pkg> dev .` to use the development version of your package
   1. Press backspace to leave `pkg` mode
1. Run `julia> using LiveServer`
1. Run `julia> servedocs(launch_browser=true)`

## Performance Considerations

If you updated something that might impact the performance of the package, you
can run the `Benchmark.yml` workflow from your pull request. To do that, add
the tag `benchmark` in the pull request. This will trigger the workflow and
post the results as a comment in you pull request.

> **Warning**:
> This requires that your branch was pushed to the main repo.
> If you have created a pull request from a fork, the Benchmark.yml workflow does not work.
> Instead, close your pull request, push your branch to the main repo, and open a new pull request.

If you want to manually run the benchmarks, you can do the following:

- Navigate to the benchmark folder
- Run `julia --project=.`
- Enter `pkg` mode by pressing `]`
- Run `dev ..` to add the development version of TulipaEnergyModel
- Now run

  ```julia
  include("benchmarks.jl")
  tune!(SUITE)
  results = run(SUITE, verbose=true)
  ```

### Manually running the benchmark across versions

We use the package [AirspeedVelocity.jl](https://github.com/MilesCranmer/AirspeedVelocity.jl) to run the benchmarks in the CI, but it can also be used to compare explicitly named versions manually.

1. Run the following to install AirspeedVelocity's commands to your Julia `bin` folder (`~/.julia/bin` on MacOS and Linux). On Windows, if you are using the default Julia installation, search for `C:/Users/` then the folder of your Windows user and then `.julia/bin`

   ```bash
   julia -e 'using Pkg; Pkg.activate(temp=true); Pkg.add("AirspeedVelocity")'
   ```

1. Check that `benchpkg` was installed:

   ```bash
   benchpkg --version
   ```

   If if can't be found, then it is possible that your Julia `bin` folder is not in the `PATH`. After fixing this, try again.

1. Then, run `benchpkg` with `--rev` to list the versions to be tested and `--bench-on` to indicate with script to use (if necessary). For instance:

   ```bash
   benchpkg TulipaEnergyModel --rev=v0.12.0,main --bench-on=main
   ```

   After all logging, the output should look like

   ```plaintext
   |                                      | v0.12.0       | main            | v0.12.0/main |
   |:-------------------------------------|:-------------:|:---------------:|:------------:|
   | energy_problem/create_model          | 25.1 ± 1.2 s  | 19.7 ± 1.1 s    | 1.27         |
   | energy_problem/input_and_constructor | 11.2 ± 0.15 s | 8.57 ± 0.064 s  | 1.3          |
   | time_to_load                         | 1.7 ± 0.022 s | 1.73 ± 0.0055 s | 0.979        |
   ```

   Be aware that the versions passed in `rev` must be compatible to the benchmark defined at `bench-on`.
   So, for instance, testing `v0.10.4` above would fail, before the versions are too different.

   If you are working on a local version of `TulipaEnergyModel`, it is possible to test the local modifications.
   First, make sure that you are at the root of the `TulipaEnergyModel` repo, and then issue

   ```bash
   benchpkg --rev=<other>,dirty
   ```

   The `dirty` value refers to the current local modifications.
   The `<other>` values can be tags or branches to compare.

1. When this is done, you can print just the table afterwards using `benchmarktable`:

   ```bash
   benchpkgtable TulipaEnergyModel --rev=v0.12.0,main
   ...
   |                                      | v0.12.0       | main            | v0.12.0/main |
   |:-------------------------------------|:-------------:|:---------------:|:------------:|
   | energy_problem/create_model          | 25.1 ± 1.2 s  | 19.7 ± 1.1 s    | 1.27         |
   | energy_problem/input_and_constructor | 11.2 ± 0.15 s | 8.57 ± 0.064 s  | 1.3          |
   | time_to_load                         | 1.7 ± 0.022 s | 1.73 ± 0.0055 s | 0.979        |
   ```

1. It is also possible to generate a plot, using `benchpkgplot`:

   ```bash
   benchpkgplot TulipaEnergyModel --rev=v0.12.0,main --format=jpeg
   ```

   Different formats can be used. Here is the output:

   ![Plot of benchmark made with benchpkgplot](./images/plot_TulipaEnergyModel.jpeg)

### Profiling

To profile the code in a more manual way, here are some tips:

- Wrap your code into functions.
- Call the function once to precompile it. This must be done after every change to the function.
- Prefix the function call with `@time`. This is the most basic timing, part of Julia.
- Prefix the function call with `@btime`. This is part of the BenchmarkTools package, which you might need to install. `@btime` will evaluate the function a few times to give a better estimate.
- Prefix the function call with `@benchmark`. Also part of BenchmarkTools. This will produce a nice histogram of the times and give more information. `@btime` and `@benchmark` do the same thing in the background.
- Call `@profview`. This needs to be done in VSCode, or using the ProfileView package. This will create a flame graph, where each function call is a block. The size of the block is proportional to the aggregate time it takes to run. The blocks below a block are functions called inside the function above.

See the file <benchmark/profiling.jl> for an example of profiling code.

## Testing the generate MPS files

To make sure that unintended changes don't change the model, we have a workflow that automatically compares the generated MPS files.
Here is an explanation of how it works, and how to run the same comparison locally.

Before we start, notice that there are files in `benchmark/model-mps-folder` with the `.mps` files for each of the test inputs.
There are the _existing_ MPS files.

### Updating the MPS files

To update the MPS files, you can simple run a script from the root of `TulipaEnergyModel.jl`:

```bash
julia --project=. utils/scripts/model-mps-update.jl
```

If you **know** that your changes will modify the model, then you need to update the MPS files as just showed.

### Comparison of MPS files via script

One quick way to check the difference between the existing MPS files and the new ones is just to run the update, and check the `git diff`.
However, if you don't want to update, or just want a summary of the changes, you can run the script:

```bash
julia --project=. utils/scripts/model-mps-compare.jl
```

!!! warning
    This comparison uses the _local version of `benchmark/model-mps-folder`_.
    So, if you run the update script, there will be no changes to be shown.

The generated log will look something liek this:

```plaintext
┌ Info: New comparison
│ Comparing files
│ - <path>/<file>.mps
└ - <temp-path>/<file>.mps
[ Info: Create mps for <path> in <temp-path>
[ Info: No difference found
┌ Info: New comparison
│ Comparing files
│ - <path>/<file>.mps
└ - <temp-path>/<file>.mps
[ Info: Create mps for <path> in <temp-path>
┌ Error: Line 1272"
│ ..Existing: '    assets_investment[2030,ocgt] max_output_flows_limit[ocgt,2030,1,18:18] -100'
│ .......New: '    assets_investment[2030,ocgt] max_output_flows_limit[ocgt,2030,1,18:18] -200'
└ @ Main <path>/utils/scripts/model-mps-compare.jl:75
```

There are 2 cases:

1. The first case starts at the beginning of the log and ends in "No difference found". There was nothing to show for that file.
2. The second case has "errors", i.e., differences between the existing and new MPS files.
   Here is what to expect from the error lines:
   - `Error: Line ####`: The line number of the MPS file (which you can manually inspect).
   - `..Existing`: Shows the existing line.
   - `.......New`: Shows the new line.

If the environment variable `TULIPA_COMPARE_MPS_LOGFILE` is defined and is a path to a file, then the log will be written to a file instead of printed.
This is mostly relevant for the GitHub workflow.

### GitHub Workflow

When creating a pull request, the workflow `CompareMPS.yml` will run the comparison above and write a PR comment to indicate whether the files are the same or not. If the files are not the same, then the workflow fails, and there are two ways in which the workflow can fail:

1. **Expected failure**: If you are making a change to the model, then the MPS file will be different. Then you should
   1.1. Verify that the changes are **only** what you expected to see (i.e., use the MPS difference to debug possible issues).
   1.2. Run the update script listed above to fix the comparison (i.e., the new MPS becomes the existing MPS).
   1.3. Commit and push your modifications and wait for the comparison to run again.
2. **Unexpected failure**: If you made modifications that were not supposed to change the model, then you need to investigate what happened. Use the MPS difference to debug what you have done. There is no easy fix for this. If you think there are bugs in the comparison script, discuss with your PR reviewer and open an issue if necessary.

!!! warning
    The comparison workflow only writes PR comments if the branch is made from within `TulipaEnergyModel`. To see the log online in that case, you have to open the GitHub action log, or run the comparison locally, as explained in the previous section.

## Procedure for Releasing a New Version (Julia Registry)

When publishing a new version of the model to the Julia Registry, follow this procedure:

!!! note
    To be able to register, you need to be a member of the organisation TulipaEnergy and set your visibility to public:
    ![Screenshot of public members of TulipaEnergy on GitHub](./images/PublicMember.png)

1. Click on the `Project.toml` file on GitHub.

1. Edit the file and change the version number according to [semantic versioning](https://semver.org/): Major.Minor.Patch

   ![Screenshot of editing Project.toml on GitHub](./images/UpdateVersion.png)

1. Commit the changes in a new branch and open a pull request. Change the commit message according to the version number.

   ![Screenshot of PR with commit message "Release 0.6.1"](./images/CommitMessage.png)

1. Create the pull request and squash & merge it after the review and testing process. Delete the branch after the squash and merge.

   ![Screenshot of full PR template on GitHub](./images/PullRequest.png)

1. Go to the main page of repo and click in the commit.
   ![Screenshot of how to access commit on GitHub](./images/AccessCommit.png)

1. Add the following comment to the commit: `@JuliaRegistrator register`

   ![Screenshot of calling JuliaRegistrator in commit comments](./images/JuliaRegistrator.png)

1. The bot should start the registration process.

   ![Screenshot of JuliaRegistrator bot message](./images/BotProcess.png)

1. After approval, the bot will take care of the PR at the Julia Registry and automatically create the release for the new version.

   ![Screenshot of new version on registry](./images/NewRelease.png)

   Thank you for helping make frequent releases!

## Adding a Package to the TulipaEnergy Organisation

To get started creating a new (Julia) package that will live in the TulipaEnergy organisation and interact with TulipaEnergyModel, please start by using [BestieTemplate.jl](https://github.com/JuliaBesties/BestieTemplate.jl), and follow the steps in their [Full guide](https://juliabesties.github.io/BestieTemplate.jl/stable/10-full-guide/#full_guide) for a new package.

This will set up the majority of automation and workflows we use and make your repo consistent with the others!

> **Note:** TulipaEnergyModel.jl is the core repo of the organisation. The Discussions are focused there and in some cases the documentation of other packages should forward to the TulipaEnergyModel docs to avoid duplicate or scattered information.
