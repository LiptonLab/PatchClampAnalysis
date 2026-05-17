
function [isOut, D2, thr, model] = robustMahalanobisOutliers(X, varargin)
% Robust Mahalanobis (MCD) による外れ値検出（フラグ付け）
%
% 使い方（例）:
% [isOut, D2, thr, model] = robustMahalanobisOutliers( ...
%     X_valid_data_temp, 'Alpha', alpha, 'Scale','robust', ...
%     'Impute','drop','UsePCA', false, 'RandomState', 0);
%
% Inputs
%   X               : (n x p) 数値行列 or table（数値列のみ対象）
%   'Alpha'         : 有意水準 α（default = 0.01）
%   'Scale'         : 'zscore' | 'robust' | 'none'（default = 'zscore'）
%                     - 'zscore' : 平均・標準偏差で標準化
%                     - 'robust' : 中央・1.4826*MAD でロバスト標準化
%                     - 'none'   : スケーリングなし
%   'Impute'        : 'drop' | 'median'（default = 'drop'）
%                     - 'drop'   : 欠損を含む行を削除
%                     - 'median' : 列中央値で代入
%   'UsePCA'        : true/false（default = false）※明示指定を推奨
%   'PCAVariance'   : PCA の累積寄与率（default = 0.95）※UsePCA=true の場合のみ使用
%   'RandomState'   : 乱数シード（default = []：変更なし）
%
% Outputs
%   isOut   : (n_kept x 1) logical。true(=1) が外れ値（X(keptIndex, :) に対応）
%   D2      : (n_kept x 1) ロバスト・マハラノビス距離の二乗
%   thr     : スカラー。χ²_{df, 1-α} の閾値
%   model   : 構造体（詳細は下記フィールドを参照）
%
% model フィールド（主なもの）
%   .mode                 : 'MCD' または 'PCA+MCD'
%   .df                   : 自由度（UsePCA=false → p, UsePCA=true → 使用PC次元）
%   .alpha                : 使用した α
%   .keptIndex            : 欠損処理後に残った元 X の行番号ベクトル
%   .scaler               : スケーリング情報（mode, mu, sigma）
%   .colNames             : 入力が table のときの数値列名
%   .robustLocation       : ロバスト中心（UsePCA=false のとき）
%   .robustCov            : ロバスト共分散（UsePCA=false のとき）
%   .robustLocation_Z     : PCA 空間でのロバスト中心（UsePCA=true のとき）
%   .robustCov_Z          : PCA 空間でのロバスト共分散（UsePCA=true のとき）
%   .pca                  : PCA 情報（UsePCA=true のとき: coeff, mu, r, explained, latent）
%
% 依存：Statistics and Machine Learning Toolbox（robustcov, pca, chi2inv）

% ---- パラメータ ----
ip = inputParser;
ip.addParameter('Alpha', 0.01, @(x)isnumeric(x) && isscalar(x) && x>0 && x<1);
ip.addParameter('Scale', 'zscore', @(s)ischar(s) || isstring(s));
ip.addParameter('Impute', 'drop', @(s)ischar(s) || isstring(s));
ip.addParameter('UsePCA', false, @(x)islogical(x) && isscalar(x));
ip.addParameter('PCAVariance', 0.95, @(x)isnumeric(x) && isscalar(x) && x>0 && x<=1);
ip.addParameter('RandomState', [], @(x)isempty(x) || (isscalar(x) && isnumeric(x)));
ip.parse(varargin{:});

alpha     = ip.Results.Alpha;
scaleMode = char(ip.Results.Scale);
impute    = char(ip.Results.Impute);
usePCA    = ip.Results.UsePCA;
pcaVar    = ip.Results.PCAVariance;
randState = ip.Results.RandomState;

% ---- 入力を数値行列に整形 ----
if istable(X)
    numVars = varfun(@isnumeric, X, 'OutputFormat','uniform');
    if ~any(numVars)
        error('入力 table に数値列がありません。');
    end
    Xmat = X{:, numVars};
    colNames = X.Properties.VariableNames(numVars);
else
    Xmat = X;
    colNames = [];
end

if ~isfloat(Xmat)
    Xmat = double(Xmat);
end

[n, p] = size(Xmat);
if n < 2 || p < 1
    error('入力 X のサイズが不正です。size(X) = [%d %d]', n, p);
end

originalIndex = (1:n)';

% ---- 欠損処理 ----
switch lower(impute)
    case 'drop'
        rowsOK = all(~isnan(Xmat), 2);
        Xproc = Xmat(rowsOK, :);
        keptIndex = originalIndex(rowsOK);
    case 'median'
        Xproc = Xmat;
        for j = 1:p
            mj = median(Xproc(:,j), 'omitnan');
            if isnan(mj)
                error('列 %d が全て NaN のため中央値での代入ができません。', j);
            end
            nanIdx = isnan(Xproc(:,j));
            Xproc(nanIdx, j) = mj;
        end
        keptIndex = originalIndex;
    otherwise
        error('Impute は ''drop'' か ''median'' を指定してください。');
end

if isempty(Xproc)
    error('欠損処理後に行が残りませんでした。');
end

[nk, pk] = size(Xproc);

% ---- スケーリング ----
scaler = struct('mode', scaleMode, 'mu', [], 'sigma', []);
Xscaled = Xproc;

switch lower(scaleMode)
    case 'zscore'
        mu = mean(Xproc, 1);
        sigma = std(Xproc, 0, 1);
        sigma(sigma==0) = 1; % 定数列の保護
        scaler.mu = mu;
        scaler.sigma = sigma;
        Xscaled = (Xproc - scaler.mu) ./ scaler.sigma;

    case 'robust'
        med = median(Xproc, 1);
        madv = median(abs(Xproc - med), 1);
        sigma = 1.4826 * madv;   % 正規整合スケール
        sigma(sigma==0) = 1;     % 定数列の保護
        scaler.mu = med;
        scaler.sigma = sigma;
        Xscaled = (Xproc - scaler.mu) ./ scaler.sigma;

    case 'none'
        % 何もしない
    otherwise
        error('Scale は ''zscore'' / ''robust'' / ''none'' のいずれかを指定してください。');
end

% ---- 乱数シード ----
if ~isempty(randState)
    rng(randState);
end

% ---- 本体：MCD（必要に応じてPCA空間）----
if usePCA
    % PCA 空間で MCD を実施（累積寄与率 pcaVar を満たす次元 r）
    % Centered=true で平均中心化（zscore/robust 済みだが PCA 計算上は中心化を再実施）
    [coeff, score, latent, ~, explained, muPCA] = pca(Xscaled, 'Centered', true);
    cumExp = cumsum(explained) / 100;
    r = find(cumExp >= pcaVar, 1, 'first');
    if isempty(r), r = min(nk-1, pk); end
    r = min([r, nk-1, pk]);   % ランク制約（安全側）

    if r < 1
        error('PCA 後の有効次元 r が 0 です。データの分散が極端に小さい可能性があります。');
    end

    Z = score(:, 1:r);
    [Srob, mrob] = robustcov(Z, 'Method','fmcd');   % Fast-MCD

    % Mahalanobis 距離^2（Z 空間）
    Zc = bsxfun(@minus, Z, mrob);
    invS = pinv(Srob);   % 数値安定のため pinv を使用
    D2 = sum((Zc * invS) .* Zc, 2);

    df = r;
    thr = chi2inv(1 - alpha, df);
    isOut = D2 > thr;

    % 返却情報
    model = struct();
    model.mode = 'PCA+MCD';
    model.df = df;
    model.alpha = alpha;
    model.keptIndex = keptIndex;
    model.scaler = scaler;
    model.colNames = colNames;
    model.robustLocation_Z = mrob;
    model.robustCov_Z = Srob;
    model.invCov_Z = invS;
    model.pca = struct('coeff', coeff, 'mu', muPCA, 'latent', latent, ...
                       'explained', explained, 'r', r);

else
    % そのままの特徴空間で MCD
    [Srob, mrob] = robustcov(Xscaled, 'Method','fmcd');   % Fast-MCD

    Xc = bsxfun(@minus, Xscaled, mrob);
    invS = pinv(Srob);
    D2 = sum((Xc * invS) .* Xc, 2);

    df = pk;
    thr = chi2inv(1 - alpha, df);
    isOut = D2 > thr;

    % 返却情報
    model = struct();
    model.mode = 'MCD';
    model.df = df;
    model.alpha = alpha;
    model.keptIndex = keptIndex;
    model.scaler = scaler;
    model.colNames = colNames;
    model.robustLocation = mrob;
    model.robustCov = Srob;
    model.invCov = invS;
end

% 出力は列ベクトル・logical に統一
isOut = logical(isOut(:));
D2    = D2(:);

end
