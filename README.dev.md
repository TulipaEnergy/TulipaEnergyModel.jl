
# Developer documentation

## GIT Setup

1. Fork this repository.
2. Clone your fork.
3. Add this repo as upstream with the following command:

   ```bash
   git remote add upstream https://github.com/TNO-Tulipa/TulipaBulb.jl
   ```

4. Open this project in your editor.
5. On Julia, activate and instantiate the project under the package mode.
6. Run the tests to make sure that everything is working as expected.

## Linting and formatting

Install a plugin to use [EditorConfig](https://editorconfig.org).

We use [https://pre-commit.com](https://pre-commit.com) to run the linters and formatters.
In particular, the Julia code is formatted using [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl).

You can install `pre-commit` globally using `pip install --user pre-commit`.
If you prefer to create a local environment with it, do the following:

```bash
python -m venv env
. env/Scripts/activate
pip install --upgrade pip setuptools pre-commit
```

On Unix or MacOS, you need to active the environment using the following command instead of the previous one:

```bash
. env/bin/activate
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

**Note:** on subsequent occassions when you need to run pre-commit in a new shell, you will need to activate the Python virtual environment. If so, do the following:

```bash
. env/Scripts/activate
pre-commit run -a
```

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
- When finalizing a PR, set the Status to "Ready for Review" and consider assigning a specific Reviewer.
- Once Issues have been addressed by merged PRs, they will automatically move to Done.
- If you want to discuss an issue at the next group meeting, mark it with the "question" label.
- Issues without updates for 60 days (and PRs without updates in 30 days) will be labelled as "stale" and filtered out of view. There is a Stale project board to view and revive these.
