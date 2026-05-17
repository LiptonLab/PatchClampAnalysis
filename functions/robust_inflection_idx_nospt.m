
function idx = robust_inflection_idx_nospt(v, dt, varargin)
% robust_inflection_idx_nospt (CUSUM版)
%   先頭の固定直線ベースラインに対する残差を標準化し、
%   一方向CUSUMで「最初の積み上がり開始点」にバックトラックして返す。
%
% 入力:
%   v   : 波形ベクトル（行・列どちらでも可）
%   dt  : サンプリング間隔 [s]
%
% Name-Value（互換）
%   'PreSmoothWin' : 事前移動平均の窓長（奇数, default 11, 1で無効）
%   'Polarity'     : 'positive'（立ち上がり）, 'negative', 'abs'
%   'SearchIdx'    : [i1 i2]（v の添字；未指定=全区間）
%   'MinProm'      : CUSUM閾値 h（標準化残差の単位, default 5）
%   'MinDist'      : 最短検出区間の連続サンプル数（default 5）
%   'Plot'         : 図の表示（true/false, default false）
%
% 出力:
%   idx : v の添字（1-based）

% ------------ 引数処理 ------------
p = inputParser;
addParameter(p, 'PreSmoothWin', 11);
addParameter(p, 'Polarity', 'positive');
addParameter(p, 'SearchIdx', []);
addParameter(p, 'MinProm', []);        % ← CUSUMの閾値 h として使用
addParameter(p, 'MinDist', 5);
addParameter(p, 'Plot', false);
parse(p, varargin{:});
opt = p.Results;

v = v(:);
N = numel(v);
if N < 5
    error('v が短すぎます（N >= 5必要）。');
end

% ------------ 事前スムージング（端一定パディング） ------------
vv = v;
w = max(1, round(opt.PreSmoothWin));
if mod(w,2)==0, w = w+1; end
if w > 1
    k = ones(w,1)/w;
    pad = (w-1)/2;
    vv_pad = [repmat(v(1),pad,1); v; repmat(v(end),pad,1)];
    vv = conv(vv_pad, k, 'same'); vv = vv(pad+1:pad+N);
end

% ------------ 探索区間（v 添字） ------------
if isempty(opt.SearchIdx)
    i1 = 1; i2 = N;
else
    i1 = max(1, min(N, opt.SearchIdx(1)));
    i2 = max(1, min(N, opt.SearchIdx(2)));
    if i1 > i2, t=i1; i1=i2; i2=t; end
end
y  = vv(i1:i2);
L  = numel(y);
tt = ((i1:i2)' - 1) * dt;
t_full = (1:N)' * dt;  % 図用

if L < 8
    % フォールバック：最大一次差分点
    [~, iloc] = max(diff(y));
    idx = i1 + iloc;
    if opt.Plot
        figure('Name','Inflection (fallback: max diff)');
        subplot(2,1,1); plot(t_full, v, 'LineWidth',1.6); hold on;
        plot(t_full(idx), v(idx), 'b*'); grid on; title('v(t) & detected');
        subplot(2,1,2); plot(t_full(1:end-1), diff(v)/dt); grid on; title('dv/dt');
    end
    return;
end

% ------------ 固定直線（先頭 B 点で一度だけフィット） ------------
% Bは「短すぎず・長すぎず」(20% or >=10点) とし、検出余地を確保
W  = max(1, round(opt.MinDist));    % 連続必要サンプル
B0 = max(10, round(0.2*L));
B  = min(max(B0, 5+W), L - (2+W));
if B < 5, B = min(L-3, 5); end

[m0, b0] = linfit(tt(1:B), y(1:B));

% ------------ 残差 → 極性反映 → 標準化（robust） ------------
r = y - (m0*tt + b0);
switch lower(opt.Polarity)
    case 'positive', s = r;
    case 'negative', s = -r;
    case 'abs',      s = abs(r);
    otherwise, error('Polarity must be positive|negative|abs');
end

% 初期B点からロバスト位置・スケールを推定
s0    = s(1:B);
med0  = median(s0);
mad0  = median(abs(s0 - med0));    % MAD
sigma = 1.4826 * max(mad0, eps);   % robust σ
z     = (s - med0) / sigma;        % 標準化残差（前半はだいたい ~0）

% ------------ CUSUM（片側）で逸脱検出 → バックトラック ------------
% S_k = max(0, S_{k-1} + z_k - kappa)
% kappa: ドリフト許容（0.25〜0.5 推奨）。固定値でOK。
kappa = 0.35;                       % 早めに反応しつつノイズは抑制
h     = ~isempty(opt.MinProm) * opt.MinProm + isempty(opt.MinProm) * 5;  % 閾値 h

S = 0;
last_reset = B;                     % Sが0になった最新位置（区間内添字）
idxSeg = []; found = false;

for k = (B+1):L
    S = max(0, S + z(k) - kappa);
    if S == 0
        last_reset = k;
    elseif S >= h
        % 直近のリセット点（= 積み上がり開始）へバックトラック
        if (k - last_reset) >= W
            idxSeg = last_reset + 1;   % 区間内添字
            found  = true;
            break;
        end
        % 連続長が足りなければ継続して観測
    end
end

if ~found
    % フォールバック：Sの最大時点の直近リセット+1 を返す
    S=0; last_reset=B; bestS=-Inf; best_k=B+1; best_last_reset=last_reset;
    for k = (B+1):L
        S = max(0, S + z(k) - kappa);
        if S==0, last_reset=k; end
        if S > bestS
            bestS = S; best_k = k; best_last_reset = last_reset;
        end
    end
    if (best_k - best_last_reset) >= 1
        idxSeg = best_last_reset + 1;
    else
        idxSeg = B + 1;
    end
end

idx = i1 + idxSeg - 1;   % v の添字に変換

% ------------ 図の描画（オプション） ------------
if opt.Plot
    figure('Name','Inflection detection (CUSUM)');
    tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

    % 上段：波形と基準直線・検出点・B境界
    nexttile;
    plot(t_full, v, 'Color',[0.95 0.6 0.1], 'LineWidth',1.8); hold on;
    plot(tt, (m0*tt + b0), 'k--', 'LineWidth',1.1);
    plot(t_full(idx), v(idx), 'b*', 'MarkerSize',7);
    xline(tt(B), ':', 'Color',[0.2 0.2 0.2], 'LineWidth',1.0);
    title('Waveform and baseline'); grid on; box on;
    xlabel('sec'); ylabel('amplitude');
    legend({'v(t)','baseline (first B pts)','detected','B boundary'}, ...
           'Location','best'); legend boxoff;

    % 中段：標準化残差 z（polarity 反映済み）
    nexttile;
    plot(tt, z, 'Color',[0.1 0.45 0.9], 'LineWidth',1.4); hold on;
    yline(kappa, '--', 'Color',[0.4 0.4 0.4]); 
    xline(tt(B), ':', 'Color',[0.2 0.2 0.2]);
    title(sprintf('Standardized residual z (kappa=%.2f)', kappa));
    grid on; box on; xlabel('sec'); ylabel('z');

    % 下段：CUSUM S と閾値 h、検出区間ハイライト
    nexttile;
    % 再計算して時系列描画
    Sseries = zeros(L,1); S=0;
    for k = (B+1):L
        S = max(0, S + z(k) - kappa);
        Sseries(k) = S;
    end
    plot(tt, Sseries, 'm', 'LineWidth',1.4); hold on;
    yline(h, 'r--', 'LineWidth',1.2);
    if ~isempty(idxSeg)
        s = idxSeg; e = min(L, s + max(1,W) - 1);
        patch([tt(s) tt(e) tt(e) tt(s)], ...
              [0 0 max(Sseries)*1.02 max(Sseries)*1.02], ...
              [1 0.8 0.8], 'EdgeColor','none','FaceAlpha',0.35);
    end
    xline(tt(B), ':', 'Color',[0.2 0.2 0.2]);
    title(sprintf('CUSUM S (h=%.2f), highlight: first run >= W', h));
    grid on; box on; xlabel('sec'); ylabel('S');
end

end

% ---- ヘルパ：最小二乗直線 ----
function [m, b] = linfit(x, y)
n = numel(x);
sx = sum(x); sy = sum(y);
sxx = sum(x.^2); sxy = sum(x.*y);
den = n*sxx - sx*sx;
if abs(den) < eps
    m = 0; b = sy/n;
else
    m = (n*sxy - sx*sy) / den;
    b = (sy - m*sx) / n;
end
end
