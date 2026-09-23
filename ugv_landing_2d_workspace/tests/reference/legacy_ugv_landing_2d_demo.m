function [results, summaryTable, cfg] = legacy_ugv_landing_2d_demo(options)
% UGV_LANDING_2D_DEMO  UGV 착륙 패드 추종 / 시야 이탈 / 상승 재포착 / 착륙.
%
% 실행:
%   [results, summaryTable] = ugv_landing_2d_demo;
%   ugv_landing_2d_demo(struct('playbackSpeed', 4));  % 4배속 표시
%   ugv_landing_2d_demo(struct('animate', false));  % 최종 그래프만 표시
%
% 모델: x-z 평면의 가속도 입력 이중 적분기, 중력 보상 완료 가정.
% 카메라: 수직 하향 고정. 패드 중심이 FOV 안에 있으면 관측 가능.
% 관측 중 위치/속도는 이상적인 값 사용. 비가시 중에는 마지막 관측 속도 유지.
% 추가 Toolbox, Simulink, 강화학습, 온톨로지, 상태 추정기는 사용하지 않음.
% MATLAB R2020a 이상을 대상으로 작성. 그래프/GUI 실행은 사용자 MATLAB에서 확인.

if nargin < 1
    options = struct();
end

%% 1. 사용자가 수정할 설정
cfg.dt = 0.01;                    % 수치 적분 간격 [s]
cfg.tEnd = 70;                    % 전체 모사 시간 [s]
cfg.segmentTimes = [8, 15];       % 2구간 / 3구간 시작 시각 [s]
cfg.scenarioSpeeds = [1.0, 4.0, 1.5; ...
                      1.5, 5.5, 2.0; ...
                      2.0, 7.0, 2.5]; % 각 행: [1구간, 2구간, 3구간] [m/s]
cfg.ugvAccelMax = 4.0;            % 구간 전환 시 UGV 가/감속 한계 [m/s^2]
cfg.padHeight = 0.6;              % 지면 기준 UGV 위 패드 높이 [m]
cfg.padHalfLength = 0.5;          % 진행 방향 패드 반길이 [m]
cfg.initialHeight = 6.0;          % 초기 패드 상대 고도 [m]
cfg.maxHeight = 18.0;             % 상승 목표의 최대 패드 상대 고도 [m]
cfg.cameraFovDeg = 50;            % 카메라 전체 시야각 [deg]

cfg.kpX = 1.4;                    % 수평 위치 P 이득 [s^-2]
cfg.kdX = 2.0;                    % 수평 속도 D 이득 [s^-1]
cfg.kpZ = 3.0;                    % 고도 위치 P 이득 [s^-2]
cfg.kdZ = 3.0;                    % 고도 속도 D 이득 [s^-1]
cfg.axMax = 1.2;                  % 드론 수평 가속도 한계 [m/s^2]
cfg.azMax = 2.0;                  % 드론 수직 가속도 한계 [m/s^2]
cfg.vxMax = 10.0;                 % 드론 수평 속도 한계 [m/s]
cfg.vzMax = 1.5;                  % 드론 수직 속도 한계 [m/s]
cfg.climbSpeed = 1.2;             % 재포착 상승 기준 속도 [m/s]
cfg.descentSpeed = 0.4;           % 착륙 하강 기준 최대 속도 [m/s]
cfg.nearPadDescentGain = 0.6;      % 패드 근처 하강 감속: min(vDesc, gain*h)
cfg.alignPositionTol = 0.30;      % 하강을 허용하는 수평 오차 [m]
cfg.alignSpeedTol = 0.35;         % 하강을 허용하는 상대 수평 속도 [m/s]
cfg.reacquireInnerRatio = 0.75;   % FOV 중앙 75% 이내에서 재포착 확인
cfg.reacquireHoldTime = 0.25;     % 재포착 확인을 위한 연속 관측 시간 [s]
cfg.touchdownHeight = 0.04;       % 패드 면과의 수치 접촉 허용 높이 [m]
cfg.touchdownSpeedX = 0.35;       % 착륙 시 허용 상대 수평 속도 [m/s]
cfg.touchdownSpeedZ = 0.30;       % 착륙 시 허용 수직 속도 [m/s]

cfg.animate = true;              % 실시간 2차원 애니메이션 표시
cfg.makeFinalPlots = true;       % 종료 후 위치/속도 그래프 표시
cfg.playbackSpeed = 1;            % 1: 실제 시간, 4: 4배속, Inf: 대기 없이
cfg.animationHz = 20;             % 애니메이션 갱신 주파수 [Hz]
cfg.saveResults = true;           % MAT / CSV / 최종 PNG 저장
cfg.outputDir = fullfile(pwd, 'ugv_landing_2d_results');

% 호출 시 지정한 설정만 덮어씀. 모르는 필드명은 오타로 간주.
assert(isstruct(options) && isscalar(options), 'options must be a scalar struct.');
fields = fieldnames(options);
for i = 1:numel(fields)
    assert(isfield(cfg, fields{i}), 'Unknown option: %s', fields{i});
    cfg.(fields{i}) = options.(fields{i});
end
validateConfig(cfg);

%% 2. 세 시나리오 초기화: 모두 같은 제어기, 속도 설정만 다름
nSteps = round(cfg.tEnd / cfg.dt);
t = (0:nSteps)' * cfg.dt;
nCases = size(cfg.scenarioSpeeds, 1);
frameStride = max(1, round(1 / (cfg.animationHz * cfg.dt)));

for j = 1:nCases
    [xp, vp, vCommand] = makeUgvTrajectory(t, cfg.scenarioSpeeds(j,:), cfg);
    r = struct('name', sprintf('Scenario %d', j), ...
        'speeds', cfg.scenarioSpeeds(j,:), 'time', t, ...
        'xUgv', xp, 'zPad', cfg.padHeight + zeros(size(t)), ...
        'vxUgv', vp, 'vxUgvCommand', vCommand);
    logNames = {'xDrone','zDrone','vxDrone','vzDrone','xError', ...
        'fovHalfWidth','mode','axCommand','azCommand','heightReference'};
    for f = 1:numel(logNames)
        r.(logNames{f}) = nan(size(t));
    end
    r.visible = false(size(t));
    r.descending = false(size(t));
    r.lossTimes = [];
    r.reacquireTimes = [];
    r.landingTime = NaN;
    r.failureTime = NaN;
    r.status = 'Not landed';
    results(j) = r; %#ok<AGROW>

    % 내부 상태 h는 지면 기준이 아니라 패드 면 기준의 상대 고도.
    states(j) = struct('x', xp(1), 'h', cfg.initialHeight, ...
        'vx', vp(1), 'vz', 0, 'heightReference', cfg.initialHeight, ...
        'mode', 1, 'lastPadSpeed', vp(1), 'seenTime', 0); %#ok<AGROW>
end

if cfg.saveResults && ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end
if cfg.animate
    live = makeAnimation(cfg, nCases);
else
    live = struct('fig', []);
end

%% 3. 시뮬레이션: 동일 시각의 세 시나리오를 함께 갱신
wallClock = tic;
for k = 1:numel(t)
    for j = 1:nCases
        s = states(j);
        xp = results(j).xUgv(k);
        vp = results(j).vxUgv(k);
        ex = xp - s.x;
        ev = vp - s.vx;

        % 접촉 판정은 환경에서 수행. 비가시 제어기에 참값을 제공하지 않음.
        safeTouchdown = s.mode == 1 && s.h <= cfg.touchdownHeight ...
            && abs(ex) <= cfg.padHalfLength ...
            && abs(ev) <= cfg.touchdownSpeedX ...
            && s.vz <= 0 && abs(s.vz) <= cfg.touchdownSpeedZ;
        if safeTouchdown
            s.mode = 3;
            s.h = 0;
            s.vz = 0;
            s.vx = vp;
            s.heightReference = 0;
            results(j).landingTime = t(k);
            results(j).status = 'Landed';
        elseif s.mode < 3 && s.h <= 0
            % 패드 면 이하로 내려갔는데 안전 착륙 조건을 만족하지 못함.
            % 충돌 동역학 대신 해당 시나리오를 실패 상태로 정지시킴.
            s.mode = 4;
            s.h = 0;
            s.vx = 0;
            s.vz = 0;
            results(j).failureTime = t(k);
            results(j).status = 'Unsafe contact / height violation';
        end

        halfWidth = max(s.h, 0) * tand(cfg.cameraFovDeg / 2);
        obs.visible = s.mode < 3 && s.h > 0 && abs(xp - s.x) <= halfWidth;
        obs.halfWidth = halfWidth;
        obs.xError = NaN;
        obs.vError = NaN;
        obs.padSpeed = NaN;
        if obs.visible
            obs.xError = xp - s.x;
            obs.vError = vp - s.vx;
            obs.padSpeed = vp;
        end

        [s, ax, az, descending, event] = pdController(s, obs, cfg);
        if event == 1
            results(j).lossTimes(end+1) = t(k);
        elseif event == 2
            results(j).reacquireTimes(end+1) = t(k);
        end

        % 현재 시각의 상태와 제어 입력 기록
        results(j).xDrone(k) = s.x;
        results(j).zDrone(k) = cfg.padHeight + s.h;
        results(j).vxDrone(k) = s.vx;
        results(j).vzDrone(k) = s.vz;
        results(j).xError(k) = xp - s.x;
        results(j).fovHalfWidth(k) = halfWidth;
        results(j).mode(k) = s.mode;
        results(j).visible(k) = obs.visible;
        results(j).descending(k) = descending;
        results(j).axCommand(k) = ax;
        results(j).azCommand(k) = az;
        results(j).heightReference(k) = s.heightReference;

        % 다음 시각으로 적분. 속도는 Euler, 위치는 양 끝 속도의 평균 사용.
        if k < numel(t)
            if s.mode == 3
                % 착륙 후 현재 수평 접촉 위치를 유지하며 UGV와 함께 이동.
                % x를 패드 중심으로 순간 이동시키지 않음.
                s.x = s.x + results(j).xUgv(k+1) - xp;
                s.vx = results(j).vxUgv(k+1);
            elseif s.mode < 3
                vxNext = saturate(s.vx + ax * cfg.dt, cfg.vxMax);
                vzNext = saturate(s.vz + az * cfg.dt, cfg.vzMax);
                s.x = s.x + 0.5 * (s.vx + vxNext) * cfg.dt;
                s.h = s.h + 0.5 * (s.vz + vzNext) * cfg.dt;
                s.vx = vxNext;
                s.vz = vzNext;
            end
        end
        states(j) = s;
    end

    % 표시 시간만 조절: 배속을 바꾸어도 적분 간격/제어기는 바뀌지 않음.
    if cfg.animate && isgraphics(live.fig) ...
            && (mod(k-1, frameStride) == 0 || k == numel(t))
        if isfinite(cfg.playbackSpeed)
            remaining = t(k) / cfg.playbackSpeed - toc(wallClock);
            if remaining > 0
                pause(remaining);
            end
        end
        if isgraphics(live.fig)
            updateAnimation(live, results, k, cfg);
            drawnow limitrate;
        end
    end
end
if cfg.animate && isgraphics(live.fig)
    drawnow;
end

%% 4. 최종 위치/속도 그래프 및 데이터 저장
summaryTable = makeSummary(results, cfg);
disp(summaryTable);
if cfg.saveResults
    save(fullfile(cfg.outputDir, 'simulation_results.mat'), 'results', 'summaryTable', 'cfg');
    writetable(summaryTable, fullfile(cfg.outputDir, 'summary.csv'));
    for j = 1:nCases
        r = results(j);
        logTable = table(r.time, r.xUgv, r.zPad, r.vxUgv, r.vxUgvCommand, ...
            r.xDrone, r.zDrone, r.vxDrone, r.vzDrone, r.xError, ...
            r.fovHalfWidth, r.visible, r.mode, r.descending, ...
            'VariableNames', {'Time_s','UgvX_m','PadZ_m','UgvVx_mps', ...
            'UgvVxCommand_mps','DroneX_m','DroneZ_m','DroneVx_mps', ...
            'DroneVz_mps','XError_m','FovHalfWidth_m','PadVisible', ...
            'Mode','Descending'});
        writetable(logTable, fullfile(cfg.outputDir, sprintf('scenario_%d_log.csv', j)));
    end
    fprintf('\nSaved results: %s\n', cfg.outputDir);
end
if cfg.makeFinalPlots
    for j = 1:nCases
        [~, finalLayout] = makeFinalFigure(results(j), cfg);
        if cfg.saveResults
            exportgraphics(finalLayout, fullfile(cfg.outputDir, ...
                sprintf('scenario_%d_position_velocity.png', j)), 'Resolution', 180);
        end
    end
end
end

%% 로컬 함수: PD 제어기
function [s, ax, az, descending, event] = pdController(s, obs, c)
% mode: 1=TRACK/LAND, 2=SEARCH/CLIMB, 3=LANDED, 4=FAILED
ax = 0; az = 0; descending = false; event = 0;
if s.mode >= 3
    return;
end
if obs.visible
    s.lastPadSpeed = obs.padSpeed;
end

% 시야를 잃으면 상승. 재포착은 중앙 영역에서 일정 시간 보인 뒤 확정.
if ~obs.visible && s.mode ~= 2
    s.mode = 2;
    s.heightReference = s.h;
    s.seenTime = 0;
    event = 1;
elseif s.mode == 2
    if obs.visible && abs(obs.xError) <= c.reacquireInnerRatio * obs.halfWidth
        s.seenTime = s.seenTime + c.dt;
    else
        s.seenTime = 0;
    end
    if s.seenTime + 1e-12 >= c.reacquireHoldTime
        s.mode = 1;
        s.heightReference = s.h;
        s.seenTime = 0;
        event = 2;
    end
end

% 수평 PD. 패드가 안 보이면 현재의 실제 패드 위치/속도를 사용하지 않음.
if obs.visible
    ax = c.kpX * obs.xError + c.kdX * obs.vError;
else
    ax = c.kdX * (s.lastPadSpeed - s.vx);
end
ax = saturate(ax, c.axMax);

% 수직 PD의 기준 궤적 생성
oldReference = s.heightReference;
if s.mode == 2
    s.heightReference = min(c.maxHeight, oldReference + c.climbSpeed * c.dt);
    vzReference = (s.heightReference - oldReference) / c.dt;
elseif abs(obs.xError) <= c.alignPositionTol && abs(obs.vError) <= c.alignSpeedTol
    descending = true;
    downSpeed = min(c.descentSpeed, c.nearPadDescentGain * max(s.h, 0));
    s.heightReference = max(0, oldReference - downSpeed * c.dt);
    vzReference = (s.heightReference - oldReference) / c.dt;
else
    % 재포착했어도 수평 오차가 크면 하강을 멈추고 먼저 정렬.
    s.heightReference = s.h;
    vzReference = 0;
end
az = c.kpZ * (s.heightReference - s.h) + c.kdZ * (vzReference - s.vz);
az = saturate(az, c.azMax);
end

%% 로컬 함수: 세 구간 UGV 속도 궤적
function [x, v, vCommand] = makeUgvTrajectory(t, speeds, c)
vCommand = speeds(1) + zeros(size(t));
vCommand(t >= c.segmentTimes(1)) = speeds(2);
vCommand(t >= c.segmentTimes(2)) = speeds(3);
x = zeros(size(t));
v = zeros(size(t));
v(1) = speeds(1);
for k = 1:numel(t)-1
    % 구간 내부는 등속, 구간 경계에서는 유한한 가속도로 목표 속도에 도달.
    dv = saturate(vCommand(k) - v(k), c.ugvAccelMax * c.dt);
    v(k+1) = v(k) + dv;
    x(k+1) = x(k) + 0.5 * (v(k) + v(k+1)) * c.dt;
end
end

%% 로컬 함수: 실시간 2차원 시각화
function live = makeAnimation(c, nCases)
live.fig = figure('Name', '2D UGV landing - live', 'NumberTitle', 'off', ...
    'Position', [70, 100, 1400, 620]);
layout = tiledlayout(live.fig, 1, nCases, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'PD tracking / FOV loss / climb / reacquisition / landing');
for j = 1:nCases
    ax = nexttile(layout);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    palette = ax.ColorOrder;
    h.fov = patch(ax, NaN, NaN, palette(1,:), 'FaceAlpha', 0.10, ...
        'EdgeColor', palette(1,:), 'LineStyle', ':', 'HandleVisibility', 'off');
    h.ground = plot(ax, NaN, NaN, '-', 'HandleVisibility', 'off');
    h.trail = plot(ax, NaN, NaN, '-', 'LineWidth', 1.2, 'DisplayName', 'Drone path');
    h.ugv = rectangle(ax, 'Position', [0,0,1.8,c.padHeight], ...
        'LineWidth', 1.5, 'HandleVisibility', 'off');
    h.pad = plot(ax, NaN, NaN, '-', 'LineWidth', 5, 'DisplayName', 'Landing pad');
    h.drone = plot(ax, NaN, NaN, '-o', 'LineWidth', 2, ...
        'MarkerSize', 5, 'DisplayName', 'Drone');
    h.info = text(ax, 0.03, 0.97, '', 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'Interpreter', 'none', 'FontSize', 10);
    xlabel(ax, 'Forward position x [m]'); ylabel(ax, 'Altitude z [m]');
    title(ax, sprintf('Scenario %d: %.1f / %.1f / %.1f m/s', ...
        j, c.scenarioSpeeds(j,:)));
    daspect(ax, [1,1,1]);
    ylim(ax, [0, c.padHeight + c.maxHeight + 4]);
    xlim(ax, [-8, 16]);
    legend(ax, [h.trail, h.pad, h.drone], 'Location', 'southoutside');
    live.axes(j) = ax;
    live.items(j) = h;
end
end

function updateAnimation(live, results, k, c)
for j = 1:numel(results)
    r = results(j); ax = live.axes(j); h = live.items(j);
    xd = r.xDrone(k); zd = r.zDrone(k); xp = r.xUgv(k);
    width = r.fovHalfWidth(k);
    set(h.fov, 'XData', [xd,xd-width,xd+width], ...
        'YData', [zd,c.padHeight,c.padHeight]);
    left = min(xd-width, xp-1) - 4;
    right = max(xd+width, xp+1) + 4;
    center = (left + right) / 2;
    span = max(24, right-left);
    limits = center + [-0.5,0.5] * span;
    xlim(ax, limits);
    set(h.ground, 'XData', limits, 'YData', [0,0]);
    set(h.ugv, 'Position', [xp-0.9,0,1.8,c.padHeight]);
    set(h.pad, 'XData', xp + [-c.padHalfLength,c.padHalfLength], ...
        'YData', [c.padHeight,c.padHeight]);
    set(h.drone, 'XData', xd + [-0.55,0,0.55], 'YData', [zd,zd,zd]);
    first = max(1, k-round(12/c.dt));
    set(h.trail, 'XData', r.xDrone(first:k), 'YData', r.zDrone(first:k));
    labels = {'TRACK / ALIGN','SEARCH / CLIMB','LANDED','FAILED'};
    modeText = labels{r.mode(k)};
    if r.mode(k) == 1 && r.descending(k)
        modeText = 'TRACK / DESCEND';
    end
    if r.mode(k) >= 3
        visibility = 'N/A';
    elseif r.visible(k)
        visibility = 'VISIBLE';
    else
        visibility = 'LOST';
    end
    set(h.info, 'String', sprintf(['t = %.2f s | %s\nPad: %s\n' ...
        'vUGV = %.2f m/s | vDrone = %.2f m/s\n' ...
        'x error = %.2f m | height above pad = %.2f m'], ...
        r.time(k),modeText,visibility,r.vxUgv(k),r.vxDrone(k), ...
        r.xError(k),zd-c.padHeight));
end
end

%% 로컬 함수: 최종 위치/속도 그래프
function [fig, layout] = makeFinalFigure(r, c)
fig = figure('Name', [r.name ' - position and velocity'], ...
    'NumberTitle', 'off', 'Position', [100,80,1200,760]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('%s | UGV %.1f / %.1f / %.1f m/s | %s', ...
    r.name,r.speeds,r.status));

ax(1) = nexttile(layout);
plot(ax(1),r.time,r.xUgv,'-',r.time,r.xDrone,'--','LineWidth',1.5);
ylabel(ax(1),'x [m]'); title(ax(1),'Forward position');
legend(ax(1),{'UGV / pad','Drone'},'Location','best');

ax(2) = nexttile(layout);
plot(ax(2),r.time,r.zDrone,'-',r.time,r.zPad,'--','LineWidth',1.5);
ylabel(ax(2),'z [m]'); title(ax(2),'Altitude (ground reference)');
legend(ax(2),{'Drone','Pad'},'Location','best');

ax(3) = nexttile(layout);
plot(ax(3),r.time,r.vxUgv,'-',r.time,r.vxDrone,'--', ...
    r.time,r.vxUgvCommand,':','LineWidth',1.5);
ylabel(ax(3),'v_x [m/s]'); title(ax(3),'Forward velocity');
legend(ax(3),{'UGV actual','Drone','UGV command'},'Location','best');

ax(4) = nexttile(layout);
plot(ax(4),r.time,r.vzDrone,'-',r.time,zeros(size(r.time)),'--','LineWidth',1.5);
ylabel(ax(4),'v_z [m/s]'); title(ax(4),'Vertical velocity (+ up / - down)');
legend(ax(4),{'Drone','UGV / pad'},'Location','best');

for i = 1:4
    grid(ax(i),'on'); box(ax(i),'on'); xlabel(ax(i),'Time [s]');
    xlim(ax(i),[r.time(1),r.time(end)]);
    for tb = c.segmentTimes
        xline(ax(i),tb,':','HandleVisibility','off');
    end
end
% 고도 그래프에 사건 시각 표시. 세로 점선은 속도 구간 경계.
for tt = r.lossTimes
    xline(ax(2),tt,'--','Loss','HandleVisibility','off', ...
        'LabelVerticalAlignment','top');
end
for tt = r.reacquireTimes
    xline(ax(2),tt,'-.','Reacq','HandleVisibility','off', ...
        'LabelVerticalAlignment','middle');
end
if isfinite(r.landingTime)
    xline(ax(2),r.landingTime,'-','Landed','HandleVisibility','off', ...
        'LabelVerticalAlignment','bottom');
end
linkaxes(ax,'x');
end

%% 로컬 함수: 요약 / 설정 검증 / 포화
function summaryTable = makeSummary(results, c)
n = numel(results);
Scenario = cell(n,1); Status = cell(n,1);
FirstLoss_s = nan(n,1); FirstReacquire_s = nan(n,1);
Landing_s = nan(n,1); PeakHeightAbovePad_m = nan(n,1);
for j = 1:n
    r = results(j);
    Scenario{j} = r.name; Status{j} = r.status;
    if ~isempty(r.lossTimes), FirstLoss_s(j) = r.lossTimes(1); end
    if ~isempty(r.reacquireTimes), FirstReacquire_s(j) = r.reacquireTimes(1); end
    Landing_s(j) = r.landingTime;
    PeakHeightAbovePad_m(j) = max(r.zDrone) - c.padHeight;
end
summaryTable = table(Scenario,FirstLoss_s,FirstReacquire_s, ...
    Landing_s,PeakHeightAbovePad_m,Status);
end

function validateConfig(c)
positive = {'dt','tEnd','ugvAccelMax','padHeight','padHalfLength', ...
    'initialHeight','maxHeight','kpX','kdX','kpZ','kdZ','axMax','azMax', ...
    'vxMax','vzMax','climbSpeed','descentSpeed','nearPadDescentGain', ...
    'alignPositionTol','alignSpeedTol','reacquireHoldTime', ...
    'touchdownHeight','touchdownSpeedX','touchdownSpeedZ','animationHz'};
for i = 1:numel(positive)
    validateattributes(c.(positive{i}),{'numeric'}, ...
        {'scalar','real','finite','positive'},mfilename,positive{i});
end
validateattributes(c.scenarioSpeeds,{'numeric'}, ...
    {'2d','real','finite','nonnegative','nonempty'},mfilename,'scenarioSpeeds');
assert(size(c.scenarioSpeeds,2)==3,'scenarioSpeeds must have three columns.');
assert(c.dt < c.tEnd,'dt must be smaller than tEnd.');
flags = {'animate','makeFinalPlots','saveResults'};
for i = 1:numel(flags)
    validateattributes(c.(flags{i}),{'logical','numeric'}, ...
        {'scalar','real','finite','binary'},mfilename,flags{i});
end
assert(numel(c.segmentTimes)==2 && all(isfinite(c.segmentTimes)) ...
    && c.segmentTimes(1)>0 && c.segmentTimes(1)<c.segmentTimes(2) ...
    && c.segmentTimes(2)<c.tEnd,'Require 0 < t1 < t2 < tEnd.');
assert(abs(c.tEnd/c.dt-round(c.tEnd/c.dt))<1e-7,'tEnd must be a multiple of dt.');
assert(isscalar(c.cameraFovDeg) && c.cameraFovDeg>0 && c.cameraFovDeg<170, ...
    'cameraFovDeg must be between 0 and 170.');
assert(isscalar(c.reacquireInnerRatio) && c.reacquireInnerRatio>0 ...
    && c.reacquireInnerRatio<1,'reacquireInnerRatio must be in (0,1).');
assert(c.initialHeight<=c.maxHeight,'initialHeight must not exceed maxHeight.');
assert(c.touchdownHeight<c.initialHeight,'touchdownHeight must be below initialHeight.');
assert(c.climbSpeed<=c.vzMax && c.descentSpeed<=c.vzMax, ...
    'climbSpeed and descentSpeed must not exceed vzMax.');
assert(isscalar(c.playbackSpeed) && isnumeric(c.playbackSpeed) ...
    && isreal(c.playbackSpeed) && c.playbackSpeed>0,'playbackSpeed must be > 0 or Inf.');
end

function y = saturate(x, limit)
y = min(max(x, -limit), limit);
end
