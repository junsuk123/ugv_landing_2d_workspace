function filter = updateUgvEstimate(filter,y,measurementCovariance,measured,navigation,t,G)
% UPDATEUGVESTIMATE  UGV 위치·속도 등속 칼만 필터 (상태 [x; z; vx; vz], 로컬 좌표).
%   예측  F(dt) = [I dt*I; 0 I],
%         Q(dt) = [dt^3/3*A dt^2/2*A; dt^2/2*A dt*A], A = diag(sigma_ax^2, sigma_az^2)
%         (축별 백색 가속도, estimator.accelerationNoiseStd = [sigma_ax, sigma_az])
%   측정 갱신  y = C s + v, C = [I 0], v ~ N(0, measurementCovariance), Joseph 형식
%         (y: UGV 위치 측정치, F: 상태 천이 행렬, Q: 공정 잡음 공분산,
%          C: 측정 행렬, P: 오차 공분산, kalmanGain: 칼만 이득)
% 측정치가 없으면(미검출·PnP 기각·영상 없음) 예측만 유지하며 참값을 쓰지 않습니다.
% 초기화: 첫 유효 측정치에서 위치 = 측정치, 속도 = 드론 융합 속도(초기 속도 정합 계약의
% 인과적 사전값), 속도 분산 = initialVelocityStd^2. 초기화 전에는 상태를 만들지 않습니다.
% 위치 측정치를 선형 모델에 넣는 KF 구성은 이번 설계의 선택입니다.
estimator = G.estimator;
filter.updated = false;
if filter.initialized
    dt = t-filter.time;
    assert(dt >= -1e-12,'landing2d:EstimatorTimeOrder','UGV estimator time moved backwards.');
    if dt > 0
        F = [eye(2),dt*eye(2); zeros(2),eye(2)];
        A = diag(estimator.accelerationNoiseStd(:).^2);
        Q = [dt^3/3*A,dt^2/2*A; dt^2/2*A,dt*A];
        filter.state = F*filter.state;
        filter.covariance = F*filter.covariance*F'+Q;
    end
    filter.time = t;
    if measured
        C = [eye(2),zeros(2)];
        P = filter.covariance;
        kalmanGain = P*C'/(C*P*C'+measurementCovariance);
        filter.state = filter.state+kalmanGain*(y-C*filter.state);
        reduction = eye(4)-kalmanGain*C;
        filter.covariance = reduction*P*reduction'+kalmanGain*measurementCovariance*kalmanGain';
        filter.updated = true;
    end
elseif measured
    filter.state = [y;navigation.velocityXZ];
    filter.covariance = blkdiag(measurementCovariance,estimator.initialVelocityStd^2*eye(2));
    filter.initialized = true;
    filter.time = t;
    filter.updated = true;
end
if filter.updated
    filter.lastUpdateTime = t;
end
end
