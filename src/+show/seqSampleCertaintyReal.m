% sample sequences, and draw for each colorful plots with what the posterior
% probability was compared to the correct state per letter
function seqSampleCertaintyReal(params, theta, dataset, outpath, tissueEIDs)
    fprintf('Showing real sequences and their epigenomics')
    [N, L] = size(dataset.X);
    % gamma - N x m x L
    % psi - N x m x k x L
    [~, ~, ~, ~, gamma, psi] = EM.EStep(params, theta, dataset.X, dataset.pcPWMp);
    % N x m x L
    posterior = calcPosterior(params, gamma, psi);
    cMap = lines(params.m);


    seqInd = 1;
    trackNames = {'H3K27ac', 'DNase'};
    % tissues x 2
    bedGraphs = misc.readAllBedGraphs(tissueEIDs, trackNames);
    YEst = misc.viterbi(params, theta, dataset.X, dataset.pcPWMp);
    for i = 1:20
        [tracks, seqInd] = getSeqWithTracks(dataset, bedGraphs, seqInd + 1);
        if seqInd == -1
            break
        end
        H3K27acTrack = tracks(:, :, 1);
        DNaseTrack = tracks(:, :, 2);
        outpathI = sprintf('%s.%s.jpg', outpath, i);
        figure('units', 'pixels', 'Position', [0 0 1000 1000]);
        % N x L x 2
        PwmVal = params.m + 1;

        % LOW PLOT
        subplot(3, 1, 3);
        hold on;
        plotProbabilityMap(params, permute(posterior(seqInd, :, :), [2, 3, 1]), YEst(seqInd, :, :), cMap, ...
                           dataset.starts(seqInd), PwmVal, dataset.chrs{seqInd});
        % LEGEND
        ax = gca;
        ax.YDir = 'normal';
        legendStrings1 = strcat({'Enhancer Type '}, num2str([1:params.m - params.backgroundAmount]'));
        legendStrings2 = strcat({'Background '}, num2str([1:params.backgroundAmount]'));
        legendStrings = {legendStrings1{:}, legendStrings2{:}};
        legendStrings{PwmVal} = 'TFBS';
        legend(legendStrings);

        % HIGH PLOT
        subplot(3, 1, 1);
        set(gca,'xtick',[]);
        title('Posterior & Viterbi Estimation');
        text(L + 1, 0.5, 'H3K27ac', 'FontSize', 10);
        plotHandle = plot(1:L, H3K27acTrack', 'LineWidth', 1.5);
        cellCMap = {};
        for i = 1:size(H3K27acTrack, 1)
            cellCMap{i, 1} = cMap(i, :);
        end
        set(plotHandle, {'Color'}, cellCMap);
        xlim([1, L]);
        ylim([0, max(H3K27acTrack(:))]);
        ylabel('-log_{10}(p-value)');

        % MIDDLE PLOT
        subplot(3, 1, 2);
        set(gca,'xtick',[]);
        text(L + 1, 0.5, 'DNase', 'FontSize', 10);
        p = plot(1:L, DNaseTrack', 'LineWidth', 1.5);
        cellCMap = {};
        for i = 1:size(DNaseTrack, 1)
            cellCMap{i, 1} = cMap(i, :);
        end
        set(p, {'Color'}, cellCMap);
        xlim([1, L]);
        ylim([0, max(DNaseTrack(:))]);
        ylabel('-log_{10}(p-value)');
        saveas(gcf, outpath);
    end
end

% tracks - tissues x L x tracks
function [tracks, seqInd] = getSeqWithTracks(dataset, bedGraphs, startInd)
    N = size(dataset.X, 1);
    for seqInd = startInd:N
        % fprintf('Trying sequence %d\n', seqInd)
        tracks = getTracks(dataset, bedGraphs, seqInd);
        if all(all(any(tracks > 0, 2), 1), 3)
            fprintf('Found seq %d\n', seqInd);
            return;
        end
    end
    fprintf('No sequence found with enough data in its track');
    seqInd = -1;
end

% tracks - tissues x L x tracks
function tracks = getTracks(dataset, bedGraphs, seqInd)
    L = size(dataset.X, 2);
    chr = dataset.chrs{seqInd};
    to = dataset.starts(seqInd) + L;
    from = dataset.starts(seqInd);
    tracks = zeros(size(bedGraphs, 1), L, size(bedGraphs, 2));
    for trackInd = 1:size(bedGraphs, 2)
        for i = 1:size(bedGraphs, 1)
            fprintf('looking for track %d of sequence %d %s[%d:%d], for tissue index %d\n', ...
                    trackInd, seqInd, chr, from, to, i);
            tracks(i, :, trackInd) = getTrack(bedGraphs{i, trackInd}, chr, from, to);
            if all(tracks(i, :, trackInd) == 0)
                return;
            end
        end
    end
end


% YEst - 1 x L x 2
% probMap - m x L
function plotProbabilityMap(params, probMap, YEst, cMap, start, PwmVal, chr)
    BARS_PLOT_DARKNESS_FACTOR = 0.85;
    LOW_BAR_HIEGHT = 0.1;
    PWM_COLOR = [0, 0, 0];

    cMapWithError = [cMap;  PWM_COLOR];
    % probMap = permute(probMap, [2, 3, 1]);
    L = size(YEst, 2);
    hold on;
    % if params.m >= size(probMap, 1) >= params.m - params.backgroundAmount
    % m x L
    YEstOneHot = matUtils.vec2mat(YEst(:, :, 1), params.m);
    selectedProb = probMap .* YEstOneHot(1:size(probMap, 1), :);
    % m + 1 x L
    barHandle = bar(start: start + L - 1, selectedProb', 1, 'stacked', 'FaceColor', 'flat');
    for j = 1:size(selectedProb, 1)
        barHandle(j).CData = cMap(j, :) * BARS_PLOT_DARKNESS_FACTOR;
    end
    % end

    plotHandle = plot(start: start + L - 1, probMap', 'LineWidth', 1.5);
    cellCMap = {};
    for i = 1:size(probMap, 1)
        cellCMap{i, 1} = cMap(i, :);
    end
    set(plotHandle, {'Color'}, cellCMap);
    rotateYLabel();


    % Comma separated ticks
    xlim([start, start + L - 1]);
    ax = gca;
    ax.XAxis.Exponent = 0;
    xtickformat('%,d');

    YEstColored = YEst;
    YEstColored(:, YEst(:, :, 2) > 0, 1) = PwmVal;
    imagesc([start - .5, start + L - 1.5], [-3 * LOW_BAR_HIEGHT / 4, -LOW_BAR_HIEGHT / 4], ...
            [YEstColored(:, :, 1); YEstColored(:, :, 1)], [1, PwmVal]);
    ylim([-LOW_BAR_HIEGHT, 1]);
    colormap(cMapWithError);
    text(L + 1, 0.5, 'Posterior Prob.', 'FontSize', 10);
    text(L + 1, -LOW_BAR_HIEGHT / 2, 'Viterbi Est.', 'FontSize', 10);
    xlabel(sprintf('Position in %s', chr));
    ylabel('P(y_{t}|X)');
end


function rotateYLabel()
    ylh = get(gca,'ylabel');
    gyl = get(ylh);
    ylp = get(ylh, 'Position');
    set(ylh, 'Rotation', 0, 'Position', ylp, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right');
end


% posterior - N x m x L
function posterior = calcPosterior(params, gamma, psi)
    N = size(gamma, 1);
    posterior = gamma;
    for l = 1:params.k
        for t = 1:params.lengths(l)
            subStatePost = permute(cat(4, -inf(N, params.m, 1, t), psi(:, :, l, 1:end-t)), [1,2,4,3]);
            posterior = matUtils.logAdd(posterior, subStatePost);
        end
    end
    posterior = exp(posterior);
end



function ret = getTrack(bedGraph, trackChr, trackFrom, trackTo)
    MIN_SAMPLES_IN_SEQ = 100;
    mask = strcmp(bedGraph.chrs, trackChr) & (bedGraph.tos >= trackFrom) & (bedGraph.froms <= trackTo);
    % dilation of bin vector
    mask = [mask(2:end); false] | mask | [false; mask(1:end-1)];
    % linear interpa
    foundSamples = sum(mask);
    fprintf('Found %d sample points in (%s:%d-%d)\n', foundSamples, trackChr, trackFrom, trackTo);
    if foundSamples < MIN_SAMPLES_IN_SEQ
        ret = zeros(trackTo - trackFrom, 1);
        fprintf('%d < %d, not enough samples in sequence', foundSamples, MIN_SAMPLES_IN_SEQ);
        return
    end
    knownPoints = double([(bedGraph.tos(mask) + bedGraph.froms(mask)) / 2]');
    knownVals = bedGraph.vals(mask)';
    [knownPoints, inds] = unique(knownPoints);
    knownVals = knownVals(inds);
    wantedPoints = double([trackFrom : trackTo - 1]);
    ret = interp1(knownPoints, knownVals, wantedPoints);
end

