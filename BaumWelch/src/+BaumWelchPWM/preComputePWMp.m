
% Xs - N x L
% pcPWMp - N x k x L
function pcPWMp = preComputePWMp(Xs)
    [PWMs, ~] = BaumWelchPWM.PWMs();
    [~, n, J] = size(PWMs);
    [N, ~] = size(Xs);
    %0 padding for handling the edges probability calculation
    Xs1H = cat(2, matUtils.mat23Dmat(Xs, n), zeros(N, J, n));
    % NxJxnxk
    pcPWMp = preComputePWMpAux(Xs1H);
end

% calculating the probability of each position in the sequences
% to be emitted by each PWM
% PWMsRep - N x J x n x k
function out = preComputePWMpAux(Xs1H)
    % pcPWMp - N x k x L
    persistent pcPWMp
    [PWMs, ~] = BaumWelchPWM.PWMs();
    [k, ~, J] = size(PWMs);
    [N, L, ~] = size(Xs1H);
    L = L - J;
    PC_PWM_PROBABILITY_FILE = fullfile('data', 'precomputation', 'pcPWMp.mat');
    if ~isempty(pcPWMp) && all(size(pcPWMp) == [N, k, L])
        % in memory
        out = pcPWMp;
        return;
    end
    if exist(PC_PWM_PROBABILITY_FILE, 'file') == 2
        fprintf('Loading pre-computed PWM from %s...\n', PC_PWM_PROBABILITY_FILE);
        load(PC_PWM_PROBABILITY_FILE, 'pcPWMp');
        if all(size(pcPWMp) == [N, k, L])
            fprintf('data size match\n');
            % loaded from file, same size
            out = pcPWMp;
            return;
        else
            delete(PC_PWM_PROBABILITY_FILE);
        end
    end
    pcPWMp = calculate(Xs1H, N, k, J, L);
    assert(not(any(isnan(pcPWMp(:)))))
    fprintf('Saving data in file %s...\n', PC_PWM_PROBABILITY_FILE);
    save(PC_PWM_PROBABILITY_FILE, 'pcPWMp', '-v7.3');
    fprintf('Done saving.\n');

    out = pcPWMp;
end

% PWMsRep - N x J x n x k
% Xs1H - N x L + J x n
% lengths - k x 1
% pcPWMp - N x k x L
function pcPWMp = calculate(Xs1H, N, k, J, L)
    fprintf('Pre-computing PWM probability on %d sequences\n', size(Xs1H, 1));
    [PWMs, lengths] = BaumWelchPWM.PWMs();
    PWMsRep = permute(repmat(PWMs, [1, 1, 1, N]), [4, 3, 2, 1]);
    mask = repmat(1:J, [N, 1, k]) > repmat(permute(lengths, [1,3,2]), [N,J,1]);
    mask = permute(mask, [1, 2, 4, 3]);
    pcPWMp = -inf(N, k, L);
    for t = 1:L
        % see c code https://github.com/yatbear/nlangp/blob/master/Baum-Welch/hmm.c
        pcPWMp(:, :, t) = BaumWelchPWM.getPWMp(J, PWMsRep, Xs1H, t, mask);
        fprintf('\r%d / %d', t, L);
        if any(isnan(pcPWMp(:)))
            keyboard
        end
    end
    fprintf('\nDone calculating\n');
end