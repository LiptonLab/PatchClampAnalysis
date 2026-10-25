function PlotDataAll = multi_stat(data_subset,sel_stat,factor_out,varargin)
    Label ={};% default
    anova_mode = 0;%default
    for ii = 1:nargin-3
        if strcmp(varargin{ii},'Label')
            Label = varargin{ii+1};
        end
        if strcmp(varargin{ii},'anova_mode')
            anova_mode = varargin{ii+1};
        end
        if strcmp(varargin{ii},'combi_para')
            combi_para = varargin{ii+1};
        end
        if strcmp(varargin{ii},'animal_subset')%new
            animal_subset = varargin{ii+1};%new
        end
    end
    nParameter = size(data_subset{1},2);
    for id_parameter = 1:nParameter
        for id_group = 1:numel(data_subset)
            plotdata = data_subset{id_group}(:,id_parameter);
            plotdata = plotdata(find(~isnan(plotdata)));
            if factor_out~=0
                [idxKept, idxOut, kept, out] = removeOutliers(plotdata,'mad','MADk',factor_out); %removeOutliersAnyN(v, 'mad', 'MADk', 3.5);
            else
                idxKept = 1:numel(plotdata);
                kept =  plotdata;
                idxOut = [];
                out = [];
            end
            PlotDataAll(id_parameter,id_group).note = '';
            PlotDataAll(id_parameter,id_group).idxKept = idxKept;
            PlotDataAll(id_parameter,id_group).idxOut = idxOut;
            PlotDataAll(id_parameter,id_group).kept = kept;
            PlotDataAll(id_parameter,id_group).out = out;
            PlotDataAll(id_parameter,id_group).N = numel(kept);
            PlotDataAll(id_parameter,id_group).raw = data_subset{id_group}(:,id_parameter);
            PlotDataAll(id_parameter,id_group).nonnan = plotdata(find(~isnan(plotdata)));
            if exist('animal_subset','var')
                temp = animal_subset{id_group};
                PlotDataAll(id_parameter,id_group).animal = temp(idxKept);
            end
            if exist('Label','var')
                PlotDataAll(id_parameter,id_group).Label = Label{id_parameter};
            end
        end
    end
    % calc P and Effect size
    nParameter = size(PlotDataAll,1);
    for id_parameter = 1:nParameter
        note = ['N=' num2str(PlotDataAll(id_parameter,1).N) '/' num2str(PlotDataAll(id_parameter,2).N)];
        if numel(data_subset)==2
            group1 = PlotDataAll(id_parameter,1).kept;
            group2 = PlotDataAll(id_parameter,2).kept;
            PlotDataAll(id_parameter,1).lillietest = lillietest(group1);
            PlotDataAll(id_parameter,2).lillietest = lillietest(group2);
            switch sel_stat
                case 1
                    testname = 'P(boot)';
                    p = bootstraptest2(group1,group2,10000);
                case 2
                    if PlotDataAll(id_parameter,1).lillietest + PlotDataAll(id_parameter,2).lillietest == 0
                        testname = 'P(ttest2_both)';
                        [h_stat, p, ci, stats] = ttest2(group1,group2,'Tail','both');
                    else
                        testname = 'P(boot)';
                        p = bootstraptest2(group1,group2,10000);
                    end
                case 3
                    if PlotDataAll(id_parameter,1).lillietest + PlotDataAll(id_parameter,2).lillietest == 0
                        testname = 'P(ttest2_both)';
                        [h_stat, p, ci, stats] = ttest2(group1,group2,'Tail','both');
                    else
                        testname = 'P(ranksum)';
                        bootstraptest2(group1,group2,10000);
                        p = ranksum(group1, group2);
                    end
                case 4
                    testname = 'LME';
                    animal_group1 = PlotDataAll(id_parameter,1).animal;
                    animal_group2 = PlotDataAll(id_parameter,2).animal;
                    p = lme_lda(group1,group2,animal_group1,animal_group2);
            end

    
            esize = effectsize_independent(group2, group1);
            % store data
            PlotDataAll(id_parameter,1).testname = testname;
            PlotDataAll(id_parameter,2).testname = testname;
            PlotDataAll(id_parameter,1).p = p;
            PlotDataAll(id_parameter,2).p = p;
            PlotDataAll(id_parameter,1).esize = esize;
            PlotDataAll(id_parameter,2).esize = esize;
            PlotDataAll(id_parameter,1).note = [note, '_' PlotDataAll(id_parameter,1).testname, '=', num2str(PlotDataAll(id_parameter,1).p),'Esize=', num2str(PlotDataAll(id_parameter,1).esize.g)];
            PlotDataAll(id_parameter,2).note = PlotDataAll(id_parameter,1).note;
        end

        switch anova_mode
            case 0

            case 1
                data_stack = [];
                group_stack = [];
                for id_group = 1:numel(data_subset)
                    data_stack = [data_stack; reshape(data_subset{id_group}(:,id_parameter),[],1)];
                    group_stack = [group_stack; repmat(id_group,numel(data_subset{id_group}(:,id_parameter)),1)];
                end
                [p, tbl, stats] = anova1(data_stack, group_stack,'off');
                result = multcompare(stats,'ctype', 'tukey-kramer');
                PlotDataAll(id_parameter,1).ANOVA1.p = p;
                PlotDataAll(id_parameter,1).ANOVA1.stats = stats;
                PlotDataAll(id_parameter,1).ANOVA1.tbl = tbl;
                PlotDataAll(id_parameter,1).Tukey = result(result(:,6) < 0.05, :);

            case 2
                data_stack = [];
                for id_group = 1:numel(data_subset)
                    data_stack = [data_stack; reshape(data_subset{id_group}(:,id_parameter),[],1)];
                end

                group_stack = [];
                for factorNumber=1:2
                    factor{factorNumber} = [];
                    for id_group = 1:numel(data_subset)
                        if (id_group == factorNumber)||(id_group == combi_para)
                            factor{factorNumber} = [factor{factorNumber}; repmat(factorNumber,numel(data_subset{id_group}(:,id_parameter)),1)];
                        else
                            factor{factorNumber} = [factor{factorNumber}; repmat(0,numel(data_subset{id_group}(:,id_parameter)),1)];
                        end
                    end
                    GroupANOVA2{factorNumber} = categorical(factor{factorNumber});
                end
                group_stack = GroupANOVA2;

                [p, tbl, stats] = anovan(data_stack, group_stack, ...
                    'model', 'interaction','varnames', {'Treatment', 'Genotype'},'display', 'off');
                result = multcompare(stats,'Dimension', [1 2],'ctype', 'tukey-kramer','display','off');
                PlotDataAll(id_parameter,1).ANOVA2.p = p;
                PlotDataAll(id_parameter,1).ANOVA2.stats = stats;
                PlotDataAll(id_parameter,1).ANOVA2.tbl = tbl;
                PlotDataAll(id_parameter,1).Tukey = result(result(:,6) < 0.05, :);
        end

    end
end