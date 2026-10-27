function [observations,metadata] = diagnosticInputs(c)
% DIAGNOSTICINPUTS Fixed current-state quartets, never a policy history buffer.
% These are constraint-consistent estimated states, not claims that every
% quartet occurs on a flight. No simulator truth or outcome enters the policy.
G=landing2d.observation.staticContext(c);
corners=[-1,-1;-1,1;1,-1;1,1];
names={'position_velocity','height_vertical_velocity','vision_age_velocity'};
observations=zeros(10,3*8*4); rows=cell(1,size(observations,2)); column=0;
for probe=1:3
    for anchor=1:8
        theta=(-1)^anchor*.08;
        targetVelocity=2+mod(anchor-1,4);
        height=.6+1.2*floor((anchor-1)/4);
        relativePosition=(-1)^anchor*.4;
        for corner=1:4
            ex=relativePosition; h=height; vr=.2; vz=-.3; age=.2;
            a=corners(corner,1); b=corners(corner,2);
            switch probe
                case 1
                    ex=.6*a; vr=.5*b;
                case 2
                    h=.35+(a+1)*.575; vz=-.3+.4*b;
                case 3
                    age=.4*(a+1); vr=.5*b;
            end
            O.ugv=struct('positionXZ',[ex;0],'velocityXZ',[targetVelocity;0], ...
                'visionUpdated',age==0,'visionAge',age,'estimateInitialized',true);
            O.drone=struct('positionXZ',[0;h+G.ugv.padOffset(2)], ...
                'velocityXZ',[targetVelocity-vr;vz], ...
                'pitchSinCos',[sin(theta);cos(theta)],'pitchRate',0);
            column=column+1;
            observations(:,column)=landing2d.observation.toVector(O,G);
            rows{column}=struct('Probe',string(names{probe}),'Anchor',anchor,'Corner',corner, ...
                'RelativePosition_m',ex,'Height_m',h,'RelativeVelocity_mps',vr, ...
                'VerticalVelocity_mps',vz,'VisionAge_s',age);
        end
    end
end
assert(all(isfinite(observations),'all') && all(abs(sum(observations(6:7,:).^2,1)-1)<1e-12));
assert(all((observations(9,:)==1)==(observations(10,:)==0)));
metadata=struct2table([rows{:}]);
end
