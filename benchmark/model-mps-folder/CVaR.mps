NAME
ROWS
 N  OBJ
 L  max_output_flows_limit_aggregated_vintage_method[ens,2030,1,1:1]
 L  max_output_flows_limit_aggregated_vintage_method[ens,2030,1,2:2]
 L  max_output_flows_limit_aggregated_vintage_method[ens,2030,1,3:3]
 L  max_output_flows_limit_aggregated_vintage_method[ens,2030,2,1:1]
 L  max_output_flows_limit_aggregated_vintage_method[ens,2030,2,2:2]
 L  max_output_flows_limit_aggregated_vintage_method[ens,2030,2,3:3]
 L  max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,1:1]
 L  max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,2:2]
 L  max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,3:3]
 L  max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,1:1]
 L  max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,2:2]
 L  max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,3:3]
 L  max_output_flows_limit_aggregated_vintage_method[wind,2030,1,1:1]
 L  max_output_flows_limit_aggregated_vintage_method[wind,2030,1,2:2]
 L  max_output_flows_limit_aggregated_vintage_method[wind,2030,1,3:3]
 L  max_output_flows_limit_aggregated_vintage_method[wind,2030,2,1:1]
 L  max_output_flows_limit_aggregated_vintage_method[wind,2030,2,2:2]
 L  max_output_flows_limit_aggregated_vintage_method[wind,2030,2,3:3]
 G  scenario_tail_excess[1]
 G  scenario_tail_excess[2]
 E  consumer_balance[demand,2030,1,1:1]
 E  consumer_balance[demand,2030,1,2:2]
 E  consumer_balance[demand,2030,1,3:3]
 E  consumer_balance[demand,2030,2,1:1]
 E  consumer_balance[demand,2030,2,2:2]
 E  consumer_balance[demand,2030,2,3:3]
COLUMNS
    flow[(wind,demand),2030,1,1:1] max_output_flows_limit_aggregated_vintage_method[wind,2030,1,1:1] 1
    flow[(wind,demand),2030,1,1:1] consumer_balance[demand,2030,1,1:1] 1
    flow[(wind,demand),2030,1,2:2] max_output_flows_limit_aggregated_vintage_method[wind,2030,1,2:2] 1
    flow[(wind,demand),2030,1,2:2] consumer_balance[demand,2030,1,2:2] 1
    flow[(wind,demand),2030,1,3:3] max_output_flows_limit_aggregated_vintage_method[wind,2030,1,3:3] 1
    flow[(wind,demand),2030,1,3:3] consumer_balance[demand,2030,1,3:3] 1
    flow[(ocgt,demand),2030,1,1:1] max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,1:1] 1
    flow[(ocgt,demand),2030,1,1:1] scenario_tail_excess[1] -150
    flow[(ocgt,demand),2030,1,1:1] consumer_balance[demand,2030,1,1:1] 1
    flow[(ocgt,demand),2030,1,1:1] OBJ 45
    flow[(ocgt,demand),2030,1,2:2] max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,2:2] 1
    flow[(ocgt,demand),2030,1,2:2] scenario_tail_excess[1] -150
    flow[(ocgt,demand),2030,1,2:2] consumer_balance[demand,2030,1,2:2] 1
    flow[(ocgt,demand),2030,1,2:2] OBJ 45
    flow[(ocgt,demand),2030,1,3:3] max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,3:3] 1
    flow[(ocgt,demand),2030,1,3:3] scenario_tail_excess[1] -150
    flow[(ocgt,demand),2030,1,3:3] consumer_balance[demand,2030,1,3:3] 1
    flow[(ocgt,demand),2030,1,3:3] OBJ 45
    flow[(ens,demand),2030,1,1:1] max_output_flows_limit_aggregated_vintage_method[ens,2030,1,1:1] 1
    flow[(ens,demand),2030,1,1:1] scenario_tail_excess[1] -1500
    flow[(ens,demand),2030,1,1:1] consumer_balance[demand,2030,1,1:1] 1
    flow[(ens,demand),2030,1,1:1] OBJ 450
    flow[(ens,demand),2030,1,2:2] max_output_flows_limit_aggregated_vintage_method[ens,2030,1,2:2] 1
    flow[(ens,demand),2030,1,2:2] scenario_tail_excess[1] -1500
    flow[(ens,demand),2030,1,2:2] consumer_balance[demand,2030,1,2:2] 1
    flow[(ens,demand),2030,1,2:2] OBJ 450
    flow[(ens,demand),2030,1,3:3] max_output_flows_limit_aggregated_vintage_method[ens,2030,1,3:3] 1
    flow[(ens,demand),2030,1,3:3] scenario_tail_excess[1] -1500
    flow[(ens,demand),2030,1,3:3] consumer_balance[demand,2030,1,3:3] 1
    flow[(ens,demand),2030,1,3:3] OBJ 450
    flow[(wind,demand),2030,2,1:1] max_output_flows_limit_aggregated_vintage_method[wind,2030,2,1:1] 1
    flow[(wind,demand),2030,2,1:1] consumer_balance[demand,2030,2,1:1] 1
    flow[(wind,demand),2030,2,2:2] max_output_flows_limit_aggregated_vintage_method[wind,2030,2,2:2] 1
    flow[(wind,demand),2030,2,2:2] consumer_balance[demand,2030,2,2:2] 1
    flow[(wind,demand),2030,2,3:3] max_output_flows_limit_aggregated_vintage_method[wind,2030,2,3:3] 1
    flow[(wind,demand),2030,2,3:3] consumer_balance[demand,2030,2,3:3] 1
    flow[(ocgt,demand),2030,2,1:1] max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,1:1] 1
    flow[(ocgt,demand),2030,2,1:1] scenario_tail_excess[2] -150
    flow[(ocgt,demand),2030,2,1:1] consumer_balance[demand,2030,2,1:1] 1
    flow[(ocgt,demand),2030,2,1:1] OBJ 30
    flow[(ocgt,demand),2030,2,2:2] max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,2:2] 1
    flow[(ocgt,demand),2030,2,2:2] scenario_tail_excess[2] -150
    flow[(ocgt,demand),2030,2,2:2] consumer_balance[demand,2030,2,2:2] 1
    flow[(ocgt,demand),2030,2,2:2] OBJ 30
    flow[(ocgt,demand),2030,2,3:3] max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,3:3] 1
    flow[(ocgt,demand),2030,2,3:3] scenario_tail_excess[2] -150
    flow[(ocgt,demand),2030,2,3:3] consumer_balance[demand,2030,2,3:3] 1
    flow[(ocgt,demand),2030,2,3:3] OBJ 30
    flow[(ens,demand),2030,2,1:1] max_output_flows_limit_aggregated_vintage_method[ens,2030,2,1:1] 1
    flow[(ens,demand),2030,2,1:1] scenario_tail_excess[2] -1500
    flow[(ens,demand),2030,2,1:1] consumer_balance[demand,2030,2,1:1] 1
    flow[(ens,demand),2030,2,1:1] OBJ 300
    flow[(ens,demand),2030,2,2:2] max_output_flows_limit_aggregated_vintage_method[ens,2030,2,2:2] 1
    flow[(ens,demand),2030,2,2:2] scenario_tail_excess[2] -1500
    flow[(ens,demand),2030,2,2:2] consumer_balance[demand,2030,2,2:2] 1
    flow[(ens,demand),2030,2,2:2] OBJ 300
    flow[(ens,demand),2030,2,3:3] max_output_flows_limit_aggregated_vintage_method[ens,2030,2,3:3] 1
    flow[(ens,demand),2030,2,3:3] scenario_tail_excess[2] -1500
    flow[(ens,demand),2030,2,3:3] consumer_balance[demand,2030,2,3:3] 1
    flow[(ens,demand),2030,2,3:3] OBJ 300
    value_at_risk_threshold_mu scenario_tail_excess[1] 1
    value_at_risk_threshold_mu scenario_tail_excess[2] 1
    value_at_risk_threshold_mu OBJ 0.5
    tail_excess_slack_xi[1] scenario_tail_excess[1] 1
    tail_excess_slack_xi[1] OBJ 1.5000000000000002
    tail_excess_slack_xi[2] scenario_tail_excess[2] 1
    tail_excess_slack_xi[2] OBJ 1.0000000000000002
RHS
    rhs       max_output_flows_limit_aggregated_vintage_method[ens,2030,1,1:1] 200
    rhs       max_output_flows_limit_aggregated_vintage_method[ens,2030,1,2:2] 200
    rhs       max_output_flows_limit_aggregated_vintage_method[ens,2030,1,3:3] 200
    rhs       max_output_flows_limit_aggregated_vintage_method[ens,2030,2,1:1] 200
    rhs       max_output_flows_limit_aggregated_vintage_method[ens,2030,2,2:2] 200
    rhs       max_output_flows_limit_aggregated_vintage_method[ens,2030,2,3:3] 200
    rhs       max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,1:1] 100
    rhs       max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,2:2] 100
    rhs       max_output_flows_limit_aggregated_vintage_method[ocgt,2030,1,3:3] 100
    rhs       max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,1:1] 100
    rhs       max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,2:2] 100
    rhs       max_output_flows_limit_aggregated_vintage_method[ocgt,2030,2,3:3] 100
    rhs       max_output_flows_limit_aggregated_vintage_method[wind,2030,1,1:1] 80
    rhs       max_output_flows_limit_aggregated_vintage_method[wind,2030,1,2:2] 80
    rhs       max_output_flows_limit_aggregated_vintage_method[wind,2030,1,3:3] 80
    rhs       max_output_flows_limit_aggregated_vintage_method[wind,2030,2,1:1] 10
    rhs       max_output_flows_limit_aggregated_vintage_method[wind,2030,2,2:2] 10
    rhs       max_output_flows_limit_aggregated_vintage_method[wind,2030,2,3:3] 10
    rhs       scenario_tail_excess[1] 0
    rhs       scenario_tail_excess[2] 0
    rhs       consumer_balance[demand,2030,1,1:1] 100
    rhs       consumer_balance[demand,2030,1,2:2] 100
    rhs       consumer_balance[demand,2030,1,3:3] 100
    rhs       consumer_balance[demand,2030,2,1:1] 100
    rhs       consumer_balance[demand,2030,2,2:2] 100
    rhs       consumer_balance[demand,2030,2,3:3] 100
RANGES
BOUNDS
 LO bounds    flow[(wind,demand),2030,1,1:1] 0
 PL bounds    flow[(wind,demand),2030,1,1:1]
 LO bounds    flow[(wind,demand),2030,1,2:2] 0
 PL bounds    flow[(wind,demand),2030,1,2:2]
 LO bounds    flow[(wind,demand),2030,1,3:3] 0
 PL bounds    flow[(wind,demand),2030,1,3:3]
 LO bounds    flow[(ocgt,demand),2030,1,1:1] 0
 PL bounds    flow[(ocgt,demand),2030,1,1:1]
 LO bounds    flow[(ocgt,demand),2030,1,2:2] 0
 PL bounds    flow[(ocgt,demand),2030,1,2:2]
 LO bounds    flow[(ocgt,demand),2030,1,3:3] 0
 PL bounds    flow[(ocgt,demand),2030,1,3:3]
 LO bounds    flow[(ens,demand),2030,1,1:1] 0
 PL bounds    flow[(ens,demand),2030,1,1:1]
 LO bounds    flow[(ens,demand),2030,1,2:2] 0
 PL bounds    flow[(ens,demand),2030,1,2:2]
 LO bounds    flow[(ens,demand),2030,1,3:3] 0
 PL bounds    flow[(ens,demand),2030,1,3:3]
 LO bounds    flow[(wind,demand),2030,2,1:1] 0
 PL bounds    flow[(wind,demand),2030,2,1:1]
 LO bounds    flow[(wind,demand),2030,2,2:2] 0
 PL bounds    flow[(wind,demand),2030,2,2:2]
 LO bounds    flow[(wind,demand),2030,2,3:3] 0
 PL bounds    flow[(wind,demand),2030,2,3:3]
 LO bounds    flow[(ocgt,demand),2030,2,1:1] 0
 PL bounds    flow[(ocgt,demand),2030,2,1:1]
 LO bounds    flow[(ocgt,demand),2030,2,2:2] 0
 PL bounds    flow[(ocgt,demand),2030,2,2:2]
 LO bounds    flow[(ocgt,demand),2030,2,3:3] 0
 PL bounds    flow[(ocgt,demand),2030,2,3:3]
 LO bounds    flow[(ens,demand),2030,2,1:1] 0
 PL bounds    flow[(ens,demand),2030,2,1:1]
 LO bounds    flow[(ens,demand),2030,2,2:2] 0
 PL bounds    flow[(ens,demand),2030,2,2:2]
 LO bounds    flow[(ens,demand),2030,2,3:3] 0
 PL bounds    flow[(ens,demand),2030,2,3:3]
 LO bounds    value_at_risk_threshold_mu 0
 PL bounds    value_at_risk_threshold_mu
 LO bounds    tail_excess_slack_xi[1] 0
 PL bounds    tail_excess_slack_xi[1]
 LO bounds    tail_excess_slack_xi[2] 0
 PL bounds    tail_excess_slack_xi[2]
ENDATA
