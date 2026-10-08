function rules = taskRules(probe,c)
% TASKRULES  Which task-regression rules apply at a probe (observable context only).
%   horizontalActive  recent vision (reference observation): the policy can see
%                     the UGV motion it should track
%   horizontalMetric  'relativeSpeed' above the final-descent exit height (match
%                     the UGV motion), 'stopError' at or below it (align with the
%                     pad center for touchdown)
%   verticalActive    landing authorized and recent vision: descending toward
%                     the pad is the task; with landing inhibited, backup or stale
%                     vision, holding or climbing is legitimate and no vertical
%                     rule applies
ctx = probe.context;
recent = ctx.estimateInitialized && ctx.visionAge <= c.experiment.safety.recentTrackGrace;
h = probe.drone(2)-probe.pad(2);
metric = 'relativeSpeed';
if h <= c.experiment.commonObservation.finalDescent.exitHeight, metric = 'stopError'; end
rules = struct('horizontalActive',recent,'horizontalMetric',metric, ...
    'verticalActive',recent && ~ctx.landingInhibited && ~ctx.abortRequested);
end
