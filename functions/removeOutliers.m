
function [idxKept, idxOut, kept, out, RangeIn, Upper, Lower] = removeOutliers(v, method, varargin)
% removeOutliersAnyN - 3要素以上の1次元データの外れ値除去
%
% 使用例:
%   [kept, out, ik, io] = removeOutliersAnyN(v);                 % 既定: n>=4はMAD, n==3は最も近い2点を保持
%   [kept, out] = removeOutliersAnyN(v, 'mad', 'MADk', 3.5);
%   [kept, out] = removeOutliersAnyN(v, 'iqr', 'IQRk', 1.5);
%   [kept, out] = removeOutliersAnyN(v, 'z',   'ZThr', 3);
%   [kept, out] = removeOutliersAnyN(v, 'auto', 'MinKeep', 2);   % 3点時の最低保持数
%
% 入力:
%   v       : ベクトル（NaN可。NaNは自動無視）
%   method  : 'auto'(default), 'mad', 'iqr', 'z'
%
% Name-Value パラメータ:
%   'MADk'    : MAD法のしきい値倍率 (default: 3)
%   'IQRk'    : IQR法のしきい値倍率 (default: 1.5)
%   'ZThr'    : Zスコアの絶対値しきい値 (default: 3)
%   'MinKeep' : 最低保持数 (default: 3 for n>=4, default: 2 for n==3)
%
% 出力:
%   kept    : 外れ値を除いたデータ（元の順序を保持）
%   out     : 外れ値データ（元の順序を保持）
%   idxKept : 入力 v に対する保持インデックス
%   idxOut  : 入力 v に対する外れ値インデックス
    Upper=[];
    Lower=[];

    %if nargin < 2 || isempty(method), method = 'auto'; end
    if nargin < 2 || isempty(method), method = 'mad'; end% default

    v = v(:);
    n = numel(v);
    if n < 3
        error('入力ベクトルは少なくとも3要素が必要です。');
    end

    % 引数処理
    p = inputParser;
    p.addParameter('MADk',   3,   @(x)isscalar(x)&&x>0);
    p.addParameter('IQRk',   1.5, @(x)isscalar(x)&&x>0);
    p.addParameter('ZThr',   3,   @(x)isscalar(x)&&x>0);
    % MinKeepの既定値は n==3 のとき2、それ以外は3
    defaultMinKeep = (n==3) * 2 + (n~=3) * 3;
    p.addParameter('MinKeep', defaultMinKeep, @(x)isscalar(x)&&x>=1&&x<=n);
    p.parse(varargin{:});
    MADk    = p.Results.MADk;
    IQRk    = p.Results.IQRk;
    ZThr    = p.Results.ZThr;
    MinKeep = p.Results.MinKeep;

    % NaN除去（インデックス管理）
    nanMask   = isnan(v);
    idxNoNaN  = find(~nanMask);
    vNoNaN    = v(idxNoNaN);
    if isempty(vNoNaN)
        kept = []; out = []; idxKept = []; idxOut = (1:n).';
        return;
    end

    mth = lower(string(method));
    inlierMaskLocal = true(size(vNoNaN)); % デフォルトは全保持
    %RangeIn = [min(vNoNaN), max(vNoNaN)];%エラー防止

    if n == 3
        % --- 3点ケースの特別扱い ---
        switch mth
            case "auto"
                if 1==2%使わない
                % 3通りのペア距離を計算して、最も近い2点を保持
                d12 = abs(vNoNaN(1) - vNoNaN(2));
                d13 = abs(vNoNaN(1) - vNoNaN(3));
                d23 = abs(vNoNaN(2) - vNoNaN(3));
                [~, whichPair] = min([d12, d13, d23]);
                inlierMaskLocal = false(3,1);
                switch whichPair
                    case 1, inlierMaskLocal([1,2]) = true;
                    case 2, inlierMaskLocal([1,3]) = true;
                    case 3, inlierMaskLocal([2,3]) = true;
                end
                % MinKeepが3なら（=外れ値なし想定）全保持に切替
                if MinKeep >= 3
                    inlierMaskLocal(:) = true;
                end
                end
                
            case {"mad","iqr","z"}
                [inlierMaskLocal, RangeIn] = localStatInlierMask(vNoNaN, mth, MADk, IQRk, ZThr);
                % 削りすぎ防止（中央値に近い順でMinKeep個残す）
                if sum(inlierMaskLocal) < MinKeep
                    med = median(vNoNaN);
                    [~, order] = sort(abs(vNoNaN - med), 'ascend');
                    inlierMaskLocal(:) = false;
                    inlierMaskLocal(order(1:MinKeep)) = true;
                end

            otherwise
                error('未知のmethodです: %s  （auto|mad|iqr|z が利用可能）', method);
        end

    else
        % --- n >= 4 の通常処理 ---
        if mth == "auto"
            mth = "mad"; % 既定はMAD
        elseif ~ismember(mth, ["mad","iqr","z"])
            error('未知のmethodです: %s  （auto|mad|iqr|z が利用可能）', method);
        end

        [inlierMaskLocal, RangeIn] = localStatInlierMask(vNoNaN, mth, MADk, IQRk, ZThr);

        % 最低保持数を満たすように緩和（中央値に近い順にMinKeep個）
        if sum(inlierMaskLocal) < MinKeep
            med = median(vNoNaN);
            [~, order] = sort(abs(vNoNaN - med), 'ascend');
            inlierMaskLocal(:) = false;
            inlierMaskLocal(order(1:min(MinKeep, numel(order)))) = true;
        end
    end

    % 元インデックスに戻す
    idxKeptNoNaN = find(inlierMaskLocal);
    idxOutNoNaN  = find(~inlierMaskLocal);

    idxKept = idxNoNaN(idxKeptNoNaN);
    idxOut  = idxNoNaN(idxOutNoNaN);

    % 出力は元の順序のまま
    maskFull = false(n,1);
    maskFull(idxKept) = true;
    kept = v(maskFull);
    out  = v(~maskFull);

    Upper.idxOut = find(v>max(RangeIn));
    Upper.idxKept = find(v<=max(RangeIn));
    Lower.idxOut = find(v<min(RangeIn));
    Lower.idxKept = find(v>=min(RangeIn));            

end

% 補助：統計ベース inlier マスク
function [inlierMask, RangeIn] = localStatInlierMask(x, method, MADk, IQRk, ZThr)
    RangeIn = [];
    switch method
        case "mad"
            med = median(x);
            absDev = abs(x - med);
            MAD = median(absDev);
            if MAD == 0
                inlierMask = true(size(x));
            else
                robustSigma = 1.4826 * MAD;       % 正規分布一貫性補正
                inlierMask = abs(x - med) <= MADk * robustSigma;
                RangeIn = [med - MADk * robustSigma, med + MADk * robustSigma];
            end

        case "iqr"
            Q1 = quantile(x, 0.25);
            Q3 = quantile(x, 0.75);
            IQRv = Q3 - Q1;
            if IQRv == 0
                inlierMask = true(size(x));
            else
                lo = Q1 - IQRk * IQRv;
                hi = Q3 + IQRk * IQRv;
                inlierMask = (x >= lo) & (x <= hi);
                RangeIn = [lo, hi];
            end

        case "z"
            mu = mean(x);
            sd = std(x, 0);
            if sd == 0
                inlierMask = true(size(x));
            else
                z = (x - mu) ./ sd;
                inlierMask = abs(z) <= ZThr;
                RangeIn = [-abs(ZThr)*sd + mu, abs(ZThr)*sd +mu];
            end

        otherwise
            error('内部エラー: 未知のmethod "%s"', method);
    end
end
