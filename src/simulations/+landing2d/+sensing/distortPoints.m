function xyd = distortPoints(xy,d)
% DISTORTPOINTS  정규화 영상 좌표 [x/z; y/z] (2 x N)에 렌즈 왜곡을 적용합니다.
% OpenCV 왜곡 모델, d = [k1 k2 p1 p2 k3]:
%   r^2 = x^2+y^2,  radial = 1+k1 r^2+k2 r^4+k3 r^6
%   x_d = x radial + 2 p1 x y + p2 (r^2+2x^2)
%   y_d = y radial + p1 (r^2+2y^2) + 2 p2 x y
% 역변환은 landing2d.sensing.undistortPoints입니다.
x = xy(1,:); y = xy(2,:);
r2 = x.^2+y.^2;
radial = 1+d(1)*r2+d(2)*r2.^2+d(5)*r2.^3;
xyd = [x.*radial+2*d(3)*x.*y+d(4)*(r2+2*x.^2); ...
    y.*radial+d(3)*(r2+2*y.^2)+2*d(4)*x.*y];
end
