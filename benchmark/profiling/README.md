# Profiling

There are three ways to investigate the performance of the code, in increasing complexity and usefulness:

1. Run a code with `@time`. This is included in base Julia and is prone to huge fluctuations.
2. Run a code with `@benchmark`. This needs the package BenchmarkTools. This will run the code once and decide how many times it needs to run to fit into a reasonable time scale. So if your code is very fast, `@benchmark` might run is thousands of times. For slow codes, however, this will run the code once, which does not account for random variations. See the benchmark.jl script for an example of how to setup the code better.

3. Run a code with `@profview`. This will _sample_ the code to look for slow parts. Essentially the profiler asks the code which line is being executed at the moment and increases an internal counter. At the end of the execution, more counters means slower. This also means that lines of the code that are very fast might be skipped, so to profile really fast code parts, use `@profview` with a loop.

Depending on the complexity of the task and how long it takes to run the code, you might choose a different way.

The most useful in this project will be the third way, since our main object is to improve when scaling, so profile scripts here will be using that function mostly.

For more information on profiling, check <https://modernjuliaworkflows.org/optimizing/#profiling>.

## Running on VSCode

To run this on VSCode:

1. Follow the developer documentation to install what is needed
2. Open the script that you want to run
3. Run the script

A tab will appear with the flame graph.

## Running outside VSCode

It should be possible to run `@profview` without VSCode, however that is not always the case because of the graphic libraries required and how your system interacts with them.
Using VSCode is easier and provides a better UI, so the recommendation is to use VSCode when profiling.
However, if you want to try to run this outside of VSCode, try the following:

Open Julia in the `benchmark` folder

```julia-repl
julia> # press ]
pkg> activate .                         # activate the environment
pkg> dev ..                             # use the development version of TEM
pkg> add ProfileView                    # not added by default because VSCode has it
pkg> up                                 # every now and then, update
julia> include("profiling/basic.jl")    # or whatever other script
```

## Understanding the flame graph

When the flame graph is created, it will normally have a lot of functions (~15)from the Julia side _before_ the actual code.
This is normally identified by a `eval` block.

If you click in the block, it will zoom into that region.
Do that to focus on the TEM code.

### Tips

#### Too fast

Make sure that your `@profview` call is not too fast.
You want to have your code run for enough time that the sampler will capture relevant information.
If you have a larger data input, that is better. Otherwise, run the relevant code inside a loop. See basic.jl.

#### Focus

If the part of the code that you want to profile does not appear in the flame graph and you are already running in a loop, then you need to change your benchmark to run something more focused.

Look into the tests, maybe there is already something that can be reused.

#### Large blocks

The size of the blocks is proportional to how much the code is taking to execute (according to the sampler).
If a block is large, it is relevant, but that doesn't mean that it's wrong.
In a large scale problem, some things will be slow.

#### Color codes

The color of the blocks are an indication of other problems in the code.

There are various tonalities of blue, which is normal.

The red blocks are bad. It means, in essence, that there are issues related to type. We should try to avoid these as much as possible, although sometimes it will happen in other packages (e.g. DataFrames).

The yellow blocks are also bad. It means that the garbage collector was called, which means that some memory stopped being used.
E.g., creating a temporary array.

See <https://github.com/timholy/ProfileView.jl?tab=readme-ov-file#color-coding> for more information.

ere is a link on improving type stability: <https://modernjuliaworkflows.org/optimizing/#type_stability>.

#### Repeated blocks

Sometimes a block will be small but will appear in many places.
Every time that the block appears, it's a separate execution.
This means that the actual time of the code is the aggregate of all blocks.
These are great candidates for improvement if they add up to become a large block.
However, as with the large blocks, being slow does not mean that it's wrong.
