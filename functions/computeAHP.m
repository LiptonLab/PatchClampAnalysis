
function AHP = computeAHP(v, spikeTime, dt)
    idx = round(spikeTime / dt);
    TW_sec = [0.001 0.01];%1ms to 10ms
    %postSpike = v(idx+10:idx+100);
    postSpike = v((idx+TW_sec(1)/dt):(idx+TW_sec(2)/dt));
    AHP = min(postSpike);
end
