function specs = representativeScenarios(c)
% REPRESENTATIVESCENARIOS  Fixed, ontology-aligned paper evaluation cases.
% The cases are fixed before any policy is evaluated (seeds 41001-41003,
% outside every manifest split). They are therefore reproducible and cannot
% be changed by looking at which checkpoint wins a particular random seed.
% UGV motion parameters lie inside the declared scenario ranges. The S3
% dropout (0.8 s) is deliberately longer than the sampled short range
% (0.2-0.5 s) and shorter than the sustained range (3.5-5.0 s): it outlasts
% the 0.5 s recent-vision grace, so LandingInhibit engages, but not the 3 s
% prolonged-loss backup. A 0.5 s dropout would never inhibit landing.
% The 3D option adds fixed lateral pad motion (vy1, ay2) inside the declared
% lateral ranges; the planar parameters and sensor events are unchanged.

specs(1) = makeSpec(c,1,'S1 Nominal alignment', ...
    'Nominal tracking / DescentEligibility', ...
    'PadVisibility -> RelativeTracking -> DescentEligibility', ...
    1.50,0.60,2.00,1.50,28.0,6.0,cleanEvents());

specs(2) = makeSpec(c,2,'S2 Rapid acceleration', ...
    'Pad acceleration / TrackingCorrection', ...
    'PadMotion -> RelativeTracking -> TrackingCorrection', ...
    1.00,1.50,2.00,2.25,28.0,7.0,cleanEvents());

events = cleanEvents();
events.dropoutKind = 'short';
events.dropoutStart = 4.2;
events.dropoutEnd = 5.0;
specs(3) = makeSpec(c,3,'S3 Visibility recovery', ...
    'Bounded dropout / ViewRecovery and LandingInhibit', ...
    'PadVisibility -> ViewRecovery -> LandingInhibit', ...
    1.00,1.20,2.00,2.75,30.0,6.5,events);
if landing2d.environment.isSpatial(c)
    lateral = [0.30,0.00; 0.00,0.50; -0.20,-0.40];   % [vy1, ay2] per S1..S3
    for k = 1:numel(specs)
        specs(k).scenario = addLateral(specs(k).scenario,lateral(k,:),c);
    end
end
end

function scenario = addLateral(scenario,lateral,c)
s = c.experiment.scenario;
scenario.vy1 = lateral(1);
scenario.ay2 = lateral(2);
scenario.vy3 = scenario.vy1+scenario.ay2*scenario.T2;
scenario.y0 = s.y0;
scenario.feasibleSpeed = hypot(scenario.v3,scenario.vy3) <= ...
    s.sustainedDroneSpeed-s.speedMargin;
if scenario.feasibleSpeed
    scenario.rejectionReason = '';
else
    scenario.rejectionReason = 'speed authority';
end
end

function spec = makeSpec(c,index,name,challenge,ontologyPath, ...
        v1,a2,T1,T2,T3,height,events)
s = c.experiment.scenario;
scenario = struct('v1',v1,'a2',a2,'T1',T1,'T2',T2,'T3',T3, ...
    'v3',v1+a2*T2,'L1',v1*T1, ...
    'L2',v1*T2+0.5*a2*T2^2,'L3',(v1+a2*T2)*T3, ...
    'height',height,'x0',s.x0,'padHeight',s.padHeight, ...
    'deadline',T1+T2+T3,'parameterization','paper_fixed', ...
    'seed',NaN,'attempt',0,'feasibleSpeed',false,'rejectionReason','');
scenario.feasibleSpeed = scenario.v3 <= s.sustainedDroneSpeed-s.speedMargin;
if ~scenario.feasibleSpeed, scenario.rejectionReason = 'speed authority'; end
spec = struct('index',index,'id',sprintf('S%d',index),'name',name, ...
    'challenge',challenge,'ontologyPath',ontologyPath, ...
    'seed',41000+index,'scenario',scenario,'sensorEvents',events);
end

function events = cleanEvents()
events = struct('dropoutStart',Inf,'dropoutEnd',-Inf, ...
    'dropoutKind','clean','pitchStart',Inf,'pitchEnd',-Inf,'pitchRate',0);
end
