function varargout = episodeServer(command,varargin)
% EPISODESERVER  MATLAB 쪽 에피소드 준비와 Simulink 환경 블록 사이의 연결.
%
%   episodeServer('setSource',source)  next()/record()를 가진 에피소드 공급원 등록
%   episodeServer('advance')           다음 에피소드 준비 (rlSimulinkEnv ResetFcn)
%   episodeServer('advanceFrom',src)   ResetFcn이 넘긴 공급원으로 준비. 학습 구간
%                                      (ChunkId)이 바뀌면 이 프로세스의 워커
%                                      번호로 난수 부분 흐름을 다시 묶습니다.
%   episodeServer('setEpisode',spec)   공급원 없이 에피소드 하나를 직접 준비
%   ep = episodeServer('current')      블록 resetImpl/stepImpl이 읽는 현재 에피소드
%   episodeServer('log',entry)         결정 시점 기록 추가
%   episodeServer('record',outcome)    종료 결과 전달 (공급원의 커리큘럼 통계)
%   episodeServer('clear')
%
% 에피소드 초기 상태는 landing2d.environment.reset이 만듭니다. 센서 난수 흐름은
% 그 결과의 RandStream 핸들을 카메라 블록이 그대로 이어 쓰므로, 같은 seed에서
% MATLAB 환경과 같은 잡음 표본이 나옵니다.
persistent source episode boundChunk
switch command
    case 'setSource'
        source = varargin{1};
        episode = [];
        boundChunk = [];
    case 'advance'
        assert(~isempty(source),'landing2d:EpisodeServer', ...
            'No episode source is configured for the Simulink environment.');
        episode = startEpisode(source.next());
    case 'advanceFrom'
        candidate = varargin{1};
        if isempty(source) || isempty(boundChunk) || boundChunk ~= candidate.ChunkId
            source = candidate;
            boundChunk = candidate.ChunkId;
            task = getCurrentTask();
            worker = 0;
            if ~isempty(task), worker = task.ID; end
            source.bind(worker);
        end
        episode = startEpisode(source.next());
    case 'setEpisode'
        episode = startEpisode(varargin{1});
    case 'current'
        assert(~isempty(episode),'landing2d:EpisodeServer', ...
            'No episode is prepared. Call advance or setEpisode before sim.');
        varargout{1} = episode;
    case 'log'
        episode.log{end+1} = varargin{1};
    case 'record'
        episode.outcome = varargin{1};
        if ~isempty(source) && ismethod(source,'record')
            source.record(varargin{1});
        end
    case 'source'
        varargout{1} = source;
    case 'clear'
        source = [];
        episode = [];
        boundChunk = [];
    otherwise
        error('landing2d:EpisodeServer','Unknown command %s.',command);
end
end

function episode = startEpisode(spec)
required = {'config','seed','resetOptions'};
assert(isstruct(spec) && all(isfield(spec,required)), ...
    'landing2d:EpisodeSpec','Episode spec needs config, seed, resetOptions.');
[env,observation,info] = landing2d.environment.reset(spec.config, ...
    spec.seed,spec.resetOptions);
episode = struct('spec',spec,'env',env,'observation',observation, ...
    'info',info,'log',{{}},'outcome',[]);
end
