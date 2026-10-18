function specs = factorialCases(c)
% FACTORIALCASES  Controlled 2 x 2 cases: UGV motion (CV/CA) x marker observation (clean/dropout).
%   S1  CV + clean      reference
%   S2  CV + dropout    observation factor only
%   S3  CA + clean      motion factor only
%   S4  CA + dropout    both; the dropout starts at the acceleration onset T1
% All four share one seed per replicate (same initial state and time-indexed
% noise table), one deadline and one evaluation window [T1, T1+T2) (+ settling),
% so  S2-S1, S4-S3 (dropout effect), S3-S1, S4-S2 (motion effect) and the
% interaction S4-S3-S2+S1 compare the same interval. Every value lies inside
% the training ranges (c.evaluation.factorial, validated in validatePrimaryConfig);
% the overlap of dropout and acceleration onset exists only in this evaluation.
f = c.evaluation.factorial;
s = c.experiment.scenario;
T3 = f.deadline-f.T1-f.T2;
window = [f.T1,f.T1+f.T2];
gap = struct('dropoutStart',f.T1,'dropoutEnd',f.T1+f.dropoutDuration, ...
    'dropoutKind','severe','pitchStart',Inf,'pitchEnd',-Inf,'pitchRate',0);
clean = struct('dropoutStart',Inf,'dropoutEnd',-Inf,'dropoutKind','clean', ...
    'pitchStart',Inf,'pitchEnd',-Inf,'pitchRate',0);
ids = {'S1','S2','S3','S4'};
names = {'CV + clean','CV + dropout','CA + clean','CA + dropout'};
motion = [0,0,1,1]; observation = [0,1,0,1];
specs = struct('id',{},'name',{},'motion',{},'observation',{},'seed',{}, ...
    'scenario',{},'sensorEvents',{},'eventWindow',{});
for i = 1:4
    a2 = f.a2*motion(i);
    scenario = struct('v1',f.v1,'a2',a2,'T1',f.T1,'T2',f.T2,'T3',T3, ...
        'v3',f.v1+a2*f.T2,'L1',f.v1*f.T1,'L2',f.v1*f.T2+0.5*a2*f.T2^2, ...
        'L3',(f.v1+a2*f.T2)*T3,'height',f.height, ...
        'initialSpeedOffset',0,'initialPositionOffset',0, ...
        'x0',s.x0,'padHeight',s.padHeight,'deadline',f.deadline, ...
        'parameterization','factorial_fixed','seed',NaN,'attempt',0, ...
        'feasibleSpeed',true,'rejectionReason','');
    events = clean; if observation(i), events = gap; end
    specs(i) = struct('id',ids{i},'name',names{i},'motion',motion(i), ...
        'observation',observation(i),'seed',f.seed,'scenario',scenario, ...
        'sensorEvents',events,'eventWindow',window); %#ok<AGROW>
end
end
