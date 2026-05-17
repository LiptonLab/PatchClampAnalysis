function fnum = getCurrentFigureNumber()
    figs = findall(0, 'Type', 'figure');  % 開いている figure を全部取得
    if isempty(figs)
        fnum = 0;                         % 何もなければ 0
    else
        f = get(groot, 'CurrentFigure');  % カレント figure を取得
        if isempty(f)
            fnum = 0;                     % カレント figure が無い場合も 0
        else
            fnum = f.Number;              % figure 番号
        end
    end
end
