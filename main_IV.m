clear; close all;
pn_m =mfilename('fullpath');
pn_f = [fileparts(pn_m), '\functions'];
addpath(pn_f);
%---------------------------------------------------------------------------------
fn_m = mfilename('fullpath');
[pn_m, fn_m] = fileparts(fn_m);
if exist([pn_m '\datapath.mat'],'file')
    load([pn_m '\datapath.mat']);
end
if ~exist('pn_def','var')
    pn_def = '';
end
%---------------------------------------------------------------------------------
recursiveSearchSupported = ~verLessThan('matlab','9.1');
if recursiveSearchSupported == 1
    fprintf("This MATLAB version supports recursive file search across all directory levels.\n");
end
%---------------------------------------------------------------------------------
fprintf('\n[ReadMe]\n')
fprintf('\n1. To run batch mode, prepare an Excel sheet with a vertical list of filenames, as shown in the sample Excel file.\n');
fprintf('Sample Excel file is "Scripps Research Dropbox/Lipton Lab/_PatchClmapData/PM2p5/PM2p5 mPFC patch_rev*.xlsm" \n\n');
fprintf(['2. To run batch mode, Abf files should be stored in the same folder \n...' ...
    'or same/different subfolders in the same folder\n...' ...
    ' or same/different grandchildren folder in the same foler\n...' ...
    'but do not save files in different levels of subfolders\n']);
fprintf('Sample Data Folder is "Scripps Research Dropbox/Lipton Lab/_PatchClmapData/PM2p5/AbfFiles" \n');
void = input('Type enter when ready\n');
%---------------------------------------------------------------------------------
% Import Abf files
if recursiveSearchSupported == 1
    pn_abf_top = uigetdir(pn_def,'Select the parent folder to search for .abf files in all subfolders');
else
    pn_abf_top = uigetdir(pn_def,'Select the parent folder to search for .abf files up to 3 subfolder levels deep.');
end
%---------------------------------------------------------------------------------
pn_def=pn_abf_top;
save([pn_m '\datapath.mat'],'pn_def');
%---------------------------------------------------------------------------------
fn_select_mode = input('1: select in a window 2:type filename, 3:copy file list from Excel sheet');
switch fn_select_mode
    case 1
        List_fn_abf{1} = uigetfile([pn_abf_top '\*.abf'],'Select Abf file');
    case 2
        List_fn_abf{1} = input('Type abf flename with .abf\n','s');
    case 3
        List_fn_abf = import_from_excel_clipboard();
        %ListPick = find(cellfun(@(x) ~isempty(strfind(x,'abf')),List_fn_abf));
        %List_fn_abf = List_fn_abf(ListPick);
end

if recursiveSearchSupported == 1
    for id_file = 1:numel(List_fn_abf)
        List_fn_abf_full{id_file} = dir(fullfile(pn_abf_top,'**',[List_fn_abf{id_file}]));
    end
else
    for id_file = 1:numel(List_fn_abf)
        List_fn_abf_full_1 = dir(fullfile(pn_abf_top,[List_fn_abf{id_file}]));
        List_fn_abf_full_2 = dir(fullfile(pn_abf_top,'*',[List_fn_abf{id_file}]));
        List_fn_abf_full_3 = dir(fullfile(pn_abf_top,'*','*',[List_fn_abf{id_file}]));
        List_fn_abf_full_4 = dir(fullfile(pn_abf_top,'*','*','*',[List_fn_abf{id_file}]));
        List_fn_abf_full{id_file} = [List_fn_abf_full_1; List_fn_abf_full_2; List_fn_abf_full_3];
    end
end

%---------------------------------------------------------------------------------
% Preset parameters
dV_window = [0.1 0.2];
def_List_Iin = [-60, -40, -20];
def_rheobase_marginstep = 1;
def_Current_Sag_pA = -100;
List_Iin = input(['Type Current injection[pA] values used for Tau calc such as ' num2str(def_List_Iin) ', type just enter to use these default values\n\n']);
if isempty(List_Iin)
    List_Iin = def_List_Iin;% I injections (pA) to calculate Tau
end
rheobase_marginstep = input(['Enter N current steps above rheobase to measure firstspike,SpikeAmp,SpikeWidth,threshold,AHP,Sag, just enter= ' ,num2str(def_rheobase_marginstep) 'step\n']);
if isempty(rheobase_marginstep)
    rheobase_marginstep = def_rheobase_marginstep;% 
end
Current_Sag_pA = input(['Type I injection pA to measure Sag, just enter=',num2str(def_Current_Sag_pA) '[pA]\n']);
if isempty(Current_Sag_pA)
    Current_Sag_pA = def_Current_Sag_pA;% 
end
fprintf('If N=3, closer 2 values are used, If N>=4 outliers are removed\n');
yn_plot_taufit = input('Plot tau fitting? y/n just enter=n\n \n','s');
if isempty(yn_plot_taufit)
    yn_plot_taufit = 'n';
end
yn_plot_inflection = input('Plot the inflection point to verify threshold detection? y/n just enter=n\n','s');
if isempty(yn_plot_inflection)
    yn_plot_inflection = 'n';
end
switch yn_plot_inflection
    case {'y','Y'}
        plot_inflection_01 = 1;
    case {'n','N'}
        plot_inflection_01 = 0;
end
yn_save = input('save output values and intermediate plot figures y/n\n','s');

%---------------------------------------------------------------------------------
% prepare Table to store IV parameters
VarNames = ["Vrest_mV", "Cm_pF", "Tau_ms", "FI_slope", "FirstSpikeLatency_s", "SpikeThreshold_mV",...
    "AdaptationIndex", "SpikeAmplitude_mV", "slope10_90_mVmS", "SpikeWidth_sec", "AHP_mV", "Sag", "Rin_Mohm"];
VarTypes = ["double","double","double","double","double","double","double","double","double","double","double","double","double"];
Table_IV = table('Size',[0 numel(VarNames)], 'VariableTypes', VarTypes, 'VariableNames', VarNames);
%---------------------------------------------------------------------------------
% Display how parameters are calculated
fprintf('===================================================================\n');
fprintf('Methods\n')
fprintf('This code analyzes IV data in which I is injected from the smallest value in a sequence without duplicaton\n');
fprintf('Data of %s pA Current injections were used to calculate Tau, Rin, Cm\n',num2str(List_Iin));
fprintf('Rin[Mohm] is calculated by measuring a slope of Current injection vs Vm, after Iin start %d-%dsec\n',dV_window(1),dV_window(2));
fprintf('Tau[ms] is the extrapolated value at Iin= 0 pA\n');
fprintf('For above, If N=3, closer 2 values are used, If N>=4 outliers are removed\n');
fprintf('Tau[ms] is calculated by finding a Y intercept of Injected Current vs Tau\n');
fprintf('Adaptation index is isi slope / mean(isi[sec]), data from sweeps that evokes >=5spikes are averaged\n');
fprintf('SpikeTime is a time when Vm crosses -20mV, minStim that evokes >=1spike is used\n');
fprintf('SpikeLatency is duration between current injection and Spike time in minStim recording that evokes >=1 spike\n');
fprintf('SpikeThreshold is identified by finding a point where Vm curve deviate from linear fitting,CUSUM=5, minStim that evokes >=1 spike\n');
fprintf('SpikeThreshold is used to measure the baseline for spike amplitude and width @ half amplitude, minStim that evokes >=1 spike\n');
fprintf('FI_slope is calculated from all sweeps in which spikes were evoked\n');
fprintf('Sag is (steadyV - minV) / (restV - minV) where steadyV is average of last 10ms current injection, minStim that evokes >=1spike is used \n');
fprintf('AHP is min(Vm) between 1ms to 10ms after SpikeTime, minStim that evokes >=1spike is used \n');
fprintf('===================================================================\n');
% How to calculate CUMSUM
%CUSUM(k) = Sk​=max(0,Sk−1​+zk​−κ);
%zk​ [robust normalized residual]= (​rk​−μ0)/σ0;
% rk​=yk​ - regression line;​
fprintf('\n');

%---------------------------------------------------------------------------------
% loop for batch processing of multiple files in the same folder
for id_file = 1:numel(List_fn_abf)
    id_h_start = getCurrentFigureNumber() + 1;

    if isempty(List_fn_abf_full{id_file})
        values(id_file,:) = NaN;
    else
        fn_abf = List_fn_abf_full{id_file}.name;
        pn_abf = List_fn_abf_full{id_file}.folder;
        fn_abf_path = [pn_abf '\' fn_abf];
        if exist(fn_abf_path)~=2
            values(id_file,:) = NaN;
        else
            try
%---------------------------------------------------------------------------------               
                [signal, si, header] = abfload([pn_abf ,'\', fn_abf]); % µs 
                dt = si * 1e-6; % sec
                time = (0:size(signal,1)-1) * dt;
                
                % channel & sweep
                nSweeps = size(signal,3);
                voltage = squeeze(signal(:,1,:)); % Vm
                current = squeeze(signal(:,2,:)); % Injected Current
                   
                % Import I_in =-10, -30, -50pA data,then discard the most different one
                targetCurrent_pA = 0;
                [T_sel_0pA, T_all] = find_target_I_in_sweep(fn_abf_path,targetCurrent_pA,'dV_window', dV_window, 'yn_plot',yn_plot_taufit);
                [T_sel_Sag, T_all] = find_target_I_in_sweep(fn_abf_path,Current_Sag_pA,'dV_window', dV_window, 'yn_plot',yn_plot_taufit);
                sweep_Sag = T_sel_Sag{1,'sweep'};
                
                ListI = [];
                ListV = [];
                ListTau = [];
                for ii = 1:numel(List_Iin)
                    T_sel{ii} = find_target_I_in_sweep(fn_abf_path,List_Iin(ii),'dV_window', dV_window,'yn_plot',yn_plot_taufit);
                    ListI = [ListI, T_sel{ii}.Imean_pA];
                    %ListV = [ListV, T_sel{ii}.Vinf_mV];
                    ListV = [ListV, T_sel{ii}.dV_mV];
                    ListTau = [ListTau, T_sel{ii}.tau_ms];
                end
            
                idx_kept = removeOutliers(ListV);% remve most different one (sometimes noizy one is included)
                ListV = ListV(idx_kept);
                ListI = ListI(idx_kept);
                ListTau = ListTau(idx_kept);
            
                % Rin is calculated by I-V fitting
                p_R = polyfit(ListI,ListV,1);
                out.Rin_Mohm = p_R(1) * 10^3;
            
                % Tau is calculated by insertion at Iin = 0
                p_Tau = polyfit(ListI,ListTau,1);
                out.Tau_ms = p_Tau(2); %Y intersept
                out.Cm_pF = out.Tau_ms/out.Rin_Mohm * 10^-3/10^6 * 10^12;
                
                % Measure Vm from the 1st sweep (however, this does not show real Vm if
                % current is injected to stablize Vm for experiments
                t0_s_1st = T_all.t0_s(1);
                idx_time_before_t0s_1st = max(find((t0_s_1st - 0.005) - time > 0 ));% scan from 5ms before rise
                out.Vrest_mV = mean(voltage(1:idx_time_before_t0s_1st));
                
                % For storage of results
                results = struct();
                spikeCounts = zeros(nSweeps,1);
                
                for i = 1:nSweeps
                    dI(:,i) = abs(current(2:end,i) - current(1:end-1,i));
                end
                AboveZero = find((sum(dI,2) - max(sum(dI,2))/2)>0);
                TW_I = [AboveZero(1), AboveZero(end)];
                
                for i = 1:nSweeps
                    %v = voltage(:,i);
                    %I = current(:,i);
                    v = voltage(TW_I(1):TW_I(2),i);
                    I = current(TW_I(1):TW_I(2),i);
                    I_pre = current(1:TW_I(1)-5,i);
                    I_subtract = I - mean(I_pre);
                    current_subtract(:,i) = I_subtract;
                
                    % Spike detection
                    [spikeTimes, spikeTimes_peak] = findSpikes(v, dt);
                    spikeCounts(i) = length(spikeTimes);
                
                    % Spike analysis, calculate spike dependent parameters
                    if ~isempty(spikeTimes) 
                        results(i).FirstSpikeLatency = spikeTimes(1);
                        results(i).FirstSpikeLatency_peak = spikeTimes_peak(1);
                        results(i).SpikeCount = length(spikeTimes);
                
                        if length(spikeTimes) >= 5%%
                            isi = diff(spikeTimes);
                            p = polyfit(1:numel(isi), isi, 1);
                            results(i).AdaptationIndex = p(1)/mean(isi);
                        else
                            results(i).AdaptationIndex = NaN;
                        end
                
                        [amp, width, threshold, threshold_time, slope10_90_mVsec, InfoAmpStep] = analyzeSpike(v,spikeTimes(1), dt,'plot_inflection_01',plot_inflection_01);
                        h=gcf;h.Name = [h.Name, '#' num2str(i) 'sweep'];
                        plot(time(TW_I(1):TW_I(2)), v);
                        plot(time(TW_I(1))+threshold_time,threshold,'*');
                        text(time(TW_I(1))+threshold_time,threshold,['Sweep#', num2str(i)]);
                        
                        results(i).SpikeAmplitude = amp;
                        results(i).SpikeWidth = width;
                        results(i).SpikeThreshold = threshold;
                        results(i).SpikeThreshold_time = threshold_time;
                        results(i).slope10_90_mVmS = slope10_90_mVsec;
                        results(i).InfoAmpStep = InfoAmpStep;
                
                        results(i).AHP = computeAHP(v, spikeTimes(1), dt);
                    else
                        results(i).FirstSpikeLatency = NaN;
                        results(i).FirstSpikeLatency_peak = NaN;
                        results(i).AdaptationIndex = NaN;
                        results(i).SpikeAmplitude = NaN;
                        results(i).SpikeWidth = NaN;
                        results(i).SpikeThreshold = NaN;
                        results(i).SpikeThreshold_time = NaN;
                        results(i).slope10_90_mVmS = NaN;
                        results(i).InfoAmpStep = NaN;
                        results(i).AHP = NaN;
                    end
                
                    %results(i).Sag = computeSag(v, I, dt);
                    results(i).Sag = computeSag(v, I_subtract, dt);% spike independent
                end
                sweep_minstim = find(spikeCounts,1,'first');
                
                %F-I curve slope
                %currents = arrayfun(@(x) mean(current(:,x)), 1:nSweeps);
                currents = arrayfun(@(x) mean(current_subtract(:,x)), 1:nSweeps);
                validFI = spikeCounts > 0;
                FI_fit_factors = polyfit(currents(validFI), spikeCounts(validFI), 1);
                out.FI_slope = FI_fit_factors(1);%slope is FI_fit_factors(1)
                disp(['F-I curve slope: ', num2str(out.FI_slope)]);
                
                % Extract Representative values（remove NaN）
                minid_Latency = find(~isnan(arrayfun(@(x) results(x).FirstSpikeLatency, 1:nSweeps)), 1+rheobase_marginstep, 'first');
                out.FirstSpikeLatency_s = results(minid_Latency).FirstSpikeLatency;
            
                validAdapt = find(~isnan(arrayfun(@(x) results(x).AdaptationIndex, 1:nSweeps)));
                out.AdaptationIndex = mean([results(validAdapt).AdaptationIndex]);
            
                validAmp = find(~isnan(arrayfun(@(x) results(x).SpikeAmplitude, 1:nSweeps)), 1+rheobase_marginstep, 'first');
                out.SpikeAmplitude_mV = results(minid_Latency).SpikeAmplitude;

                validslope10_90_mVmS = find(~isnan(arrayfun(@(x) results(x).slope10_90_mVmS, 1:nSweeps)), 1+rheobase_marginstep, 'first');
                out.slope10_90_mVmS = results(minid_Latency).slope10_90_mVmS;

                validWidth = find(~isnan(arrayfun(@(x) results(x).SpikeWidth, 1:nSweeps)), 1+rheobase_marginstep, 'first');
                out.SpikeWidth_sec = results(validWidth).SpikeWidth;
            
                validThresh = find(~isnan(arrayfun(@(x) results(x).SpikeThreshold, 1:nSweeps)), 1+rheobase_marginstep, 'first');
                out.SpikeThreshold_mV = results(validThresh).SpikeThreshold;
            
                validAHP = find(~isnan(arrayfun(@(x) results(x).AHP, 1:nSweeps)), 1+rheobase_marginstep, 'first');
                out.AHP_mV = results(validAHP).AHP;
            
                %validSag = find(~isnan(arrayfun(@(x) results(x).Sag, 1:nSweeps)), 1+rheobase_marginstep, 'first');
                validSag = find(~isnan(arrayfun(@(x) results(x).Sag, 1:nSweeps)), sweep_Sag, 'first');
                out.Sag = results(validSag).Sag;
            
                % Fill with NaN if empty
                for id_varname = 1:numel(VarNames)
                    if isempty(out.(VarNames{id_varname}))
                        out.(VarNames{id_varname}) = NaN;
                    end
                end
            
                out_cat = [];
                for id_field = 1:numel(VarNames)
                    out_cat = [out_cat, out.((VarNames{id_field}))];
                end
                values(id_file,:) = out_cat;
            
                fprintf('\n--- Representative Values ---\n');
                for id_field = 1:numel(VarNames)
                    fprintf('%s : %.3f mV\n', VarNames{id_field}, out.(VarNames{id_field}));
                end
            
                figure('Name','I-V raw wave');hold on
                subplot(2,1,1);title('Injected Current');hold on;
                plot(time,current);xlabel('sec');ylabel('pA');
                if sweep_minstim > 0
                    plot(time,current(:,sweep_minstim),'LineWidth',2)
                end
                subplot(2,1,2);title('Voltage');hold on;
                plot(time,voltage);xlabel('sec');ylabel('mV');
                if sweep_minstim> 0
                    plot(time,voltage(:,sweep_minstim),'LineWidth',2);
                    spiketime_peak_minstim = TW_I(1)*dt+results(sweep_minstim).FirstSpikeLatency_peak;
                    plot(spiketime_peak_minstim,voltage(round(spiketime_peak_minstim/dt),sweep_minstim),'r*');
            
                    spikeThreshold_time_minstim = TW_I(1)*dt+results(sweep_minstim).SpikeThreshold_time;
                    plot(spikeThreshold_time_minstim,voltage(round(spikeThreshold_time_minstim/dt),sweep_minstim),'b*');
                end
            %---------------------------------------------------------------------------------
                if yn_save == 'y'
                    h = gcf;
                    id_h_end = getCurrentFigureNumber();
                    pn_result = [pn_abf, '\results\' fn_abf(1:end-4)];
                    mkdir(pn_result);
                    for id_fig = id_h_start:id_h_end
                        h = figure(id_fig);
                        saveas(h,[pn_result '\' h.Name, '.fig'],'fig');
                    end
                    save([pn_result '\out.mat'],'out');
                end
            catch
                values(id_file,:) = NaN;
            end
%---------------------------------------------------------------------------------
        end
    end
end
%---------------------------------------------------------------------------------
% Copy to Clipboard
for ii = 1:numel(Table_IV.Properties.VariableNames)
    fprintf('%d:%s\n',ii,Table_IV.Properties.VariableNames{ii});
end
List_copy = input('Type variable# to copy, use a vector format []=all\n');
if isempty(List_copy)
    List_copy = 1:numel(Table_IV.Properties.VariableNames);
end

labels = Table_IV.Properties.VariableNames;
subLabels = labels(List_copy);
clipboard('copy', strjoin(subLabels, '\t'));
disp('Label names are copied to the clipboard in Excel format (TSV). Paste them into the top row.');
void = input('Type enter to proceed\n');

values = values(:,List_copy);
% Format（Each Row: C column、Last column lacks tab、Add line change at the end)
[R, C] = size(values);
if C == 0 || R == 0
    error('values is empty');
end

% If the data have C colums, add C-1 of '%.5f\t' at the head, then add
% '%.5f\n' at the end
fmt = [repmat('%.5f\t', 1, C-1), '%.5f\n'];

% Rotate matrix since sprintf fills column direction first
str = sprintf(fmt, values.');

% remove last line change (enter), in case data is pasted on a Excel sheet
if ~isempty(str) && str(end) == sprintf('\n')
    str(end) = [];
end

% Copy to clipboard
clipboard('copy', str);
disp('Data Matrix is copied to clipboard in Excel format (TSV）');
%---------------------------------------------------------------------------------


