import os
import pandas as pd
import numpy as np

inputs_path = 'C:\\GitLocal\\TulipaEnergyModel.jl\\debugging\\FULLYEAR-profiles_rep_periods.csv'
outputs_path = 'C:\\GitLocal\\TulipaEnergyModel.jl\\debugging\\to-convert\\case-study\\profiles-rep-periods.csv'


inframe = pd.read_csv(inputs_path)
inframe_wind = inframe[inframe['profile_name'] == 'NL_Wind_Onshore'].reset_index()
inframe_solar = inframe[inframe['profile_name'] == 'NL_Solar'].reset_index()
inframe_demand = inframe[inframe['profile_name'] == 'NL_E_Demand'].reset_index()
df = pd.DataFrame(columns=('profile_name', 'year', 'rep_period', 'timestep', 'value', 'scenario'))

base = 5301

for i in range(0,168):
  df.loc[i] = ['demand-demand', 2030, 1, i+1, inframe_demand['value'][base+i], 1]

for i in range(168,2*168):
  df.loc[i] = ['solar-availability', 2030, 1, (i % 168) + 1, inframe_solar['value'][base+(i%168)], 1]

for i in range(2*168,3*168):
  df.loc[i] = ['wind-availability', 2030, 1, (i % 168) + 1, inframe_wind['value'][base+(i%168)], 1]


df.to_csv(index=False, path_or_buf=outputs_path)
