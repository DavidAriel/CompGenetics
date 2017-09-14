% This model assumes m modes bases that emits like high order HHM,
% where each base can transfer into k submodes that emits with PWM from JASPAR project
% m - sum of enhancer and background modes (not a parameter)
% T - m x m transfer probability matrix between mode bases
% theta.G - m x k transfer probability matrix between mode bases and their PWM modes
% theta.F - m x 1 probability to get into a PWM mode per state.
% n - number of alphabet (4, i.e. ACGT)
% startT - m x 1 probabilities of first states
% theta.E - m x n x n x ... x n (order times) alphabet emission probability matrix
% pcPWMp - N x k x L
% lengths - m x 1 length of each motif in the PWM matrix. J = max(lengths)
% X - N x L emission variables
% alpha - N x m x L
function alpha = forwardAlgJ(X, theta, params, pcPWMp)
    [N, L] = size(X);
    matSize = [params.m , params.n * ones(1, params.order)];
    % m x L
    kronMN = kron(1:params.m, ones(1, N));
    compF = repmat(log(1-exp(theta.F))', [N, 1]);
    Gs = repmat(shiftdim(theta.G, -1), [N, 1, 1]);
    Fs = repmat(theta.F.', [N, 1, params.k]);
    expT = exp(theta.T);
    % the k+1 index is for base modes, 1 to k are for sub modes
    alpha = -inf(N, params.m, L + params.J);
    % N x m
    Ep = BaumWelchPWM.EM.getEp(theta, params, X, 1, kronMN, matSize);
    alpha(:, :, params.J+1) = (repmat(theta.startT', [N, 1]) + Ep);

    % if length is 3, J = 4
    % then B is the base mode, S is the submode (PWM mode)
    % 654321t     - indices
    % BBBBSSS???? - hidden
    % XXXX123???? - emission
    for t = 2:L
        % fprintf('Forward algorithm %.2f%%\r', 100*t/L);
        % N x m
        Ep = BaumWelchPWM.EM.getEp(theta, params, X, t, kronMN, matSize);
        % N x m
        % N x m * m x m
        baseStateStep = matUtils.logMatProd(alpha(:, :, params.J+t-1) + compF, theta.T) + Ep;
        % N x m x k
        alphaSlice = alpha(:, :, params.J+t-theta.lengths-1);
        % N x m
        subStateStep = BaumWelchPWM.EM.PWMstep(alphaSlice, Gs, t-theta.lengths', pcPWMp, repmat(Ep, [1, 1, params.k]), Fs);

        alpha(:, :, params.J + t) = matUtils.logAdd(baseStateStep, subStateStep);
    end
    % fprintf('\n');
    alpha = alpha(:, :, params.J+1:end);
end
