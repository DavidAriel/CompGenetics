% cd /cs/stud/boogalla/projects/CompGenetics/mm9Genome
% load('/cs/cbio/tommy/Enhancers/Data/genome_mm9.mat');
% load('/cs/stud/boogalla/Work/data/mat/peaks_raw.mat');
% negSeqs = readSeq('/cs/cbio/tommy/Enhancers/Data/NEnhancers.seq', 500);
% negSeqs = sortBaseContent(negSeqs);
% reader(T, genome, negSeqs);
function reader(peaks, genome, negSeqs)
    close all;
    % profile on
    format compact

    params = [...
              0.005, 1, 0.05, 1, 0.05, 1, 3000;...
              0.03, 1, 0.05, 1, 0.05, 1, 3000;...
              0.02, 1, 0.05, 1, 0.05, 1, 3000;...
              0.1, 1, 0.05, 1, 0.05, 1, 3000;...
              15000, 2, -1, 3, 0.05, 3, 3000;...
              10000, 2, -1, 3, 0.05, 3, 3000;...
              1000.1, 2, -1, 3, 0.05, 3, 3000;...
             ];
    ga(@(x) readParam(x, peaks, genome, negSeqs), 7,[], [], [], [],...
         [0,0,0,0,0,0,1000], [0.2,1,0.1,1,0.1,1,5000] )
    % for j = 1:size(params, 1)
    %     tic
    %     fprintf('Params #%d\n', j);
    %     readParam(params(j,:), peaks, genome, negSeqs);
    %     toc
    % end
end
function err = readParam(param, peaks, genome, negSeqs)
    fprintf('%.3f ', param)
    fprintf('\n');
    fid = fopen('/cs/stud/boogalla/projects/CompGenetics/mm9Genome/peaksOutput.csv', 'a');
    seqsLength = 500;
    N = length(peaks); %23
    overlaps = []; from = []; to = []; chr = {};
    for i = 1 : N
        enhancers = filterPeaks(peaks(i), param);

        M = length(enhancers.height);
        overlapsAdd = zeros(M, N);
        overlapsAdd(:, i) = 1;

        overlaps = cat(1, overlaps, overlapsAdd);
        from = cat(1, from, enhancers.from.');
        to = cat(1, to, enhancers.to.');
        chr = cat(2, chr, enhancers.chr);
    end

    [overlaps, from, to, chr] = merge(overlaps, from, to, chr, seqsLength);
    if isempty(to)
        err = inf;
        return
    end
    posSeqs = getSeqs(from, to, chr, genome);
    % filter bad reads from posSeqs
    % from(any(posSeqs > 4, 2)) = [];
    % to(any(posSeqs > 4, 2)) = [];
    % chr(any(posSeqs > 4, 2)) = [];
    overlaps(any(posSeqs > 4, 2), :) = [];
    posSeqs(any(posSeqs > 4, 2), :) = [];

    fprintf('%d\n', size(posSeqs, 1));

    peaksPath = ['/cs/cbio/david/data/peaks_output/peaks_', num2str(j), '.mat'];
%     save(peaksPath, 'posSeqs', 'overlaps', 'from', 'to', 'chr');
    [MMmean, MMvar, amounts] = learn(posSeqs, negSeqs, overlaps);
    err = MMmean(1);
    fprintf(fid, '%2.3f, ', param);
    for i = 1:length(amounts)
        fprintf(fid, '%.3f, ', MMmean(i));
        fprintf(fid, '%d, ', amounts(i));
    end
    fprintf(fid, '\n');
    fclose(fid);
end


function seqs = getSeqs(from, to, chr, genome)
    chrU = unique(chr);
    seqs = ones(length(from), to(1) - from(1));
    for i = 1:length(chrU)
        chrMask = ismember(chr, chrU{i});
        chromo = genome.(chrU{i});  
        ranges = genRanges(from(chrMask).', to(chrMask).');
        seqs(chrMask, :) = nt2int(upper(chromo(ranges)));
    end
end

% assumes ranges are with same lengths
function ranges = genRanges(lows, highs)
    n = cumsum([1;highs(:) - lows(:)]);
    z = ones(n(end)-1,1);
    z(n(1:end-1)) = [lows(1),lows(2:end)-highs(1:end-1)];
    rangesV = cumsum(z);
    ranges = reshape(rangesV, [highs(1) - lows(1), length(lows)]).';
end

function peaks = filterPeaksAux(peaks, mask)
    if exist('peaks.gTSSdist', 'var')
        peaks.gTSSdist = peaks.gTSSdist(mask);
    end
    peaks.chr = peaks.chr(mask);
    peaks.to = peaks.to(mask);
    peaks.from = peaks.from(mask);
    peaks.height = peaks.height(mask);
end

function filtered = filterPeaks(peaks, params)
    % distance
    distal = abs(peaks.H3K27ac.gTSSdist) > params(7);
    peaks.H3K27ac = filterPeaksAux(peaks.H3K27ac, distal);

    % height
    peaks.H3K27ac = filterHeight(peaks.H3K27ac, params(1), params(2));
    
    if params(3) < 0 || params(5) < 0
        filtered = peaks.H3K27ac;
        return;
    end
    
    peaks.H3K4me1 = filterHeight(peaks.H3K4me1, params(3), params(4));
    peaks.H3K4me3 = filterHeight(peaks.H3K4me3, params(5), params(6));
    meMask = [];
    chrs = unique(peaks.H3K27ac.chr);
    for c = 1 : length(chrs)
        acChrMask = ismember(peaks.H3K27ac.chr, chrs{c});
        m1ChrMask = ismember(peaks.H3K4me1.chr, chrs{c});
        m3ChrMask = ismember(peaks.H3K4me3.chr, chrs{c});
        if sum(m1ChrMask) == 0
            continue;
        end
        acChrPos = (peaks.H3K27ac.to(acChrMask) + peaks.H3K27ac.from(acChrMask)) ./ 2;
        m1ChrPos = (peaks.H3K4me1.to(m1ChrMask) + peaks.H3K4me1.from(m1ChrMask)) ./ 2;
        m3ChrPos = (peaks.H3K4me3.to(m3ChrMask) + peaks.H3K4me3.from(m3ChrMask)) ./ 2;
        acL = length(acChrPos);
        m1L = length(m1ChrPos);
        m3L = length(m3ChrPos);
        acM1 = min(abs(repmat(acChrPos.', [1, m1L]) - repmat(m1ChrPos, [acL, 1])), [], 2);
        acM3 = min(abs(repmat(acChrPos.', [1, m3L]) - repmat(m3ChrPos, [acL, 1])), [], 2);
        if m1L == 0 || m3L == 0
            filtered = peaks.H3K27ac;
            return;
        end

        meMaskChr = acM3 > 3000 & acM1 < 3000;
        chrIndices = find(acChrMask);
        meMask = cat(1,meMask, chrIndices(meMaskChr).');
    end
    filtered = filterPeaksAux(peaks.H3K27ac, meMask);

end
function peaksSet = filterHeight(peaksSet, threshold, thresholdType)
    [vals, ord] = sort([peaksSet.height], 'descend');
    mask = ord(1:ceil(length(peaksSet.height) * threshold));
    % switch thresholdType
    %     case 1
    %         mask = ord(1:ceil(length(peaksSet.height) * threshold));
    %     case 2
    %         mask = ord(1:threshold);
    %     case 3
    %         mask = ord(vals > threshold);
    % end
    peaksSet = filterPeaksAux(peaksSet, mask);
end
function [overlapsOut, fromOut, toOut, chrOut] = merge(overlaps, from, to, chr, seqsLength)
    chrU = unique(chr);
    fromOut = []; toOut = []; overlapsOut = []; chrOut = {};
    for i = 1:length(chrU)
        indices = find(ismember(chr, chrU{i}));
        fromC = from(indices);
        toC = to(indices);
        overlapsC = overlaps(indices, :);
        [~, ord] = sort(fromC);
        
        % sort
        fromC = fromC(ord);
        toC = toC(ord);
        overlapsC = overlapsC(ord, :);
        
        M = 0;
        while M ~= size(fromC, 1) & size(fromC, 1) > 1
            M = size(fromC, 1);
            % mark to merge
            toMerge = false(M, 1);
            toMerge(2:end) = fromC(2:end) < toC(1:end-1);
            toMerge(2:end) = diff(toMerge) > 0;

            % merge 
            overlapsC(1:end-1, :) = overlapsC(1:end-1, :) + ...
                bsxfun(@times, overlapsC(2:end, :),toMerge(2:end));
            fromC([toMerge(2:end);false]) = min([fromC([toMerge(2:end); false]), fromC(toMerge)], [], 2);
            toC([toMerge(2:end);false]) = max([toC([toMerge(2:end); false]), toC(toMerge)], [], 2);

            % remove merged
            overlapsC(toMerge, :) = [];
            fromC(toMerge) = [];
            toC(toMerge) = [];
        end
        fromOut = cat(1, fromOut, fromC);
        toOut = cat(1, toOut, toC);
        overlapsOut = cat(1, overlapsOut, overlapsC);
        [chrOut{end+1:end+length(fromC)}] = deal(chrU{i});
    end
    seqsLengthHalf = ceil(seqsLength / 2);
    centers = ceil((fromOut + toOut) / 2);
    fromOut = centers - seqsLengthHalf;
    toOut = centers + seqsLengthHalf;
    overlapsOut = overlapsOut > 0;
end