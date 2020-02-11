% help the algorithm converge to the correct result
% G - m x k
% T - m x m
function [G, T, startT] = GTbound3(params, G, T, startT)
    if params.m == 1
        return;
    end
    assert(all(abs(sum(G, 2) + sum(T, 2) - 1) < 0.00001, 1))
    % G = exp(G);
    % T = exp(T);
    originG = G;
    originT = T;
    originStartT = startT;

    MAX_ENH_LENGTH = 1000;
    MIN_ENH_LENGTH = 100;
    BG_START_T = 0.95;
    % diag
    maxT = ones(params.m) - (1 / MAX_ENH_LENGTH);
    minT = eye(params.m) .* (1 - 1 / MIN_ENH_LENGTH);
    T(T > maxT) = maxT(T > maxT);
    T(T < minT) = minT(T < minT);

    % G bg motifs max
    G_background = G(params.m - params.backgroundAmount + 1: end, :) ;
    G_background_over = G_background(sum(G_background, 2) > BACKGROUND_MAX_MOTIFS, :);
    G_background_over = G_background_over .* BACKGROUND_MAX_MOTIFS ./ sum(G_background_over, 2);
    G_background(sum(G_background, 2) > BACKGROUND_MAX_MOTIFS, :) = G_background_over;
    G(params.m - params.backgroundAmount + 1: end, :) = G_background;

    % G TF motifs min
    G_tf = G(1:params.m - params.backgroundAmount, :) ;
    G_tf_under = G_tf(sum(G_tf, 2) < TF_MIN_MOTIFS, :);
    G_tf_under = G_tf_under .* TF_MIN_MOTIFS ./ sum(G_tf_under, 2);
    G_tf(sum(G_tf, 2) < TF_MIN_MOTIFS, :) = G_tf_under;
    G(1:params.m - params.backgroundAmount, :) = G_tf;

    % T TF -> BG
    T_enh_bg = T(1:params.m - params.backgroundAmount, params.m - params.backgroundAmount + 1: end);
    T_enh_bg(T_enh_bg > ENH_MAX_BG) = ENH_MAX_BG;
    T(1:params.m - params.backgroundAmount, params.m - params.backgroundAmount + 1: end) = T_enh_bg;

    % T BG -> ENH
    T_bg_enh = T(params.m - params.backgroundAmount + 1:end, 1: params.m - params.backgroundAmount);
    T_bg_enh(T_bg_enh < BG_MIN_ENH) = BG_MIN_ENH;
    T(params.m - params.backgroundAmount + 1:end, 1: params.m - params.backgroundAmount) = T_bg_enh;

    % startT
    if sum(startT(params.m - params.backgroundAmount + 1 : end), 1) < BG_START_T
        startT(params.m - params.backgroundAmount + 1 : end) = BG_START_T /  params.backgroundAmount;
    end

    s = sum(G, 2) + sum(T, 2);
    T = T ./ repmat(s, [1, params.m]);
    G = G ./ repmat(s, [1, params.k]);
    startT = startT ./ sum(startT, 1);
    assert(all(abs(sum(G, 2) + sum(T, 2) - 1) < 0.000001, 1));
    assert(abs(sum(startT, 1) - 1) < 0.000001);
    % assert(all(params.maxG(:) >= G(:) >= params.minG(:)));
    % assert(all(params.maxT(:) >= T(:) >= params.minT(:)));
    fprintf('%d/%d (G) and %d/%d (T) changed in bounding process\n', sum(sum(originG ~= G, 2), 1), params.m * params.k, sum(sum(originT ~= T, 2), 1), params.m ^ 2);
    G = log(G);
    T = log(T);
    startT = log(startT);

    assert(not(any(isnan(T(:)))));
    assert(not(any(isnan(G(:)))));
    assert(not(any(isnan(startT(:)))));
    assert(isreal(T));
    assert(isreal(G));
    assert(isreal(startT));
end

