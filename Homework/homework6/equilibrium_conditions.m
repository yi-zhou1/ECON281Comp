% Inputs:  (1) vars: vector which contains the variables in the system, the time derivatives of 
%			         those variables, the expectational errors, and the shocks
%
% Outputs: (1) vResduals: residuals of equilibrium conditions, evaluated at vars

function vResidual = equilibrium_conditions(vars)

%----------------------------------------------------------------
% Housekeeping
%----------------------------------------------------------------

call_parameters;
% create structure with numerical parameters
numerical_parameters;
% create structure with grids and initial guesses for v
grid = create_grid(param,num);


% Declare global variables
global ggamma rrho ddelta aalpha ssigmaTFP rrhoTFP z lla mmu ttau I amin amax a da aa ...
	zz rmin rmax r0 maxit crit Delta Ir crit_S IfSS IbSS I0SS aaa zzz varsSS zAvg nVars nEErrors l_supply
	
% Unpack vars
V=vars(1:2*I) + varsSS(1:2*I);
g=vars(2*I+1:4*I-1) + varsSS(2*I+1:4*I-1);	% vector of distribution, removing last point		
g_end=1/grid.da-sum(g);		% ensures that distribution integrates to 1
logAggregateTFP = vars(4*I);
KHat = vars(4*I+1) + varsSS(4*I+1);
rHat = vars(4*I+2) + varsSS(4*I+2);
wHat = vars(4*I+3) + varsSS(4*I+3);
output = vars(4*I+4) + varsSS(4*I+4);
C = vars(4*I+5) + varsSS(4*I+5);
investment = vars(4*I+6) + varsSS(4*I+6);
    % order matters here, must be consistent throughout the code

V = reshape(V,I,2);

VDot = vars(nVars+1:nVars+2*I);
gDot = vars(nVars+2*I+1:nVars+4*I-1);
logAggregateTFPDot = vars(nVars+4*I);

VEErrors = vars(2*nVars+1:2*nVars+2*I);

aggregateTFPShock = vars(2*nVars+nEErrors+1);

% Initialize other variables, using vars to ensure everything is a dual number
dVf = V;
dVb = V;

%K = sum(aaa .* [g;g_end] * da);
K = sum(grid.aa .* [g;g_end] .* grid.da);
r = exp(logAggregateTFP) * param.alpha * (KHat ^ (param.alpha - 1)) * (l_supply ^ (1 - param.alpha)) - param.delta;
w = exp(logAggregateTFP) * (1 - param.alpha) * (KHat ^ param.alpha) * (l_supply ^ (-param.alpha)); 

%----------------------------------------------------------------
% Compute one iteration of HJB Equation
%----------------------------------------------------------------

%{
c0 = w * ((1 - ttau) * zz + mmu * (1 - zz)) + r * aa;

% Compute forward difference
dVf(1:I-1,:) = (V(2:I,:)-V(1:I-1,:))/da;
dVf(I,:) = c0(I,:) .^ (-ggamma); %will never be used, but impose state constraint a<=amax just in case

% Compute backward difference
dVb(2:I,:) = (V(2:I,:)-V(1:I-1,:))/da;
dVb(1,:) = c0(1,:) .^ (-ggamma); %state constraint boundary condition


% Compute consumption and savings with forward difference
cf = dVf.^(-1/ggamma);
ssf = c0 - cf;

% Compute consumption and savings with backward difference
cb = dVb.^(-1/ggamma);
ssb = c0 - cb;

% Compute consumption and derivative of value function for no drift
dV0 = c0.^(-ggamma);

% Compute upwind difference
dV_Upwind = dVf.*IfSS + dVb.*IbSS + dV0.*I0SS;
c = dV_Upwind.^(-1/ggamma);
u = c.^(1-ggamma)/(1-ggamma);
savings = c0 - c;

% Construct A matrix
X = -ssb.*IbSS/da;
Y = -ssf.*IfSS/da + ssb.*IbSS/da;
Z = ssf.*IfSS/da;

X(1,:)=0;
lowdiag=reshape(X,2*I,1);
Z(I,:)=0;

A = spdiags(reshape(Y,2*I,1),0,2*I,2*I)...
    +spdiags(lowdiag(2:2*I),-1,2*I,2*I)...
    +spdiags([0,reshape(Z,1,2*I)]',1,2*I,2*I)...
    +Aswitch;
%}

c0=w*param.e+r*grid.a;
% c0 = w * ((1 - ttau) * zz + mmu * (1 - zz)) + r * aa;

dVf(1:end-1,:) = (V(2:end,:) - V(1:end-1,:))/grid.da ;
dVf(end,:) = 0; 

dVb(2:end,:) = (V(2:end,:)-V(1:end-1,:))./grid.da;
dVb(1,:) = (r*grid.a(1,:) + w*param.e).^(-1);

cf = dVf.^(-1);
ssf = c0 - cf ;
%consumption and savings with backward difference
cb = dVb.^(-1);
ssb = c0 - cb ;
%consumption and derivative of value function at steady state
dV0 = c0.^(-1);

% Compute upwind difference
dV_Upwind = dVf.*IfSS + dVb.*IbSS + dV0.*I0SS;
c = dV_Upwind.^(-1);
u = utility(c);
savings = c0 - c;

% Construct A matrix
X = -ssb.*IbSS/grid.da;
Y = -ssf.*IfSS/grid.da + ssb.*IbSS/grid.da;
Z = ssf.*IfSS/grid.da;

Aswitch = [-speye(I)*param.lambda(1),speye(I)*param.lambda(1);speye(I)*param.lambda(2),-speye(I)*param.lambda(2)];

X(1,:)=0;
lowdiag=reshape(X,2*I,1);
Z(I,:)=0;

A = spdiags(reshape(Y,2*I,1),0,2*I,2*I)...
    +spdiags(lowdiag(2:2*I),-1,2*I,2*I)...
    +spdiags([0,reshape(Z,1,2*I)]',1,2*I,2*I)...
    +Aswitch;

%{
A1=spdiags(Y(:,1),0,I,I)+spdiags(X(2:I,1),-1,I,I)+spdiags([0;Z(1:I-1,1)],1,I,I);
A2=spdiags(Y(:,2),0,I,I)+spdiags(X(2:I,2),-1,I,I)+spdiags([0;Z(1:I-1,2)],1,I,I);

A = [A1,sparse(I,I);sparse(I,I),A2] + Aswitch;
%}

%----------------------------------------------------------------
% Compute equilibrium conditions
%----------------------------------------------------------------

% HJB Equation
hjbResidual = reshape(u,2*I,1) + A * reshape(V,2*I,1) + VDot + VEErrors - param.rho * reshape(V,2*I,1);

% KFE 
gIntermediate = A' * [g;g_end];
gResidual = gDot - gIntermediate(1:2*I-1,1);

% Aggregates
kResidual = K - KHat;
rResidual = r - rHat;
wResidual = w - wHat;
yResidual = output - exp(logAggregateTFP) * (K ^ param.alpha) * (l_supply ^ (1 - param.alpha));
cResidual = C - sum(c(:) .* [g;g_end] .* grid.da);
iResidual = investment - sum((savings(:) + param.delta .* grid.aa) .* [g;g_end] .* grid.da); 
%{
yResidual = output - exp(logAggregateTFP) * (sum(aaa .* [g;g_end] * da) ^ aalpha) * (zAvg ^ (1 - aalpha));
cResidual = C - sum(c(:) .* [g;g_end] * da);
iResidual = investment - sum((savings(:) + ddelta * aaa) .* [g;g_end] * da); 
%}

% Law of motion for aggregate shocks
tfpResidual = logAggregateTFPDot + (1 - rrhoTFP) * logAggregateTFP - ssigmaTFP * aggregateTFPShock;

vResidual = [hjbResidual;gResidual;tfpResidual;kResidual;rResidual;wResidual;yResidual;cResidual;iResidual];
