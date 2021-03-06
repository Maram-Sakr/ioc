colorVec = [0,0.6,0;  ...
            0,0.9,0;  ...
            0.7,0.95,0;  ...
            1,0.9,0;  ...
            1,0.75,0;  ...
            1,0.55,0;  ...
            1,0.1,0.1;  ...
            0.95,0,0.6;  ...
            0.4,0.1,0.7;  ...
            0,0.5,1;  ...
            0,0.9,0.95;  ...
            0,1,0.9]; ...

colorVec = [0,0.5,0; 0,0.8,0; 0.7,0.95,0; 1,0.8,0.1; 1,0.55,0; ...
            0.9,0,0.55; 0.4,0.1,0.7; 0.8,0.7,1; 0,0.5,0.9; 0,0.85,1; ...
            0.5,0.85,0.45; 0.7,0.6,0.2; 0.9,0.7,0.5; 0.8,0.4,0.3; 0.6,0.5,0.7; ...
            1,0,0; 0,1,0; 0,0,1; 1,1,0; 1,0,1; 0,1,1];
        
% colorVec = [0.1,0.1,1; 0.8,0.7,1; 0,0.9,0; 1,0.8,0.1; 1,0.1,0];

figure(1); clf; hold on;
for i = 1:size(colorVec,1)
    plot([0,size(colorVec,1)],[i,i],'LineWidth',10,'Color',colorVec(i,:));
end

