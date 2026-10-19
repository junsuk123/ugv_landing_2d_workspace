function E = buildEvents(decisionTrace)
% BUILDEVENTS  Event log of a decision trace (one row per real computation).
%   E = landing2d.trace.buildEvents(trace)
% Every row is a computation the episode actually performed; its Time is the
% simulation data stamp of the code (camera frame stamp, navigation stamp,
% KF update time, decision time). Several stages share one decision time
% because the environment computes the frame, detection, PnP, KF update and
% o_t at the end of the decision interval and the policy reads them at once;
% Phase only orders them for display and is not a latency. Events:
%   camera_frame            a frame exists (also when it holds no marker)
%   marker_valid/missing    registered ArUco markers detected / none in a frame
%   pnp_valid/rejected      PnP attempted on detected corners: accepted / rejected
%   kf_measurement_update   accepted PnP measurement entered the UGV KF
%                           (Detail 'initialization' for the first one)
%   kf_time_update          prediction only (no accepted measurement)
%   kf_uninitialized        no estimate exists yet
%   own_navigation_update   new navigation estimate (stamp)
%   common_observation_built, tosm_features_built, actor_rgat_forward,
%   actor_group_readout, actor_action_decided   decision computations
%   episode_terminal        contact / boundary / timeout (no frame, no decision)
% The terminal row group holds the final observation the environment builds
% at the terminal time (no image, navigation and KF prediction only) and no
% policy decision. InjectedDropout is evaluation-only metadata.
eventRows = {};
lastMarker = NaN; lastNav = NaN;
for k = 1:numel(decisionTrace.records)
    r = decisionTrace.records(k);
    [newRows,lastMarker,lastNav] = sensingRows(r.sensing,k,lastMarker,lastNav);
    eventRows = [eventRows,newRows]; %#ok<AGROW>
    t = r.time;
    eventRows{end+1} = eventRow('common_observation','common_observation_built',t,k,3,true,false, ...
        '',sprintf('o_t v%d (12-D)',k),t,0,false); %#ok<AGROW>
    eventRows{end+1} = eventRow('tosm','tosm_features_built',t,k,4,true,false,'', ...
        'X_t 6x7',t,0,false); %#ok<AGROW>
    eventRows{end+1} = eventRow('actor','actor_rgat_forward',t,k,5,true,false,'', ...
        sprintf('typed edges 13 + self 7, %s',decisionTrace.schema.relationOperators),t,0,false); %#ok<AGROW>
    eventRows{end+1} = eventRow('actor','actor_group_readout',t,k,6,true,false,'', ...
        sprintf('|g_A| = %.3f',norm(r.actor.g)),t,0,false); %#ok<AGROW>
    eventRows{end+1} = eventRow('actor','actor_action_decided',t,k,6,true,false,'', ...
        sprintf('a = [%+.3f, %+.3f] m/s^2',r.command.requestedAcceleration),t,0,false); %#ok<AGROW>
end
term = decisionTrace.terminal;
n = numel(decisionTrace.records);
if term.terminated || term.truncated
    newRows = sensingRows(term.sensing,n+1,lastMarker,lastNav);
    eventRows = [eventRows,newRows];
    eventRows{end+1} = eventRow('environment','episode_terminal',term.time,n+1,7,true,false, ...
        '',sprintf('%s (truncated %d)',term.reason,term.truncated),term.time,0,false);
end
if isempty(eventRows)    % live skeleton before the first decision
    E = struct2table(eventRow('','',NaN,NaN,NaN,false,false,'','',NaN,NaN,false));
    E(1,:) = [];
else
    E = struct2table([eventRows{:}]);
end
E.EventId = (1:height(E))';
E = movevars(E,'EventId','Before',1);
E.Interarrival_s = NaN(height(E),1);
groupKeys = E.Source+"|"+E.Type;
for key = unique(groupKeys)'
    index = find(groupKeys==key);
    E.Interarrival_s(index(2:end)) = diff(E.Time_s(index));
end
end

function [eventRows,lastMarker,lastNav] = sensingRows(s,k,lastMarker,lastNav)
% Rows of one decision-time sensing replay (landing2d.trace.decisionSensing).
eventRows = {};
t = s.time; dropout = s.evaluation.injectedDropout;
if s.camera.frameCaptured
    eventRows{end+1} = eventRow('camera','camera_frame',s.camera.stamp,k,0,true,false,'', ...
        sprintf('%d markers',s.camera.markerCount),s.camera.stamp,0,dropout);
    ids = strjoin(string(s.camera.markerIds),' ');
    if s.camera.markerCount > 0
        lastMarker = s.camera.stamp;
        eventRows{end+1} = eventRow('marker','marker_valid',s.camera.stamp,k,1,true,false,ids, ...
            sprintf('IDs %s',ids),lastMarker,0,dropout);
    else
        eventRows{end+1} = eventRow('marker','marker_missing',s.camera.stamp,k,1,false,false,'', ...
            'no registered marker in the frame',lastMarker,t-lastMarker,dropout);
    end
    if s.pnp.attempted
        if s.pnp.valid
            eventRows{end+1} = eventRow('pnp','pnp_valid',s.camera.stamp,k,1,true,true,ids, ...
                sprintf('%d markers, reprojection RMS %.2f px',s.pnp.markerCount, ...
                s.pnp.reprojectionRms),s.camera.stamp,0,dropout);
        else
            eventRows{end+1} = eventRow('pnp','pnp_rejected',s.camera.stamp,k,1,false,false,ids, ...
                sprintf('rejected, reprojection RMS %.2f px',s.pnp.reprojectionRms), ...
                NaN,NaN,dropout);
        end
    end
end
kf = s.kf;
switch kf.update
    case {'measurement_update','initialization'}
        eventRows{end+1} = eventRow('kf','kf_measurement_update',t,k,2,true,true,'',kf.update, ...
            kf.lastUpdateTime,0,dropout);
    case 'time_update'
        eventRows{end+1} = eventRow('kf','kf_time_update',t,k,2,true,false,'', ...
            sprintf('prediction dt %.2f s',kf.predictionDt),kf.lastUpdateTime, ...
            t-kf.lastUpdateTime,dropout);
    otherwise
        eventRows{end+1} = eventRow('kf','kf_uninitialized',t,k,2,false,false,'', ...
            'no UGV estimate yet',NaN,NaN,dropout);
end
nav = s.navigation;
if nav.valid
    lastNav = nav.stamp;
    eventRows{end+1} = eventRow('navigation','own_navigation_update',nav.stamp,k,0,true,false,'', ...
        sprintf('v = [%+.2f, %+.2f] m/s',nav.velocityXZ),nav.stamp,t-nav.stamp,false);
end
end

function r = eventRow(source,eventType,time,k,phase,valid,accepted,ids,detail,lastValid,age,dropout)
r = struct('Source',string(source),'Type',string(eventType),'Time_s',double(time), ...
    'DecisionIndex',double(k),'Phase',double(phase),'Valid',logical(valid), ...
    'AcceptedMeasurement',logical(accepted),'MarkerIds',string(ids), ...
    'Detail',string(detail),'ProcessingTime_s',NaN,'LastValidTime_s',double(lastValid), ...
    'Age_s',double(age),'InjectedDropout_evalOnly',logical(dropout));
end
