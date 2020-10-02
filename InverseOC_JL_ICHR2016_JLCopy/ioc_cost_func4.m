function [J, A, x, b, J_cost_combined] = ioc_cost_func(z_init, c_use, J_cost_all, J_const_all, c_const, param)
% IOC cost function calc. combine the matrices generated by setup_ioc into
% the form that the pivot requires
[lambda_use_cell] = vec2mat_multi(z_init, param.matVec_struct);

lambda_use = mat2vec(lambda_use_cell{1});

J_cost_combined = horzcat(J_cost_all{:}); 
J_const_combined = horzcat(J_const_all{:}); 

% calculate the cost function side of the eq'n
J_b = J_cost_all{param.pivotTerm}; % pull out the pivot term
J_cost_all{param.pivotTerm} = []; % the nth term is the pivot, don't include it (ie J_coeff_ddq)
A_cost = horzcat(J_cost_all{:}); 

% calculate the const function side fo the eq'n
% J_coeff_constBlk = blkdiag(J_coeff_const{:}); 
% A = blkdiag(A_cost, zeros(size(J_coeff_constBlk))); % include the constraints base
% b = [J_b; zeros(size(J_coeff_constBlk, 1), 1)];

b = J_b;
b = b - A_cost*c_use;

% now deal with the constraints. merge the two matrices
A = horzcat(J_const_all{:});

%  set up the x array
len_constx = length(param.const_x);
len_constdx = length(param.const_dx);
len_constddx = length(param.const_ddx);
set_x = 1:len_constx;
set_dx = len_constx+(1:len_constdx);
set_ddx = len_constx+len_constdx+(1:len_constddx);
x = [];
for ind_const = 1:length(J_const_all)
    if sum(eq(set_x, ind_const))
        % q
        c_const_use = c_const(1);
    elseif sum(eq(set_dx, ind_const))
        % dq
        c_const_use = c_const(2);
        
    elseif sum(eq(set_ddx, ind_const))
        % ddq
        c_const_use = c_const(3);
    end
    
    x = [x; c_const_use*lambda_use(ind_const)];
end

J = A*x + b;

% check for length and width of A
heightX = length(x);
heightA = size(J_cost_combined, 1);

if heightA < heightX % the A matrix is 'wide'. apply regulariation
    J = J + (1e-9)*norm(x);
else % else square, or 'tall' matrix
    % don't do anything
end
end