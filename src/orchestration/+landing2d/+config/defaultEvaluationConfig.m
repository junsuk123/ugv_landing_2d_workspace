function ev = defaultEvaluationConfig()
% DEFAULTEVALUATIONCONFIG  Evaluation settings of relational_policy_v1 (docs/EXPERIMENT_DESIGN_KO.md).
% Top-level c.evaluation: outside the training signature and the task
% fingerprint, so changing an evaluation never invalidates a checkpoint.
% No evaluation result selects a checkpoint (selection uses validation only).
ev.schemaVersion = 'relational_policy_evaluation_v1';
% Window metrics use [event start, event end + settling) [s].
ev.settling = 2.0;

% (1) Held-out test of the training distribution: experiment.testEpisodeCount
%     test-split episodes, reported per motion x observation cell.

% (2) Controlled 2 x 2 factorial cases (landing2d.evaluation.factorialCases):
%     S1 CV + clean, S2 CV + dropout, S3 CA + clean, S4 CA + dropout, all with
%     one seed, deadline and window per replicate. The dropout starts at the
%     acceleration onset T1 (overlap only here; independent in training).
%     Every value lies inside the training ranges (severe dropout class).
ev.factorial = struct('replicates',20,'seed',43001,'v1',1.0,'a2',0.6, ...
    'T1',3.0,'T2',1.5,'height',6.0,'deadline',30.0,'dropoutDuration',0.8);

% (3) Generalization outside the training ranges (stress split, the same
%     seeds in every condition so conditions are paired):
%     motion    UGV acceleration 1.0-1.5 m/s^2 in every episode (train 0.3-0.8)
%     dropout   one 1.0-2.0 s dropout in every episode (train <= 1.0 s)
%     noise     sensor-noise standard deviations x 2 (train x 1)
%     combined  motion and dropout together
ev.generalization = struct('episodes',100, ...
    'conditions',{{'motion','dropout','noise','combined'}}, ...
    'oodA2Range',[1.0,1.5],'oodDropoutDuration',[1.0,2.0],'oodNoiseScale',2);

% (4) Open-loop same-state probes (landing2d.evaluation.openLoopProbes): the
%     policy-independent reference driver flies test-split episodes; at probe
%     decisions every policy receives the same observation and
%       velocity contrast  UGV velocity estimate +/- velocityDelta with the same
%                          relative position (relative-motion response)
%       update contrast    the same physical state with the marker frames of the
%                          last staleAge seconds dropped (observation-update
%                          response; the estimator predicts)
ev.probes = struct('episodes',20,'stride',10,'velocityDelta',0.3, ...
    'staleAge',0.8,'minimumHeight',0.5);
% Reference driver of the probes (landing2d.probe.recordReference).
ev.probe = struct('driver','causal_tracking_v1','driverNoise',0.10, ...
    'randomOffset',6000000);

% (5) Learning efficiency from the training history: environment steps until
%     the validation landing rate first reaches each target, and the
%     normalized area under the validation landing-rate curve.
ev.learning = struct('targets',[0.5,0.8]);

% Intermediate policy snapshots during PPO (not used by this design).
ev.trainingSnapshots = 0;
end
