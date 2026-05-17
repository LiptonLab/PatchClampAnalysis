
function C = import_from_excel_clipboard()
% Excelでセル範囲をコピーして、MATLABのセル配列 C に取り込む
% 文字列・数値を自動判定してセル配列化する

    disp('Open Excel file and Copy cells Ctrl+C）');
    disp('Type Enter when cells are copied...');
    pause;  % ユーザー操作待ち

    raw = clipboard('paste');  % クリップボードから文字列取得（TSV想定）
    if isempty(raw)
        error('Clipboard is empty. Copy is not completed');
    end

    % 行ごとに分割
    lines = regexp(raw, '\r\n|\n|\r', 'split');
    % 末尾の空行を除く
    if ~isempty(lines) && isempty(lines{end})
        lines(end) = [];
    end

    % 各行をタブで分割 → セル配列 C{row, col}
    maxCols = 0;
    rows = numel(lines);
    tmp = cell(rows, 1);
    for i = 1:rows
        tmp{i} = strsplit(lines{i}, sprintf('\t'), 'CollapseDelimiters', false);
        maxCols = max(maxCols, numel(tmp{i}));
    end

    C = cell(rows, maxCols);
    for i = 1:rows
        rowi = tmp{i};
        for j = 1:numel(rowi)
            token = rowi{j};

            % 数値判定（空白は空に）
            if isempty(token)
                C{i,j} = [];
            else
                % 小数点・指数表記・符号対応
                num = str2double(strrep(token, ',', '')); % カンマ区切り数も許容
                if ~isnan(num)
                    C{i,j} = num;
                else
                    C{i,j} = token; % 文字列として保持
                end
            end
        end
    end
end
