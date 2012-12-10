function [posterior,out] = VBA_groupBMC(L,options)
% VB algorithm for group-level Bayesian Model Comparison
% function [posterior,out] = VBA_groupBMC(L,options)
% IN:
%   - L: Kxn matrix of log-model evidences (K models; n subjects)
%   - options: a structure containing the following fields:
%       .priors: this variable can contain a field .a, which is the Kx1
%       vector of dummy 'prior counts' of each model (default is one per
%       class)
%       .MaxIter: max number of iterations
%       .MinIter: min number of iterations
%       .TolFun: max change in Free Energy
%       .DisplayWin: flag for display window
%       .verbose: flag for summary statistics display
%       .families: a cell array of size nf, which contains the indices of
%       the models that belong to each of the nf families. NB: using
%       families change the default prior (uniform prior on families), and
%       hence the model evidence...
% OUT:
%   - posterior: a structure containg the following fields:
%       .r: Kxn matrix of model attributions, i.e. the posterior
%       probability, for each subject, of belonging to each model.
%       .a: Kx1 vector of 'posterior counts' of each model. These are the
%       sufficient statistics of the posterior Dirichlet density on model
%       frequencies.
%   - out: structure containing the following fields:
%       .ep: Kx1 vector of model exceedance probabilities
%       .options: this is useful when using default options
%       .dt: the running time of the VB algorithm (in sec)
%       .F: the series of free energies along the VB iterations
%       .Ef/Vf: first- and second-order posterior moments of the model
%       frequencies
%       .ELJ/Sqf/Sqm: the expected log-joint, and entropies of the VB
%       marginal densities
%       .F0: the null model evidence
%       .families: a structure containing the following fields:
%           .ep: nfx1 vector of family exceedance probabilities
%           .Ef/Vf: first- and second-order posterior moments of the
%           familiy frequencies
%       .r/a: family 'posterior counts' and attributions.

[K,n] = size(L);

%-- fill in options with defaults if needed
options.tStart = tic;
if ~isfield(options,'MaxIter')
    options.MaxIter = 32;
end
if ~isfield(options,'MinIter')
    options.MinIter = 1;
end
if ~isfield(options,'TolFun')
    options.TolFun = 1e-4;
end
if ~isfield(options,'DisplayWin')
    options.DisplayWin = 1;
end
if ~isfield(options,'verbose')
    options.verbose = 1;
end
if ~isfield(options,'families')
    options.families = [];
end
if ~isfield(options,'priors')
    priors = [];
else
    priors = options.priors;
end
if isempty(priors) || ~isfield(priors,'a') || isempty(priors.a)
    priors.a = 1e0*ones(K,1);
    if ~isempty(options.families)
        nf = length(options.families);
        for i=1:nf
            indf = options.families{i};
            priors.a(indf) = 1./length(indf);
        end
    end
    options.priors = priors;
end
if ~isempty(options.families)
    nf = length(options.families);
    options.C = zeros(K,nf);
    for i=1:nf
        indf = options.families{i};
        options.C(indf,i) = 1;
    end
end

%-- initialize posterior and free energy
f0 = priors.a./sum(priors.a);
priors.r = repmat(f0,1,n);
posterior = priors;
F = FE(L,posterior,priors);

%-- enter VB iterative algorithm
stop = 0;
it = 1;
while ~stop
    it = it+1;
    % update subject attributions
    Elogr = psi(posterior.a) - psi(sum(posterior.a));
    for i=1:n
        tmp = L(:,i)+Elogr;
        g = exp(tmp-max(tmp));
        posterior.r(:,i) = g./sum(g);
    end
    % update posterior model counts
    posterior.a = priors.a + posterior.r*ones(n,1);
    % calculate Free Energy
    F(it) = FE(L,posterior,priors);
    % check stopping criteria
    stop = checkStop(it,F,options);
    if options.DisplayWin
        out = wrapUp(L,posterior,priors,F,options);
        options.handles = VBA_displayGroupBMC(posterior,out);
        drawnow
    end
end

%-- wrap up VBA output
out = wrapUp(L,posterior,priors,F,options);
try
    out.ep = VBA_ExceedanceProb(posterior.a,[],'dirichlet',0);
    if ~isempty(out.options.families)
        out.families.ep = VBA_ExceedanceProb(out.families.a,[],'dirichlet',0);
    end
catch
    disp('Warning: exceedance probabilities are approximated!')
end
out.date = clock;
if options.DisplayWin
    VBA_displayGroupBMC(posterior,out);
end

%-- display summary statistics
if options.verbose
    fprintf('\n')
    fprintf('---')
    fprintf('\n')
    fprintf(['Date: ',datestr(out.date),'\n'])
    if floor(out.dt./60) == 0
        timeString = [num2str(floor(out.dt)),' sec'];
    else
        timeString = [num2str(floor(out.dt./60)),' min'];
    end
    fprintf(['VB converged in ',num2str(it),' iterations (took ~',timeString,').','\n'])
    fprintf(['Dimensions:','\n'])
    fprintf(['     - subjects: n=',num2str(n),'\n'])
    fprintf(['     - models: K=',num2str(K),'\n'])
    if ~isempty(out.options.families)
        fprintf(['     - families: m=',num2str(nf),'\n'])
    end
    prfx = 1/(1+exp(out.F0-out.F(end)));
    fprintf(['Posterior probabilities:','\n'])
    fprintf(['     - RFX: p(H1|y)= ','%4.3f','\n'],prfx)
    fprintf(['     - null: p(H0|y)= ','%4.3f','\n'],1-prfx)
    fprintf('\n')
end


%-- subfunctions

function out = wrapUp(L,posterior,priors,F,options)
% wraps up the ou structure for display purposes
out.dt = toc(options.tStart);
out.options = options;
out.L = L;
out.F = F;
% derive first and second order moments on model frequencies:
[out.Ef,out.Vf] = Dirichlet_moments(posterior.a);
% derive exceedance probabilities (using Gaussian moment matching)
out.ep = VBA_ExceedanceProb(out.Ef,out.Vf,'gaussian');
% store accuracy and entropy terms of the Free Energy
[F,out.ELJ,out.Sqf,out.Sqm] = FE(L,posterior,priors);
% derive Free Energy under the null:
if ~isempty(options.families)
    [out.F0,out.families.F0] = FE_null(L,options);
else
    [out.F0] = FE_null(L,options);
end
% pool evidence over families
if ~isempty(options.families)
    out.families.r = options.C'*posterior.r;
    out.families.a = options.C'*posterior.a;
    [out.families.Ef,out.families.Vf] = Dirichlet_moments(out.families.a);
    out.families.ep = VBA_ExceedanceProb(out.families.Ef,out.families.Vf,'gaussian');
end



function stop = checkStop(it,F,options)
% checks stopping criteria
stop = 0;
if it<options.MinIter
    return
end
dF = F(it) - F(it-1);
if abs(dF)<=options.TolFun || it>=options.MaxIter
    stop = 1;
end



function [F,ELJ,Sqf,Sqm] = FE(L,posterior,priors)
% derives the free energy for the current approximate posterior
[K,n] = size(L);
a0 = sum(posterior.a);
Sqf = sum(gammaln(posterior.a)) - gammaln(a0) + (a0-K)*psi(a0) - sum((posterior.a-1).*psi(posterior.a));
Sqm = 0;
for i=1:n
    Sqm = Sqm - sum(posterior.r(:,i).*log(posterior.r(:,i)+eps));
end
Elogr = psi(posterior.a) - psi(sum(posterior.a));
ELJ = -sum(gammaln(priors.a)) + gammaln(sum(priors.a));
for k=1:K
    ELJ = ELJ + (priors.a(k)-1)*Elogr(k);
    for i=1:n
        ELJ = ELJ + posterior.r(k,i).*(Elogr(k)+L(k,i));
    end
end
F = ELJ + Sqf + Sqm;



function [F0m,F0f] = FE_null(L,options)
% derives the free energy of the 'null' (H0: equal model frequencies)
[K,n] = size(L);
F0m = 0;
if ~isempty(options.families)
    f0 = options.C*sum(options.C,1)'.^-1/size(options.C,2);
    F0f = 0;
else
    F0f = [];
end
for i=1:n
    tmp = L(:,i) - max(L(:,i));
    g = exp(tmp)./sum(exp(tmp));
    for k=1:K
        tmp = L(:,i);
        cst = max(tmp);
        tmp = tmp -cst;
        F0m = F0m + g(k).*(log(sum(exp(tmp)))+cst-log(K));
        if ~isempty(options.families)
            F0f = F0f + g(k).*(log(sum(exp(tmp)))+cst+log(f0(k)));
        end
    end
end



function [E,V] = Dirichlet_moments(a)
% derives the firs- and second-order moments of a Dirichlet density
a0 = sum(a);
E = a./a0;
V = -a*a';
V = V - diag(diag(V)) + diag(a.*(a0-a));
V = V./((a0+1)*a0^2);


