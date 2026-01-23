NAME
ROWS
 N  OBJ
 L  max_output_flows_limit_simple_method[G01,2030,1,1:1]
 L  max_output_flows_limit_simple_method[G02,2030,1,1:1]
 L  max_output_flows_limit_simple_method[G03,2030,1,1:1]
 L  max_output_flows_limit_simple_method[G04,2030,1,1:1]
 L  max_output_flows_limit_simple_method[G05,2030,1,1:1]
 L  max_output_flows_limit_simple_method[G06,2030,1,1:1]
 L  max_output_flows_limit_simple_method[G07,2030,1,1:1]
 L  max_output_flows_limit_simple_method[G08,2030,1,1:1]
 L  max_output_flows_limit_simple_method[G09,2030,1,1:1]
 L  limit_units_on_simple_method[bid1,2030,1,1:1]
 L  limit_units_on_simple_method[bid2,2030,1,1:1]
 L  limit_units_on_simple_method[bid3,2030,1,1:1]
 L  limit_units_on_simple_method[bid4,2030,1,1:1]
 L  limit_units_on_simple_method[bid5,2030,1,1:1]
 L  limit_units_on_simple_method[bid6,2030,1,1:1]
 L  limit_units_on_simple_method[bid7,2030,1,1:1]
 L  max_output_flow_with_basic_unit_commitment[bid1,2030,1,1:1]
 L  max_output_flow_with_basic_unit_commitment[bid2,2030,1,1:1]
 L  max_output_flow_with_basic_unit_commitment[bid3,2030,1,1:1]
 L  max_output_flow_with_basic_unit_commitment[bid4,2030,1,1:1]
 L  max_output_flow_with_basic_unit_commitment[bid5,2030,1,1:1]
 L  max_output_flow_with_basic_unit_commitment[bid6,2030,1,1:1]
 L  max_output_flow_with_basic_unit_commitment[bid7,2030,1,1:1]
 G  min_output_flow_with_unit_commitment[bid1,2030,1,1:1]
 G  min_output_flow_with_unit_commitment[bid2,2030,1,1:1]
 G  min_output_flow_with_unit_commitment[bid3,2030,1,1:1]
 G  min_output_flow_with_unit_commitment[bid4,2030,1,1:1]
 G  min_output_flow_with_unit_commitment[bid5,2030,1,1:1]
 G  min_output_flow_with_unit_commitment[bid6,2030,1,1:1]
 G  min_output_flow_with_unit_commitment[bid7,2030,1,1:1]
 E  consumer_balance[bid1,2030,1,1:1]
 E  consumer_balance[bid2,2030,1,1:1]
 E  consumer_balance[bid3,2030,1,1:1]
 E  consumer_balance[bid4,2030,1,1:1]
 E  consumer_balance[bid5,2030,1,1:1]
 E  consumer_balance[bid6,2030,1,1:1]
 E  consumer_balance[bid7,2030,1,1:1]
 E  consumer_balance[bid_manager,2030,1,1:1]
COLUMNS
    flow[(G08,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G08,2030,1,1:1] 1
    flow[(G08,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G08,bid_manager),2030,1,1:1] OBJ 9
    flow[(G09,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G09,2030,1,1:1] 1
    flow[(G09,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G09,bid_manager),2030,1,1:1] OBJ 10
    flow[(G03,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G03,2030,1,1:1] 1
    flow[(G03,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G03,bid_manager),2030,1,1:1] OBJ 3.5
    flow[(G07,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G07,2030,1,1:1] 1
    flow[(G07,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G07,bid_manager),2030,1,1:1] OBJ 8
    flow[(G02,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G02,2030,1,1:1] 1
    flow[(G02,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G02,bid_manager),2030,1,1:1] OBJ 3
    flow[(G05,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G05,2030,1,1:1] 1
    flow[(G05,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G05,bid_manager),2030,1,1:1] OBJ 5
    flow[(G04,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G04,2030,1,1:1] 1
    flow[(G04,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G04,bid_manager),2030,1,1:1] OBJ 4.5
    flow[(G06,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G06,2030,1,1:1] 1
    flow[(G06,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G06,bid_manager),2030,1,1:1] OBJ 6
    flow[(G01,bid_manager),2030,1,1:1] max_output_flows_limit_simple_method[G01,2030,1,1:1] 1
    flow[(G01,bid_manager),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] 1
    flow[(G01,bid_manager),2030,1,1:1] OBJ 1
    flow[(bid_manager,bid1),2030,1,1:1] consumer_balance[bid1,2030,1,1:1] 1
    flow[(bid_manager,bid1),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] -1
    flow[(bid_manager,bid1),2030,1,1:1] OBJ -18
    flow[(bid_manager,bid2),2030,1,1:1] consumer_balance[bid2,2030,1,1:1] 1
    flow[(bid_manager,bid2),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] -1
    flow[(bid_manager,bid2),2030,1,1:1] OBJ -3
    flow[(bid_manager,bid3),2030,1,1:1] consumer_balance[bid3,2030,1,1:1] 1
    flow[(bid_manager,bid3),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] -1
    flow[(bid_manager,bid3),2030,1,1:1] OBJ -20
    flow[(bid_manager,bid4),2030,1,1:1] consumer_balance[bid4,2030,1,1:1] 1
    flow[(bid_manager,bid4),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] -1
    flow[(bid_manager,bid4),2030,1,1:1] OBJ -16
    flow[(bid_manager,bid5),2030,1,1:1] consumer_balance[bid5,2030,1,1:1] 1
    flow[(bid_manager,bid5),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] -1
    flow[(bid_manager,bid5),2030,1,1:1] OBJ -11
    flow[(bid_manager,bid6),2030,1,1:1] consumer_balance[bid6,2030,1,1:1] 1
    flow[(bid_manager,bid6),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] -1
    flow[(bid_manager,bid6),2030,1,1:1] OBJ -7
    flow[(bid_manager,bid7),2030,1,1:1] consumer_balance[bid7,2030,1,1:1] 1
    flow[(bid_manager,bid7),2030,1,1:1] consumer_balance[bid_manager,2030,1,1:1] -1
    flow[(bid_manager,bid7),2030,1,1:1] OBJ -15
    flow[(bid1,bid1),2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid1,2030,1,1:1] 1
    flow[(bid1,bid1),2030,1,1:1] min_output_flow_with_unit_commitment[bid1,2030,1,1:1] 1
    flow[(bid1,bid1),2030,1,1:1] consumer_balance[bid1,2030,1,1:1] -1
    flow[(bid2,bid2),2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid2,2030,1,1:1] 1
    flow[(bid2,bid2),2030,1,1:1] min_output_flow_with_unit_commitment[bid2,2030,1,1:1] 1
    flow[(bid2,bid2),2030,1,1:1] consumer_balance[bid2,2030,1,1:1] -1
    flow[(bid3,bid3),2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid3,2030,1,1:1] 1
    flow[(bid3,bid3),2030,1,1:1] min_output_flow_with_unit_commitment[bid3,2030,1,1:1] 1
    flow[(bid3,bid3),2030,1,1:1] consumer_balance[bid3,2030,1,1:1] -1
    flow[(bid4,bid4),2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid4,2030,1,1:1] 1
    flow[(bid4,bid4),2030,1,1:1] min_output_flow_with_unit_commitment[bid4,2030,1,1:1] 1
    flow[(bid4,bid4),2030,1,1:1] consumer_balance[bid4,2030,1,1:1] -1
    flow[(bid5,bid5),2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid5,2030,1,1:1] 1
    flow[(bid5,bid5),2030,1,1:1] min_output_flow_with_unit_commitment[bid5,2030,1,1:1] 1
    flow[(bid5,bid5),2030,1,1:1] consumer_balance[bid5,2030,1,1:1] -1
    flow[(bid6,bid6),2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid6,2030,1,1:1] 1
    flow[(bid6,bid6),2030,1,1:1] min_output_flow_with_unit_commitment[bid6,2030,1,1:1] 1
    flow[(bid6,bid6),2030,1,1:1] consumer_balance[bid6,2030,1,1:1] -1
    flow[(bid7,bid7),2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid7,2030,1,1:1] 1
    flow[(bid7,bid7),2030,1,1:1] min_output_flow_with_unit_commitment[bid7,2030,1,1:1] 1
    flow[(bid7,bid7),2030,1,1:1] consumer_balance[bid7,2030,1,1:1] -1
    MARKER    'MARKER'                 'INTORG'
    units_on[bid1,2030,1,1:1] limit_units_on_simple_method[bid1,2030,1,1:1] 1
    units_on[bid1,2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid1,2030,1,1:1] -7
    units_on[bid2,2030,1,1:1] limit_units_on_simple_method[bid2,2030,1,1:1] 1
    units_on[bid2,2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid2,2030,1,1:1] -3
    units_on[bid3,2030,1,1:1] limit_units_on_simple_method[bid3,2030,1,1:1] 1
    units_on[bid3,2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid3,2030,1,1:1] -8
    units_on[bid4,2030,1,1:1] limit_units_on_simple_method[bid4,2030,1,1:1] 1
    units_on[bid4,2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid4,2030,1,1:1] -4
    units_on[bid5,2030,1,1:1] limit_units_on_simple_method[bid5,2030,1,1:1] 1
    units_on[bid5,2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid5,2030,1,1:1] -4
    units_on[bid6,2030,1,1:1] limit_units_on_simple_method[bid6,2030,1,1:1] 1
    units_on[bid6,2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid6,2030,1,1:1] -5
    units_on[bid7,2030,1,1:1] limit_units_on_simple_method[bid7,2030,1,1:1] 1
    units_on[bid7,2030,1,1:1] max_output_flow_with_basic_unit_commitment[bid7,2030,1,1:1] -5
    MARKER    'MARKER'                 'INTEND'
RHS
    rhs       max_output_flows_limit_simple_method[G01,2030,1,1:1] 5
    rhs       max_output_flows_limit_simple_method[G02,2030,1,1:1] 12
    rhs       max_output_flows_limit_simple_method[G03,2030,1,1:1] 13
    rhs       max_output_flows_limit_simple_method[G04,2030,1,1:1] 8
    rhs       max_output_flows_limit_simple_method[G05,2030,1,1:1] 8
    rhs       max_output_flows_limit_simple_method[G06,2030,1,1:1] 9
    rhs       max_output_flows_limit_simple_method[G07,2030,1,1:1] 10
    rhs       max_output_flows_limit_simple_method[G08,2030,1,1:1] 10
    rhs       max_output_flows_limit_simple_method[G09,2030,1,1:1] 5
    rhs       limit_units_on_simple_method[bid1,2030,1,1:1] 1
    rhs       limit_units_on_simple_method[bid2,2030,1,1:1] 1
    rhs       limit_units_on_simple_method[bid3,2030,1,1:1] 1
    rhs       limit_units_on_simple_method[bid4,2030,1,1:1] 1
    rhs       limit_units_on_simple_method[bid5,2030,1,1:1] 1
    rhs       limit_units_on_simple_method[bid6,2030,1,1:1] 1
    rhs       limit_units_on_simple_method[bid7,2030,1,1:1] 1
    rhs       max_output_flow_with_basic_unit_commitment[bid1,2030,1,1:1] 0
    rhs       max_output_flow_with_basic_unit_commitment[bid2,2030,1,1:1] 0
    rhs       max_output_flow_with_basic_unit_commitment[bid3,2030,1,1:1] 0
    rhs       max_output_flow_with_basic_unit_commitment[bid4,2030,1,1:1] 0
    rhs       max_output_flow_with_basic_unit_commitment[bid5,2030,1,1:1] 0
    rhs       max_output_flow_with_basic_unit_commitment[bid6,2030,1,1:1] 0
    rhs       max_output_flow_with_basic_unit_commitment[bid7,2030,1,1:1] 0
    rhs       min_output_flow_with_unit_commitment[bid1,2030,1,1:1] 0
    rhs       min_output_flow_with_unit_commitment[bid2,2030,1,1:1] 0
    rhs       min_output_flow_with_unit_commitment[bid3,2030,1,1:1] 0
    rhs       min_output_flow_with_unit_commitment[bid4,2030,1,1:1] 0
    rhs       min_output_flow_with_unit_commitment[bid5,2030,1,1:1] 0
    rhs       min_output_flow_with_unit_commitment[bid6,2030,1,1:1] 0
    rhs       min_output_flow_with_unit_commitment[bid7,2030,1,1:1] 0
    rhs       consumer_balance[bid1,2030,1,1:1] 0
    rhs       consumer_balance[bid2,2030,1,1:1] 0
    rhs       consumer_balance[bid3,2030,1,1:1] 0
    rhs       consumer_balance[bid4,2030,1,1:1] 0
    rhs       consumer_balance[bid5,2030,1,1:1] 0
    rhs       consumer_balance[bid6,2030,1,1:1] 0
    rhs       consumer_balance[bid7,2030,1,1:1] 0
    rhs       consumer_balance[bid_manager,2030,1,1:1] 0
RANGES
BOUNDS
 LO bounds    flow[(G08,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G08,bid_manager),2030,1,1:1]
 LO bounds    flow[(G09,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G09,bid_manager),2030,1,1:1]
 LO bounds    flow[(G03,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G03,bid_manager),2030,1,1:1]
 LO bounds    flow[(G07,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G07,bid_manager),2030,1,1:1]
 LO bounds    flow[(G02,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G02,bid_manager),2030,1,1:1]
 LO bounds    flow[(G05,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G05,bid_manager),2030,1,1:1]
 LO bounds    flow[(G04,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G04,bid_manager),2030,1,1:1]
 LO bounds    flow[(G06,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G06,bid_manager),2030,1,1:1]
 LO bounds    flow[(G01,bid_manager),2030,1,1:1] 0
 PL bounds    flow[(G01,bid_manager),2030,1,1:1]
 LO bounds    flow[(bid_manager,bid1),2030,1,1:1] 0
 PL bounds    flow[(bid_manager,bid1),2030,1,1:1]
 LO bounds    flow[(bid_manager,bid2),2030,1,1:1] 0
 PL bounds    flow[(bid_manager,bid2),2030,1,1:1]
 LO bounds    flow[(bid_manager,bid3),2030,1,1:1] 0
 PL bounds    flow[(bid_manager,bid3),2030,1,1:1]
 LO bounds    flow[(bid_manager,bid4),2030,1,1:1] 0
 PL bounds    flow[(bid_manager,bid4),2030,1,1:1]
 LO bounds    flow[(bid_manager,bid5),2030,1,1:1] 0
 PL bounds    flow[(bid_manager,bid5),2030,1,1:1]
 LO bounds    flow[(bid_manager,bid6),2030,1,1:1] 0
 PL bounds    flow[(bid_manager,bid6),2030,1,1:1]
 LO bounds    flow[(bid_manager,bid7),2030,1,1:1] 0
 PL bounds    flow[(bid_manager,bid7),2030,1,1:1]
 LO bounds    flow[(bid1,bid1),2030,1,1:1] 0
 PL bounds    flow[(bid1,bid1),2030,1,1:1]
 LO bounds    flow[(bid2,bid2),2030,1,1:1] 0
 PL bounds    flow[(bid2,bid2),2030,1,1:1]
 LO bounds    flow[(bid3,bid3),2030,1,1:1] 0
 PL bounds    flow[(bid3,bid3),2030,1,1:1]
 LO bounds    flow[(bid4,bid4),2030,1,1:1] 0
 PL bounds    flow[(bid4,bid4),2030,1,1:1]
 LO bounds    flow[(bid5,bid5),2030,1,1:1] 0
 PL bounds    flow[(bid5,bid5),2030,1,1:1]
 LO bounds    flow[(bid6,bid6),2030,1,1:1] 0
 PL bounds    flow[(bid6,bid6),2030,1,1:1]
 LO bounds    flow[(bid7,bid7),2030,1,1:1] 0
 PL bounds    flow[(bid7,bid7),2030,1,1:1]
 LO bounds    units_on[bid1,2030,1,1:1] 0
 PL bounds    units_on[bid1,2030,1,1:1]
 LO bounds    units_on[bid2,2030,1,1:1] 0
 PL bounds    units_on[bid2,2030,1,1:1]
 LO bounds    units_on[bid3,2030,1,1:1] 0
 PL bounds    units_on[bid3,2030,1,1:1]
 LO bounds    units_on[bid4,2030,1,1:1] 0
 PL bounds    units_on[bid4,2030,1,1:1]
 LO bounds    units_on[bid5,2030,1,1:1] 0
 PL bounds    units_on[bid5,2030,1,1:1]
 LO bounds    units_on[bid6,2030,1,1:1] 0
 PL bounds    units_on[bid6,2030,1,1:1]
 LO bounds    units_on[bid7,2030,1,1:1] 0
 PL bounds    units_on[bid7,2030,1,1:1]
ENDATA
