function C = channelStatus(decisionTrace,k)
% CHANNELSTATUS  Freshness of every o_t entry at decision K (or the terminal record).
%   C = landing2d.trace.channelStatus(trace,k)
% C.code (1 x 12):
%   'measured'    UGV KF entry right after an accepted PnP measurement update
%   'predicted'   UGV KF entry after a time update only (no new measurement)
%   'none'        no UGV estimate yet (the entry is a zero-filled input)
%   'navigation'  new navigation estimate at this decision time
%   'recomputed'  flag/age recomputed from stamps at the decision time
% Relative entries combine the UGV KF estimate with the navigation estimate;
% their code follows the KF part (the slower, possibly stale part).
if k <= numel(decisionTrace.records), s = decisionTrace.records(k).sensing; else, s = decisionTrace.terminal.sensing; end
names = decisionTrace.provenance.channelNames;
switch s.kf.update
    case {'measurement_update','initialization'}, ugv = 'measured';
    case 'time_update', ugv = 'predicted';
    otherwise, ugv = 'none';
end
navFresh = s.navigation.valid && s.navigation.stamp == s.time;
code = strings(1,numel(names));
label = strings(1,numel(names));
for i = 1:numel(names)
    switch names{i}
        case {'relative_x','relative_height','relative_vx','ugv_vx'}
            code(i) = ugv;
        case {'ugv_visionUpdated','ugv_visionAge','drone_navigationAge'}
            code(i) = "recomputed";
        otherwise
            if navFresh, code(i) = "navigation"; else, code(i) = "recomputed"; end
    end
    switch code(i)
        case "measured", label(i) = "측정 갱신값";
        case "predicted", label(i) = sprintf("예측값 (시간 갱신, 마지막 측정 %.2f s 전)", ...
                s.time-s.kf.lastUpdateTime);
        case "none", label(i) = "추정 없음 (0으로 채운 입력)";
        case "navigation", label(i) = sprintf("새 항법 추정 (측정 시각 %.2f s)",s.navigation.stamp);
        otherwise, label(i) = "결정 시각에 재계산";
    end
end
C = struct('names',{names},'code',code,'label',label,'time',s.time);
end
