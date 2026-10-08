function out = signalCodec(kind,value)
% SIGNALCODEC  환경 구조체와 Simulink 고정 길이 열벡터 사이의 변환.
%
%   v = landing2d.simulink.signalCodec('track',track)   구조체 -> 벡터
%   t = landing2d.simulink.signalCodec('track',v)       벡터 -> 구조체
%   n = landing2d.simulink.signalCodec('size','track')  벡터 길이
%
% Simulink 환경 블록끼리는 이 벡터만 주고받습니다. 필드 순서는 이 파일에만
% 정의되어 있고, 왕복 변환은 값과 논리형을 그대로 보존합니다.
% 'perception'은 평면 공통 관측 o_t(결정 시각 구조체)와 그 기억(UGV 상태추정기·
% 직전 기록)입니다. 복원한 o_t의 schemaVersion은 비어 있으며 블록이 부가 정보
% Gamma의 version으로 채웁니다(landing2d.simulink.BlockBase.perceptionOf).
if strcmp(kind,'size')
    out = layoutSize(value);
elseif strcmp(kind,'reasons')
    out = reasonNames();
elseif isstruct(value)
    out = encode(kind,value);
else
    out = decode(kind,double(value(:)));
end
end

function n = layoutSize(kind)
sizes = layouts();
assert(isfield(sizes,kind),'landing2d:SignalLayout', ...
    'Unknown signal layout %s.',kind);
n = sizes.(kind);
end

function sizes = layouts()
% 물리 스텝마다 수만 번 불리므로 형식표를 한 번만 만듭니다.
persistent cache
if isempty(cache)
    cache = struct('drone',7,'pad',5,'measurement',15,'track',16, ...
        'status',22,'event',13,'clock',5,'snapshot',12,'timing',4, ...
        'packet',numel(packetNames()),'perception',64);
end
sizes = cache;
end

function names = packetNames()
persistent cache
if isempty(cache)
    cache = landing2d.sensing.observationSchema().names;
end
names = cache;
end

function names = reasonNames()
% 종료 사유 코드: 0은 진행 중, 그 외는 이 목록의 순번입니다.
names = {'SUCCESS','UNSAFE_CONTACT','UNAUTHORIZED_CONTACT', ...
    'MISSED_PAD_CONTACT','SAFETY_ENVELOPE_VIOLATION','SAFE_ABORT', ...
    'TASK_TIMEOUT'};
end

function code = reasonCode(reason)
if isempty(reason)
    code = 0;
    return;
end
code = find(strcmp(reasonNames(),reason),1);
assert(~isempty(code),'landing2d:SignalLayout', ...
    'Unknown terminal reason %s.',reason);
end

function reason = reasonText(code)
if code == 0
    reason = '';
else
    names = reasonNames();
    reason = names{code};
end
end

function v = encode(kind,s)
switch kind
    case 'drone'
        v = [s.x;s.z;s.vx;s.vz;s.theta;s.pitchRate;s.collectiveThrust];
    case 'pad'
        v = [s.x;s.z;s.vx;s.ax;s.phase];
    case 'measurement'
        p = s.projection;
        v = [s.timestamp;s.detected;s.valid;s.bearingValid;s.relativeX; ...
            s.bearing;s.confidence;p.ex;p.h;p.depth;p.lateral;p.range; ...
            p.bearing;p.visible;p.fovMargin];
    case 'track'
        v = [s.initialized;s.padX;s.padVx;s.padAx;s.positionStd; ...
            s.velocityStd;s.accelerationStd;s.lastUpdateTime; ...
            s.lastMeasurementTime;s.lastMeasurementPadX; ...
            s.lastMeasuredVelocity;s.lastVelocityTime; ...
            s.timeSinceLastDetection;s.lastConfidence;s.lastBearing; ...
            s.bearingValid];
    case 'status'
        [hasContact,contact] = impactVector(s.contact);
        v = [s.terminated;s.truncated;reasonCode(s.terminalReason); ...
            s.terminalRewardPaid;s.landingInhibited;s.abortRequested; ...
            s.abortRequestTime;s.abortCompletionTime; ...
            s.previousNormalizedAction(:);s.supervisorDuration; ...
            s.physicalContact;s.contactAuthorized;s.mechanicallySafeContact; ...
            hasContact;contact; ...
            fieldOr(s,'finalDescentActive',false);fieldOr(s,'finalDescentStartTime',NaN)];
    case 'event'
        [hasImpact,impact] = impactVector(s.preImpact);
        v = [s.occurred;reasonCode(s.reason);s.time;s.alpha; ...
            s.physicalContact;s.authorized;s.mechanicallySafe; ...
            hasImpact;impact];
    case 'perception'
        v = zeros(64,1);
        if s.present
            O = s.O; u = O.ugv; d = O.drone; h = O.history;
            f = s.memory.filter; p = s.memory.previous;
            v = [1;O.decisionTime;u.positionXZ;u.velocityXZ;u.visionUpdated; ...
                u.visionAge;u.estimateInitialized;u.visionStamp; ...
                d.positionXZ;d.velocityXZ;d.pitchSinCos;d.pitchRate; ...
                d.navigationValid;d.navigationAge;d.navigationStamp; ...
                recordVector(h);f.initialized;f.time;f.state(:);f.covariance(:); ...
                f.lastUpdateTime;f.updated;recordVector(p)];
        end
    case 'packet'
        % landing2d.sensing.packetVector와 같은 순서·값 (double 변환)
        names = packetNames();
        v = zeros(numel(names),1);
        for i = 1:numel(names)
            v(i) = double(s.(names{i}));
        end
    otherwise
        error('landing2d:SignalLayout','Cannot encode %s.',kind);
end
v = double(v);
end

function s = decode(kind,v)
assert(numel(v) == layoutSize(kind),'landing2d:SignalLayout', ...
    '%s signal has %d elements, expected %d.',kind,numel(v),layoutSize(kind));
switch kind
    case 'drone'
        s = struct('x',v(1),'z',v(2),'vx',v(3),'vz',v(4),'theta',v(5), ...
            'pitchRate',v(6),'collectiveThrust',v(7));
    case 'pad'
        s = struct('x',v(1),'z',v(2),'vx',v(3),'ax',v(4),'phase',v(5));
    case 'measurement'
        projection = struct('ex',v(8),'h',v(9),'depth',v(10), ...
            'lateral',v(11),'range',v(12),'bearing',v(13), ...
            'visible',v(14)~=0,'fovMargin',v(15));
        s = struct('timestamp',v(1),'detected',v(2)~=0,'valid',v(3)~=0, ...
            'bearingValid',v(4)~=0,'relativeX',v(5),'bearing',v(6), ...
            'confidence',v(7),'projection',projection);
    case 'track'
        s = struct('initialized',v(1)~=0,'padX',v(2),'padVx',v(3), ...
            'padAx',v(4),'positionStd',v(5),'velocityStd',v(6), ...
            'accelerationStd',v(7),'lastUpdateTime',v(8), ...
            'lastMeasurementTime',v(9),'lastMeasurementPadX',v(10), ...
            'lastMeasuredVelocity',v(11),'lastVelocityTime',v(12), ...
            'timeSinceLastDetection',v(13),'lastConfidence',v(14), ...
            'lastBearing',v(15),'bearingValid',v(16)~=0);
    case 'status'
        s = struct('terminated',v(1)~=0,'truncated',v(2)~=0, ...
            'terminalReason',reasonText(v(3)),'terminalRewardPaid',v(4)~=0, ...
            'landingInhibited',v(5)~=0,'abortRequested',v(6)~=0, ...
            'abortRequestTime',v(7),'abortCompletionTime',v(8), ...
            'previousNormalizedAction',v(9:10),'supervisorDuration',v(11), ...
            'physicalContact',v(12)~=0,'contactAuthorized',v(13)~=0, ...
            'mechanicallySafeContact',v(14)~=0, ...
            'contact',impactStruct(v(15),v(16:20)), ...
            'finalDescentActive',v(21)~=0,'finalDescentStartTime',v(22));
    case 'event'
        s = struct('occurred',v(1)~=0,'reason',reasonText(v(2)), ...
            'time',v(3),'alpha',v(4),'physicalContact',v(5)~=0, ...
            'authorized',v(6)~=0,'mechanicallySafe',v(7)~=0, ...
            'preImpact',impactStruct(v(8),v(9:13)));
    case 'clock'
        s = struct('time',v(1),'elapsed',v(2),'decisionIndex',v(3), ...
            'heldAction',v(4:5));
    case 'snapshot'
        s = struct('drone',decode('drone',v(1:7)),'pad',decode('pad',v(8:12)));
    case 'timing'
        s = struct('t0',v(1),'dt',v(2),'nextTime',v(3),'active',v(4)~=0);
    case 'packet'
        s = cell2struct(num2cell(v),packetNames(),1);
    case 'perception'
        ugv = struct('positionXZ',v(3:4),'velocityXZ',v(5:6), ...
            'visionUpdated',v(7)~=0,'visionAge',v(8), ...
            'estimateInitialized',v(9)~=0,'visionStamp',v(10));
        drone = struct('positionXZ',v(11:12),'velocityXZ',v(13:14), ...
            'pitchSinCos',v(15:16),'pitchRate',v(17),'navigationValid',v(18)~=0, ...
            'navigationAge',v(19),'navigationStamp',v(20));
        O = struct('schemaVersion','','decisionTime',v(2),'ugv',ugv, ...
            'drone',drone,'history',recordStruct(v(21:30)));
        filter = struct('initialized',v(31)~=0,'time',v(32),'state',v(33:36), ...
            'covariance',reshape(v(37:52),4,4),'lastUpdateTime',v(53), ...
            'updated',v(54)~=0);
        s = struct('present',v(1)~=0,'O',O,'memory',struct('filter',filter, ...
            'previous',recordStruct(v(55:64))));
    otherwise
        error('landing2d:SignalLayout','Cannot decode %s.',kind);
end
end

function [present,v] = impactVector(impact)
% 접촉 직전 값은 접촉 사건에서만 존재합니다. 없으면 NaN과 존재 플래그 0.
if isstruct(impact) && isfield(impact,'xError')
    present = 1;
    v = [impact.xError;impact.relativeVx;impact.relativeVz; ...
        impact.pitch;impact.pitchRate];
else
    present = 0;
    v = nan(5,1);
end
end

function impact = impactStruct(present,v)
if present == 0
    impact = struct();
else
    impact = struct('xError',v(1),'relativeVx',v(2),'relativeVz',v(3), ...
        'pitch',v(4),'pitchRate',v(5));
end
end

function v = recordVector(r)
% 직전 결정 시점 운동 기록 H_t (landing2d.observation.capture의 memory.previous).
v = [r.ugvPositionXZ;r.ugvVelocityXZ;r.dronePositionXZ;r.droneVelocityXZ; ...
    r.ugvInitialized;r.valid];
end

function r = recordStruct(v)
r = struct('ugvPositionXZ',v(1:2),'ugvVelocityXZ',v(3:4), ...
    'dronePositionXZ',v(5:6),'droneVelocityXZ',v(7:8), ...
    'ugvInitialized',v(9)~=0,'valid',v(10)~=0);
end

function value = fieldOr(s,name,default)
value = default;
if isfield(s,name), value = s.(name); end
end
