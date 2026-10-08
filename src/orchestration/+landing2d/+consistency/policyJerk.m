function out = policyJerk(commandLog,settings)
% POLICYJERK  J_policy and supervisor-applied jerk in steady tracking windows.
% COMMANDLOG from landing2d.rl.rolloutEpisodeV2 (commandLog = true).
%   J_policy  time-weighted RMS of the requested-command rate
%             (a_{k+1} - a_k)/(t_{k+1} - t_k) over consecutive policy decisions
%             inside the same steady window, using the logged policy timestamps
%             [m/s^3]; per axis and as the vector norm. Windows are never joined.
%   J_applied the same for the supervisor-applied command at physics steps.
% Windows: landing2d.consistency.steadyWindows (exogenous schedule only),
% clipped at the episode end. NaN when no window contains two decisions.
% policyWeight/appliedWeight are the summed rate intervals [s], so episodes
% pool as sqrt(sum(J.^2.*weight)/sum(weight)).
endTime = commandLog.truth.time(end);
windows = landing2d.consistency.steadyWindows(commandLog.exogenous,endTime,settings);
policy = rateRms(commandLog.policy.time,commandLog.policy.requestedAcceleration,windows);
startTimes = commandLog.physics.time-commandLog.physics.dt;
applied = rateRms(startTimes,commandLog.physics.appliedAcceleration,windows);
out = struct('J_policy',policy.norm,'J_policyAxis',policy.axis, ...
    'J_applied',applied.norm,'J_appliedAxis',applied.axis, ...
    'windowSeconds',sum(windows(:,2)-windows(:,1)),'windows',windows, ...
    'policySamples',policy.samples,'appliedSamples',applied.samples, ...
    'policyWeight',policy.weight,'appliedWeight',applied.weight);
end

function r = rateRms(t,a,windows)
% Command value a(:,k) holds from t(k); its change at t(k+1) is a rate over
% the interval t(k+1)-t(k). Only pairs with both samples in one window count.
A = size(a,1);
sumSquares = zeros(A,1); weight = 0; samples = 0;
for w = 1:size(windows,1)
    in = find(t >= windows(w,1)-1e-9 & t < windows(w,2)-1e-9);
    for i = 1:numel(in)-1
        k = in(i); j = in(i+1);
        if j ~= k+1, continue; end
        dt = t(j)-t(k);
        if dt <= 0, continue; end
        rate = (a(:,j)-a(:,k))/dt;
        sumSquares = sumSquares+rate.^2*dt;
        weight = weight+dt; samples = samples+1;
    end
end
r = struct('axis',sqrt(sumSquares/weight)','norm',sqrt(sum(sumSquares)/weight), ...
    'samples',samples,'weight',weight);
if weight == 0
    r.axis = NaN(1,A); r.norm = NaN;
end
end
