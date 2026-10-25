function LDAdata = process_LDA(data_num_import,data_category_import,mask_input,List_select,id_compare,factor_out,varargin)

    for ii = 1:nargin - 6
        if strcmp(varargin{ii},'data_animal_import')%new
            data_animal_import = varargin{ii+1};%new
        end
    end

    DataNum_packed = data_num_import(mask_input==1,:);
    ListGroup_packed = cell2mat(data_category_import(mask_input==1,id_compare));%
    ListGroupName = List_select{id_compare};

    if exist('data_animal_import','var')
        DataAnimal_packed = data_animal_import(mask_input==1);%new
    end
    
    %lda
    temp = DataNum_packed - mean(DataNum_packed,1);
    DataNum_packed = temp ./ std(temp,1);

    LDAdata.lda = fitcdiscr(DataNum_packed, ListGroup_packed);
    LDAdata.DataNum_packed = DataNum_packed;%Add input data as new field
    LDAdata.ListGroup_packed = ListGroup_packed;%Add input data as new field
    LDAdata.ListGroupName = ListGroupName;%Add input data as new field
    LDAdata.factor_out = factor_out;
    
    % Determination of the separating axis (discriminant vector)
    w = LDAdata.lda.Coeffs(1,2).Linear;  % the linear discriminant vector between Class 1 and Class 2
    % Projection of individual samples along the discriminant axis
    X_proj = (DataNum_packed - mean(DataNum_packed,1))* w;% Perform data centering before weighting.
    LDAdata.X_proj= X_proj;
    
    %-----------------------------------------------
    % Assessment of statistical significance of differences in the projected data distributions
    group1_proj = LDAdata.X_proj(LDAdata.ListGroup_packed == ListGroupName(1));
    [idxKept_LDAgroup1, idxOutgroup1, keptgroup1, outgroup1] = removeOutliers(group1_proj,'mad','MADk',factor_out);
    group1_proj = keptgroup1;
    group2_proj = LDAdata.X_proj(LDAdata.ListGroup_packed == ListGroupName(2));
    [idxKept_LDAgroup2, idxOutgroup2, keptgroup2, outgroup2] = removeOutliers(group2_proj,'mad','MADk',factor_out);
    group2_proj = keptgroup2;
    if exist('DataAnimal_packed','var')
        animal_group1 = DataAnimal_packed(idxKept_LDAgroup1);
        animal_group2 = DataAnimal_packed(idxKept_LDAgroup2);
    end
    
    % test normal distributoin
    lillieTEST.group1_proj = lillietest(group1_proj);
    lillieTEST.group2_proj = lillietest(group2_proj);
    
    % all stat tests
    [~, p_ttest_proj] = ttest2(group1_proj,group2_proj,'Tail','both');
    p_ranksum_proj = ranksum(group1_proj, group2_proj);
    p_bootstraptest_proj = bootstraptest2(group1_proj(~isnan(group1_proj)), group2_proj(~isnan(group2_proj)),10000);
    P.boot_proj = p_bootstraptest_proj;
    P.ttest_proj = p_ttest_proj;
    P.ranksum_proj = p_ranksum_proj;
    if exist('DataAnimal_packed','var')
        P.lme = lme_lda(group1_proj,group2_proj,animal_group1,animal_group2);
    end
    
    % Print results
    fprintf('P-value -Bootstraptest: %.4f\n', P.boot_proj);
    fprintf('P-value -ttest_both: %.4f\n', P.ttest_proj);
    fprintf('P-value -Wilcoxon: %.4f\n', P.ranksum_proj);
    fprintf('Lillie test for group1 and 2 are %s-%s [0=normal dist]\n', num2str(lillieTEST.group1_proj),  num2str(lillieTEST.group2_proj));
    if exist('DataAnimal_packed','var')
        fprintf('P-value -Bootstraptest: %.4f\n', P.lme);
    end
    
    sel_stat_proj = input('1:bootstrap only, 2:ttest+bootstrap, 3:ttest+ranksum, 4 Liniear Mixed Effect Model\n');
    switch sel_stat_proj
        case 1
            testname = 'boot';
            P_value_proj = p_bootstraptest_proj;
        case 2
            if lillieTEST.group1_proj + lillieTEST.group1_proj == 0
                testname = 'ttest2_both';
                P_value_proj = p_ttest_proj;
            else
                testname = 'ranksum';
                P_value_proj = p_bootstraptest_proj;
            end
        case 3
            if lillieTEST.group1_proj + lillieTEST.group1_proj == 0
                testname = 'ttest2_both';
                P_value_proj = p_ttest_proj;
            else
                testname = 'ranksum';
                P_value_proj = p_ranksum_proj;
            end
        case 4
            testname = 'LME';
            P_value_proj = P.lme;

    end
    P.testname = testname;
    P.sel_stat_proj = sel_stat_proj;
    P.P_value_proj = P_value_proj;
    LDAdata.P = P;

    % Derivation and normalization of the discriminant axis
    w = LDAdata.lda.Coeffs(1,2).Linear;
    w_unit = w / norm(w);
    LDAdata.w_unit = w_unit;

    % Calculation of angles with each parameter axis
    n_features = size(DataNum_packed, 2);
    angles_deg = zeros(n_features, 1);
    
    for i = 1:n_features
        param_vec = zeros(n_features, 1);
        param_vec(i) = 1;  % Unit vector (i-th parameter axis)
        cos_theta = dot(param_vec, LDAdata.w_unit);
        angles_deg(i) = acosd(cos_theta);  % angle(deg)
    end
    LDAdata.angles_deg = angles_deg;


end