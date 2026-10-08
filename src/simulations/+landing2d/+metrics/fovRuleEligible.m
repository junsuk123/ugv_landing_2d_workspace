function tf = fovRuleEligible(probe,c)
% FOVRULEELIGIBLE  Whether keeping the pad in the camera FOV is required at a probe.
% Required only with recent vision (reference observation), the pad center
% currently in the camera FOV, and the drone above the final-descent exit
% height: the contract authorizes blind final descent below it.
ctx = probe.context;
recent = ctx.estimateInitialized && ctx.visionAge <= c.experiment.safety.recentTrackGrace;
state = landing2d.metrics.probeState(probe);
pad = landing2d.metrics.probePad(probe);
p = landing2d.sensing.projectPad(state,pad,c.experiment.sensor);
h = state.z-pad.z;
tf = recent && p.visible && h > c.experiment.commonObservation.finalDescent.exitHeight;
end
