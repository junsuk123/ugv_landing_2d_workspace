function filter = updateUgvAcceleration(filter,y,measurementCovariance,measured,navigation,t,G)
% UPDATEUGVACCELERATION  병렬 등가속 칼만 필터 (상태 [x; z; vx; vz; ax; az], 로컬 좌표).
%   예측  F(dt) = kron([1 dt dt^2/2; 0 1 dt; 0 0 1], I2),
%         Q(dt) = kron(T(dt), diag(q)), T = [dt^5/20 dt^4/8 dt^3/6; dt^4/8 dt^3/3 dt^2/2;
%         dt^3/6 dt^2/2 dt] (축별 백색 jerk, 스펙트럼 밀도 q = estimator.acceleration.
%         jerkSpectralDensity [qx, qz] [m^2/s^5])
%   측정 갱신  y = C s + v, C = [I 0 0], v ~ N(0, measurementCovariance), Joseph 형식
% 등속 필터(landing2d.observation.updateUgvEstimate)와 같은 측정치 y·공분산·유효성·시각을
% 쓰며 측정이나 난수를 추가하지 않습니다. 측정치가 없으면 예측만 유지하고, 참값·평활화·
% 미래 입력은 쓰지 않습니다. 초기화: 첫 유효 측정치에서 [y; 드론 융합 속도; 0; 0],
% P = blkdiag(R, initialVelocityStd^2 I, diag(initialAccelerationStd.^2)).
% 등속 필터의 상태와 관측 o1-o10은 바꾸지 않습니다(가속 추정은 별도 항목).
settings = G.estimator.acceleration;
filter.updated = false;
if filter.initialized
    dt = t-filter.time;
    assert(dt >= -1e-12,'landing2d:EstimatorTimeOrder','UGV acceleration estimator time moved backwards.');
    if dt > 0
        F = kron([1,dt,dt^2/2; 0,1,dt; 0,0,1],eye(2));
        T = [dt^5/20,dt^4/8,dt^3/6; dt^4/8,dt^3/3,dt^2/2; dt^3/6,dt^2/2,dt];
        Q = kron(T,diag(settings.jerkSpectralDensity(:)));
        filter.state = F*filter.state;
        filter.covariance = F*filter.covariance*F'+Q;
    end
    filter.time = t;
    if measured
        C = [eye(2),zeros(2,4)];
        P = filter.covariance;
        kalmanGain = P*C'/(C*P*C'+measurementCovariance);
        filter.state = filter.state+kalmanGain*(y-C*filter.state);
        reduction = eye(6)-kalmanGain*C;
        filter.covariance = reduction*P*reduction'+kalmanGain*measurementCovariance*kalmanGain';
        filter.updated = true;
    end
elseif measured
    filter.state = [y;navigation.velocityXZ;0;0];
    filter.covariance = blkdiag(measurementCovariance, ...
        G.estimator.initialVelocityStd^2*eye(2),diag(settings.initialAccelerationStd(:).^2));
    filter.initialized = true;
    filter.time = t;
    filter.updated = true;
end
end
