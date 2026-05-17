
function Rin = computeInputResistance(v, I)
    baselineV = mean(v(1:100));
    steadyV = mean(v(end-100:end));
    deltaV = steadyV - baselineV;
    deltaI = mean(I);
    Rin = deltaV / deltaI; % Ohm
end
