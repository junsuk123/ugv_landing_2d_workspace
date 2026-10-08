function windows = steadyWindows(exogenous,endTime,settings)
% STEADYWINDOWS  Steady tracking windows of one episode from the exogenous schedule.
% Only exogenous events define the windows, so they are the same for every
% method on one seed (each episode then ends at its own END TIME):
%   removed  [0, initialTransient), the UGV acceleration phase [T1, T1+T2] and
%            each dropout and pitch-disturbance interval, each followed by
%            SETTLING seconds
%   kept     the remaining intervals of at least minimumWindow seconds
% EXOGENOUS is the episode manifest (landing2d.environment.exogenousManifest).
% windows is a k x 2 [start, end] list [s].
sc = exogenous.scenario; ev = exogenous.sensorEvents;
blocked = [0,settings.initialTransient; ...
    sc.T1,sc.T1+sc.T2+settings.settling];
if isfinite(ev.dropoutStart)
    blocked(end+1,:) = [ev.dropoutStart,ev.dropoutEnd+settings.settling];
end
if isfinite(ev.pitchStart)
    blocked(end+1,:) = [ev.pitchStart,ev.pitchEnd+settings.settling];
end
blocked = sortrows(blocked);
windows = zeros(0,2);
cursor = 0;
for i = 1:size(blocked,1)
    if blocked(i,1) > cursor
        windows(end+1,:) = [cursor,min(blocked(i,1),endTime)]; %#ok<AGROW>
    end
    cursor = max(cursor,blocked(i,2));
end
if cursor < endTime, windows(end+1,:) = [cursor,endTime]; end
windows = windows(windows(:,2)-windows(:,1) >= settings.minimumWindow,:);
end
