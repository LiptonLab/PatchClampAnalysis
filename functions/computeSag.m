
function sag = computeSag(v, I, dt)
    if mean(I) < 0
        restV = v(1);
        minV = min(v);
        range_idx =  0.01 / dt;% last 10msec average for Vend
        steadyV = mean(v(end-range_idx:end));
        sag = (steadyV - minV) / (restV - minV);
    else
        sag = NaN;
    end
end
