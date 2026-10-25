function [mask_exinhi, StackPrescreen] = prescreen_outlier(data_num_import, ListNumericCol, List_col_prescreen,varargin)

    Label = arrayfun(@num2str, List_col_prescreen, 'UniformOutput', false);
    for ii = 1:nargin - 3
        if strcmp(varargin{ii},'Label')
            Label_prescreen = varargin{ii+1};
        end
    end

    % default
    StackPrescreen.RangeIn = [];
    StackPrescreen.LogAdapIndex_table = [];
    StackPrescreen.select_limit = [];
    StackPrescreen.select_majorminor = [];
    StackPrescreen.menu_select_limit = '1:lower limit 2:upper limit 3:both limits';
    StackPrescreen.menu_select_majorminor = '1: Major 2: Minor 3: both';
    mask_exinhi = ones(size(data_num_import,1),1);

    if isempty(ListNumericCol)
        h(1) = figure('Name','logPlot AdapIndex','Color','w');
    end
    for kk = 1:numel(List_col_prescreen)
        subplot(1,numel(List_col_prescreen),kk);
        hold on;
        title(Label_prescreen{kk});
        
        id_col_prescreen = List_col_prescreen(kk);
        if ~isempty(id_col_prescreen)
            data_AdapIdx = data_num_import(:,ListNumericCol==id_col_prescreen);
            logdata = real(log(data_AdapIdx));
            validIdx = isfinite(logdata);
            ListValidIdx = find(validIdx);
            logdata_valid = logdata(validIdx);
            plot(ListValidIdx,logdata_valid,'.');

            [idxKept_ori, idxOut_ori, kept, out, RangeIn] = removeOutliers(logdata_valid ,'mad','MADk',3);
            StackPrescreen.RangeIn(kk,:) = RangeIn;
            
            a=gca;
            plot([a.XLim(1),a.XLim(2)],[RangeIn(1), RangeIn(1)],'b-');
            plot([a.XLim(1),a.XLim(2)],[RangeIn(2), RangeIn(2)],'r-');
            ylabel('log(adap index)');
            xlabel('sample # in Excel file');
            
            select_limit = input('Select 1:lower limit 2:upper limit 3:both limits\n');
            StackPrescreen.select_limit(kk) = select_limit;
            switch select_limit
                case 1
                    LogLimit = RangeIn(1);
                case 2 
                    LogLimit = RangeIn(2);
                case 3
                    LogLimit = RangeIn([1 2]);
            end
            
            plot(0,LogLimit,'*');
            for ii = 1:numel(LogLimit)
                text(0,LogLimit(ii),num2str(LogLimit(ii)));
            end
            switch select_limit
                case 1
                    idxKept = find(logdata_valid >= LogLimit);
                    idxOut = find(logdata_valid <= LogLimit);
                case 2
                    idxKept = find(logdata_valid <= LogLimit);
                    idxOut = find(logdata_valid >= LogLimit);
                case 3
                    idxKept = intersect(find(logdata_valid >= LogLimit(1)),find(logdata_valid <= LogLimit(2)));
                    idxOut = setdiff(1:numel(logdata_valid),idxKept);
            end
        
            logdata_table = nan(size(logdata,1),2);
            logdata_table(validIdx,1) = logdata_valid;
            logdata_table(ListValidIdx(idxKept),2) = 1;
            logdata_table(ListValidIdx(idxOut),2) = 0;
          
            IdxInh = find(logdata_table(:,2) == 0);
            IdxEx = find(logdata_table(:,2) == 1);

            

            select_majorminor = input('Which to analyze 1: Major 2: Minor 3: both');
            StackPrescreen.select_majorminor(kk) = select_majorminor;
            StackPrescreen.mask_exinhi(:,kk) = zeros(size(data_AdapIdx));
            switch select_majorminor
                case 1
                    StackPrescreen.mask_exinhi(IdxEx,kk) = 1;
                case 2
                    StackPrescreen.mask_exinhi(IdxInh,kk) = 1;
                case 3
                    StackPrescreen.mask_exinhi(:,kk) = ones(size(data_AdapIdx));
            end

            ListOut = find(StackPrescreen.mask_exinhi(:,kk)==0);
            for ii = 1:numel(ListOut)
                text(ListOut(ii),logdata_table(ListOut(ii),1),num2str(ListOut(ii)));
            end

            StackPrescreen.LogAdapIndex_table(:,:,kk) = logdata_table;
        end
    end
    List_filter = input('Type prescreen/filter list [if multiples filters are made] to include in a vector, just enter = 1\n');
    if isempty(List_filter)
        List_filter = 1;
    end
    List_ax = findall(gcf,'Type','axes');
    for ii = 1:numel(List_filter)
        id_ax = numel(List_ax) + 1 - List_filter(ii);
        List_ax(id_ax).Title.String = "*" + List_ax(id_ax).Title.String;
    end
    StackPrescreen.List_filter = List_filter;
    if ~isempty(List_filter)
        mask_exinhi = prod(StackPrescreen.mask_exinhi(:,List_filter),2);
    end
end