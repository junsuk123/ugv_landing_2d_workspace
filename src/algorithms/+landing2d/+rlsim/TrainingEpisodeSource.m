classdef TrainingEpisodeSource < handle
    % TRAININGEPISODESOURCE  Simulink 학습용 에피소드 공급원과 커리큘럼 상태.
    %
    % landing2d.rl.ppoTrain과 같은 학습 분포를 만듭니다. 반복마다
    % episodesPerIteration개의 seed와 커리큘럼 수준(쉬운·중간 재생 포함)을 뽑고,
    % landing2d.rl.trainingEpisodeConfig로 에피소드 설정을 만듭니다.
    %
    % 클라이언트는 평가 구간(chunk)마다 계획을 세우고(beginChunk), 에피소드는
    % ResetFcn이 실행되는 프로세스에서 next()로 뽑습니다. 병렬 학습에서는
    % 워커마다 이 객체의 복사본이 생기므로, 워커 번호별 난수 부분 흐름으로
    % 서로 다른 seed를 뽑습니다. 종료 결과는 Simulink 출력(episodeOutcome)으로
    % 돌아와 windowStats/advanceCurriculum이 클라이언트에서 처리합니다.
    properties
        Config
        Rl
        CurriculumLevel = NaN    % 클라이언트의 현재 커리큘럼 수준
        Streak = 0
        ChunkId = 0
        ChunkSeed = 0
        ChunkStart = 0           % 이 구간 직전까지 끝난 반복 수
        ChunkEnd = 0
        Workers = 1
    end
    properties (Transient)
        Stream = []
        LocalBatches = 0
        BatchSeeds = []
        BatchLevels = []
        BatchIteration = 0
        BatchLevel = NaN
        BatchIndex = 0
    end

    methods
        function obj = TrainingEpisodeSource(c)
            obj.Config = c;
            obj.Rl = c.rl;
            if strcmp(c.rl.curriculumMode,'performance')
                obj.CurriculumLevel = 0;
            end
        end

        function beginChunk(obj,startIteration,endIteration,seed,workers)
            % 클라이언트: 다음 train() 호출이 학습할 반복 구간 계획
            obj.ChunkId = obj.ChunkId+1;
            obj.ChunkStart = startIteration;
            obj.ChunkEnd = endIteration;
            obj.ChunkSeed = double(seed);
            obj.Workers = max(1,workers);
            obj.Stream = [];
        end

        function bind(obj,worker)
            % 에피소드를 뽑을 프로세스: 구간 seed + 워커 번호 부분 흐름
            obj.Stream = RandStream('threefry','Seed',obj.ChunkSeed);
            obj.Stream.Substream = worker+1;
            obj.LocalBatches = 0;
            obj.BatchIndex = 0;
        end

        function spec = next(obj)
            if isempty(obj.Stream), obj.bind(0); end
            if obj.BatchIndex == 0 || obj.BatchIndex >= obj.Rl.episodesPerIteration
                obj.startBatch();
            else
                obj.BatchIndex = obj.BatchIndex+1;
            end
            k = obj.BatchIndex;
            level = obj.BatchLevels(k);
            [episodeConfig,heightRange] = landing2d.rl.trainingEpisodeConfig( ...
                obj.Config,obj.BatchIteration,level);
            spec = struct('config',episodeConfig,'seed',obj.BatchSeeds(k), ...
                'resetOptions',struct('scenarioHeightRange',heightRange), ...
                'actions',[],'iteration',obj.BatchIteration, ...
                'curriculumLevel',level,'iterationLevel',obj.BatchLevel);
        end

        function stats = windowStats(~,outcomes)
            % landing2d.rl.ppoTrain 평가 창 통계와 같은 정의.
            % outcomes 행: [seed level iterationLevel reasonCode return ...]
            names = landing2d.simulink.signalCodec('reasons','');
            n = size(outcomes,1);
            reason = strings(n,1);
            for i = 1:n
                code = outcomes(i,4);
                if code >= 1 && code <= numel(names)
                    reason(i) = names{code};
                else
                    reason(i) = "TRUNCATED";
                end
            end
            success = reason == "SUCCESS";
            level = outcomes(:,2);
            iterationLevel = outcomes(:,3);
            nominal = level >= 1-1e-12;
            current = abs(level-iterationLevel) < 1e-12;
            stats = struct('trainReturn',sum(outcomes(:,5))/max(n,1), ...
                'trainLandingRate',sum(success)/max(n,1), ...
                'trainNominalLandingRate',NaN, ...
                'trainCurriculumLandingRate',sum(success & current)/max(sum(current),1), ...
                'trainSafeAbortRate',sum(reason == "SAFE_ABORT")/max(n,1), ...
                'episodes',n);
            if any(nominal)
                stats.trainNominalLandingRate = sum(success & nominal)/sum(nominal);
            end
        end

        function raiseFloor(obj,iteration)
            if isfinite(obj.CurriculumLevel)
                obj.CurriculumLevel = max(obj.CurriculumLevel, ...
                    landing2d.rl.curriculumFloor(obj.Rl,iteration));
            end
        end

        function advanceCurriculum(obj,curriculumLandingRate)
            if isfinite(obj.CurriculumLevel)
                [obj.CurriculumLevel,obj.Streak] = landing2d.rl.advanceCurriculumLevel( ...
                    obj.Rl,obj.CurriculumLevel,curriculumLandingRate,obj.Streak);
            end
        end
    end

    methods (Access = private)
        function startBatch(obj)
            % 직렬이면 반복 번호가 정확히 하나씩 늘고, 병렬이면 워커 수만큼
            % 진행된 것으로 근사합니다(구간 끝을 넘지 않음).
            obj.LocalBatches = obj.LocalBatches+1;
            obj.BatchIteration = min(obj.ChunkEnd, ...
                obj.ChunkStart+1+(obj.LocalBatches-1)*obj.Workers);
            obj.BatchLevel = obj.CurriculumLevel;
            if isfinite(obj.BatchLevel)
                obj.BatchLevel = max(obj.BatchLevel, ...
                    landing2d.rl.curriculumFloor(obj.Rl,obj.BatchIteration));
            end
            count = obj.Rl.episodesPerIteration;
            obj.BatchSeeds = randi(obj.Stream,intmax('int32'),count,1);
            obj.BatchLevels = landing2d.rl.curriculumBatchLevels(obj.Rl, ...
                obj.BatchLevel,count);
            obj.BatchIndex = 1;
        end
    end
end
