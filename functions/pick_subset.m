function [data_subset, ListRowSubset, N_total] = pick_subset(data_category, id_compare, data_num_import, mask_input, ListCompareName)
    ListGroup(mask_input==1,1) = data_category(mask_input==1,id_compare);
    if isnumeric(ListCompareName(1))
        ListGroup(mask_input==0) = {-9999};% flag for exclude
        ListGroup = cellfun(@num2str, ListGroup, 'UniformOutput', false);
        for ii = 1:numel(ListCompareName)
            ListRowSubset{ii} = find(ismember(ListGroup,num2str(ListCompareName(ii))));
            data_subset{ii} = data_num_import(ListRowSubset{ii},:);
            N_total(ii) = numel(ListRowSubset{ii});
            fprintf('N of Group#%d is %d\n',ListCompareName(ii),N_total(ii))
        end
    elseif ~iscell(ListCompareName)
        fprintf('Parameter classifying compare group is mixture of number and character, check excel sheet\n');
    elseif ~ischar(ListCompareName{1})
        fprintf('Parameter classifying compare group is mixture of number and character, check excel sheet\n');
    elseif ischar(ListCompareName{1})
        ListGroup(mask_input==0) = {'exclude'};
        for ii = 1:numel(ListCompareName)
            ListRowSubset{ii} = find(ismember(ListGroup,ListCompareName(ii)));
            data_subset{ii} = data_num_import(ListRowSubset{ii},:);
            N_total(ii) = numel(ListRowSubset{ii});
            fprintf('N of Group#%s is %d\n',ListCompareName{ii},N_total(ii))
        end
    end
end