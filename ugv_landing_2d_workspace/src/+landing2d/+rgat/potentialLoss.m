function [loss,grads,phi] = potentialLoss(P,X,y,T,onto)
% POTENTIALLOSS  MSE + 약한 출력 정규화. 원 저장소 training.rgatGradients와 같은 손실.
[phi,cache] = landing2d.rgat.potentialForward(P,X,T);
y = reshape(y,1,[]);
residual = phi-y;
B = numel(y);
loss = mean(residual.^2)+onto.outputRegularization*mean(phi.^2);
dphi = (2*residual+2*onto.outputRegularization*phi)/B;
grads = landing2d.rgat.potentialBackward(cache,dphi);
end
