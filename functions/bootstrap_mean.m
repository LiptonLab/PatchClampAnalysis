function [p_value, obs_diff] = bootstrap_mean(group1, group2, nrepeats)
    % 実際の平均差
    obs_diff = mean(group1) - mean(group2);
    
    % ブートストラップの設定
    nBoot = nrepeats;
    boot_diff = zeros(nBoot,1);
    
    % ブートストラップ分布の生成
    for i = 1:nBoot
        resample1 = datasample(group1, length(group1));
        resample2 = datasample(group2, length(group2));
        boot_diff(i) = mean(resample1) - mean(resample2);
    end
    
    % 両側検定のP値計算
    p_value = mean(abs(boot_diff) >= abs(obs_diff));
    
    % 結果表示
    fprintf('観測された平均差: %.4f\n', obs_diff);
    fprintf('ブートストラップによるP値: %.4f\n', p_value);
end
