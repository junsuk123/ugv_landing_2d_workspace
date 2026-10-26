function T = typingSwap(runs,d,seeds)
% TYPINGSWAP Closed-loop dependence of the trained graph actors on their own relation typing (P6).
% TOSM and Shuffled of the same training seed share topology, node features and
% parameter shapes; only the relation index of six semantic edges differs.
% Each trained graph actor flies the v2 motion-OOD cell with its own typing and
% with its partner's typing (same parameters). This measures how much a trained
% policy depends on the typing it was trained with; it is not a comparison with
% a model trained under the other typing. Own-typing rows must equal the stored
% protocol-v2 development rollouts.
if nargin<3, seeds = d.typingSwap.seeds; end
q = d.typingSwap;
stored = readtable(fullfile(d.v2Evaluation,'generalizationEpisodes.csv'),'TextType','string');
graph = runs(ismember({runs.id},{'onto_rgat_ppo','shuffled_rgat_ppo'}));
rows = {};
for r = 1:numel(graph)
    run = graph(r);
    partnerId = setdiff({'onto_rgat_ppo','shuffled_rgat_ppo'},{run.id});
    partner = runs(strcmp({runs.id},partnerId{1}) & [runs.trainSeed]==run.trainSeed);
    assert(isscalar(partner));
    [envConfig,scale] = landing2d.bias_diagnostics.condition(d,run.config,q.factor,q.shift);
    spec = struct('scenario',[],'sensorEvents',[],'eventWindow',[],'sensorNoiseScale',scale);
    swapped = run; swapped.agent.encoderSpec = partner.agent.encoderSpec;
    for variant = ["own","partnerTyping"]
        candidate = run; if variant=="partnerTyping", candidate = swapped; end
        identity = struct('Factor',string(q.factor),'Shift',string(q.shift),'Variant',variant);
        E = struct2table(landing2d.evaluation.rolloutSet(candidate,envConfig,seeds, ...
            repmat(spec,1,numel(seeds)),repmat(identity,1,numel(seeds))));
        if variant=="own"
            for i = 1:height(E)
                s = stored(stored.MethodId==string(run.id) & stored.TrainSeed==run.trainSeed ...
                    & stored.Factor==string(q.factor) & stored.Shift==string(q.shift) ...
                    & stored.EpisodeSeed==E.EpisodeSeed(i),:);
                assert(height(s)==1 && s.Success==E.Success(i) && s.Unsafe==E.Unsafe(i), ...
                    'landing2d:BiasDiagnosticsReplay','Own-typing rollout differs from the stored v2 evaluation.');
            end
        end
        rows{end+1} = E(:,{'MethodId','TrainSeed','Variant','EpisodeSeed','Success','Unsafe', ...
            'AimErrorRMS_m','FailureClass'}); %#ok<AGROW>
    end
end
T = vertcat(rows{:});
end
