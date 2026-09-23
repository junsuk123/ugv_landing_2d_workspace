function test_baseline_equivalence()
% TEST_BASELINE_EQUIVALENCE  원본 단일 파일과 모든 수치/상태 로그 비교.
% 기본 유도 법칙은 비례 항법으로 바뀌었지만, controller='pd' 경로는 원본과
% 완전히 같은 수치를 유지해야 합니다. 이 테스트가 그 경로를 고정합니다.
% 기본 시나리오의 구간 전환 시각은 이후 바뀌었으므로, 회귀 비교는 원본이 쓰던
% 값을 양쪽에 똑같이 넘겨서 수행합니다. 비교 대상은 제어/동역학 수치입니다.
options = struct('animate',false,'makeFinalPlots',false,'saveResults',false, ...
    'segmentTimes',[8,15],'controller','pd');
c = landing2d.config.applyOptions(landing2d.config.defaultConfig(),options);
actual = landing2d.simulation.run(c);
legacyOptions = rmfield(options,'controller');
evalc('[expected,~,~] = legacy_ugv_landing_2d_demo(legacyOptions);');
for j = 1:numel(expected)
    keys = fieldnames(expected(j));
    for f = 1:numel(keys)
        a = actual(j).(keys{f}); b = expected(j).(keys{f});
        assert(isequal(size(a),size(b)),sprintf('Size mismatch: %s',keys{f}));
        if isnumeric(a)
            assert(isequal(isnan(a),isnan(b)),sprintf('NaN mismatch: %s',keys{f}));
            mask = isfinite(a) & isfinite(b);
            assert(all(abs(a(mask)-b(mask)) <= 1e-10), ...
                sprintf('Numeric mismatch: scenario %d, %s',j,keys{f}));
        else
            assert(isequal(a,b),sprintf('Mismatch: %s',keys{f}));
        end
    end
end
end
