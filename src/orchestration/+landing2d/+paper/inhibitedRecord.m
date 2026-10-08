function inhibited = inhibitedRecord(traj,c)
% INHIBITEDRECORD  Landing inhibition in force at each decision of a rollout.
% Rollouts record it directly (traj.landingInhibited). Older saved rollouts
% fall back to the landingInhibited channel of a packet policy observation.
if isfield(traj,'landingInhibited')
    inhibited = logical(traj.landingInhibited(:)');
else
    index = strcmp(c.experiment.observationSchema.names,'landingInhibited');
    inhibited = traj.observation(index,:)>0.5;
end
end
