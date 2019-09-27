%Full Body LG EKF and EUL EKF for the boxing CMU data
%Load up the generated model
clear vis; close all;

% EKFCodePath = 'C:\Users\kgwester\Documents\ResearchWork\CloudSLAM\lg_persontracking\';
EKFCodePath = 'C:\Users\kgwester\Documents\ResearchWork\MatlabWrapper\';

addpath(genpath(pwd));
addpath(EKFCodePath);

visualize = 1;
plotJointAngles = 0;
pauseActive = 0;
saveMarkerData = 1;
saveJointAngles = 1;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
partNum = '02';
[age,gender,height,weight,S2sc,calibPose] = getPartData(partNum);
S2sc = S2sc/100;

dataFolder = ['P' partNum '_filtered/'];
targetDist = {'55','70','85'};


data_files = cellstr(ls(fullfile(['C:\Users\kgwester\Documents\ResearchWork\Jumping Data Analysis\data\' dataFolder], '*.trc')));

% Large Nested FOR Loops for each jump recording
for i_targ = 2%1:3
    for i_set = 2%1:2
        for i_jump = 4:6%1:6
%             dataName = ['P' partNum '_target_' targetDist{i_targ} '_' num2str(i_set) ...
%                         '_' num2str(i_jump) '_clean-P' partNum '_template'];
            dataName = ['P' partNum '_target_' targetDist{i_targ} '_' num2str(i_set) ...
                        '_' num2str(i_jump) '_clean-P']; %because some files names "P03-template"
            file_ind = strfind(data_files,dataName);
            file_ind = find(not(cellfun('isempty', file_ind)));
            dataName = data_files{file_ind};
            
            dataNameSL = ['P' partNum '_target_' targetDist{i_targ} '_' num2str(i_set) ...
                        '_' num2str(i_jump) '_clean-start_land'];
            
%             if(exist(['../data/' dataFolder dataName '.trc'],'file')~=2)
%                 disp([dataName '.TRC does not exist'])
            if(exist(['../data/' dataFolder dataName],'file')~=2)
                disp([dataName '.TRC does not exist'])
                
            else
                %% Read in marker data, make models, visualize
%                 trc = readTrc(['../data/' dataFolder dataName '.trc']);
                trc = readTrc(['../data/' dataFolder dataName]);
                markerNames = fieldnames(trc.data);
                markerNames = markerNames(3:end); % first 2 names are Frame # and Time
                % Rotate markers so subject jumps in positive X direction
                for m = 1:length(markerNames)
                    trc.data.(markerNames{m}) = (rotz(-pi/2)*trc.data.(markerNames{m})')';
                end
%                 trc = fillInTRCFrames(trc);


                % Read in start line and landing platform marker data
                trcSL = readTrc(['../data/' dataFolder dataNameSL '.trc']);
                markerNamesSL = fieldnames(trcSL.data);
                markerNamesSL = markerNamesSL(3:end); % first 2 names are Frame # and Time
                % Rotate markers so subject jumps in positive X direction
                for m = 1:length(markerNamesSL)
                    trcSL.data.(markerNamesSL{m}) = (rotz(-pi/2)*trcSL.data.(markerNamesSL{m})')';
                end
                trcSL = fillInTRCFrames(trcSL);

                %Determine TO and landing frames in recording
                dt = 1/(trc.DataRate);
%                 footSpeedX = diff(trc.data.FRMed(:,1));
%                 footTOFrame = find(footSpeedX>=1,1); % equivalent to (1/1000)/dt = 0.2 [m/s]
%                 startFrame = footTOFrame - trc.DataRate; %add 1 second to start
%                 landPos = (mean(trcSL.data.LAND_BL(1:200,1)) + mean(trcSL.data.LAND_BR(1:200,1)))/2; %x-coord of front edge of target platform
%                 footOverTargetFrame = find(trc.data.FRMed(:,1) >= (landPos - 300),1); % actually when ball of foot within 30cm of front edge of target
%                 if(isempty(footOverTargetFrame)) % if didn't make it to platform
%                     footOverTargetFrame = footTOFrame + 40; %no jump should be shorter than this
%                 end
%                 footLandFrame = footOverTargetFrame + find(footSpeedX(footOverTargetFrame:end)<=1,1);
%                 endFrame = footLandFrame + trc.DataRate; %add 1 second to end
                
                footSpeedX = diff(trc.data.FRMed(:,1));
                [~,midJumpFrame] = max(footSpeedX);
                footTOFrame = find(footSpeedX(1:midJumpFrame)<=1,1,'last'); % equivalent to (1/1000)/dt = 0.2 [m/s]
                footLandFrame = midJumpFrame + find(footSpeedX(midJumpFrame:end)<=1,1,'first');
                startFrame = footTOFrame - trc.DataRate; %add 1 second to start
                endFrame = footLandFrame + trc.DataRate; %add 1 second to end

%                 figure(4); clf; hold on; grid on;
%                 plot(footSpeedX,'r--');
%                 plot((footPosZ./10),'b');
%                 plot([footTOFrame,footTOFrame],[0,15],'k--');
%                 plot([footLandFrame,footLandFrame],[0,15],'k--');
                
                
                %Create Euler and Lie Group Models
                initPosWindow = [101, 200];
    %             initPosWindow = [(startFrame-100), startFrame];
                [mdl_eul, trcMod_eul, initPos] = createJumpModel(trc, 1, initPosWindow, S2sc, calibPose, EKFCodePath);
%                 [mdl_lie, trcMod_lie, initPos_lie] = createJumpModel_Lie(trc, 1, initPosWindow, S2sc, calibPose, EKFCodePath);

                mdl_eul.forwardPosition;
                %Shift the Lie group model by 1 meter in x and y to visualize better
%                 mdl_lie.transforms(1).t(1:2,4) = mdl_eul.transforms(1).t(1:2,4) + [1 1]';
%                 mdl_lie.forwardPosition();

                if(visualize)
                    vis = rlVisualizer('vis', 640, 960);
                    vis.addModel(mdl_eul);
%                     vis.addModel(mdl_lie);
                    vis.update;
                end

                % %Visualize the markers
                % for m=1:numel(markerNames)
                %     mp = trc_markers.data.(markerNames{m})(1,:);
                %     %For some reason we have to call ADD marker twice before its placed
                %     %correctly
                %     vis.addMarker(markerNames{m},mp);
                % %     vis.addMarker(m_names{m},mp);
                % end
                % vis.update();

                if(pauseActive)
                    disp('PRESS ANY KEY TO CONTINUE');
                    pause();
                end

                %% Run EKF
                %Initialize model, set to initPos (approximate start position)
                mdl_eul.position = initPos;
                mdl_eul.velocity(:) = 0;
                mdl_eul.acceleration(:) = 0;
                mdl_eul.forwardPosition;
                mdl_eul.forwardVelocity;

%                 mdl_lie.position = initPos_lie;
%                 mdl_lie.velocity(:) = 0;
%                 mdl_lie.acceleration(:) = 0;
%                 mdl_lie.forwardPosition;
%                 mdl_lie.forwardVelocity;

                if(visualize)
                    vis.update;
                end

                %Create the Measurement vector by concatenating marker data
                mes_eul = zeros(size(trc.data.Frame,1),numel(mdl_eul.sensors)*3);

                for i=1:numel(mdl_eul.sensors)
                    indxs = i*3-2:i*3;
                    mes_eul(:,indxs) = trcMod_eul.data.(mdl_eul.sensors(i).name);
                end
                %Because of the shift in model placement need to add
%                 mes_lie = mes_eul + repmat([1 1 0],size(mes_eul,1),numel(mdl_lie.sensors));


                %Resample at a lower rate
    %             resample = 1;
                %Time Difference between samples
    %             dt = 1/((trc.DataRate)/resample);

    %             mes_eul = mes_eul(1:resample:end,:);
                % mes_lie = mes_lie(1:resample:end,:);

                mes_eul_predict = zeros(size(mes_eul));
%                 mes_lie_predict = zeros(size(mes_lie));

                % mes_eul_predict_V = zeros(size(mes_eul,1),2*size(mes_eul,2)); % marker velocity from ekf is 6x1 vector (not 3D position)
                % mes_lie_predict_V = zeros(size(mes_lie,1),2*size(mes_lie,2));
                % mes_eul_predict_V_rot = zeros(size(mes_eul,1),2*size(mes_eul,2)); % marker velocity from ekf is 6x1 vector (not 3D position)
                % mes_lie_predict_V_rot = zeros(size(mes_lie,1),2*size(mes_lie,2));

                ekf_eul = EKF_Q_DQ_DDQ(mdl_eul);
%                 ekf_lie = LG_EKF_Q_DQ_DDQ(mdl_lie);

                ekf_eul.observation_noise = eye(ekf_eul.sizeZ) * 0.01;
%                 ekf_lie.observation_noise = ekf_eul.observation_noise;

                ekf_eul.covariance = eye(ekf_eul.sizeX) * 1;
%                 ekf_lie.covariance = ekf_eul.covariance;

                %Calculating Process Noise
%                 eta = 300;
%                 dim = ekf_lie.dim/3; % num markers
%                 G = [ones(dim,1)*dt^2/2*eta; ones(dim,1)*dt*eta; ones(dim,1)*eta];
%                 P_tmp = G*G';
%                 P = zeros(size(P_tmp));
%                 for i=1:3
%                     for j=i:3
%                         P(i*dim-dim+1:i*dim,j*dim-dim+1:j*dim) = ...
%                             diag(diag(P_tmp(i*dim-dim+1:i*dim,j*dim-dim+1:j*dim))) ;
%                     end
%                 end
%                 P = P+P' - diag(diag(P));
%                 ekf_eul.process_noise = P;
%                 ekf_lie.process_noise = P;
                ekf_eul.process_noise = eye(ekf_eul.sizeX) * 1;
%                 ekf_lie.process_noise = ekf_eul.process_noise;
                
                ekf_covariance = zeros(size(ekf_eul.covariance,1),size(ekf_eul.covariance,2),size(mes_eul,1));
%                 lg_ekf_covariance = zeros(size(ekf_lie.covariance,1),size(ekf_lie.covariance,2),size(mes_eul,1));

                %We will also save hatInv of state instead of full out state
                ekf_state = zeros(size(mes_eul,1),ekf_eul.sizeX);
%                 lg_ekf_hatInvState = zeros(size(mes_eul,1),size(ekf_lie.hatinvState(ekf_lie.logState(ekf_lie.state)),1));

                jointAngles_names = {mdl_eul.joints.name};
                jointAngles_eul = [];
%                 jointAngles_lie = [];
                
                % record shoulder rpy decomposition to counter "shoulder flipping"
                rshldrRPY = zeros(size(mes_eul,1),3);
                lshldrRPY = zeros(size(mes_eul,1),3);
                
                
                % For new marker swapping MatlabWrapper
                mes_obj = SensorMeasurement(1,30);
                [mes_obj.size] = deal(3);
                [mes_obj.type] = deal(mdl_eul.sensors(1).binary_type);
                matches = 1:numel(mdl_eul.sensors);
                matches = [matches' matches'];
                
                
                tic;
                for i=1:size(mes_eul,1)
    %             for i=(startFrame-100):size(mes_eul,1)

                %     if(i==footTOFrame)
                %         disp('footTOFrame, PRESS ANY KEY');
                %         pause();
                %     end
                %     if(i==footLandFrame)
                %         disp('footLandFrame, PRESS ANY KEY');
                %         pause();
                %     end

                    z_eul = mes_eul(i,:);
                    mes_obj.setMesArray(z_eul); % For marker swapping MatlabWrapper
%                     z_lie = mes_lie(i,:)';

                    u = dt;

                    ekf_eul.run_iteration(u,mes_obj,matches); % For marker swapping MatlabWrapper
%                     ekf_lie.run_iteration(u,z_lie);

                    ekf_state(i,:) = ekf_eul.state;
%                     lg_ekf_hatInvState(i,:) = ekf_lie.hatinvState(ekf_lie.logState(ekf_lie.state));

                    mes_eul_predict(i,:) = ekf_eul.makeMeasure(ekf_eul.state).getMesArray(); % For marker swapping MatlabWrapper
%                     mes_lie_predict(i,:) = ekf_lie.makeMeasure(ekf_lie.state);

                    jointAngles_eul = [jointAngles_eul; mdl_eul.position'];
%                     jointAngles_lie = [jointAngles_lie; mdl_lie.position']; % NOTE: this doesn't work, since "mdl_lie.position" is in LieMapping
%                     jointAngles_lie = getLieModelJAs(mdl_lie);
                    rshldrRPY(i,:) = getShldrRPY(mdl_eul,'rshoulder_jElevation','R');
                    lshldrRPY(i,:) = getShldrRPY(mdl_eul,'lshoulder_jElevation','L');
                    
                %     mes_eul_predict_V(i,:) = vertcat(ekf_eul.model_handle.sensors.velocity)';
                %     mes_lie_predict_V(i,:) = vertcat(ekf_lie.model_handle.sensors.velocity)';
                %     
                %     % Rotate marker angular and linear velocities back to world frame
                %     for j=1:numel(ekf_eul.model_handle.sensors)
                %         sens_eul =  ekf_eul.model_handle.sensors(j);
                %         sens_lie =  ekf_lie.model_handle.sensors(j);
                %         
                %         Rlie = sens_lie.transform(1:3,1:3);
                %         V1 = Rlie*sens_lie.velocity(1:3);
                %         V2 = Rlie*sens_lie.velocity(4:6);
                %         mes_lie_predict_V_rot(i,j*6-5:j*6) = [V1;V2];
                %         
                %         Reul = sens_eul.transform(1:3,1:3);
                %         V1 = Reul*sens_eul.velocity(1:3);
                %         V2 = Reul*sens_eul.velocity(4:6);
                %         mes_eul_predict_V_rot(i,j*6-5:j*6) = [V1;V2];
                %         
                %     end

                    ekf_covariance(:,:,i) = ekf_eul.covariance;
%                     lg_ekf_covariance(:,:,i) = ekf_lie.covariance;


                    if(visualize && (mod(i,5)==0) )
%                         for m=1:numel(z_eul)/3
%                             m_pos = z_eul(m*3-2:m*3);
%                             vis.addMarker([num2str(m)],m_pos);
%                         end

%                         for m=1:numel(z_lie)/3
%                             m_pos = z_lie(m*3-2:m*3);
%                             vis.addMarker([num2str(m) 'L'],m_pos);
%                         end

                        vis.update();
                        %pause(dt);
                %         pause(0.03);
                    end




    %                 disp(['Frame: ' num2str(i) ' out of ' num2str(size(mes_eul,1))]);

                %     if mod(i,50)==0
                %         disp(['Frame: ' num2str(i) ' out of ' num2str(size(mes_eul,1))]);
                %         for m=1:numel(z_eul)/3
                %             m_pos = z_eul(m*3-2:m*3);
                %             vis.addMarker(['Meul' num2str(m)],m_pos,[1 1 0 1]);
                %         end
                % %         for m=1:numel(z_lie)/3
                % %             m_pos = z_lie(m*3-2:m*3);
                % %             vis.addMarker(['Mlie' num2str(m)],m_pos,[1 1 0 1]);
                % %         end
                %         
                %         vis.update();
                %     end
                end
                EKF_runtime = toc

                if(visualize)
                    clear vis;
                end

                %% Computing data and output
                
                
%                 figure(1); clf;
%                 subplot(2,1,1); hold on; grid on;
%                 plot(jointAngles_eul(:,10),'r');
%                 plot(jointAngles_eul(:,11),'g');
%                 plot(jointAngles_eul(:,12),'b');
%                 plot(rshldrRPY(:,1),'r--','Linewidth',2);
%                 plot(rshldrRPY(:,2),'g--','Linewidth',2);
%                 plot(rshldrRPY(:,3),'b--','Linewidth',2);
%                 title('R shoulder');
%                 subplot(2,1,2); hold on; grid on;
%                 plot(jointAngles_eul(:,15),'r');
%                 plot(jointAngles_eul(:,16),'g');
%                 plot(jointAngles_eul(:,17),'b');
%                 plot(lshldrRPY(:,1),'r--','Linewidth',2);
%                 plot(lshldrRPY(:,2),'g--','Linewidth',2);
%                 plot(lshldrRPY(:,3),'b--','Linewidth',2);
%                 title('L shoulder');
                
                
                if(plotJointAngles)
                    %Plot joint angles
                    % joints: (1-6) p0,p1,p2,r0,r1,r2, 
                    % (7-9) backFB, backAxial, backLateral, 
                    % (10-14) rshldrElev, rshldrAbd, rshldrExtRot, relbowFlex, relbowSup
                    % (15-19) lshldrElev, lshldrAbd, lshldrExtRot, lelbowFlex, lelbowSup
                    % (20-22) rhipFlex, rhipAbd, rhipExtRot, 
                    % (23-26) rkneeExtend, rkneeExtRot, rankleDorsi, ranklePron
                    % (27-29) lhipFlex, lhipAbd, lhipExtRot, 
                    % (30-33) lkneeExtend, lkneeExtRot, lankleDorsi, lanklePron
                    plotJoints(1).a = [7,8,9]; %back
                    plotJoints(2).a = [10,15]; %shldr elevation
                    plotJoints(3).a = [11,16]; %shldr abduction
                    plotJoints(4).a = [12,17]; %shldr ext. rotation
                    plotJoints(5).a = [13,18]; %elbow flexion
                    plotJoints(6).a = [20,27]; %hip flexion
                    % plotJoints(7).a = [21,28]; %hip abduction
                    % plotJoints(8).a = [22,29]; %hip ext. rotation
                    plotJoints(7).a = [23,30]; %knee flexion 
                    % plotJoints(10).a = [24,31]; %knee ext. rotation
                    plotJoints(8).a = [25,32]; %ankle dorsiflexion
                    plotJoints(9).a = [26,33]; %ankle pronation
                    plotNames = {'Back','Shoulder Elev.','Shoulder Abd.','Shoulder Ext. Rot.',...
                        'Elbow Flex.','Hip Flex.','Knee Flex.','Ankle Dorsiflex.','Ankle Pronate'};

                    dataLength = size(jointAngles_eul,1);
                    figure(1);
                    for i = 1:numel(plotJoints)
                        clf; hold on;
                        leg = [];
                        for j = 1:numel(plotJoints(i).a)
                            jj = plotJoints(i).a(j);
                            plot(1:dataLength,rad2deg(jointAngles_eul(:,jj)),'LineWidth',2);
                            leg = [leg; jointAngles_names(jj)];
                        end
                        plot([footTOFrame, footTOFrame],[-180,180],'g','LineWidth',2);
                        plot([footLandFrame, footLandFrame],[-180,180],'r','LineWidth',2);
                        plot([startFrame, startFrame],[-180,180],'k--');
                        plot([endFrame, endFrame],[-180,180],'k--');
                        title(plotNames(i));
                        legend(cellstr(leg));
                        xlabel('Frame Number');
                        ylabel('Angle [deg]');
                        ylim([-120,120]);
                        grid on;
                        w = waitforbuttonpress;
                    end
                end


                %% Save mes_### and mes_###_predict data
                if(saveMarkerData)
                    mydir = pwd;
                    idcs = strfind(mydir,'\');
                    newdir = mydir(1:idcs(end)); 
                    saveFilePath = [newdir 'results\RESULTS_EKF_P' partNum '_' targetDist{i_targ} '_' num2str(i_set) '_' num2str(i_jump) '.mat'];
                    
                    % reset models to initial positions before saving
                    mdl_eul.position = initPos;
                    mdl_eul.velocity(:) = 0;
                    mdl_eul.acceleration(:) = 0;
                    mdl_eul.forwardPosition;
                    mdl_eul.forwardVelocity;

%                     mdl_lie.position = initPos_lie;
%                     mdl_lie.velocity(:) = 0;
%                     mdl_lie.acceleration(:) = 0;
%                     mdl_lie.forwardPosition;
%                     mdl_lie.forwardVelocity;
                    
%                     save(saveFilePath,'mdl_eul','mes_eul','mes_eul_predict','ekf_state');
%                     save(saveFilePath,'mdl_eul','mdl_lie','mes_eul','mes_eul_predict','mes_lie','mes_lie_predict',...
%                          'ekf_state','lg_ekf_hatInvState');
                    save(saveFilePath,'mes_eul','mes_eul_predict','ekf_state');
%                     save(saveFilePath,'mes_eul','mes_eul_predict','mes_lie','mes_lie_predict',...
%                          'ekf_state','lg_ekf_hatInvState');

                    disp([dataName ' EKF data saved'])
                end

                if(saveJointAngles)
                    mydir = pwd;
                    idcs = strfind(mydir,'\');
                    newdir = mydir(1:idcs(end)); 
                    saveFilePath = [newdir 'results\RESULTS_JA_P' partNum '_' targetDist{i_targ} '_' num2str(i_set) '_' num2str(i_jump) '.mat'];
                    
                    save(saveFilePath,'jointAngles_names','jointAngles_eul',...
                            'footTOFrame','footLandFrame','startFrame','endFrame');
%                     save(saveFilePath,'jointAngles_names','jointAngles_eul','jointAngles_lie',...
%                             'footTOFrame','footLandFrame','startFrame','endFrame');

                    disp([dataName ' JA data saved'])
                end
                
                
                disp([dataName ' filtering complete'])
            end
% END MAIN NESTED FOR LOOPS
        end
    end
end



