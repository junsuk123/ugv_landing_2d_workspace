function d = relativeDistance(r)
% RELATIVEDISTANCE  패드 중심과 드론 사이의 x-z 평면 상대거리 [m].
% 착륙 후에는 드론이 패드에 붙어 이동하므로 0에 머무릅니다.
% 접촉 실패 후에는 UGV가 멀어지므로 값이 다시 커집니다.
d = hypot(r.xUgv-r.xDrone, r.zPad-r.zDrone);
end
