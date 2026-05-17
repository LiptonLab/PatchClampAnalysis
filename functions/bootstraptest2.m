function P_value = bootstraptest2(SAMPLE1, SAMPLE2, nRepeat)
% SAMPLE1, SAMPLE2 は [max_n x nDataset] 行列。短い列は NaN でパディング。
    if nargin < 3, nRepeat = 10000; end
    [~, nDataset] = size(SAMPLE1);
    if size(SAMPLE2,2) ~= nDataset
        error('列数が一致していません。');
    end

    P_value = nan(1, nDataset);
    for ii = 1:nDataset
        x = SAMPLE1(:,ii); x = x(~isnan(x));
        y = SAMPLE2(:,ii); y = y(~isnan(y));
        if numel(x) < 2 || numel(y) < 2
            P_value(ii) = NaN; continue;
        end
        % 以降は permtest_mean2_cell と同じ
        d_obs = mean(x) - mean(y);
        z = [x; y];
        n1 = numel(x); n2 = numel(y);
        d_null = zeros(nRepeat,1);
        for b = 1:nRepeat
            idx = randperm(n1+n2);
            xb = z(idx(1:n1));
            yb = z(idx(n1+1:end));
            d_null(b) = mean(xb) - mean(yb);
        end
        P_value(ii) = (sum(abs(d_null) >= abs(d_obs)) + 1) / (nRepeat + 1);
    end
end
