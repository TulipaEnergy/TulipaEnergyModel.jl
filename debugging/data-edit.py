import os
import pandas as pd
import numpy as np

inputs_path = 'D:\\GitShit\\TulipaEnergyModel.jl\\debugging\\to-convert'
outputs_path = 'D:\\GitShit\\TulipaEnergyModel.jl\\debugging\\converted'

cases = [f for f in os.scandir(inputs_path) if f.is_dir()]

def locate(in_data, table, asset_name, use_from_asset=False, use_to_asset=False):
    if not use_from_asset and not use_to_asset:
        try:
            return in_data[table].loc[in_data[table].asset == asset_name].iloc[0].copy()
        except:
            return None
    elif use_to_asset:
        try:
            return in_data[table].loc[in_data[table].to_asset == asset_name].iloc[0].copy()
        except:
            return None
    else:
        try:
            return in_data[table].loc[in_data[table].from_asset == asset_name].iloc[0].copy()
        except:
            return None

def compute_investment_limit(asset, in_data):
    df = in_data["asset-commission.csv"]
    return int(np.floor(df.loc[df["asset"] == asset.asset].investment_limit/asset.capacity)) # in units of assets

def compute_init_units(asset, in_data):
    df = in_data["asset-both.csv"]
    return int(np.floor(df.loc[df["asset"] == asset.asset].initial_units))

def read_case(case):
    data = {}
    csvs = [f for f in os.scandir(case.path) if f.is_file() and f.path.endswith('.csv')]
    for csv in csvs:
        df = pd.read_csv(csv.path)
        data[csv.name] = df

    return data


def convert_case(case, in_data):
    out_data = {}

    for key in in_data.keys():
        out_data[key] = pd.DataFrame(columns=in_data[key].columns)

    # First, for each asset we find the maximum number Tulipa can buy, and add that many
    # We do this, and duplicate its flows, profiles, groups, etc.
    # Keeping in mind investement limit is defined in MW
    # We do this separately for each year
    new_rows = {
        "asset-both": [],
        "asset-commission": [],
        "asset-milestone": [],
        "asset": [],
        "assets-profiles": [],
        "flow-both": [],
        "flow-commission": [],
        "flow-milestone": [],
        "flow": [],
        "flows-profiles": [],
        "profiles-rep-periods": [],
        "rep-periods-data": [],
        "rep-periods-mapping": [],
        "timeframe-data": [],
        "year-data": [],
    }

    # Duplicate asset-related data
    for _, asset in in_data["asset.csv"].iterrows():
        if asset.type != "producer":
            new_rows["asset-both"].append(locate(in_data, "asset-both.csv", asset.asset))
            new_rows["asset-commission"].append(locate(in_data, "asset-commission.csv", asset.asset))
            new_rows["asset-milestone"].append(locate(in_data, "asset-milestone.csv", asset.asset))
            new_rows["assets-profiles"].append(locate(in_data, "assets-profiles.csv", asset.asset))
            new_rows["asset"].append(asset)
            continue
        inv_limit = compute_investment_limit(asset, in_data)
        init_units = compute_init_units(asset, in_data)
    
        
        for i in range(0, inv_limit):
            # ASSET
            new_row = asset.copy()
            new_row.asset = f"{new_row.asset}_{i}"
            new_rows["asset"].append(new_row)


            # ASSET-BOTH
            new_row = locate(in_data, "asset-both.csv", asset.asset)
            new_row.asset = f"{new_row.asset}_{i}"
            
            if (init_units > 0):
                new_row.initial_units = 1
            else:
                new_row.initial_units = 0
            init_units -= 1    
            
            new_rows["asset-both"].append(new_row)


            # ASSET-COMMISSION
            new_row = locate(in_data, "asset-commission.csv", asset.asset)
            if new_row is not None:
                new_row.asset = f"{new_row.asset}_{i}"

                new_row.investment_limit = 1 * asset.capacity

                new_rows["asset-commission"].append(new_row)


            # ASSET-MILESTONE
            new_row = locate(in_data, "asset-milestone.csv", asset.asset)
            if new_row is not None:
                new_row.asset = f"{new_row.asset}_{i}"
                new_rows["asset-milestone"].append(new_row)

            # ASSETS-PROFILES
            new_row = locate(in_data, "assets-profiles.csv", asset.asset)
            if new_row is not None:
                new_row.asset = f"{new_row.asset}_{i}"
                new_rows["assets-profiles"].append(new_row)

            # FLOW-BOTH
            new_row = locate(in_data, "flow-both.csv", asset.asset, use_from_asset=True)
            if new_row is not None:
                new_row.from_asset = f"{new_row.from_asset}_{i}"
                new_rows["flow-both"].append(new_row)

            # FLOW-COMMISSION
            new_row = locate(in_data, "flow-commission.csv", asset.asset, use_from_asset=True)
            if new_row is not None:
                new_row.from_asset = f"{new_row.from_asset}_{i}"
                new_rows["flow-commission"].append(new_row)

            # FLOW-MILESTONE
            new_row = locate(in_data, "flow-milestone.csv", asset.asset, use_from_asset=True)
            if new_row is not None:
                new_row.from_asset = f"{new_row.from_asset}_{i}"
                new_rows["flow-milestone"].append(new_row)

            # FLOW
            new_row = locate(in_data, "flow.csv", asset.asset, use_from_asset=True)
            if new_row is not None:
                new_row.from_asset = f"{new_row.from_asset}_{i}"
                new_rows["flow"].append(new_row)

            # FLOWs-PROFILES
            new_row = locate(in_data, "flows-profiles.csv", asset.asset, use_from_asset=True)
            if new_row is not None:
                new_row.from_asset = f"{new_row.from_asset}_{i}"
                new_rows["flows-profiles"].append(new_row)        

    # Propagate asset-unrelated data
    for table in ("profiles-rep-periods", "rep-periods-data", "rep-periods-mapping", "timeframe-data", "year-data"):
        for _, row in in_data[f"{table}.csv"].iterrows():
            new_rows[table].append(row)

    for key in new_rows.keys():
        valid_rows = [row for row in new_rows[key] if row is not None]

        if len(valid_rows) == 0:
            continue
        out_data[key + ".csv"] = pd.DataFrame(valid_rows)


    return out_data

def write_case(case, data):
    for key in data.keys():
        path = os.path.join(outputs_path, case.name, key)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        data[key].to_csv(index=False, path_or_buf=path)

for case in cases:
    in_data = read_case(case)
    out_data = convert_case(case, in_data)
    write_case(case, out_data)