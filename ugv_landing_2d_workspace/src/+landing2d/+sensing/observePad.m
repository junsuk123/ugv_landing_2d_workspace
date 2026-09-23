function obs = observePad(s, xp, vp, c)
% OBSERVEPAD  수직 하향 카메라의 기하학적 FOV 판정.
% 보이지 않을 때 xError/vError/padSpeed를 NaN으로 차단.
obs.halfWidth = max(s.h,0) * tand(c.cameraFovDeg/2);
obs.visible = s.mode < 3 && s.h > 0 && abs(xp-s.x) <= obs.halfWidth;
obs.xError = NaN;
obs.vError = NaN;
obs.padSpeed = NaN;
if obs.visible
    obs.xError = xp-s.x;
    obs.vError = vp-s.vx;
    obs.padSpeed = vp;
end
end
