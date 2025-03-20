# [Getting Started](@id getting-started)

```@contents
Pages = ["00-getting-started.md"]
Depth = [2, 3]
```

Let's get you set up! This will only take a few minutes.

## Installing Julia and an Editor

To use Tulipa, you first need to install the open-source [Julia](https://julialang.org) programming language.

Then consider installing a user-friendly code editor, such as [VSCode](https://code.visualstudio.com). Otherwise you will be working in the terminal/command prompt.

## Installing Tulipa

### Starting Julia

Choose one:

- In VSCode: Press `CTRL`+`Shift`+`P` and then `Enter` to start a Julia REPL.
- In the terminal: Type `julia` and press `Enter`

### Adding Tulipa and dependencies

In Julia:

- Press `]` to enter package mode, then run:

```julia-pkg
pkg> add TulipaEnergyModel  # The model builder
pkg> add TulipaIO           # For data handling
```

Tulipa relies on [DuckDB](https://duckdb.org/) for data-handling:

```julia-pkg
pkg> add DuckDB
```

- Press `backspace` to return to Julia mode

## Using packages in your project

Now that the packages are installed, you need to activate them in your project. You should always have this line at the top of your code, specifying any packages you want to use.

```julia
using TulipaEnergyModel, TulipaIO, DuckDB
```

Just to show that it worked, try accessing the documentation of a package:

- Press `?` to enter help mode, then:

```julia
# Search the documentation for this function from TulipaEnergyModel
help?> default_parameters
```

You should see the documentation for the [default_parameters](@ref) function. If Julia says it does not exist, that means TulipaEnergyModel is not in your environment (you need to activate it with `add` and `using` as described above).

## Next Step

Now that you're all set up, head over to our [Beginner Tutorials](@ref basic-example) to run your first analyses! 🌷
