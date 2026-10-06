function rl = ensurePool(rl)
% ENSUREPOOL  에피소드 병렬 수집에 쓸 병렬 풀을 준비합니다.
% Parallel Computing Toolbox가 없거나 풀을 열 수 없으면 직렬로 되돌립니다.
% 병렬 여부는 결과를 바꾸지 않으므로(에피소드별 난수 흐름을 미리 뽑습니다)
% 되돌아가도 수치는 같습니다.
if ~rl.parallelEpisodes
    return;
end
if isempty(ver('parallel'))
    warning('landing2d:NoParallelToolbox', ...
        'Parallel Computing Toolbox가 없어 직렬로 학습합니다.');
    rl.parallelEpisodes = false;
    return;
end
if rl.parallelWorkers > 0
    workers = rl.parallelWorkers;
else
    workers = max(1,min(feature('numcores'),rl.episodesPerIteration));
end
pool = gcp('nocreate');
if ~isempty(pool) && pool.NumWorkers >= workers
    return;
end
try
    if ~isempty(pool)
        delete(pool);
    end
    % 기본 Processes 프로파일은 워커 수가 8로 제한되어 있습니다. 메모리 상의
    % 클러스터 객체에서만 올리고 saveProfile은 하지 않습니다(사용자 설정 보존).
    cluster = parcluster('Processes');
    if cluster.NumWorkers < workers
        cluster.NumWorkers = workers;
    end
    parpool(cluster,workers);
catch err
    warning('landing2d:PoolFailed', ...
        '병렬 풀을 열지 못해 직렬로 학습합니다: %s',err.message);
    rl.parallelEpisodes = false;
end
end
