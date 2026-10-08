function aNorm = referenceDriver(O,G,c,rs,noiseLevel)
% REFERENCEDRIVER  고정 probe 기준 궤적용 인과적 스크립트 구동기 ('causal_tracking_v1').
% 세 비교군과 무관한 고정 제어 법칙입니다. 입력은 공통 관측 o_t(UGV 추정·융합 측위),
% 부가 정보 G(패드 장착 오프셋), 공개 설정(카메라 장착각·안전 임계값·최종 하강 고도)뿐
% 이고 패드 참값을 쓰지 않습니다. probe 상태 분포를 특정 비교군에 맞추지 않기 위한
% 궤적 생성기이며 성능 기준이나 정답 행동이 아닙니다.
%   UGV 추정 초기화 후  패드 중심을 수평 자세 광축 위에 두는 수평 위치·속도 추종,
%                       최근 영상 보정이거나 최종 하강 고도 이하이면 고도 비례 하강,
%                       아니면 상승(시야 확대)
%   초기화 전           수평 가속 0, 상승
% RS·NOISELEVEL: 상태 다양화용 명령 잡음 (행동 한계 대비 표준편차, 전용 난수열).
s = c.experiment.safety;
offset = G.ugv.padOffset(:);
xD = O.drone.positionXZ(1); zD = O.drone.positionXZ(2);
vx = O.drone.velocityXZ(1); vz = O.drone.velocityXZ(2);
u = O.ugv;
ax = 0; vzTarget = 0.3;
if u.estimateInitialized
    padX = u.positionXZ(1)+offset(1);
    h = zD-(u.positionXZ(2)+offset(2));
    xTarget = padX+max(h,0)*tan(c.experiment.sensor.cameraPitchOffset);
    ax = 1.2*(xTarget-xD)+1.8*(u.velocityXZ(1)-vx);
    nearPad = h <= c.experiment.commonObservation.finalDescent.exitHeight ...
        && u.visionAge < s.prolongedLoss;
    if u.visionAge <= s.recentTrackGrace || nearPad
        vzTarget = -max(0.2,min(0.8,0.35*h));
    end
end
az = 2.5*(vzTarget-vz);
aNorm = [ax/c.axMax;az/c.azMax];
if noiseLevel > 0
    aNorm = aNorm+noiseLevel*randn(rs,2,1);
end
aNorm = min(max(aNorm,-1),1);
end
