
function out = effectsize_independent(x, y, varargin)
% out.d, out.g, out.glassDelta, out.pooledSD, out.J (補正係数)
% x, y: ベクトル（NaNは自動で無視）
% オプション: 'EqualVariance', true/false (デフォルト true)
    p = inputParser; p.addParameter('EqualVariance', true); p.parse(varargin{:});
    eqv = p.Results.EqualVariance;

    x = x(:); y = y(:);
    x = x(~isnan(x)); y = y(~isnan(y));
    nx = numel(x); ny = numel(y);

    mx = mean(x); my = mean(y);
    vx = var(x, 1); vy = var(y, 1); % 母分散推定（偏り小）
    if eqv
        sp2 = ((nx-1)*var(x) + (ny-1)*var(y)) / (nx+ny-2); % 不偏分散のpool
        sp  = sqrt(sp2);
        d   = (mx - my) / sp;
    else
        % Welch 版（等分散仮定しない）：SDの調和ではなく Glass/非対称dの代替
        % 参考：平均差を pooled SD の代わりに sqrt((vx+vy)/2) で割る簡便法
        sp  = sqrt((var(x) + var(y))/2);
        d   = (mx - my) / sp;
    end

    % Hedges’ g（小標本補正）
    N   = nx + ny;
    J   = 1 - (3/(4*N - 9)); % Hedges & Olkinの近似
    g   = J * d;

    % Glass’s Delta（対照群 y のSDで割ると仮定）
    s_control = std(y);
    glassDelta = (mx - my) / s_control;

    out = struct('d', d, 'g', g, 'glassDelta', glassDelta, ...
                 'pooledSD', sp, 'J', J, 'nx', nx, 'ny', ny, ...
                 'meanX', mx, 'meanY', my);
end
