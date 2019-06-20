function theta = permThetaByAnother(params, thetaOrig, thetaEst)
    vectorizedOrig = misc.thetaToMat(params, thetaOrig, false);
    vectorizedEst = misc.thetaToMat(params, thetaEst, false);
    perm = matUtils.repermuteMat(vectorizedOrig, vectorizedEst);
    theta = permTheta(thetaEst, perm);
end


function theta = permTheta(theta, perm)
    theta.T = theta.T(perm, :);
    theta.T = theta.T(:, perm);
    theta.startT = theta.startT(perm);
    theta.G = theta.G(perm, :);
    for i = 1:length(perm)
        theta.E(i, :) = theta.E(perm(i), :);
    end
end