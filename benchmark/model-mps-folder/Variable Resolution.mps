NAME
ROWS
 N  OBJ
 L  max_output_flows_limit_simple_method[H2,2030,1,1:6]
 L  max_output_flows_limit_simple_method[ccgt,2030,1,1:1]
 L  max_output_flows_limit_simple_method[ccgt,2030,1,2:2]
 L  max_output_flows_limit_simple_method[ccgt,2030,1,3:3]
 L  max_output_flows_limit_simple_method[ccgt,2030,1,4:4]
 L  max_output_flows_limit_simple_method[ccgt,2030,1,5:5]
 L  max_output_flows_limit_simple_method[ccgt,2030,1,6:6]
 L  max_output_flows_limit_simple_method[phs,2030,1,1:4]
 L  max_output_flows_limit_simple_method[phs,2030,1,5:6]
 L  max_output_flows_limit_simple_method[wind,2030,1,1:2]
 L  max_output_flows_limit_simple_method[wind,2030,1,3:3]
 L  max_output_flows_limit_simple_method[wind,2030,1,4:6]
 L  max_input_flows_limit_simple_method[phs,2030,1,1:3]
 L  max_input_flows_limit_simple_method[phs,2030,1,4:6]
 L  max_storage_level_rep_period_limit[phs,2030,1,1:6]
 L  max_transport_flow_limit_simple_method[(balance,demand),2030,1,1:3]
 L  max_transport_flow_limit_simple_method[(balance,demand),2030,1,4:6]
 G  min_storage_level_rep_period_limit[phs,2030,1,1:6]
 G  min_transport_flow_limit_simple_method[(balance,demand),2030,1,1:3]
 G  min_transport_flow_limit_simple_method[(balance,demand),2030,1,4:6]
 E  consumer_balance[demand,2030,1,1:3]
 E  consumer_balance[demand,2030,1,4:6]
 E  balance_storage_rep_period[phs,2030,1,1:6]
 E  balance_hub[balance,2030,1,1:1]
 E  balance_hub[balance,2030,1,2:2]
 E  balance_hub[balance,2030,1,3:3]
 E  balance_hub[balance,2030,1,4:4]
 E  balance_hub[balance,2030,1,5:5]
 E  balance_hub[balance,2030,1,6:6]
 E  conversion_balance[ccgt,2030,1,1:6]
COLUMNS
    flow[(H2,ccgt),2030,1,1:6] max_output_flows_limit_simple_method[H2,2030,1,1:6] 1
    flow[(H2,ccgt),2030,1,1:6] conversion_balance[ccgt,2030,1,1:6] 6
    flow[(H2,ccgt),2030,1,1:6] OBJ 0.06
    flow[(wind,balance),2030,1,1:2] max_output_flows_limit_simple_method[wind,2030,1,1:2] 1
    flow[(wind,balance),2030,1,1:2] balance_hub[balance,2030,1,1:1] 1
    flow[(wind,balance),2030,1,1:2] balance_hub[balance,2030,1,2:2] 1
    flow[(wind,balance),2030,1,1:2] OBJ 0.01
    flow[(wind,balance),2030,1,3:6] max_output_flows_limit_simple_method[wind,2030,1,3:3] 1
    flow[(wind,balance),2030,1,3:6] max_output_flows_limit_simple_method[wind,2030,1,4:6] 1
    flow[(wind,balance),2030,1,3:6] balance_hub[balance,2030,1,3:3] 1
    flow[(wind,balance),2030,1,3:6] balance_hub[balance,2030,1,4:4] 1
    flow[(wind,balance),2030,1,3:6] balance_hub[balance,2030,1,5:5] 1
    flow[(wind,balance),2030,1,3:6] balance_hub[balance,2030,1,6:6] 1
    flow[(wind,balance),2030,1,3:6] OBJ 0.02
    flow[(wind,phs),2030,1,1:3] max_output_flows_limit_simple_method[wind,2030,1,1:2] 1
    flow[(wind,phs),2030,1,1:3] max_output_flows_limit_simple_method[wind,2030,1,3:3] 1
    flow[(wind,phs),2030,1,1:3] max_input_flows_limit_simple_method[phs,2030,1,1:3] 1
    flow[(wind,phs),2030,1,1:3] balance_storage_rep_period[phs,2030,1,1:6] -2.7
    flow[(wind,phs),2030,1,1:3] OBJ 0.006
    flow[(wind,phs),2030,1,4:6] max_output_flows_limit_simple_method[wind,2030,1,4:6] 1
    flow[(wind,phs),2030,1,4:6] max_input_flows_limit_simple_method[phs,2030,1,4:6] 1
    flow[(wind,phs),2030,1,4:6] balance_storage_rep_period[phs,2030,1,1:6] -2.7
    flow[(wind,phs),2030,1,4:6] OBJ 0.006
    flow[(phs,balance),2030,1,1:4] max_output_flows_limit_simple_method[phs,2030,1,1:4] 1
    flow[(phs,balance),2030,1,1:4] balance_storage_rep_period[phs,2030,1,1:6] 4.444444444444445
    flow[(phs,balance),2030,1,1:4] balance_hub[balance,2030,1,1:1] 1
    flow[(phs,balance),2030,1,1:4] balance_hub[balance,2030,1,2:2] 1
    flow[(phs,balance),2030,1,1:4] balance_hub[balance,2030,1,3:3] 1
    flow[(phs,balance),2030,1,1:4] balance_hub[balance,2030,1,4:4] 1
    flow[(phs,balance),2030,1,1:4] OBJ 0.004
    flow[(phs,balance),2030,1,5:6] max_output_flows_limit_simple_method[phs,2030,1,5:6] 1
    flow[(phs,balance),2030,1,5:6] balance_storage_rep_period[phs,2030,1,1:6] 2.2222222222222223
    flow[(phs,balance),2030,1,5:6] balance_hub[balance,2030,1,5:5] 1
    flow[(phs,balance),2030,1,5:6] balance_hub[balance,2030,1,6:6] 1
    flow[(phs,balance),2030,1,5:6] OBJ 0.002
    flow[(ccgt,balance),2030,1,1:1] max_output_flows_limit_simple_method[ccgt,2030,1,1:1] 1
    flow[(ccgt,balance),2030,1,1:1] balance_hub[balance,2030,1,1:1] 1
    flow[(ccgt,balance),2030,1,1:1] conversion_balance[ccgt,2030,1,1:6] -2
    flow[(ccgt,balance),2030,1,1:1] OBJ 0.05
    flow[(ccgt,balance),2030,1,2:2] max_output_flows_limit_simple_method[ccgt,2030,1,2:2] 1
    flow[(ccgt,balance),2030,1,2:2] balance_hub[balance,2030,1,2:2] 1
    flow[(ccgt,balance),2030,1,2:2] conversion_balance[ccgt,2030,1,1:6] -2
    flow[(ccgt,balance),2030,1,2:2] OBJ 0.05
    flow[(ccgt,balance),2030,1,3:3] max_output_flows_limit_simple_method[ccgt,2030,1,3:3] 1
    flow[(ccgt,balance),2030,1,3:3] balance_hub[balance,2030,1,3:3] 1
    flow[(ccgt,balance),2030,1,3:3] conversion_balance[ccgt,2030,1,1:6] -2
    flow[(ccgt,balance),2030,1,3:3] OBJ 0.05
    flow[(ccgt,balance),2030,1,4:4] max_output_flows_limit_simple_method[ccgt,2030,1,4:4] 1
    flow[(ccgt,balance),2030,1,4:4] balance_hub[balance,2030,1,4:4] 1
    flow[(ccgt,balance),2030,1,4:4] conversion_balance[ccgt,2030,1,1:6] -2
    flow[(ccgt,balance),2030,1,4:4] OBJ 0.05
    flow[(ccgt,balance),2030,1,5:5] max_output_flows_limit_simple_method[ccgt,2030,1,5:5] 1
    flow[(ccgt,balance),2030,1,5:5] balance_hub[balance,2030,1,5:5] 1
    flow[(ccgt,balance),2030,1,5:5] conversion_balance[ccgt,2030,1,1:6] -2
    flow[(ccgt,balance),2030,1,5:5] OBJ 0.05
    flow[(ccgt,balance),2030,1,6:6] max_output_flows_limit_simple_method[ccgt,2030,1,6:6] 1
    flow[(ccgt,balance),2030,1,6:6] balance_hub[balance,2030,1,6:6] 1
    flow[(ccgt,balance),2030,1,6:6] conversion_balance[ccgt,2030,1,1:6] -2
    flow[(ccgt,balance),2030,1,6:6] OBJ 0.05
    flow[(balance,demand),2030,1,1:3] max_transport_flow_limit_simple_method[(balance,demand),2030,1,1:3] 1
    flow[(balance,demand),2030,1,1:3] min_transport_flow_limit_simple_method[(balance,demand),2030,1,1:3] 1
    flow[(balance,demand),2030,1,1:3] consumer_balance[demand,2030,1,1:3] 1
    flow[(balance,demand),2030,1,1:3] balance_hub[balance,2030,1,1:1] -1
    flow[(balance,demand),2030,1,1:3] balance_hub[balance,2030,1,2:2] -1
    flow[(balance,demand),2030,1,1:3] balance_hub[balance,2030,1,3:3] -1
    flow[(balance,demand),2030,1,1:3] OBJ 0.00030000000000000003
    flow[(balance,demand),2030,1,4:6] max_transport_flow_limit_simple_method[(balance,demand),2030,1,4:6] 1
    flow[(balance,demand),2030,1,4:6] min_transport_flow_limit_simple_method[(balance,demand),2030,1,4:6] 1
    flow[(balance,demand),2030,1,4:6] consumer_balance[demand,2030,1,4:6] 1
    flow[(balance,demand),2030,1,4:6] balance_hub[balance,2030,1,4:4] -1
    flow[(balance,demand),2030,1,4:6] balance_hub[balance,2030,1,5:5] -1
    flow[(balance,demand),2030,1,4:6] balance_hub[balance,2030,1,6:6] -1
    flow[(balance,demand),2030,1,4:6] OBJ 0.00030000000000000003
    assets_decommission[H2,2030,2030] max_output_flows_limit_simple_method[H2,2030,1,1:6] 400
    assets_decommission[balance,2030,2030] OBJ 0
    assets_decommission[ccgt,2030,2030] max_output_flows_limit_simple_method[ccgt,2030,1,1:1] 100
    assets_decommission[ccgt,2030,2030] max_output_flows_limit_simple_method[ccgt,2030,1,2:2] 100
    assets_decommission[ccgt,2030,2030] max_output_flows_limit_simple_method[ccgt,2030,1,3:3] 100
    assets_decommission[ccgt,2030,2030] max_output_flows_limit_simple_method[ccgt,2030,1,4:4] 100
    assets_decommission[ccgt,2030,2030] max_output_flows_limit_simple_method[ccgt,2030,1,5:5] 100
    assets_decommission[ccgt,2030,2030] max_output_flows_limit_simple_method[ccgt,2030,1,6:6] 100
    assets_decommission[demand,2030,2030] OBJ 0
    assets_decommission[phs,2030,2030] max_output_flows_limit_simple_method[phs,2030,1,1:4] 25
    assets_decommission[phs,2030,2030] max_output_flows_limit_simple_method[phs,2030,1,5:6] 25
    assets_decommission[phs,2030,2030] max_input_flows_limit_simple_method[phs,2030,1,1:3] 25
    assets_decommission[phs,2030,2030] max_input_flows_limit_simple_method[phs,2030,1,4:6] 25
    assets_decommission[wind,2030,2030] max_output_flows_limit_simple_method[wind,2030,1,1:2] 5.5
    assets_decommission[wind,2030,2030] max_output_flows_limit_simple_method[wind,2030,1,3:3] 5.5
    assets_decommission[wind,2030,2030] max_output_flows_limit_simple_method[wind,2030,1,4:6] 5.166666666666667
    flows_decommission[("balance",_"demand"),2030,2030] max_transport_flow_limit_simple_method[(balance,demand),2030,1,1:3] 200
    flows_decommission[("balance",_"demand"),2030,2030] max_transport_flow_limit_simple_method[(balance,demand),2030,1,4:6] 200
    flows_decommission[("balance",_"demand"),2030,2030] min_transport_flow_limit_simple_method[(balance,demand),2030,1,1:3] -200
    flows_decommission[("balance",_"demand"),2030,2030] min_transport_flow_limit_simple_method[(balance,demand),2030,1,4:6] -200
    storage_level_rep_period[phs,2030,1,1:6] max_storage_level_rep_period_limit[phs,2030,1,1:6] 1
    storage_level_rep_period[phs,2030,1,1:6] min_storage_level_rep_period_limit[phs,2030,1,1:6] 1
    storage_level_rep_period[phs,2030,1,1:6] balance_storage_rep_period[phs,2030,1,1:6] 1
RHS
    rhs       max_output_flows_limit_simple_method[H2,2030,1,1:6] 400
    rhs       max_output_flows_limit_simple_method[ccgt,2030,1,1:1] 100
    rhs       max_output_flows_limit_simple_method[ccgt,2030,1,2:2] 100
    rhs       max_output_flows_limit_simple_method[ccgt,2030,1,3:3] 100
    rhs       max_output_flows_limit_simple_method[ccgt,2030,1,4:4] 100
    rhs       max_output_flows_limit_simple_method[ccgt,2030,1,5:5] 100
    rhs       max_output_flows_limit_simple_method[ccgt,2030,1,6:6] 100
    rhs       max_output_flows_limit_simple_method[phs,2030,1,1:4] 25
    rhs       max_output_flows_limit_simple_method[phs,2030,1,5:6] 25
    rhs       max_output_flows_limit_simple_method[wind,2030,1,1:2] 11
    rhs       max_output_flows_limit_simple_method[wind,2030,1,3:3] 11
    rhs       max_output_flows_limit_simple_method[wind,2030,1,4:6] 10.333333333333334
    rhs       max_input_flows_limit_simple_method[phs,2030,1,1:3] 25
    rhs       max_input_flows_limit_simple_method[phs,2030,1,4:6] 25
    rhs       max_storage_level_rep_period_limit[phs,2030,1,1:6] 150
    rhs       max_transport_flow_limit_simple_method[(balance,demand),2030,1,1:3] 200
    rhs       max_transport_flow_limit_simple_method[(balance,demand),2030,1,4:6] 200
    rhs       min_storage_level_rep_period_limit[phs,2030,1,1:6] 0
    rhs       min_transport_flow_limit_simple_method[(balance,demand),2030,1,1:3] -200
    rhs       min_transport_flow_limit_simple_method[(balance,demand),2030,1,4:6] -200
    rhs       consumer_balance[demand,2030,1,1:3] 85
    rhs       consumer_balance[demand,2030,1,4:6] 69.99999999999999
    rhs       balance_storage_rep_period[phs,2030,1,1:6] 0
    rhs       balance_hub[balance,2030,1,1:1] 0
    rhs       balance_hub[balance,2030,1,2:2] 0
    rhs       balance_hub[balance,2030,1,3:3] 0
    rhs       balance_hub[balance,2030,1,4:4] 0
    rhs       balance_hub[balance,2030,1,5:5] 0
    rhs       balance_hub[balance,2030,1,6:6] 0
    rhs       conversion_balance[ccgt,2030,1,1:6] 0
RANGES
BOUNDS
 LO bounds    flow[(H2,ccgt),2030,1,1:6] 0
 PL bounds    flow[(H2,ccgt),2030,1,1:6]
 LO bounds    flow[(wind,balance),2030,1,1:2] 0
 PL bounds    flow[(wind,balance),2030,1,1:2]
 LO bounds    flow[(wind,balance),2030,1,3:6] 0
 PL bounds    flow[(wind,balance),2030,1,3:6]
 LO bounds    flow[(wind,phs),2030,1,1:3] 0
 PL bounds    flow[(wind,phs),2030,1,1:3]
 LO bounds    flow[(wind,phs),2030,1,4:6] 0
 PL bounds    flow[(wind,phs),2030,1,4:6]
 LO bounds    flow[(phs,balance),2030,1,1:4] 0
 PL bounds    flow[(phs,balance),2030,1,1:4]
 LO bounds    flow[(phs,balance),2030,1,5:6] 0
 PL bounds    flow[(phs,balance),2030,1,5:6]
 LO bounds    flow[(ccgt,balance),2030,1,1:1] 0
 PL bounds    flow[(ccgt,balance),2030,1,1:1]
 LO bounds    flow[(ccgt,balance),2030,1,2:2] 0
 PL bounds    flow[(ccgt,balance),2030,1,2:2]
 LO bounds    flow[(ccgt,balance),2030,1,3:3] 0
 PL bounds    flow[(ccgt,balance),2030,1,3:3]
 LO bounds    flow[(ccgt,balance),2030,1,4:4] 0
 PL bounds    flow[(ccgt,balance),2030,1,4:4]
 LO bounds    flow[(ccgt,balance),2030,1,5:5] 0
 PL bounds    flow[(ccgt,balance),2030,1,5:5]
 LO bounds    flow[(ccgt,balance),2030,1,6:6] 0
 PL bounds    flow[(ccgt,balance),2030,1,6:6]
 FR bounds    flow[(balance,demand),2030,1,1:3]
 FR bounds    flow[(balance,demand),2030,1,4:6]
 LO bounds    assets_decommission[H2,2030,2030] 0
 PL bounds    assets_decommission[H2,2030,2030]
 LO bounds    assets_decommission[balance,2030,2030] 0
 PL bounds    assets_decommission[balance,2030,2030]
 LO bounds    assets_decommission[ccgt,2030,2030] 0
 PL bounds    assets_decommission[ccgt,2030,2030]
 LO bounds    assets_decommission[demand,2030,2030] 0
 PL bounds    assets_decommission[demand,2030,2030]
 LO bounds    assets_decommission[phs,2030,2030] 0
 PL bounds    assets_decommission[phs,2030,2030]
 LO bounds    assets_decommission[wind,2030,2030] 0
 PL bounds    assets_decommission[wind,2030,2030]
 LO bounds    flows_decommission[("balance",_"demand"),2030,2030] 0
 PL bounds    flows_decommission[("balance",_"demand"),2030,2030]
 LO bounds    storage_level_rep_period[phs,2030,1,1:6] 0
 PL bounds    storage_level_rep_period[phs,2030,1,1:6]
ENDATA
