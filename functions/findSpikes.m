
function [spikeTimes, spikeTimes_peak] = findSpikes(v, dt)
    % スパイク検出：膜電位がしきい値を超えたとき
    threshold = -20; % mV（例：-20mVを超えたらスパイクとみなす）
    refractoryPeriod = 0.005; % 5msの不応期
    minInterval = round(refractoryPeriod / dt);

    spikeIdx = find(v > threshold);
    if isempty(spikeIdx)
        spikeTimes = [];
        spikeTimes_peak = [];
        return;
    end

    % 不応期を考慮してスパイクを間引く
    spikeTimes = [];
    spikeTimes_peak = [];
    lastSpike = -Inf;
    for i = 1:length(spikeIdx)
        if spikeIdx(i) - lastSpike > minInterval
            spikeTimes(end+1) = spikeIdx(i) * dt;
            lastSpike = spikeIdx(i);

            TW = spikeIdx(i): min(numel(v),spikeIdx(i) +round(0.002/dt));%2msでピーク検出
            spikeTimes_peak(end+1) = (spikeIdx(i) + find(v(TW) == max(v(TW)),1,'first')) * dt;
        end
    end
end


%function spikeTimes = findSpikes(v, dt)
%    dv = diff(v);
%    threshold = 10; % mV/ms
%    spikeIdx = find(dv > threshold);
%    spikeTimes = spikeIdx * dt;
%end
