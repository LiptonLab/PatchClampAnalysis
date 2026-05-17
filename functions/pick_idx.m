% pick_data
% input: List_IDXcat[], List_select{}, List_category
% output: List_data(:,1)

function [Selected, mask] = pick_idx(data_category, List_cat, List_select)

    for ii_cat = 1:numel(List_cat)
        id_col = List_cat(ii_cat);
        search = List_select{ii_cat};
        datalist = data_category(:,id_col);
        if isnumeric(search(1))
            List_nonnumeric =find(cellfun(@(x) isempty(x)||~isnumeric(x), datalist));
            [datalist{List_nonnumeric}] = deal(-99999);%exclude character
            datalist = cell2mat(datalist);
        else
            List_numeric =find(cellfun(@(x) isnumeric(x), datalist));
            [datalist{List_numeric}] = deal('no data');%exclude numeric data
        end
        Flag(:,ii_cat) = ismember(datalist,search);
    end
    mask = prod(Flag,2);
    Selected = find(mask);

end