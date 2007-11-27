##
#  action-sim.nas   Updates various simulated features including:
#                    egt, fuel pressure, oil pressure, prop visibility, 
#                    stall warning, etc. every frame
##

#   Initialize local variables
var rpm = nil;
var fuel_pres = 0.0;
var oil_pres = 0.0;
var fuel_pres_ave = 0.0;
var oil_pres_ave = 0.0;
var factor = nil;
var ias = nil;
var flaps = nil;
var gforce = nil;
var stall = nil;
var bsw = nil;
var node = nil;
var OnGround = nil;
var fuel_flow = nil;
var egt = nil;
var egt_ave = 0.0;

var init_actions = func {
    setprop("engines/engine[0]/fuel-flow-gph", 0.0);
    setprop("/surface-positions/flap-pos-norm", 0.0);
    setprop("/instrumentation/airspeed-indicator/indicated-speed-kt", 0.0);
    setprop("/instrumentation/airspeed-indicator/pressure-alt-offset-deg", 0.0);
    setprop("/accelerations/pilot-g", 1.0);

    # Request that the update fuction be called next frame
    settimer(update_actions, 0);
}


var update_actions = func {
##
#  This is a convenient cludge to model fuel pressure and oil pressure
##
    rpm = getprop("/engines/engine/rpm");
    if (rpm > 600.0) {
    fuel_pres = 3.2;
    oil_pres = 41.5;
    }
    if (getprop("/controls/engines/engine/fuel-pump")) {
    fuel_pres += 3.1;
    }
    # filter both presures
    fuel_pres_ave = 0.8 * fuel_pres_ave + 0.2 * fuel_pres;
    oil_pres_ave = 0.8 * oil_pres_ave + 0.2 * oil_pres;
# print( " rpm = ", rpm, " fuel pres = ", fuel_pres_ave, " oil pres = ", oil_pres_ave ); 

##
#  Save a factor used to make the prop disc disapear as rpm increases
##
    factor = 1.0 - rpm/2400;
    if ( factor < 0.0 ) {
        factor = 0.0;
    }

##
#  Stall Warning
##
    ias = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
    flaps = getprop("/surface-positions/flap-pos-norm");
    gforce = getprop("/accelerations/pilot-g");
#    print("ias = ", ias, "  flaps = ", flaps);
#  pa28-161 Vs = 50 knots,  warn at 52
    stall = 50 - 7*flaps + 20*(gforce - 1.0);
    node = props.globals.getNode("/sim/alarms/stall-warning",1);
    if ( ias > stall ) {
      node.setBoolValue(0);
    }
    else {
      node.setBoolValue(1);
    }

##
#  Simulate egt from pilot's perspective using fuel flow and rpm
##
    fuel_flow = getprop("engines/engine[0]/fuel-flow-gph");
    egt = 325 - abs(fuel_flow - 10)*20;
    if (egt < 20) {egt = 20; }
    egt = egt*(rpm/2400)*(rpm/2400);
#   Smooth and add some lag
    egt_ave = 0.995*egt_ave + 0.005*egt;

    # outputs
    setprop("/engines/engine[0]/egt-degf-fix", egt_ave);
    setprop("/sim/models/materials/propdisc/factor", factor);  
    setprop("/engines/engine/fuel-pressure-psi", fuel_pres_ave);
    setprop("/engines/engine/oil-pressure-psi", oil_pres_ave);

    settimer(update_actions, 0);
}

# Setup listener call to start update loop once the fdm is initialized
# 
setlistener("/sim/signals/fdm-initialized", init_actions);  



