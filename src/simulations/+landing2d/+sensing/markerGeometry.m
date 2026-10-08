function corners = markerGeometry(padConfig)
% MARKERGEOMETRY  등록 마커의 패드 기준 실제 코너 좌표 (M x 4 x 3) [m].
% 패드 좌표: x 전방, y 좌측, z 패드 면 법선(위), 원점 = 패드 면 중심.
% 슬롯 순서는 padConfig.markerIds 순서, 코너 순서는 ArUco 규약(좌상·우상·우하·좌하)이며
% 마커 좌상단은 +x·+y 모서리입니다. 시뮬레이션 검출기와 부가 정보 Gamma가
% 이 함수 하나로 같은 기하를 씁니다.
offsets = 0.5*[1,1; 1,-1; -1,-1; -1,1];
M = numel(padConfig.markerIds);
corners = zeros(M,4,3);
for i = 1:M
    corners(i,:,1:2) = reshape(padConfig.markerCenters(i,:)+ ...
        padConfig.markerSides(i)*offsets,1,4,2);
end
end
