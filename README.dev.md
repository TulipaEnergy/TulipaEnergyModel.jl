
# Developer documentation

## Git setup

First we need to set some config variables so that the code is
consistent across all operating systems - different OSs use different
line-endings for text files (source code).

Disable any ambiguity in your global and current repository settings:

```shell
cd /path/to/TulipaEnergyModel.jl
git config --unset core.autocrlf         # disable autocrlf in the EnergyModel repo
git config --global core.autocrlf false  # explicitly disable autocrlf globally
git config --global --unset core.eol     # disable explicit file-ending globally
git config core.eol lf                   # set Linux style file-endings in EnergyModel
```

1. Fork this repository.
2. Clone your fork.
3. Add this repo as upstream with the following command:

   ```bash
   git remote add upstream https://github.com/TulipaEnergy/TulipaEnergyModel.jl
   ```

4. Open this project in your editor.
5. On Julia, activate and instantiate the project under the package mode.
6. Run the tests to make sure that everything is working as expected.

## Linting and formatting

Install a plugin to use [EditorConfig](https://editorconfig.org).

We use [https://pre-commit.com](https://pre-commit.com) to run the linters and formatters.
In particular, the Julia code is formatted using [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl).

You need to install `JuliaFormatter`. Open Julia and press `]` to enter `pkg` mode. Then enter the following:

```bash
pkg> activate
pkg> add JuliaFormatter
```

You can install `pre-commit` globally using `pip install --user pre-commit`.
If you prefer to create a local environment with it, do the following:

```bash
python -m venv env
. env/bin/activate
pip install --upgrade pip setuptools pre-commit
```

On Windows, you need to active the environment using the following command instead of the previous one:

```bash
. env/Scrips/activate
```

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

**Note:** On subsequent occasions when you need to run pre-commit in a new shell, you will need to activate the Python virtual environment. If so, do the following:

```bash
. env/bin/activate # for Windows the command is: . env/Scripts/activate
pre-commit run -a
```

In VSCode, you can activate "Format on Save" for the Julia Formatter.

1. Open VSCode Settings (CTRL + ,)
2. In Search Settings, type "Format on Save"
3. Tick the first result

![Screenshot of Format on Save option](docs/FormatOnSave.png)

## Contributing workflow

Our workflow is:

1. Fetch from org remote, fast-forward your local main
2. Create a branch to address the issue (see below for naming) - *"Always branch from `main`."*
3. Push the new local branch to your personal remote repository
4. Create a pull request to merge your remote branch into the org main

Creating a branch:

- If there is an associated issue, add the issue number
- If there is no associated issue, **and the changes are small**, add a prefix such as "typo", "hotfix", "small-refactor", according to the type of update
- If the changes are not small and there is no associated issue, then create the issue first, so we can properly discuss the changes

Commit message:

- Use imperative, present tense (Add feature, Fix bug)
- Have informative titles
- If necessary, add a body with details

Before creating a pull request:

- Try to create "atomic git commits" (recommended reading: [The Utopic Git History](https://blog.esciencecenter.nl/the-utopic-git-history-d44b81c09593))
- Make sure the tests pass
- Make sure the pre-commit tests pass
- Rebase: Fetch any `main` updates from upstream and rebase your branch into `origin/main` if necessary
- Then you can open a pull request and work with the reviewer to address any issues

## GitHub Rules of Engagement

- Assign only yourself to issues.
- Assign yourself to issues you **want** to address. Consider if you will be able to work on it in the near future - if not, consider leaving it available for someone else to address.
- Set the issue Status to "In Progress" when you have started working on it.
  - Creating a PR for an issue (even if only a draft) will automatically set an issue as 'In Progress.' A good habit is creating a *draft* PR early, to take advantage of this automation and get feedback early.
- When finalizing a PR, set the Status to "Ready for Review" - if someone specific **needs** to review it, you can assign them as the reviewer.
- Once Issues have been addressed by merged PRs, they will automatically move to Done.
- If you want to discuss an issue at the next group meeting, mark it with the "question" label.
- Issues without updates for 60 days (and PRs without updates in 30 days) will be labelled as "stale" and filtered out of view. There is a Stale project board to view and revive these.

## Most commonly used Git commands in the contributing flow

Assuming `origin` is the upstream repository, i.e., not the fork.

First, update your local main branch.

```bash
git switch main
git fetch --all --prune
git merge --ff-only origin/main
```

> **Warning**
>
> If you have a conflict on your main, it will appear now. You can delete your old `main` branch using `git reset --hard origin/main`.

Then, create a new branch, work, commit, and push.

```bash
git switch -c <branch_name>
# awesome coding...
# run the tests and the linter (see end of this section).
git commit -am "A short but descriptive commit message" # Equivalent to: git commit -a -m "commit msg"
git push -u myfork <branch_name>
```

Let's say upstream has updates while you are working on your local branch. You need to fetch the new changes because if you don't do conflict resolution locally, you will get conflicts in your PR. So you need to repeat the steps from the first code block in this section.

Now, we are going to rebase our local feature branch on top of the updated `main`.

```bash
git switch <branch_name>
git rebase main <branch_name>
```

It will say you have conflicts. Open the file(s) and edit it to remove the conflicts, until the code looks correct to you.

```bash
git diff # Check that changes are correct.
git add <file_name>
git diff --staged # Another way to check changes, i.e., what you will see in the pull request.
```

Run the tests and the linter.

### Tests

On Julia:

```bash
TulipaEnergyModel> test
```

To run the tests with code coverage, you can use the `LocalCoverage` package.
You can add it to and load it from your global environment to avoid polluting the package dependencies:

```julia
julia>
# ]
pkg> activate           # activate the global environment
pkg> add LocalCoverage  # if not yet added previously
# <backspace>
julia> using LocalCoverage
# ]
pkg> activate .
# <backspace>
julia> cov = generate_coverage()
```

This will run the tests, track line coverage and print a report table as output. Note that we want to maintain 100% test coverage. If any file does not show 100% coverage, please add tests to cover the missing lines.

If you are having trouble reaching 100% test coverage, you can set your PR to 'draft' status and ask for help.

### Linter

On the bash/git bash terminal, the pre-commit:

```bash
. env/bin/activate # if necessary (for Windows the command is: . env/Scripts/activate)
pre-commit run -a
```

If there are things to fix, do it.
Then, add them again (`git add`), rerun the tests & linter, and commit.

```bash
git status # Another way to show that all conflicts are fixed.
git rebase --continue
git push --force myfork <branch_name>
```

After pushing, the PR will be automatically updated.
If a review was made, re-request a review.

## Performance considerations

If you updated something that might impact the performance of the
package, you can run the `Benchmark.yml` workflow from your PR.  To do
that, add the command `/run-benchmark` as a comment in the PR.  This
will trigger the workflow for your branch, and post the results as a
comment in you PR.

If you want to manually run the benchmarks, you can do the following:

- Navigate to the benchmark folder
- Run `julia --project=.`
- Enter `pkg` mode by pressing `]`
- Run `dev ..` to add the development version of TulipaEnergyModel
- Now run

  ```julia
  using BenchmarkTools
  include("benchmarks.jl")
  tune!(SUITE)
  results = run(SUITE, verbose=true)
  ```

## Build and see the documentation locally

To build and see the documentation locally, first, navigate to the `docs` folder in your file explorer and open a terminal. Then, run `julia --project` (remember that `julia` must be part of your environment variables to call it from the command line). With the `julia` open, enter the `pkg` mode by pressing `]`. Check that the environment name is `docs`. The first time here, you have to run:

```julia-pkg
docs> dev ..
docs> update
```

Then, to build the documentation, run

```julia
julia> include("make.jl")
```

If you intend to rerun the build step, ensure you have the package `Revise` installed in your global environment, and run `using Revise` before including `make.jl`. Alternatively, close `julia` and reopen it.

After building, the documentation will be available in the folder `docs/build/`. Open the `index.html` file on the browser to see it.
