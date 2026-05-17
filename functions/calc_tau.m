function res = calc_tau(t, V, t_step_on, fit_window, baseline_window, do_baseline)

% estimate_tau_mat_nocft
%   Curve Fitting Toolbox なしで τ を推定する指数フィット（単一指数）
%   モデル: V(t) = A + B * exp(-(t - t0)/tau)
%
% 入力:
%   t [s], V [mV]               : ベクトル（同じ長さ）
%   t_step_on [s]               : ステップ開始時刻
%   fit_window [s,s]            : 相対時間（開始から）例 [0.0005 0.030]
%   baseline_window [s,s]       : 相対時間（開始前）例 [-0.020 -0.002]
%   do_baseline (true/false)    : ベースライン補正
%
% 出力:
%   res.tau [s], res.A, res.B, res.t0
%   res.V0_est, res.Vinf_est
%   res.r2
%   res.t_fit, res.v_fit
%   res.model   : 予測関数ハンドル @(tt) A + B*exp(-(tt - t0)/tau)

    % ------ 入力整形 ------
    t = t(:); V = V(:);
    if nargin < 4 || isempty(fit_window),       fit_window = [0.0005 0.030]; end
    if nargin < 5 || isempty(baseline_window),  baseline_window = [-0.020 -0.002]; end
    if nargin < 6, do_baseline = true; end

    % ------ ベースライン補正 ------
    if do_baseline
        bl_mask = (t >= (t_step_on + baseline_window(1))) & (t <= (t_step_on + baseline_window(2)));
        if nnz(bl_mask) >= 5
            V = V - mean(V(bl_mask));
        end
    end

    % ------ フィット区間抽出 ------
    t1 = t_step_on + fit_window(0+1);
    t2 = t_step_on + fit_window(2);
    mask = (t >= t1) & (t <= t2);
    t_fit = t(mask);  v_fit = V(mask);
    if numel(t_fit) < 20
        error('フィット用データ点が不足しています。fit_window を見直してください。');
    end

    % ------ 初期値 ------
    % 直後と後期の中央値から A, B を推定
    early_mask = (t >= t_step_on) & (t <= t_step_on + 0.002);
    late_mask  = (t >= t2 - 0.003) & (t <= t2);
    if ~any(early_mask), early_mask = (t >= t1) & (t <= t1 + 0.002); end
    if ~any(late_mask),  late_mask  = (t >= t2 - 0.005) & (t <= t2);  end

    V0_guess   = median(V(early_mask));
    Vinf_guess = median(V(late_mask));
    A0 = Vinf_guess;
    B0 = V0_guess - Vinf_guess;
    tau0 = 0.010;                % 10 ms 初期値
    t00  = t_step_on;            % t0 は開始近傍に初期化

    % ------ パラメータ変換（無限領域→制約領域） ------
    % p = [A, B, log(tau), u4] where:
    %   tau = exp(p3) > 0
    %   t0  = t_step_on + dmax * tanh(p4),  |d| <= dmax
    dmax = 0.002;  % t0 を開始±2msに制約（過学習/不安定防止）
    inv_tanh_clip = @(x) atanh(max(min(x, 0.999999), -0.999999));
    p0 = [A0, B0, log(max(tau0, 1e-5)), inv_tanh_clip((t00 - t_step_on)/dmax)];

    % ------ 目的関数（SSE） ------
    function sse = objfun(p)
        A = p(1);
        B = p(2);
        tau = exp(p(3));                 % >0
        t0  = t_step_on + dmax * tanh(p(4));
        yhat = A + B.*exp(-(t_fit - t0)./tau);

        % 残差（二乗誤差）
        r = v_fit - yhat;
        sse = sum(r.^2);

        % 弱い正則化（極端な解の暴走防止）
        % 例：非常に大きな |B| や極小 tau への軽いペナルティ
        sse = sse + 1e-8*(A^2 + B^2) + 1e-12*(1/tau);
    end

    % ------ 最適化（fminsearch） ------
    opts = optimset('Display','off', 'MaxFunEvals', 5e4, 'MaxIter', 5e4, ...
                    'TolX', 1e-9, 'TolFun', 1e-12);
    p_opt = fminsearch(@objfun, p0, opts);

    % ------ パラメータ復元 ------
    A_hat  = p_opt(1);
    B_hat  = p_opt(2);
    tau_hat= exp(p_opt(3));
    t0_hat = t_step_on + dmax * tanh(p_opt(4));

    % ------ 適合度（R^2） ------
    yhat = A_hat + B_hat.*exp(-(t_fit - t0_hat)./tau_hat);
    ss_res = sum((v_fit - yhat).^2);
    ss_tot = sum((v_fit - mean(v_fit)).^2);
    r2 = 1 - ss_res / max(ss_tot, eps);

    % ------ 出力 ------
    res.tau     = tau_hat;
    res.A       = A_hat;
    res.B       = B_hat;
    res.t0      = t0_hat;
    res.V0_est  = A_hat + B_hat;   % 立ち上がり直後の推定値
    res.Vinf_est= A_hat;           % 定常値
    res.r2      = r2;
    res.t_fit   = t_fit;
    res.v_fit   = v_fit;
    % 可視化用（従来の feval(res.model, x) で呼べます）
    res.model   = @(tt) A_hat + B_hat.*exp(-(tt - t0_hat)./tau_hat);
end
