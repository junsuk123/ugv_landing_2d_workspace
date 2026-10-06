function rl = applyScratchSettings(rl)
% APPLYSCRATCHSETTINGS  교사 없이 처음부터 학습할 때의 설정을 덮어씁니다.
% 모방 학습으로 만든 초기 정책이 없으면 탐색과 학습량을 늘려야 합니다.
overrides = rl.scratch;
keys = fieldnames(overrides);
for i = 1:numel(keys)
    if ~isfield(rl,keys{i})
        error('landing2d:UnknownOption', ...
            'rl.scratch overrides an unknown option: %s',keys{i});
    end
    rl.(keys{i}) = overrides.(keys{i});
end
end
