
function y = medfilt1_simple(x, k, padtype)
% medfilt1_simple  - Toolbox不要の1次元メディアンフィルタ
%    y = medfilt1_simple(x, k)
%    y = medfilt1_simple(x, k, padtype)
%
% 入力:
%   x       : ベクトルまたは行列（各列ごとに1次元フィルタ）
%   k       : 窓幅（正の整数、奇数推奨。偶数でも動くが中心がずれる）
%   padtype : 'symmetric'（既定）, 'replicate', 'circular' のいずれか
%
% 出力:
%   y       : x と同サイズ。各列（もしくはベクトル）に移動メディアンを適用
%
% 備考:
%   - 端点処理のために左右に (k-1)/2 サンプルをパディングします
%   - 速度は純粋なforループ実装のため大きな配列では遅くなります
%     （必要なら一括ソート最適化版に差し替え可能）

    if nargin < 2
        error('Usage: y = medfilt1_simple(x, k, [padtype])');
    end
    if nargin < 3 || isempty(padtype)
        padtype = 'symmetric';
    end
    if ~isscalar(k) || k < 1 || k ~= floor(k)
        error('k must be a positive integer.');
    end
    if isrow(x)
        x = x(:);  % 行ベクトルは列に変換（最終的に元の形に戻す）
        wasRow = true;
    else
        wasRow = false;
    end

    % 行列対応：各列ごとに処理
    [n, m] = size(x);
    y = zeros(n, m, class(x));

    half = floor((k-1)/2);     % 左右に付ける数
    padL = half; 
    padR = k - 1 - half;       % 偶数窓の場合も両端の合計がk-1になるように

    for col = 1:m
        xc = x(:, col);

        % 端点パディング
        switch lower(padtype)
            case 'symmetric'
                % 対称パディング
                leftPad  = flipud(xc(1:padL));
                rightPad = flipud(xc(end-padR+1:end));
            case 'replicate'
                leftPad  = repmat(xc(1), padL, 1);
                rightPad = repmat(xc(end), padR, 1);
            case 'circular'
                leftIdx  = mod((-padL:-1) + n, n) + 1;
                rightIdx = mod((n:(n+padR-1)), n) + 1;
                leftPad  = xc(leftIdx);
                rightPad = xc(rightIdx);
            otherwise
                error('Unsupported padtype: %s', padtype);
        end

        xpad = [leftPad; xc; rightPad];

        % 移動メディアン（ナイーブなループ実装）
        % 性能が必要ならウィンドウごとのソートの再利用最適化や
        % MATLABの movmedian が使える環境なら差し替え可。
        yc = zeros(n, 1, class(x));
        for i = 1:n
            window = xpad(i:i+k-1);
            yc(i) = median(window, 'omitnan');
        end
        y(:, col) = yc;
    end

    % 形状を元に戻す
    if wasRow
        y = y.';  % 行ベクトルに戻す
    end
end
