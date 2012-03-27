function [iQ] = VB_inv(Q,indIn,flag,v)
% overloaded sparse matrix inversion routine
% function [iQ] = VB_inv(Q,indIn,flag,v)
% IN:
%   - Q: the nxn matrix to be inverted
%   - indIn: a vector of indices that specifies the submatrix of Q that has
%   to be inverted. The rest of the matrix is padded with zeros. If empty,
%   the routine looks for infinite or below precision (close to zero)
%   entries in the the diagonal of Q.
%   - flag: if flag='replace', the routine returns Q, having replaced its
%   elements not in 'indIn' with v (see below)
%   - v: a number by which to padd the elements of Q not in 'indIn' (only
%   for flag='replace')
% OUT:
%   - iQ: the nxn matrix that is either the inverse of Q or v-padded Q (for
%   flag='replace').
%------------------------------------------------------------
% Copyright (C) 2012 Jean Daunizeau / License GNU GPL v2
%------------------------------------------------------------

if nargin < 4
    v = 0;
end
if nargin < 3
    replace = 0;
else
    replace = isequal(flag,'replace');
end
if nargin < 2 || isempty(indIn)
    dq = diag(Q);
    indIn = find(~isinf(dq)&dq~=0);%abs(dq)>=1e-8&
end
subQ = full(Q(indIn,indIn));
if replace % v-padd
    iQ = v.*ones(size(Q));
    iQ(indIn,indIn) = subQ;
else % (p)invert Q
    if isequal(subQ,eye(length(indIn))) % identity matrix
        subiQ = subQ;
    elseif isequal(subQ,diag(diag(subQ))) % diagonal matrix
        subiQ = diag(diag(subQ).^-1);
    else % full matrix
        subiQ = pinv(subQ);
    end
    iQ = zeros(size(Q));
    iQ(indIn,indIn) = subiQ;
end