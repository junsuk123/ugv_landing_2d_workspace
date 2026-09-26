function tableOut = horizontalRecoveryFeasibility(c)
% HORIZONTALRECOVERYFEASIBILITY  Idealized FOV-retention feasibility bound.
%
% Assumptions: initially matched speed/position, no anticipation, constant
% maximum accelerations, constant altitude.  The bound is a diagnostic, not
% a claim that a controller can attain it.
deltaSpeed = max(c.scenarioSpeeds(:,2)-c.scenarioSpeeds(:,1),0);
if c.axMax < c.ugvAccelMax
    maximumLag = 0.5*deltaSpeed.^2*(1/c.axMax-1/c.ugvAccelMax);
else
    maximumLag = zeros(size(deltaSpeed));
end
halfAngle = c.cameraFovDeg/2;
availableHalfWidth = c.initialHeight*tand(halfAngle) ...
    *ones(size(deltaSpeed));
minimumHeight = maximumLag/tand(halfAngle);
retentionFeasible = maximumLag <= availableHalfWidth;
scenario = (1:size(c.scenarioSpeeds,1))';
tableOut = table(scenario,deltaSpeed,maximumLag,availableHalfWidth, ...
    minimumHeight,retentionFeasible,'VariableNames', ...
    {'Scenario','SpeedStep_mps','IdealLag_m','InitialFovHalfWidth_m', ...
     'MinimumNoLossHeight_m','NoLossFeasible'});
end
