
function scatter_zitter(data, varargin)

    plot_type = 'scatter';
    rep_value = 'mean';
    bar_width = 0.75;
    bar_color = 'w';
    for ii = 1:nargin-1
        if strcmp(varargin{ii},'dx')
            dx = varargin{ii+1};
        end
        if strcmp(varargin{ii},'Label')
            Label = varargin{ii+1};
        end
        if strcmp(varargin{ii},'plot_type')
            plot_type = varargin{ii+1};
        end
        if strcmp(varargin{ii},'rep_value')
            rep_value = varargin{ii+1};
        end
        if strcmp(varargin{ii},'bar_width')
            bar_width = varargin{ii+1};
        end
        if strcmp(varargin{ii},'bar_color')
            bar_color = varargin{ii+1};
        end
    end

    % X方向のジッターを正規分布に従って生成（平均1、標準偏差0.01）
    x = 1 + randn(size(data)) * 0.1;

    % 統計量の計算
    mean_val = mean(data);
    sem_val = std(data) / sqrt(length(data));
    median_val = median(data);
    q25 = prctile(data, 25);
    q75 = prctile(data, 75);


    if exist('Label','var')
        for ii = 1:numel(data)
            text(dx+x(ii), data(ii), Label{ii});
        end
    end

    % プロット
    switch plot_type
        case 'bar'
            bar(dx, mean_val, bar_width, 'FaceColor', bar_color,'LineWidth',1.5);
            scatter(dx+x-1, data, 5, 'k', 'filled'); hold on;
        case 'scatter'
            scatter(dx+x, data, 5, 'k', 'filled'); hold on;
    end

    switch rep_value
        case 'mean'
            % 平均とSEM
            switch plot_type
                case 'scatter'
                    errorbar(dx+1, mean_val, sem_val, 'ro', 'LineWidth', 2, 'CapSize', 10);
                case 'bar'
                    errorbar(dx, mean_val, sem_val, 'Marker','none', 'LineWidth', 0.75, 'CapSize', 5,'Color','k');
            end

        case 'quad'
            % メジアン（赤線）
            plot(dx+[0.98 1.02], [median_val median_val], 'g-', 'LineWidth', 1.5);
        
            % 四分位範囲（赤点線）
            plot(dx+[0.9 1.1], [q25 q25], 'g--', 'LineWidth', 1);
            plot(dx+[0.9 1.1], [q75 q75], 'g--', 'LineWidth', 1);
    end

    %xlim([0.98 1.02]);
    %ylabel('Data Values');
end
