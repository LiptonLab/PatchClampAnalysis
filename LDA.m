% Input: Clipborad copied from Excel sheet
%---------------------------------------------------------------------------------
clear; close all;
fn_m_full =mfilename('fullpath');
pn_f = [fileparts(fn_m_full), '\functions'];
addpath(pn_f);
%---------------------------------------------------------------------------------
[pn_m, fn_m] = fileparts(fn_m_full);
if exist([pn_m '\datapath.mat'],'file')
    load([pn_m '\datapath.mat']);
end
if ~exist('pn_def','var')
    pn_def = '';
end
%---------------------------------------------------------------------------------
%---------------------------------------------------------------------------------
%---------------------------------------------------------------------------------
% ↓from Plot_PV.m
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
List_col_prescreen = input('Type category column list [vector, ex17] to exclude/include PV/inhibitory neurons, just enter to integrate excitatory/inhibitory\n');
List_col_animal = input('Type animal# column, ex 6\n');
ListNumericCol = input('Type columns of numeric data, ex 14:18\n');
ListNumericRow = input('Type rows of numeric data, ex 10:261\n');
Label = LabelExcel(ListNumericCol);
data_num_import = data(ListNumericRow,ListNumericCol);
if ~isempty(List_col_animal)
    data_animal_import = data(ListNumericRow,List_col_animal);
end
data_category_import = data(ListNumericRow,List_col_category);
List_category = data(1,List_col_category);

% Clean data_num_import
emptyIdx = find(cellfun(@isempty, data_num_import));
for ii = 1:numel(emptyIdx)
    data_num_import{emptyIdx(ii)} = NaN; %fill empty cells with NaN
end
data_num_import(strcmp(data_num_import, 'NaN')) = {NaN}; %  fill 'NaN' cells with NaN
data_num_import = cell2mat(data_num_import);

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
        note_input = '**only 2** ';
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
h(1)=gcf;
if exist('data_animal_import','var')% if animal info exists
    for ii = 1:numel(ListRowSubset)
        animal_subset{ii} = data_animal_import(ListRowSubset{ii});
    end
end
%---------------------------------------------------------------------------------
% STAT
% prepare data
sel_stat = input('1:bootstrap only, 2:ttest+bootstrap, 3:ttest+ranksum 4:LME, []=4\n');
if isempty(sel_stat)
    sel_stat = 4;
end
factor_out = input('Type factors for MAD, ex 2.5[narrow] 3 to 4.5 [wide] 0 [no cut], just enter=3\n');
if isempty(factor_out)
    factor_out = 3;
end
PlotDataAll = multi_stat(data_subset,sel_stat,factor_out,'Label',Label,'animal_subset',animal_subset);
%---------------------------------------------------------------------------------
% ↑from Plot_PV.m
%---------------------------------------------------------------------------------

% run LDA
%---------------------------------------------------------------------------------
% Processing
%---------------------------------------------------------------------------------
%struct LDAdata
%---------------------------------------------------------------------------------
%                lda: [1×1 ClassificationDiscriminant]
%      DataNum_packed: [30×5 double]
%    ListGroup_packed: [30×1 double]
%       ListGroupName: [1 2]
%          factor_out: 3
%             X_proj: [30×1 double]
%                  P: [1×1 struct]
% struct P
%        boot_proj, ttest_proj:, ranksum_proj, testname: sel_stat_proj:
%        ex.,2, P_value_proj:

LDAdata = process_LDA(data_num_import,data_category_import,mask_input,List_select,id_compare,factor_out,'data_animal_import',data_animal_import);
%-----------------------------------------------
% ↓LDA start
%-----------------------------------------------
% Prepare Display data
lda = LDAdata.lda;
X_proj = LDAdata.X_proj;
DataNum_packed = LDAdata.DataNum_packed;
ListGroup_packed = LDAdata.ListGroup_packed;
testname = LDAdata.P.testname;
P_value_proj = LDAdata.P.P_value_proj;

h(2)=figure('Name','LDA scatter','Color','w');
h(2).Position(3:4) = [560, 170];% Figure Size
b = 0.015;                                % Scale（corresponds to σ, spread adjustment）
u = rand(size(X_proj)) - 0.5;             % U ~ Uniform(-1/2, 1/2)
y = -b * sign(u) .* log(1 - 2*abs(u));    % Laplace(0, b)
%gscatter(X_proj, y, group_valid);
gscatter(X_proj, y, ListGroup_packed);
Label_legend = input('Type Legend such as {"Control","PM2.5"}\n');
legend(Label_legend);
xlabel(['LDA projection axis, P' testname '=', num2str(P_value_proj)],'FontSize', 14);
a=gca; a.LineWidth = 1;
a.YLim = [-0.3, 0.3];a.YTickLabels = [];
set(findall(gcf,'-property','Interpreter'),'Interpreter','none');
%-------------------------------------------------------------------------------
%-------------------------------------------------------------------------------
% Plot results
disp('Angle (degrees) between each parameter axis and the LDA discriminant axis:');
ListAngles = [];
angles_deg = LDAdata.angles_deg;
n_features = numel(angles_deg);
for i = 1:n_features
    %fprintf('Parameter %d: %s %.2f degrees, p-value=%d, effectsize = %d\n', i, Label{ListNumericCol(i)}, angles_deg(i), P_boot_each(i), EffectSZ_each(i).g);
    fprintf('Parameter %d: %s %.2f degrees, p-value=%d, effectsize = %d\n', i, Label{i}, angles_deg(i), PlotDataAll(i,1).p, PlotDataAll(i,1).esize.g);
    ListAngles = [ListAngles,angles_deg(i)];
end
List_invert = input('Type feature# to X-invert angle representation [type vector], (ex [2:4], unify parameter vectors to point excitatory direction)\n');

for i = 1:n_features
    if ismember(i,List_invert)
        ListVectors(i,:) = abs(PlotDataAll(i,1).esize.g)*[-cos(LDAdata.angles_deg(i)*pi/180), sin(LDAdata.angles_deg(i)*pi/180)];
    else
        ListVectors(i,:) = abs(PlotDataAll(i,1).esize.g)*[cos(LDAdata.angles_deg(i)*pi/180), sin(LDAdata.angles_deg(i)*pi/180)];
    end
end
SumVector = sum(ListVectors, 1);
fprintf('Sum Vector is %s\n',num2str(SumVector));
if SumVector(1) < 0
    yn_flip_xaxis = input('SumVector(x) is negative, Invert X axis for unified display y/n? []=y\n','s');
    if isempty(yn_flip_xaxis)
        yn_flip_xaxis = 'y';
    end
else
    fprintf('SumVector(x) is positive, no need to invert X axis\n');
    yn_flip_xaxis = 'n';
end

yn_colorode_p = input('Colorcode p-values y/n\n','s');
yn_lengthcode_ES = input('Show Effectsize by vector length y/n\n','s');

h(3)=figure('Name','LDA angle','Color','w');
pax = polaraxes;
if yn_flip_xaxis~='y'
    pax.ThetaZeroLocation = 'right';
    pax.ThetaDir = 'counterclockwise';
else
    pax.ThetaZeroLocation = 'left';
    pax.ThetaDir = 'clockwise';
    set(h(2).CurrentAxes,'XDir','rev');
end
pax.ThetaLim = [0 180];
pax.ThetaTick = [0 90 180];
pax.ThetaGrid = 'on';
pax.RGrid     = 'off';
pax.LineWidth = 1;
pax.FontSize = 10;
hold (pax, 'on');
yn_show_p_etc = input('Show p values/effect size on the graph y/n','s');
cmap = jet(255);
colormap(pax, cmap);
cb = colorbar(pax);
caxis(pax, [0 6]);
cb.Ticks = 0:2:6;
cb.TickLabels = {'1','10^{-2}','10^{-4}','10^{-6}'};
cb.Label.FontSize = 10;
pax_pos = pax.Position;   % [x y width height]
pax_pos(3) = pax_pos(3) * 0.9;    % 横幅を 80% に縮小
pax.Position = pax_pos;
cb_pos  = cb.Position;
gap = 0.02;
cb_pos(1) = pax_pos(1) + 1.05*pax_pos(3) + gap;  % right
cb_pos(4) = pax_pos(4) /4;                 % height
cb_pos(2) = pax_pos(4)/2;      % vertical position
cb_pos(3) = cb_pos(3)/1.5;
cb.Position = cb_pos;
cb.Label.String = '-log_{10}(p)';
for i = 1:n_features

    if ~ismember(i, List_invert)
        note_sig = '';
        angle_display = angles_deg(i);
    else
        note_sig = 'less ';
        angle_display = mod(180-angles_deg(i), 360);
    end

    if yn_colorode_p == 'y'
        p_value = PlotDataAll(i,1).p;
        id_color = min(max(1,floor(-log(p_value)/7*255)),255);
        color = cmap(id_color,:);
    else
        color = 'k';
    end
    if yn_lengthcode_ES == 'y'
        rho = abs(PlotDataAll(i,1).esize.g);
    else
        rho = 1;
    end
    polarplot(pax,[0 angle_display*pi/180], [0 rho],'Color',color,'LineWidth',2);
    
    note_p=[];
    if p_value <0.05
        note_p = '*';
    end
    if p_value <0.01
        note_p = '**';
    end
    if p_value <0.001
        note_p = '***';
    end
    angle_display_text = sprintf('%.3g', angle_display);
    deg = char(176);
    if yn_show_p_etc == 'y'
        text(pax,angle_display*pi/180, rho, [note_p, note_sig, Label(i), string(angle_display_text) + string(deg) ', EffectSZ', num2str(PlotDataAll(i,1).esize.g),' P=' num2str(PlotDataAll(i,1).p)],'FontSize', 6,'Interpreter', 'none');
    else
        text(pax,angle_display*pi/180, rho, [note_p, note_sig, Label(i), string(angle_display_text) + string(deg) ],'FontSize', 6,'Interpreter', 'none');
    end
end
% Display SumVector
rho = sqrt(sum(SumVector.^2,2));
angle_rad = acos(SumVector(1)/rho);
polarplot(pax,[0 angle_rad], [0 rho/n_features],'Color','k','LineWidth',2);
text(pax,angle_rad, rho/n_features, 'mean(vec)' ,'FontSize', 6,'Interpreter', 'none');

pax.RLim(2) = pax.RTick(end);
pax.RTick = pax.RLim;
text(pax, 0.85, -0.12, 'Effect Size', ...
     'Units', 'normalized', ...
     'HorizontalAlignment', 'right', ...
     'VerticalAlignment', 'top', ...
     'FontSize', 6, ...
     'FontWeight', 'normal', ...
     'Interpreter', 'none');
%-------------------------------------------------------------------------------
% save
%-------------------------------------------------------------------------------
yn_save = input('save figs y/n\n','s');
if yn_save == 'y'
    pn_save = uigetdir(pn_def,'Select folder to save');
    pn_def = pn_save;
    note = input('Type note\n','s');
    for id_fig = 1:numel(h)
        set(findall(h(id_fig),'-property','Interpreter'),'Interpreter','none');
        saveas(h(id_fig),[pn_save '\' h(id_fig).Name '_' note '.fig'],'fig')
    end
    save([pn_save '\LDA data_' note '.mat'],'PlotDataAll','LDAdata','angles_deg','List_category','ListNumericCol');
    save([pn_m '\datapath.mat'],'pn_def');% save default folder for next run
end
%---------------------------------------------------------------------------------
%---------------------------------------------------------------------------------
%---------------------------------------------------------------------------------