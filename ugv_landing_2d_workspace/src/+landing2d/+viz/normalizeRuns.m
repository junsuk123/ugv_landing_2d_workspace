function runs = normalizeRuns(runs)
% NORMALIZERUNS  비교 표시용 run 구조체의 기본 표시 설정 채우기.
% results 필드는 필수이며, 나머지는 순서에 따른 기본 색/선형을 사용합니다.
defaults = struct( ...
    'label',{'PN guidance','PPO RL','Onto R-GAT','Run 4'}, ...
    'color',{[0.05,0.20,0.42],[0.72,0.25,0.10],[0.35,0.15,0.55],[0.10,0.45,0.35]}, ...
    'lineStyle',{'-','-.','--',':'});
assert(isstruct(runs) && ~isempty(runs),'runs must be a nonempty struct array.');
assert(isfield(runs,'results'),'Each run needs a results field.');
assert(numel(runs) <= numel(defaults), ...
    'landing2d:TooManyRuns','At most %d runs can be compared.',numel(defaults));
fields = {'label','color','lineStyle'};
for i = 1:numel(runs)
    for f = 1:numel(fields)
        key = fields{f};
        if ~isfield(runs,key) || isempty(runs(i).(key))
            runs(i).(key) = defaults(i).(key);
        end
    end
    runs(i).label = char(runs(i).label);
    if ~isfield(runs,'note')
        runs(i).note = '';
    end
end
end
