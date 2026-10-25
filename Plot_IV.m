% Input: Clipborad copied from Excel sheet
% Output: stat tests, plots
% process: filter data by category cell (data_category_import, numeric and characters)
%---------------------------------------------------------------------------------
clear; close all;
fn_m_full =mfilename('fullpath');
pn_f = [fileparts(fn_m_full), '\functions'];
addpath(pn_f);
%---------------------------------------------------------------------------------
% load default folder
[pn_m, fn_m] = fileparts(fn_m_full);
if exist([pn_m '\datapath.mat'],'file')
    load([pn_m '\datapath.mat']);
end
if ~exist('pn_def','var')
    pn_def = '';
end
%---------------------------------------------------------------------------------

% Input
%---------------------------------------------------------------------------------
% Instructions before run
fprintf('Open Excel file made with main_IV.m\n');
fprintf('Make a flag_include column [0 or 1], type "flag_include" on top row\n');
fprintf('Make a group# column [ex, 1:control, 2:PM2.5, 3:PM2.5+L-NAME], type "group" on top row\n');
fprintf('Make a gender column [M, F], type "gender" on top row\n');
fprintf('Make a batch# column [ex, 1, 2, 3], type "batch" on top row\n');
void = input('Type Enter when ready\n');
%---------------------------------------------------------------------------------
% Import Data from Excel file and format it into Matrix
fprintf('Copy an entire Excel page, including labels\n')
data = import_from_excel_clipboard();

LabelExcel = data(1,:);
for ii = 1:numel(LabelExcel)
    fprintf('%d: %s\n',ii, LabelExcel{ii});
end

% Extract data from clipboard
List_col_category = input('Type category column list in a vector, ex. [2:5]\n');
List_col_prescreen = input('Type category column list ex,[17] to exclude/include PV/inhibitory neurons, just enter to integrate excitatory/inhibitory\n');
ListNumericCol = input('Type columns of numeric data, ex[14:22]\n');
List_col_animal = input('Type animal# column, ex 6\n');
ListNumericRow = input('Type rows of numeric data ex[10:261]\n');
Label = LabelExcel(ListNumericCol);
data_num_import = data(ListNumericRow,ListNumericCol);
data_category_import = data(ListNumericRow,List_col_category);
List_category = data(1,List_col_category);

% Clean data_num_import
emptyIdx = find(cellfun(@isempty, data_num_import));
for ii = 1:numel(emptyIdx)
    data_num_import{emptyIdx(ii)} = NaN; %fill empty cells with NaN
end
data_num_import(strcmp(data_num_import, 'NaN')) = {NaN}; %  fill 'NaN' cells with NaN
data_num_import = cell2mat(data_num_import);
if ~isempty(List_col_animal)
    data_animal_import = data(ListNumericRow,List_col_animal);
end

% Clean data_category_import
emptyIdx = find(cellfun(@isempty, data_category_import));
for ii = 1:numel(emptyIdx)
    data_category_import{emptyIdx(ii)} = NaN; %fill empty cells with NaN
end
data_category_import(strcmp(data_category_import, 'NaN')) = {NaN};%  fill 'NaN' cells with NaN, keep cell format
%---------------------------------------------------------------------------------
% Pick category
for ii = 1:numel(List_category)
    fprintf('%d: %s\n',ii, List_category{ii});
end
id_compare = input('Select single category# from above for comparison \n');
count = 0;
for ii = 1:numel(List_category)
    if ii == id_compare
        note_input = '**if group>2, ANOVA1or2 and Tukey is selected** ';
    else
        note_input = '';
    end
    List_category_temp = [data_category_import{:,ii}];
    List_category_temp = List_category_temp(~isnan(List_category_temp));
    fprintf('\n%d: %s, List is %s\n',ii, List_category{ii}, num2str(unique(List_category_temp)));
    data_temp = unique([data_category_import{:,ii}]);
    data_temp = data_temp(~isnan(data_temp));
    if isnumeric(data_temp(1))
        Para = input(['Select ' note_input 'parameters to pick, ex [' num2str(data_temp(end-1)) ', ' num2str(data_temp(end)) ']\n']);
    end
    if ischar(data_temp(1))
        text_prompt = "Select " + note_input + "parameters to pick, ex {'" + string(data_temp(end-1)) + "'," + "'" + string(data_temp(end)) + "'}";
        Para = input(text_prompt + "\n");
    end
    if ~isempty(Para)
        count = count +1;
        List_cat(count) = ii;
        List_select{count} = Para;
    end
end
%---------------------------------------------------------------------------------


% Processing
%---------------------------------------------------------------------------------
[Selected, mask_cat] = pick_idx(data_category_import, List_cat, List_select);
ListCompareName = List_select{id_compare};
%---------------------------------------------------------------------------------
% Prescreen outliers in log scale
Label_prescreen = Label(find(ismember(ListNumericCol,List_col_prescreen)));
[mask_exinhi, StackPrescreen] = prescreen_outlier(data_num_import, ListNumericCol, List_col_prescreen,'Label',Label_prescreen);
%---------------------------------------------------------------------------------
% Statistic comparison and plot
%---------------------------------------------------------------------------------
mask_input = mask_cat.*mask_exinhi;
[data_subset, ListRowSubset, N_total] = pick_subset(data_category_import, id_compare, data_num_import, mask_input, ListCompareName);
if exist('data_animal_import','var')% if animal info exists
    for ii = 1:numel(ListRowSubset)
        animal_subset{ii} = data_animal_import(ListRowSubset{ii});
    end
end
h(1)=gcf;
%---------------------------------------------------------------------------------
% STAT
% prepare data
sel_stat = input('1:bootstrap only, 2:ttest+bootstrap, 3:ttest+ranksum, 4:LME (linear mixed effect model)\n');
factor_out = input('Type factors for MAD, ex 2.5[narrow] 3 to 4.5 [wide] 0 [no cut], just enter=3\n');
if isempty(factor_out)
    factor_out = 3;
end

if numel(data_subset) >=3
    anova_mode = input('Which anova 1:1way or 2:2ways\n');
    switch anova_mode
        case 1
            PlotDataAll = multi_stat(data_subset,sel_stat,factor_out,'Label',Label, 'anova_mode', 1);

        case 2
            combi_para = input(['Which group# is combined condition? choose from' num2str(1:numel(data_subset)) '\n']);
            PlotDataAll = multi_stat(data_subset,sel_stat,factor_out,'Label',Label, 'anova_mode', 2, 'combi_para', combi_para);
            
    end
else
    if exist('animal_subset','var')
        PlotDataAll = multi_stat(data_subset,sel_stat,factor_out,'Label',Label,'animal_subset',animal_subset);
    else
        PlotDataAll = multi_stat(data_subset,sel_stat,factor_out,'Label',Label);
    end
end

%--------------------------------------------------------------------------


% Output
%--------------------------------------------------------------------------
% Display
%--------------------------------------------------------------------------
h(2) = figure('Name','PlotIVdata','Color','w'); 
ListGrouLabel = input('Type Legend such as {"Control","PM2.5"}\n');
select_graph = input('1: bar 2: scatter\n');
ListBarColor = {[38 108 206]/255,[231 55 13]/255,[254 163 2]/255};
nParameter = size(PlotDataAll,1);
for id_parameter = 1:nParameter
    subplot(1,nParameter,id_parameter);hold on;
    
    for id_group = 1:numel(data_subset)
        switch select_graph
            case 1
                scatter_zitter(PlotDataAll(id_parameter,id_group).kept, 'dx', id_group,'plot_type','bar','bar_width',0.5,'bar_color',ListBarColor{id_group});
            case 2
                scatter_zitter(PlotDataAll(id_parameter,id_group).kept, 'dx', id_group-1,'plot_type','scatter');
        end
    end
    if select_graph == 1
        a=gca;a.YLim = [-max(abs(a.YLim)), max(abs(a.YLim))];
    end

    title(PlotDataAll(id_parameter,1).Label ,PlotDataAll(id_parameter,1).note,'Fontsize',8);% show esize and P-values in the title
    a=gca;a.XLim = [0 numel(data_subset)+0.5]; a.XTick=1:numel(data_subset); a.XTickLabels = ListGrouLabel;
    a.LineWidth = 1.5;
end
set(findall(gcf,'-property','Interpreter'),'Interpreter','none');
h(2).Position(3:4) = [786 420];
Axes = findall(gcf,'Type','axes');
for ii = 1:numel(Axes)
    Axes(ii).Position(2:4) = [0.1100    0.0603    0.8150];
    Axes(ii).TickDir = 'out';
end
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% Save
%--------------------------------------------------------------------------
yn_save = input('save figs y/n\n','s');
if yn_save == 'y'
    pn_save = uigetdir(pn_def,'Select folder to save');
    pn_def = pn_save;
    note = input('Type note\n','s');
    for id_fig = 1:numel(h)
        set(findall(h(id_fig),'-property','Interpreter'),'Interpreter','none');
        saveas(h(id_fig),[pn_save '\' h(id_fig).Name '_' note '.fig'],'fig')
    end
    save([pn_save '\PlotIVdata_' note '.mat'],'PlotDataAll','StackPrescreen','N_total');
    save([pn_m '\datapath.mat'],'pn_def');
end
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


