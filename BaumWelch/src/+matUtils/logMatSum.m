function ret = logMatSum(A, dim)
    sizeA = size(A);
    sizeRet = sizeA;
    sizeRet(dim) = 1;
    ret = -inf(sizeRet);
    for i = 1:size(A, dim)
        ret = matUtils.logAdd(ret, arraySlice(A, i, dim));
    end
end

function S = arraySlice(A, I, d)
    if length(size(A)) == 3
        if d == 1
            S = A(I, :, :);
        elseif d == 2
            S = A(:, I, :);
        else
            S = A(:, :, I);
        end
        return;
    end
    s1 = size(A); s2 = size(A); s3 = size(A);
    s1(d) = I-1;
    s2(d) = 1;
    s3(d) = s3(d)-I;
    S = zeros(s2);
    S(:) = A(cat(d, false(s1), true(s2), false(s3)));
end
