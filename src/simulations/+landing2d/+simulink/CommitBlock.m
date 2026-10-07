classdef CommitBlock < landing2d.simulink.BlockBase
    % COMMITBLOCK  한 물리 스텝의 결과 확정 (environment.step 루프 본문의 끝).
    %
    % 접촉 판정이 스텝 중간 접촉을 찾으면 그 시점(alpha)으로 드론 상태를
    % 보간하고 패드 궤적을 다시 계산합니다. 그 스텝의 측정·추정·문맥은
    % 갱신하지 않습니다. 실제 경과 시간만큼 시각을 진행하고, 감독기 개입
    % 시간과 종료 사유를 status에 기록합니다.
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'drone','pad','clock','snapshot','timing','intervened', ...
                'droneNext','padNext','contactEvent','terminalEvent', ...
                'measurementNext','trackNext','statusNext'};
        end
        function ports = outputPorts(obj)
            ports = {'droneCommit',obj.width('drone');'padCommit',obj.width('pad'); ...
                'measurementCommit',obj.width('measurement'); ...
                'trackCommit',obj.width('track'); ...
                'statusCommit',obj.width('status'); ...
                'clockCommit',obj.width('clock'); ...
                'snapshotCommit',obj.width('snapshot')};
        end
        function [drone,pad,measurement,track,status,clock,snapshot] = stepImpl( ...
                obj,droneBefore,padBefore,clockIn,snapshotIn,timing,intervened, ...
                droneNext,padNext,contactEvent,terminalEvent,measurementNext, ...
                trackNext,statusNext)
            measurement = measurementNext(:);
            track = trackNext(:);
            status = statusNext(:);
            clock = clockIn(:);
            snapshot = snapshotIn(:);
            if timing(4) == 0
                drone = droneBefore(:);
                pad = padBefore(:);
                return;
            end
            drone = droneNext(:);
            pad = padNext(:);
            first = obj.decode('event',contactEvent);
            if first.occurred
                event = first;
                if first.physicalContact && first.alpha < 1
                    % step.m의 interpolatePhysical과 같은 식
                    drone = droneBefore(:)+first.alpha*(droneNext(:)-droneBefore(:));
                    scenario = obj.currentEpisode().env.scenario;
                    [x,vx,ax,phase] = landing2d.scenario.evaluateTrajectory( ...
                        scenario,first.time);
                    pad = [x;scenario.padHeight;vx;ax;phase];
                end
            else
                event = obj.decode('event',terminalEvent);
            end
            actualDt = timing(2);
            if event.occurred, actualDt = event.time-timing(1); end
            clock(2) = clockIn(2)+actualDt;
            clock(1) = clockIn(1)+actualDt;
            s = obj.decode('status',status);
            if intervened ~= 0
                s.supervisorDuration = s.supervisorDuration+actualDt;
            end
            if event.occurred
                s.terminated = true;
                s.terminalReason = event.reason;
                s.physicalContact = event.physicalContact;
                s.contactAuthorized = event.authorized;
                s.mechanicallySafeContact = event.mechanicallySafe;
                s.contact = event.preImpact;
                if strcmp(event.reason,'SAFE_ABORT')
                    s.abortCompletionTime = event.time;
                end
            end
            status = obj.encode('status',s);
        end
    end
end
