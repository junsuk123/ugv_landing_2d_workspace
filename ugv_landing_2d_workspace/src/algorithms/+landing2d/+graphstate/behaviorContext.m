function cases = behaviorContext(p,c)
% BEHAVIORCONTEXT  Interpretable bounded priors, never acceleration labels.
fov = c.experiment.sensor.fov/2;
age = min(p.timeSinceLastDetection/c.experiment.safety.prolongedLoss,1);
alignment = exp(-abs(p.exEstimate)/1.0);
speedMatch = exp(-abs(p.relativeVxEstimate)/0.5);
attitude = exp(-abs(atan2(p.sinTheta,p.cosTheta))/deg2rad(5));
consistent = p.trackInitialized*exp(-p.positionStd/1.0-p.velocityStd/1.0);
boundary = min(1,max(0,-p.predictedFovMargin)/fov);
lowHeightRisk = exp(-max(p.h,0)/0.5)*min(1,abs(p.vz)/0.3);
deadline = 1-min(max(p.remainingMissionTime/c.experiment.maxMissionTime,0),1);
scores = [p.detected*(1-boundary),p.detected*boundary, ...
    min(1,abs(p.padAxEstimate)/1.0),(~p.detected)*(1-age), ...
    (~p.detected)*consistent, p.detected*consistent, ...
    p.detected*(1-consistent),alignment*speedMatch*attitude*consistent, ...
    lowHeightRisk, max(age,double(p.abortRequested)), ...
    (~p.detected)*boundary,deadline];
ids = arrayfun(@(k)sprintf('C%02d',k),1:12,'UniformOutput',false);
cases = struct('version','behavior_context_v2','ids',{ids}, ...
    'scores',min(max(double(scores),0),1));
end
