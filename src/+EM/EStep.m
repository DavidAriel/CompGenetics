% X - N x L
% alpha - N x m x L
% beta - N x m x L
% pX - N x 1
% xi - N x m x m x L
% gamma - N x m x L
% psi - N x m x k x L
function [alpha, beta, pX, xi, gamma, psi] = EStep(params, theta, X, pcPWMp)
    % fprintf('Running E step...\n');
    [N, L] = size(X);
    Eps = EM.getEp3d(theta, params, X, 1:L);
    fprintf('. ');
    alpha = EM.forwardAlg(X, theta, params, pcPWMp, Eps);
    assert(not(any(isnan(alpha(:)))));
    % fprintf('Calculating beta...\n')
    fprintf('. ');
    beta = EM.backwardAlg(X, theta, params, pcPWMp, Eps);
    assert(not(any(isnan(beta(:)))));
    fprintf('. ');
    % N x 1
    pX = EM.makePx(alpha, beta);
    assert(not(any(isnan(pX(:)))));
    % fprintf('Calculating Xi...\n')
    fprintf('. ');
    % xi - N x m x m x L
    xi = EM.makeXi(theta, params, alpha, beta, X, pX);
    assert(not(any(isnan(xi(:)))));
    % fprintf('Calculating Gamma...\n')
    % gamma - N x m x L
    gamma = EM.makeGamma(params, alpha, beta, pX);
    assert(not(any(isnan(gamma(:)))));
    fprintf('. ');
    % N x m x k x L
    psi = EM.makePsi(alpha, beta, X, params, theta, pcPWMp, pX);
    assert(not(any(isnan(psi(:)))));
    fprintf('. \n');
end