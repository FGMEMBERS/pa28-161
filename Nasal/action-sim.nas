##
#  action-sim.nas   Updates various simulated features including:
#                    egt, fuel pressure, oil pressure, stall warning, etc. every frame
##

#   Initialize local variables
var rpm = nil;
var fuel_pres = 0.0;
var oil_pres = 0.0;
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
var fuel_pump_volume = nil;

# set up filters for these actions

var fuel_pres_lowpass = aircraft.lowpass.new(0.5);
var oil_pres_lowpass = aircraft.lowpass.new(0.5);
var egt_lowpass = aircraft.lowpass.new(0.95);

var init_actions = func {
    setprop("engines/engine[0]/fuel-flow-gph", 0.0);
    setprop("/surface-positions/flap-pos-norm", 0.0);
    setprop("/instrumentation/airspeed-indicator/indicated-speed-kt", 0.0);
    setprop("/instrumentation/airspeed-indicator/pressure-alt-offset-deg", 0.0);
    setprop("/accelerations/pilot-g", 1.0);
    setprop("/controls/flight/aileron_in", 0.0);
    setprop("/controls/flight/elevator_in", 0.0);
    setprop("/sim/model/material/LandingLight/factorAGL", 0.0);  

    # Make sure that init_actions is called when the sim is reset
    setlistener("sim/signals/reset", init_actions); 

    # Request that the update fuction be called next frame
    settimer(update_actions, 0);
}


var update_actions = func {
##
#  This is a convenient cludge to model fuel pressure and oil pressure
##
    rpm = getprop("/engines/engine/rpm");
    if (rpm > 600.0) {
       fuel_pres = 6.8-3000/rpm;
       oil_pres = 62-12600/rpm;
    } else {
       fuel_pres = 0.0;
       oil_pres = 0.0;
    }

    if (getprop("/controls/engines/engine/fuel-pump")) {
    fuel_pres += 1.5;
    }

##
#  reduce fuel pump sound volume as rpm increases
##
   if (rpm < 1200) {
     fuel_pump_volume = 0.75/(0.002*rpm+1)
   } else {
     fuel_pump_volume = 0.0
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

##
#  Simulate landing light ground illumination fall-off with increased agl distance
##
    var factor = getprop("sim/model/material/LandingLight/factor");
    var agl = getprop("position/altitude-agl-ft");
    var aglFactor = 10000/(agl*agl);
    var factorAGL = factor;
    if (agl > 100) { 
       factorAGL = factor*aglFactor;
    }

##
#  Disengage Joystick aileron if autopilot is controlling roll
##

  if ( getprop("autopilot/KAP140/locks/roll-axis")) { 
      aileron = getprop("controls/flight/AP_aileron");
  }
  else {
      aileron = getprop("controls/flight/aileron");
  }

##
#  Disengage Joystick elevator if autopilot is controlling pitch
##

  if ( getprop("autopilot/KAP140/locks/pitch-axis")) {
      elevator = getprop("controls/flight/AP_elevator");
  }
  else {
      elevator = getprop("controls/flight/elevator");
  }

    # outputs
    setprop("/controls/flight/aileron_in", aileron);
    setprop("/controls/flight/elevator_in", elevator);
    setprop("/engines/engine[0]/egt-degf-fix", egt_lowpass.filter(egt));
    setprop("/sim/model/material/LandingLight/factorAGL", factorAGL);  
    setprop("/engines/engine/fuel-pressure-psi", fuel_pres_lowpass.filter(fuel_pres));
    setprop("/engines/engine/oil-pressure-psi", oil_pres_lowpass.filter(oil_pres));
    setprop("/sim/sound/fuel_pump_volume", fuel_pump_volume);

    settimer(update_actions, 0);
}

# Setup listener call to start update loop once the fdm is initialized
# 
setlistener("/sim/signals/fdm-initialized", init_actions);  



