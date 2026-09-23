function phi = predict(P,X,T)
% PREDICT  학습된 잠재함수 값을 그래프 배치에 대해 계산. 기울기 경로 없음.
phi = landing2d.rgat.potentialForward(P,X,T);
end
