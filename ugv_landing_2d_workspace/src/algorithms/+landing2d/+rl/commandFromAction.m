function u = commandFromAction(ax,az,c)
% COMMANDFROMACTION  actionFromCommand의 역변환. 모방 학습 목표값 생성용.
% 교사 출력이 한계에 붙어 있어도 유한한 목표가 되도록 경계에서 잘라냅니다.
limit = 0.995;
u = [atanh(landing2d.util.saturate(ax/c.axMax,limit)); ...
    atanh(landing2d.util.saturate(az/c.azMax,limit))];
end
