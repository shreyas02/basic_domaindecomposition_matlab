% One level Additive Shcwarz method

clc
clear all

%% Finite element matrix construction  

% Length of the domain
L = 1 ;
% Number of elements
nElem = 9 ;
% Number of nodes per element
nne = 2 ;
% Source term 
f = 1 ;
% Boundary nodes
BCNodes = [1; nElem+1];
BCValues = [0; 0];

% Coordinates of the nodes
crd = [0:L/nElem:L]';

% Connectivity matrix of the elements
conn = zeros(nElem,nne); 
nn = 1;
for i=1:nElem
    nn = nn-1;
    for j=1:nne
        nn = nn+1; 
        conn(i,j) = nn;
    end
end

% Definition of Gauss Quadrature and Shape Function Space

% Location of Gauss points
gP = [-1/sqrt(3), 1/sqrt(3)] ;
% Weights of Gauss points
gW = [1,  1] ;
% Number of Gauss points
nQuad = length(gW) ;
% Shape functions
N(1,:) = 0.5.*(1-gP(1,:)) ;
N(2,:) = 0.5.*(1+gP(1,:)) ;
% Gradient of shape functions
Nx(1,:) = -0.5.*ones(1,2) ;
Nx(2,:) =  0.5.*ones(1,2) ;

% Formation of Local to Global DOF Mapping

ii = zeros(nne^2*nElem,1); 
jj = zeros(nne^2*nElem,1);
index = 0;
for i = 1:nne
   for j = 1:nne
      ii(index+1:index+nElem) = double(conn(:,i)); 
      jj(index+1:index+nElem) = double(conn(:,j));  
      index = index + nElem;
   end
end

%Initialization of Solution Vector 
ndof = size(crd,1) ;
Sol.u = zeros(ndof,1);

% Satisfy boundary conditions
Sol.u(BCNodes) = BCValues ;

% Initialization for Element-level Calculations 

xx = zeros(size(conn));
yy = zeros(size(conn));

for i=1:nne
   xx(:,i) = crd(conn(:,i),1);
end

%%%%% Element-level Evaluation of Matrices %%%%%conn

% Gauss quadrature loop
for p = 1:nQuad  
    
    % Jacobian evaluation and its absolute value
    J = [xx*Nx(:,p)];
    absJac = abs(J);
    
    % Evaluation of gradients of shape functions
    DNDx = (1./absJac)*Nx(:,p)' ;  
            
    index = 0;
    for i = 1:nne
        for j = 1:nne
            
            % Galerkin diffusion term
            Kij = gW(p)*(DNDx(:,i).*DNDx(:,j));
            Kij = Kij.*absJac;
            sK(index+1:index+nElem,p) = Kij; 
                    
            % Galerkin source term
            Fij = gW(p)*(N(i,p)*N(j,p));
            Fij = Fij.*absJac ;
            sF(index+1:index+nElem,p) = Fij;

            index = index + nElem;
        end
    end
end

% Summation of All Quadrature Data for Numerical Integration
sK = sum(sK,2);
sF = sum(sF,2);

%Assembly of Local Matrices to Global Matrix 
K= sparse(ii,jj,sK,ndof,ndof); 
F_global = sparse(ii,jj,sF,ndof,ndof); 

%Defining force matrix 
F = F_global*(f.*ones(ndof,1)) ;

%%%%% Incorporating Boundary Conditions to the RHS %%%%%
F = F - K*Sol.u ;

% Selecting unknown degrees of freedom for solution
unKnowns = setdiff([1:ndof]',BCNodes) ;

K = K(unKnowns,unKnowns);
F = F(unKnowns);

%% Additive Schwarz method 

% Number of elements in overlapping domain 1 
n1 = 7;

% Number of elements in overlapping domain 2 
n2 = 5;

% Restriction matrice - 1
I1 = ones(1,n1);
I1 = diag(I1);
Z1 = zeros(n1,nElem-1-n1);
R1 = [I1,Z1];

% Restriction matrice - 2
I2 = ones(1,n2);
I2 = diag(I2);
Z2 = zeros(n2,nElem-1-n2);
R2 = [Z2,I2];

%computations of local stiffness matrices 

K1 = R1*K*R1'; 
K2 = R2*K*R2';

%Partition of unity matrix 
D1 = [1,1,1,0.5,0.5,0.5,0.5];
D1 = diag(D1);
D2 = [0.5,0.5,0.5,0.5,1];
D2 = diag(D2);


% calculating the preconditioner 
P1 = R1'*D1*inv(K1)*R1;
P2 = R2'*D2*inv(K2)*R2;
P = P1 + P2;

% iteration loop starts 
for i=1:100
    % calculating residual 
    r = F - K*Sol.u(unKnowns);
    norm(r)
    %fixed point iteration 
    Sol.u(unKnowns) = Sol.u(unKnowns) + P*r;
    if(norm(r)<0.1 && i > 1)
        break
    end
end

%% post processing 

% Exact solution
x_Refined = [0:L/1000:L]';
u_exact = -(f/2).*x_Refined.^2 + (f*L/2).*x_Refined ;

figure(1);
plot(crd,Sol.u,':sk',x_Refined,u_exact,'-r','LineWidth',3,'MarkerSize',15);
set(gca,'TickLabelInterpreter','latex','FontSize',30);
xlabel('$x$','Interpreter','latex');
ylabel('$u$','Interpreter','latex');
legend('Numerical','Exact','Interpreter','latex');



