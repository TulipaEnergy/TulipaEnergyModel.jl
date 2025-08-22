# Tutorial: raw data to TEM format

This contribution in the form of a workflow tutorial has been constructed during the first Tulipa Learning Community.

within this tutorial, we will be showcasing how to convert a typical raw dataset from a published scenario study (TYNDP2024) into a format suitable as input for TulipaEnergyModel.

Specifically, our objective is to extract the installed capacities per technology per country for 2050 under the Global Ambition scenario.

## Install packages

To follow this tutorial, you need to install some packages:

1. Open `julia` in the folder that you will be working
1. In the `julia` terminal, press `]`. You should see `pkg>`
1. Activate you local environment using `activate .`
1. Install packages with `add <Package1>,<Package2>`, etc. You shouldn't need
   to specify the versions, if this tutorial is up-to-date.

These are the necessary packages and their versions:

```
CSV v0.10.15
Chain v0.6.0
DataFrames v1.7.0
DuckDB v1.2.2
Tables v1.12.0
```

You can use the following lines if you have not yet activated/instantiated your environment:
```julia
using Pkg: Pkg
Pkg.activate(".")
Pkg.instantiate()
```

## External source

For this tutorial, we use the TYNDP2024 output data. Download it from the [Published scenario study data](https://2024-data.entsos-tyndp-scenarios.eu/files/scenarios-outputs/GA2050CY2009.zip).
The exact file we will be working with is called 'MMStandardOutputFile_GA2050_Plexos_CY2009_v11_SoS.xlsb' with the sheet 'Yearly Outputs'.
Save this sheet as a database file. This can be done in programming languages such as R or Python, for example through the following lines (R):

```r
GA2050 <- read_xlsb("TYNDP2024_GA_2050_installed_capacities_Plexos_CY1995.xlsb", sheet = "Yearly Outputs")
#Connect to a DuckDB database (will create it if it doesn't exist)
con <- dbConnect(duckdb::duckdb(), "GA2050_capacities.duckdb")
#Write the dataframe into the DuckDB database
dbWriteTable(con, "Installed_capacities", GA2050, overwrite = TRUE)
```

Now that we have a DuckDB file, we will continue the rest of the tutorial in Julia to process the initial raw data into TEM format.

First step after activating and instantiating is specifying which packages we will be using as such:

```julia
using DuckDB
using DataFrames
using Chain
using Statistics
using Tables
using CSV
```

Next, we connect to the DuckDB file to have access to our raw data in a dataframe format:

```julia
con = DBInterface.connect(DuckDB.DB, "GA2050_capacities.duckdb")
```

We can observe which tables we have in this file, we should have one that is called "Installed_capacities":
```julia
println(DuckDB.execute(con, "SHOW TABLES") |> DataFrame)
```

Once we have checked the table is there, we can access it and select everything in it to see what we are working with:
```julia
df = DuckDB.execute(con, "SELECT * FROM \"Installed_capacities\"") |> DataFrame
```
```
229×224 DataFrame
 Row │ Scenario                           GA50                              X          X.1        X.2         X.3                         X.4                       X.5        X.6       X.7      X.8        X.9       X.10                        X.11                      X.12       X.13       X.14       X.15                        X.16                      X.17       X.18      X.19     X.20       X.21      X.22           ⋯
     │ String                             String                            String     String     String      String                      String                    String?    String    String?  String?    String    String?                     String?                   String?    String     String?    String?                     String?                   String?    String?   String?  String?    String    String?        ⋯
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Simulator                          Plexos                                                                                                                                                                                                                                                                                                                                                                                      ⋯
   2 │ Date                               2024-03-22
   3 │ Status                             1995
   4 │
   5 │ Output type                        Output type                       AL00       AL00 SRES  AT00        AT00 EV Passenger Prosumer  AT00 EV Passenger Street  AT00 SRES  AT00RETE  BA00     BA00 SRES  BE00      BE00 EV Passenger Prosumer  BE00 EV Passenger Street  BE00 SRES  BE00RETE   BG00       BG00 EV Passenger Prosumer  BG00 EV Passenger Street  BG00 SRES  BG00RETE  CH00     CH00 SRES  CY00      CY00 EV Passen ⋯
   6 │ Annual generation [GWh]            Nuclear                           0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          10537.011  0                           0                         0          0         0        0          0         0
   7 │                                    Lignite old 1                     0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
   8 │                                    Lignite old 2                     0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
   9 │                                    Lignite new                       0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0              ⋯
  10 │                                    Lignite CCS                       0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
  11 │                                    Hard coal old 1                   0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
  12 │                                    Hard coal old 2                   0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
  13 │                                    Hard coal new                     0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0              ⋯
  14 │                                    Hard coal CCS                     0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
  15 │                                    Gas conventional old 1            0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
  16 │                                    Gas conventional old 2            0          0          0           0                           0                         0          0         0        0          31.703    0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
  17 │                                    Gas CCGT old 1                    0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0              ⋯
  18 │                                    Gas CCGT old 2                    0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
  ⋮  │                 ⋮                                 ⋮                      ⋮          ⋮          ⋮                   ⋮                          ⋮                  ⋮         ⋮         ⋮         ⋮         ⋮                  ⋮                          ⋮                  ⋮          ⋮          ⋮                  ⋮                          ⋮                  ⋮         ⋮         ⋮         ⋮         ⋮                  ⋮  ⋱
 212 │                                    Light oil biofuel                 0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
 213 │                                    Heavy oil biofuel                 0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
 214 │                                    Oil shale biofuel                 0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0              ⋯
 215 │                                    Battery Storage discharge (gen.)  0          0          304         254572                      109102                    0          337       0        0          1130      322551                      138236                    0          1566       4923       143587                      61537                     0          2018      5050     0          3076      23392
 216 │                                    Battery Storage charge (load)     0          0          304         254572                      109102                    0          337       0        0          1130      322551                      138236                    0          1566       4923       143587                      61537                     0          2018      5050     0          3076      23392
 217 │                                    Electrolyser (load)               0          0          15465.448   0                           0                         0          0         0        0          4361.303  0                           0                         0          0          201.599    0                           0                         0          0         262.65   0          1018.078  0
 218 │                                    Hydrogen Fuel Cell                0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0              ⋯
 219 │                                    Hydrogen CCGT                     0          0          3260        0                           0                         0          0         0        0          3390      0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
 220 │                                    Demand Side Response              0          0          700         0                           0                         0          0         0        0          3268      0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
 221 │                                    CH4 Heat Pump (load)              0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          242140     0          0                           0                         0          23429     0        0          0         0
 222 │                                    H2 Heat Pump (load)               0          0          0           0                           0                         0          108606    0        0          0         0                           0                         0          0          0          0                           0                         0          36338     0        0          0         0              ⋯
 223 │                                    Adequacy                          0          0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
 224 │ System costs [M€]                                                    0.162      0          0.054       0                           0                         0          0         0        0          264.983   0                           0                         0          0          295.126    0                           0                         0          0         2.194    0          0         0
 225 │ Marginal Cost Yearly Average [€]                                     39.284226  0          196.578182  -718.210737                 306.202381                missing    69.35016  missing  missing    4.225389  missing                     missing                   missing    47.745765  missing    missing                     missing                   missing    missing   missing  missing    6         missing
 226 │ Marginal Cost Yearly Average (ex…                                    39.284226  0          0           0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0              ⋯
 227 │ Pan-EU Marginal Cost Yearly Aver…                                    0.256259
 228 │ Spilled Energy On Hydro Plants […
 229 │ SMR costs [M€]                                                       0          0          52          0                           0                         0          0         0        0          0         0                           0                         0          0          0          0                           0                         0          0         0        0          0         0
```

## Data processing

This is of course not suitable yet to use as an input for TEM. Therefore, we will process the dataframe to make it more suitable for our needs.

Drop the first four rows:
```julia
df = df[5:end, :]
```

Rename the column names (currently they are unknown such as X, X.1, X.2 etc.):
```julia
new_names = String.(collect(df[1, :]))
rename!(df, Symbol.(new_names); makeunique=true)
```

Remove the first row as we have just renamed the column names to the same string values:
```julia
df = df[2:end, :]
```

The dataframe seems to contain more data than just installed capacities. We will filter it in such a way that we only consider rows from this section onwards:

```julia
start_index = findfirst(row -> row[1] == "Installed Capacities [MW]", eachrow(df))
end_index = nrow(df)
df = df[start_index:end_index, :]
```

Now we will specify in which countries we are interested to obtain capacity values. For now, we will consider all the countries in the set but feel free to adjust according to what country you are interested in for your analysis:

```julia
country_codes = [
    "NL", "BE", "DE", "FR", "DK", "UK", "IE", "CH", "AT", "LU", "CZ", "PL", "SE", "NO",
    "ES", "PT", "IT", "MT", "SI", "HU", "SK", "LT", "LV", "EE", "FI", "HR", "GR", "BG",
    "RO", "CY", "BA", "RS", "AL", "MK", "ME"
]
```

We will also need to be careful of data types in each column. Therefore, we will convert all columns except for the first two (that contain string values) to numeric. We also rename the first two columns for clarity:

```julia
for c in names(df)[3:end]
    df[!, c] = [ismissing(x) ? 0.0 : tryparse(Float64, String(x)) === nothing ? 0.0 : tryparse(Float64, String(x)) for x in df[!, c]]
end

rename!(df, Dict(names(df)[1] => "Category", names(df)[2] => "Output_type"))
```

Now we can proceed to make a new dataframe 'df_summed' which contains the summed values of capacity per country. You will have noticed that the TYNDP provides capacity values in different subcategories per country. Take for example Austria, where we have the following columns: AT00, AT00 EV Passenger Prosumer, AT00 EV Passenger Street, AT00 SRES and AT00RETE. These capacities all belong to bidding zone AT00.

```julia
df_summed = df[:, [:Output_type]] # Here we create the new df_summed

for code in country_codes # This is done for the countries previously mentioned in the country_codes dictionary
    matching_cols = filter(c -> startswith(String(c), code), names(df)[3:end])
    if !isempty(matching_cols)
        df_summed[!, Symbol(code)] = reduce(+, eachcol(df[:, matching_cols]); init=zeros(nrow(df)))
    end
end

```

Let's inspect this new df_summed by taking the first twenty rows to see how our new dataframe is looking:

```julia
first(df_summed, 20)
```
```
20×36 DataFrame
 Row │ Output_type             NL       BE       DE       FR       DK       UK       IE       CH       AT       LU       CZ       PL       SE       NO       ES       PT        ⋯
     │ String                  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64  Float64   ⋯
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Nuclear                     0.0      0.0      0.0  50139.0      0.0  16000.0      0.0      0.0      0.0      0.0   6983.0  15000.0  11600.0      0.0      0.0      0.0   ⋯
   2 │ Lignite old 1               0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
   3 │ Lignite old 2               0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
   4 │ Lignite new                 0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
   5 │ Lignite CCS                 0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0   ⋯
   6 │ Hard coal old 1             0.0      0.0      0.0      0.0      0.0     70.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
   7 │ Hard coal old 2             0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0    833.0      0.0      0.0      0.0      0.0
   8 │ Hard coal new               0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0   1663.0      0.0      0.0      0.0      0.0
   9 │ Hard coal CCS               0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0   ⋯
  10 │ Gas conventional old 1      0.0      0.0      0.0      0.0      0.0    194.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
  11 │ Gas conventional old 2      0.0    807.0      0.0      0.0      0.0    202.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
  12 │ Gas CCGT old 1              0.0      0.0      0.0      0.0      0.0      0.0    294.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
  13 │ Gas CCGT old 2              0.0      0.0      0.0      0.0     10.0    539.0    407.0      0.0      0.0      0.0    396.0      0.0      0.0      0.0      0.0      0.0   ⋯
  14 │ Gas CCGT new                0.0   3390.0      0.0      0.0      0.0   1030.0   2238.0      0.0      0.0      0.0   2162.0   6223.0      0.0      0.0      0.0      0.0
  15 │ Gas CCGT CCS                0.0      0.0      0.0      0.0      0.0   3384.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
  16 │ Gas OCGT old                0.0      0.0      0.0      0.0    492.0   1243.0      0.0      0.0      0.0      0.0      0.0      0.0     97.0      0.0      0.0      0.0
  17 │ Gas OCGT new                0.0    244.0      0.0      0.0    120.0      0.0    116.0      0.0      0.0      0.0    131.0      0.0      0.0      0.0      0.0      0.0   ⋯
  18 │ Gas CCGT present 1          0.0      0.0      0.0      0.0      0.0   3748.0    803.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0  14920.0      0.0
  19 │ Gas CCGT present 2          0.0   1281.0      0.0   3835.0      0.0    408.0   2098.0      0.0      0.0      0.0     55.0      0.0      0.0      0.0      0.0      0.0
  20 │ Light oil                   0.0      0.0      0.0      0.0    683.0    389.0    188.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0      0.0
```

Now we have a clean dataframe that contains aggregated installed capacity values per technology per country.

## TEM Format

The final step is to take our newly created 'df_summed' and convert it into something that can be used as input for TEM. Since we are considering installed capacities for electricity generating units, we are only considering producing assets. Since we are describing their installed capacity values, we should process this data into the `"asset.csv"` stucture. We will fill it in with the information we know, namely the `asset`, `type` and `capacity` values.

Create the columns:

```julia
assets = String[]
types = String[]
capacities = Float64[]
```

Now fill the columns in for each country and associated 'output type' (type of technology e.g. onshore wind or ccgt installations):

```julia
for country in names(df_summed)[2:end]
    for row in eachrow(df_summed)
        push!(assets, "$(country)_$(row.Output_type)")
        push!(types, "producer")
        push!(capacities, row[country])
    end
end
```

We can now create our final dataframe, alongside some cleaning (we do not want empty columns or "technologies" such as `adequacy`):

```julia
df_assets = DataFrame(asset=assets, type=types, capacity=capacities)
df_assets = filter(row -> !endswith(row.asset, "_") && !occursin(r"(?i)adequacy", row.asset), df_assets)
```

To verify if everything looks correct, let's print the first few rows of this new dataframe:

```julia
first(df_assets, 40)
```
```
40×3 DataFrame
 Row │ asset                              type      capacity
     │ String                             String    Float64
─────┼───────────────────────────────────────────────────────
   1 │ NL_Nuclear                         producer       0.0
   2 │ NL_Lignite old 1                   producer       0.0
   3 │ NL_Lignite old 2                   producer       0.0
   4 │ NL_Lignite new                     producer       0.0
   5 │ NL_Lignite CCS                     producer       0.0
   6 │ NL_Hard coal old 1                 producer       0.0
   7 │ NL_Hard coal old 2                 producer       0.0
   8 │ NL_Hard coal new                   producer       0.0
   9 │ NL_Hard coal CCS                   producer       0.0
  10 │ NL_Gas conventional old 1          producer       0.0
  11 │ NL_Gas conventional old 2          producer       0.0
  12 │ NL_Gas CCGT old 1                  producer       0.0
  13 │ NL_Gas CCGT old 2                  producer       0.0
  14 │ NL_Gas CCGT new                    producer       0.0
  15 │ NL_Gas CCGT CCS                    producer       0.0
  ⋮  │                 ⋮                     ⋮         ⋮
  27 │ NL_Pump Storage - Open Loop (tur…  producer       0.0
  28 │ NL_Pump Storage - Open Loop (pum…  producer       0.0
  29 │ NL_Pump Storage - Closed Loop (t…  producer       0.0
  30 │ NL_Pump Storage - Closed Loop (p…  producer       0.0
  31 │ NL_Pondage                         producer       0.0
  32 │ NL_Wind Onshore                    producer   20000.0
  33 │ NL_Wind Offshore                   producer   41000.0
  34 │ NL_Solar (Photovoltaic)            producer   99984.0
  35 │ NL_Solar (Thermal)                 producer       0.0
  36 │ NL_Others renewable                producer       0.0
  37 │ NL_Others non-renewable            producer       0.0
  38 │ NL_Lignite biofuel                 producer       0.0
  39 │ NL_Hard Coal biofuel               producer       0.0
  40 │ NL_Gas biofuel                     producer       0.0
```

And there you have it, a raw data output from a scenario study converted to TEM input format!

We can now save it as a .csv and it can be ready for modelling!

```julia
CSV.write("asset.csv", df_assets)
```

## Full script

The full code can be found below so you can run it in one go if you wish:
```julia
#TLC Data processing June 2025 - this scripts converts a raw TYNDP2024 output file for the installed capacities into TulipaEnergyModel input format. More specifically, we convert the values found for the Global Ambition 2050 scenario.
using Pkg: Pkg
Pkg.activate(".")
Pkg.instantiate()
using DuckDB
using DataFrames
using Chain
using Statistics
using Tables
using CSV

con = DBInterface.connect(DuckDB.DB, "GA2050_capacities.duckdb")

println(DuckDB.execute(con, "SHOW TABLES") |> DataFrame)

df = DuckDB.execute(con, "SELECT * FROM \"Installed_capacities\"") |> DataFrame

df = df[5:end, :]

new_names = String.(collect(df[1, :]))
rename!(df, Symbol.(new_names); makeunique=true)

df = df[2:end, :]

start_index = findfirst(row -> row[1] == "Installed Capacities [MW]", eachrow(df))
end_index = nrow(df)
df = df[start_index:end_index, :]

country_codes = [
    "NL", "BE", "DE", "FR", "DK", "UK", "IE", "CH", "AT", "LU", "CZ", "PL", "SE", "NO",
    "ES", "PT", "IT", "MT", "SI", "HU", "SK", "LT", "LV", "EE", "FI", "HR", "GR", "BG",
    "RO", "CY", "BA", "RS", "AL", "MK", "ME"
]


for c in names(df)[3:end]
    df[!, c] = [ismissing(x) ? 0.0 : tryparse(Float64, String(x)) === nothing ? 0.0 : tryparse(Float64, String(x)) for x in df[!, c]]
end

rename!(df, Dict(names(df)[1] => "Category", names(df)[2] => "Output_type"))


df_summed = df[:, [:Output_type]]

for code in country_codes
    matching_cols = filter(c -> startswith(String(c), code), names(df)[3:end])
    if !isempty(matching_cols)
        df_summed[!, Symbol(code)] = reduce(+, eachcol(df[:, matching_cols]); init=zeros(nrow(df)))
    end
end

first(df_summed, 20)

assets = String[]
types = String[]
capacities = Float64[]

for country in names(df_summed)[2:end]
    for row in eachrow(df_summed)
        push!(assets, "$(country)_$(row.Output_type)")
        push!(types, "producer")
        push!(capacities, row[country])
    end
end

df_assets = DataFrame(asset=assets, type=types, capacity=capacities)
df_assets = filter(row -> !endswith(row.asset, "_") && !occursin(r"(?i)adequacy", row.asset), df_assets)

first(df_assets, 40)
CSV.write("asset.csv", df_assets)
```
