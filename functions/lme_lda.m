
function p_value = lme_lda(group1_proj,group2_proj,animal_group1,animal_group2)
    %% データを1つのテーブルにまとめる
    
    % 測定値
    Value = [group1_proj(:); group2_proj(:)];
    
    % グループ情報
    Group = [repmat({'Group1'}, numel(group1_proj), 1); ...
             repmat({'Group2'}, numel(group2_proj), 1)];
    
    % 動物ID
    AnimalID = [animal_group1(:); animal_group2(:)];
    
    % テーブル作成
    tbl = table(Value, Group, AnimalID);
    
    % カテゴリ変数化
    tbl.Group = categorical(tbl.Group);
    tbl.AnimalID = categorical(tbl.AnimalID);
    
    %% Linear Mixed Effects Model
    % 固定効果: Group
    % ランダム効果: AnimalID
    
    lme = fitlme(tbl, 'Value ~ Group + (1|AnimalID)');
    
    %% 結果表示
    disp(lme);
    
    %% Group効果のp値取得
    coefTable = lme.Coefficients;
    disp(coefTable);
    
    % Group2 vs Group1 のp値
    p_value = coefTable.pValue(2);
    
    fprintf('Group effect p-value = %.6g\n', p_value);
end