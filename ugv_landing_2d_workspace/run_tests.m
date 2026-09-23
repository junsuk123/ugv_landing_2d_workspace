function report = run_tests(includeGraphics)
% RUN_TESTS  별도 Toolbox 없이 assert 기반 테스트 실행.
% run_tests          : 수치 회귀 + 정보경계 + 구간 + 설정 + 강화학습 + 온톨로지 + 그래픽/저장
% run_tests(false)   : 그래픽을 제외한 테스트만
if nargin < 1, includeGraphics = true; end
projectRoot = setup_project();
oldPath = path;
cleanup = onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(projectRoot,'tests'));
addpath(fullfile(projectRoot,'tests','reference'));
tests = {@test_baseline_equivalence,@test_pn_guidance,@test_observation_boundary, ...
    @test_speed_segments,@test_config_validation, ...
    @test_rl_gradients,@test_rl_observation_boundary,@test_rl_pipeline, ...
    @test_rgat_gradients,@test_ontology_schema,@test_reward_design, ...
    @test_graph_state_adapter,@test_graph_state_encoder,@test_graph_state_ppo};
if includeGraphics
    tests = [tests,{@test_segment_background,@test_plot_export}];
end
names = cell(numel(tests),1);
passed = false(numel(tests),1);
messages = cell(numel(tests),1);
for i = 1:numel(tests)
    names{i} = func2str(tests{i});
    try
        tests{i}();
        passed(i) = true;
        messages{i} = 'PASS';
    catch err
        messages{i} = getReport(err,'basic','hyperlinks','off');
    end
    fprintf('[%d/%d] %s: %s\n',i,numel(tests),names{i},messages{i});
end
report = table(names,passed,messages,'VariableNames',{'Test','Passed','Message'});
if ~all(passed)
    error('landing2d:TestsFailed','%d test(s) failed. See output above.',sum(~passed));
end
end
