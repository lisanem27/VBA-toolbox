%------------------------------------------------------------
% Copyright (C) 2012 Jean Daunizeau / License GNU GPL v2
%------------------------------------------------------------

clear all
close all


beta = 1;
s2 = 1e-1;
n = 10;

N = 1e2;

options.inG.X = ones(n,1);
options.DisplayWin = 0;
options.verbose =0;
options.priors.muPhi = 0;
options.priors.SigmaPhi = 1;
dim.n_phi = 1;
dim.n = 0;
dim.n_theta = 0;
g_fname = @g_GLM;
o1 = options;
o0 = options;
o0.priors.SigmaPhi = 0;

LBF = zeros(N,2);

for i=1:N
    
    i
    
    y0 = 0 + sqrt(s2).*randn(n,1);
    y1 = beta + sqrt(s2).*randn(n,1);
    
    
    [p1,ou1] = VBA_NLStateSpaceModel(y0,[],[],g_fname,dim,o1);
    
    [p0,ou0] = VBA_NLStateSpaceModel(y0,[],[],g_fname,dim,o0);
    
    LBF(i,1) = ou1.F - ou0.F;
    
    
    [p1,ou1] = VBA_NLStateSpaceModel(y1,[],[],g_fname,dim,o1);
    
    [p0,ou0] = VBA_NLStateSpaceModel(y1,[],[],g_fname,dim,o0);
    
    
    LBF(i,2) = ou1.F - ou0.F;
    
end