# [Setting up](@id tutorials-setup)

In this pre-tutorial, you will learn (a bit) about:

- Creating a VS Code project
- Setting up a workflow file for Julia
- Retrieving the data necessary for the following tutorials

These are simply some set-up steps to get you ready for the rest of the tutorials. Do not skip these steps!

*Let's get started!*

## [Create a VS Code project](@id vscode-project)

Make sure you have Julia installed, as well as the Julia extension in VS Code.

- Open VS Code and create a new project\
   *File > Open Folder > Create a new folder > Select*
- Open a Julia REPL\
  *CTRL + SHIFT + P > ENTER*
- Run the code below in your Julia REPL to create a new environment and add the necessary packages (only necessary when creating a new project environment):

```julia
using Pkg: Pkg       # Julia package manager
Pkg.activate(".")    # Creates and activates the project in the new folder - notice it creates Project.toml and Manifest.toml in your folder for reproducibility
Pkg.add("TulipaEnergyModel")
Pkg.add("TulipaIO")
Pkg.add("DuckDB")
Pkg.add("DataFrames")
Pkg.add("Plots")
Pkg.instantiate()
```

!!! tip
    If you already had an installed version of the packages, then consider updating them using
    the update function in Pkg, for instance, `Pkg.update("TulipaEnergyModel")`.

- Create a Julia file called `my_workflow.jl`
- Paste this code in the file. Running it will load the necessary packages:

```julia
import TulipaIO as TIO
import TulipaEnergyModel as TEM
using DuckDB
using DataFrames
using Plots
```

## [Set up data and folders](@id tutorial-data-folders)

- **Download the folders**
     1. Go to main repo website: [https://github.com/TulipaEnergy/TulipaEnergyModel.jl/](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/)
     1. Click on *Tags*
     1. Download the Zip file of the version you have installed (usually the latest)
     1. The data is located in the subfolders: *docs > src > 10-tutorials > my-awesome-energy-system*

- **Move the 'my-awesome-energy-system' folder** into your VS Code project.\
    *To find the folder where you created your project, right click on any file in VS code (e.g. 'my_workflow.jl') and click "Reveal in File Explorer"*

Now the file workflow.jl and folder 'my-awesome-energy-system' should both be present in your VS Code project.

!!! info "What parameters can I use?"
    Check out the docs: [Input Table Schemas](@ref table-schemas) and the [input-schemas.json](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/main/src/input-schemas.json) file.
