function X = attributionSample(X,onto)
% ATTRIBUTIONSAMPLE  반사실 분석에 쓸 표본을 설정한 개수만큼 균등하게 추립니다.
if size(X,3) > onto.maxAttributionSamples
    index = round(linspace(1,size(X,3),onto.maxAttributionSamples));
    X = X(:,:,index);
end
end
