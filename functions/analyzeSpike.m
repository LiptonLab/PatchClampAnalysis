
function [amp, width, threshold, threshold_time, slope10_90_mVmS, InfoAmpStep] = analyzeSpike(v, spikeTime, dt, varargin)

    
    for ii = 1:nargin-3
        if strcmp(varargin{ii},'plot_inflection_01')
            plot_inflection_01 = varargin{ii+1};
        end
    end

    %threshold 測定
    % 時間窓の設定
    window_start = spikeTime - 0.003;  % sec
    window_end = spikeTime;        % sec

    % インデックス取得
    idx_start = max(1,round(window_start / dt));
    idx_end = round(window_end / dt);
    v_range = v(idx_start:idx_end);

    % 微分計算
    %dvdt = diff(v_range) / dt;
    %d2vdt2 = diff(dvdt) / dt;
    %[~, peak_idx] = max(d2vdt2);
    %peak_idx_single = min(peak_idx);


    peak_idx_single = robust_inflection_idx_nospt(v_range, 2.0e-5, ...
    'Polarity','positive', ...
    'PreSmoothWin',7, ...   % 5〜9推奨
    'MinProm',4.0, ...      % ← h（閾値）。3.5〜4.5が入口
    'MinDist',3, ...        % 2〜4に下げるとさらに早め
    'SearchIdx',[], ...
    'Plot',plot_inflection_01);

    % Spike Thresholdの膜電位
    threshold = v_range(peak_idx_single);
    threshold_time = (idx_start + peak_idx_single - 1)*dt;

    % amp width 測定
    %idx = round(spikeTime / dt);
    baseline = threshold;
    TW_idx = round(threshold_time/dt):round(spikeTime/dt)+round(0.003/dt);
    peak = max(v(TW_idx));
    amp = peak - baseline;
    halfAmp = baseline + amp/2;
    aboveHalf = find(v(TW_idx) > halfAmp);
    width = length(aboveHalf) * dt;

    ampStep = 0.1:0.1:1;
    for ii = 1:numel(ampStep)
        ampIm = baseline + amp*ampStep(ii);
        diff = v_range - ampIm;
        idx_step = min(find(min(abs(diff))==abs(diff)));
        ampStepTime(ii) = (idx_start + idx_step)*dt;
    end

    % slope測定
    slope10_90_mVmS = amp*0.8/(ampStepTime(9) - ampStepTime(1))/1000;

    InfoAmpStep.ampStep = ampStep;
    InfoAmpStep.time = ampStep;

end
