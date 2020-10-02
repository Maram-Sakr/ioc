%Process the bench data
addpath('../');
addpath(genpath('C:\asl_git\kalmanfilter\ik_framework\common\ars'));

vis = rlVisualizer('vis',640,480);
vis.update();

%Load up the TRC data
bar_trc = parseTRC('C:\aslab\data\bench\bench_1_interpolated_smoothed-bAR.trc');
bod_trc = parseTRC('C:\aslab\data\bench\bench_1_interpolated_smoothed-SSA_Pilot.trc');
bar_m_names = fieldnames(bar_trc.data);
bar_m_names = bar_m_names(3:end);
bod_m_names = fieldnames(bod_trc.data);
bod_m_names = bod_m_names(3:end);
%Convert to meters
for j=1:numel(bod_m_names)
    bod_trc.data.(bod_m_names{j}) = bod_trc.data.(bod_m_names{j})/1000;
end
for j=1:numel(bar_m_names)
    bar_trc.data.(bar_m_names{j})= bar_trc.data.(bar_m_names{j})/1000;
end

%Combine all trc
trc = bod_trc;
for j=1:numel(bar_m_names)
    trc.data.(bar_m_names{j})= bar_trc.data.(bar_m_names{j});
end

m_names = fieldnames( trc.data);

%% Visualize only markers
for i=1:1
    for j=1:numel(m_names)
        vis.addMarker(m_names{j},trc.data.(m_names{j})(i,:));
    end
    vis.update
end

%% Load up 2 arm models and build them to match TRC
mdl_rarm = rlCModel('../Models/right_arm.xml');
mdl_rarm.forwardPosition();

%Figure out the middle of the body
torso_or = (mean(bod_trc.data.SHOULDER_R)+mean(bod_trc.data.SHOULDER_L))/2;
%torso axis will point down along the body (torso origing -> clavical marker)
torso_ax = mean(bod_trc.data.CLAVICAL) - torso_or;
%Remove Z component
torso_ax = torso_ax - dot(torso_ax,[0 0 1]')*[0 0 1];
torso_ax = torso_ax/norm(torso_ax);

%Position the origin 
%NOTE WE SHIFT ALONG TORSO AXIS 4CM to get closer to SHOULDER CENTER OF
%ROTATION. Ideally we want something like harrington for shoulder.
r_shoul_or = mean(bod_trc.data.SHOULDER_R) + 0.04*torso_ax;
mdl_rarm.transforms(1).t(1:3,4) = r_shoul_or;

%Position the elbow, the primary rotation axis is determined by the vector
%between the two elbow markers lateral -> medial

%We will average this many seconds for building the model
mean_time = 2;
mean_indxs = round(1:mean_time*bod_trc.DataRate);

r_elbow_lat = mean(bod_trc.data.ELBOW_R_LAT(mean_indxs,:));
r_elbow_med = mean(bod_trc.data.ELBOW_R_MED(mean_indxs,:));
r_elbow_ax = r_elbow_med - r_elbow_lat;
r_elbow_or = r_elbow_lat + r_elbow_ax/2;
r_elbow_ax = r_elbow_ax/norm(r_elbow_ax);

r_wrist_lat = mean(bod_trc.data.WRIST_R_LAT(mean_indxs,:));
r_wrist_med = mean(bod_trc.data.WRIST_R_MED(mean_indxs,:));
r_wrist_ax = r_wrist_med - r_wrist_lat;
r_wrist_or = r_wrist_lat + r_wrist_ax/2;
r_wrist_ax = r_wrist_ax/norm(r_wrist_ax);

t_indx = find(contains({mdl_rarm.transforms.name},'length_rshoulder_relbow'),1);
trans = mdl_rarm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

%Translation from shoulder to elbow in world frame
t_sho_elb_0 = r_elbow_or - r_shoul_or;
%In shoulder frame
t_sho_elb_f = f_in.t(1:3,1:3)'*t_sho_elb_0';
%Now figure out rotation between shoulder and elbow
%First figure out elbow rotation in world frame
x_ax = r_elbow_ax';
z_ax = r_wrist_or - r_elbow_or;
z_ax = z_ax'/norm(z_ax);
y_ax = cross(z_ax,x_ax);
y_ax = y_ax/norm(y_ax);
z_ax = cross(x_ax,y_ax);
R = [x_ax y_ax z_ax];
trans.t(1:3,1:3) = f_in.t(1:3,1:3)'*R;
trans.t(1:3,4) = t_sho_elb_f;
mdl_rarm.forwardPosition();

%Buld the elbow to wrist transform
t_indx = find(contains({mdl_rarm.transforms.name},'length_relbow_rwrist'),1);
trans = mdl_rarm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

%Translation from elbow to wrist in world frame
t_elb_wri_0 = r_wrist_or - r_elbow_or;
%In shoulder frame
t_elb_wri_f = f_in.t(1:3,1:3)'*t_elb_wri_0';

%Now figure out rotation between elbow and wrist, note, we keep same Z axis
%as before going from the elbow up to wrist and through
x_ax = r_wrist_ax';
z_ax = r_wrist_or - r_elbow_or;
z_ax = z_ax'/norm(z_ax);
y_ax = cross(z_ax,x_ax);
y_ax = y_ax/norm(y_ax);
z_ax = cross(x_ax,y_ax);
R = [x_ax y_ax z_ax];
trans.t(1:3,1:3) = f_in.t(1:3,1:3)'*R;
trans.t(1:3,4) = t_elb_wri_f;
mdl_rarm.forwardPosition();

%Finally make the end effector the middle of the bar and aligned with world
left_u = mean(bar_trc.data.LEFT_U(mean_indxs,:));
left_l = mean(bar_trc.data.LEFT_L(mean_indxs,:));
right_u = mean(bar_trc.data.RIGHT_U(mean_indxs,:));
right_l = mean(bar_trc.data.RIGHT_L(mean_indxs,:));
bar_mid = (left_u+left_l+right_u+right_l)/4;

t_indx = find(contains({mdl_rarm.transforms.name},'length_rwrist_rhand'),1);
trans = mdl_rarm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

t_wri_bar_0 = bar_mid - r_wrist_or;
t_wri_bar_f = f_in.t(1:3,1:3)'*t_wri_bar_0';
trans.t(1:3,1:3) = f_in.t(1:3,1:3)';
trans.t(1:3,4) = t_wri_bar_f;
mdl_rarm.forwardPosition();

%Now in the same exact way build the left arm
mdl_larm = rlCModel('../Models/left_arm.xml');
mdl_larm.forwardPosition();

%Position the origin
%SIMILARLY SHIFT A BIT ALONG TORSO AXIS
l_shoul_or = mean(bod_trc.data.SHOULDER_L) + 0.04*torso_ax;
mdl_larm.transforms(1).t(1:3,4) = l_shoul_or;

%Position the elbow, the primary rotation axis is determined by the vector
%between the two elbow markers lateral -> medial

%We will average this many seconds for building the model
mean_time = 2;
mean_indxs = round(1:mean_time*bod_trc.DataRate);

l_elbow_lat = mean(bod_trc.data.ELBOW_L_LAT(mean_indxs,:));
l_elbow_med = mean(bod_trc.data.ELBOW_L_MED(mean_indxs,:));
l_elbow_ax = l_elbow_med - l_elbow_lat;
l_elbow_or = l_elbow_lat + l_elbow_ax/2;
l_elbow_ax = l_elbow_ax/norm(l_elbow_ax);

l_wrist_lat = mean(bod_trc.data.WRIST_L_LAT(mean_indxs,:));
l_wrist_med = mean(bod_trc.data.WRIST_L_MED(mean_indxs,:));
l_wrist_ax = l_wrist_med - l_wrist_lat;
l_wrist_or = l_wrist_lat + l_wrist_ax/2;
l_wrist_ax = l_wrist_ax/norm(l_wrist_ax);

t_indx = find(contains({mdl_larm.transforms.name},'length_lshoulder_lelbow'),1);
trans = mdl_larm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

%Translation from shoulder to elbow in world frame
t_sho_elb_0 = l_elbow_or - l_shoul_or;
%In shoulder frame
t_sho_elb_f = f_in.t(1:3,1:3)'*t_sho_elb_0';
%Now figure out rotation between shoulder and elbow
%First figure out elbow rotation in world frame
x_ax = l_elbow_ax';
z_ax = l_wrist_or - l_elbow_or;
z_ax = z_ax'/norm(z_ax);
y_ax = cross(z_ax,x_ax);
y_ax = y_ax/norm(y_ax);
z_ax = cross(x_ax,y_ax);
R = [x_ax y_ax z_ax];
trans.t(1:3,1:3) = f_in.t(1:3,1:3)'*R;
trans.t(1:3,4) = t_sho_elb_f;
mdl_larm.forwardPosition();

%Buld the elbow to wrist transform
t_indx = find(contains({mdl_larm.transforms.name},'length_lelbow_lwrist'),1);
trans = mdl_larm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

%Translation from elbow to wrist in world frame
t_elb_wri_0 = l_wrist_or - l_elbow_or;
%In shoulder frame
t_elb_wri_f = f_in.t(1:3,1:3)'*t_elb_wri_0';

%Now figure out rotation between elbow and wrist, note, we keep same Z axis
%as before going from the elbow up to wrist and through
x_ax = l_wrist_ax';
z_ax = l_wrist_or - l_elbow_or;
z_ax = z_ax'/norm(z_ax);
y_ax = cross(z_ax,x_ax);
y_ax = y_ax/norm(y_ax);
z_ax = cross(x_ax,y_ax);
R = [x_ax y_ax z_ax];
trans.t(1:3,1:3) = f_in.t(1:3,1:3)'*R;
trans.t(1:3,4) = t_elb_wri_f;
mdl_larm.forwardPosition();

%Finally make the end effector the middle of the bar and aligned with world
left_u = mean(bar_trc.data.LEFT_U(mean_indxs,:));
left_l = mean(bar_trc.data.LEFT_L(mean_indxs,:));
right_u = mean(bar_trc.data.RIGHT_U(mean_indxs,:));
right_l = mean(bar_trc.data.RIGHT_L(mean_indxs,:));
bar_mid = (left_u+left_l+right_u+right_l)/4;

t_indx = find(contains({mdl_larm.transforms.name},'length_lwrist_lhand'),1);
trans = mdl_larm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

t_wri_bar_0 = bar_mid - l_wrist_or;
t_wri_bar_f = f_in.t(1:3,1:3)'*t_wri_bar_0';
trans.t(1:3,1:3) = f_in.t(1:3,1:3)';
trans.t(1:3,4) = t_wri_bar_f;
mdl_larm.forwardPosition();

%% Attach Motion Capture Markers
%This cell array defines model frames and what markers are attached to them
marker_attachement_rarm = ...
    {{'body_rshoulder_relbow','ELBOW_R_LAT','ELBOW_R_MED','UPPERARM_R_IMU_T','UPPERARM_R_IMU_L','UPPERARM_R_IMU_R'};...
    {'body_relbow_rwrist','WRIST_R_LAT','WRIST_R_MED','LOWERARM_R_IMU_T','LOWERARM_R_IMU_R','LOWERARM_R_IMU_L'};...
    {'body_rwrist_rhand','RIGHT_U','RIGHT_L','BAR_IMU_T','BAR_IMU_R','BAR_IMU_L'};
    };

for i=1:numel(marker_attachement_rarm)
    f_name =  marker_attachement_rarm{i}{1};
    frame = mdl_rarm.getFrameByName(f_name);
    
    for j = 2:numel(marker_attachement_rarm{i})
        %translation from frame to marker in world frame
        marker = mean(trc.data.(marker_attachement_rarm{i}{j})(mean_indxs,:))';
        t_0 = marker - frame.t(1:3,4);
        t_f = frame.t(1:3,1:3)'*t_0;
        T = eye(4);
        T(1:3,4) = t_f;
        sens = SensorCore(marker_attachement_rarm{i}{j});
        sens.addDecorator('position');
        mdl_rarm.addSensor(sens,frame.name,T);
    end
end

mdl_rarm.forwardPosition();

marker_attachement_larm = ...
    {{'body_lshoulder_lelbow','ELBOW_L_LAT','ELBOW_L_MED','UPPERARM_L_IMU_T','UPPERARM_L_IMU_L','UPPERARM_L_IMU_R'};...
    {'body_lelbow_lwrist','WRIST_L_LAT','WRIST_L_MED','LOWERARM_L_IMU_T','LOWERARM_L_IMU_R','LOWERARM_L_IMU_L'};...
    {'body_lwrist_lhand','LEFT_U','LEFT_L','BAR_IMU_T','BAR_IMU_R','BAR_IMU_L'};
    };

for i=1:numel(marker_attachement_larm)
    f_name =  marker_attachement_larm{i}{1};
    frame = mdl_larm.getFrameByName(f_name);
    
    for j = 2:numel(marker_attachement_larm{i})
        %translation from frame to marker in world frame
        marker = mean(trc.data.(marker_attachement_larm{i}{j})(mean_indxs,:))';
        t_0 = marker - frame.t(1:3,4);
        t_f = frame.t(1:3,1:3)'*t_0;
        T = eye(4);
        T(1:3,4) = t_f;
        sens = SensorCore(marker_attachement_larm{i}{j});
        sens.addDecorator('position');
        mdl_larm.addSensor(sens,frame.name,T);
    end
end
mdl_larm.forwardPosition();

%Build measurement vectors
mes_rarm = [];
for i=1:numel(marker_attachement_rarm)
    for j = 2:numel(marker_attachement_rarm{i})
        mes_rarm = [mes_rarm trc.data.(marker_attachement_rarm{i}{j})];
    end
end
mes_larm = [];
for i=1:numel(marker_attachement_larm)
    for j = 2:numel(marker_attachement_larm{i})
        mes_larm = [mes_larm trc.data.(marker_attachement_larm{i}{j})];
    end
end

mes_rarm_obj = SensorMeasurement(trc.NumFrames,numel(mdl_rarm.sensors));
[mes_rarm_obj.type] = deal(1);
[mes_rarm_obj.size] = deal(3);
mes_rarm_obj.setMesArray(mes_rarm);

mes_larm_obj = SensorMeasurement(trc.NumFrames,numel(mdl_larm.sensors));
[mes_larm_obj.type] = deal(1);
[mes_larm_obj.size] = deal(3);
mes_larm_obj.setMesArray(mes_larm);

vis.addModel(mdl_rarm);
vis.addModel(mdl_larm);
vis.update();

%% Set up EKF to estimate joint angles based on MOCAP
ekf_rarm = EKF_Q_DQ_DDQ(mdl_rarm);
ekf_larm = EKF_Q_DQ_DDQ(mdl_larm);
state_est_rarm_mocap = zeros(trc.NumFrames,numel(ekf_rarm.state));
state_est_larm_mocap = zeros(trc.NumFrames,numel(ekf_larm.state));
%Marker Noise
ekf_rarm.observation_noise = ekf_rarm.observation_noise*0.01;
ekf_larm.observation_noise = ekf_larm.observation_noise*0.01;

eta = 10;
dt = 1/trc.DataRate;
%Process noise
dim = numel(mdl_rarm.joints);
G = [ones(dim,1)*dt^2/2*eta; ones(dim,1)*dt*eta; ones(dim,1)*eta];
P_tmp = G*G';
P = zeros(size(P_tmp));
for i=1:3
    for j=i:3
        P(i*dim-dim+1:i*dim,j*dim-dim+1:j*dim) = ...
            diag(diag(P_tmp(i*dim-dim+1:i*dim,j*dim-dim+1:j*dim))) ;
    end
end
P = P+P' - diag(diag(P));
ekf_rarm.process_noise = P;
ekf_larm.process_noise = P;

%% Do the estimation

for i=1:trc.NumFrames
    
    %This is the measurement for current timestep, must be vertical vector
    z_rarm = mes_rarm_obj(i,:);
    z_larm = mes_larm_obj(i,:);
    
    ekf_rarm.run_iteration(dt,z_rarm);
    state_est_rarm_mocap(i,:) = ekf_rarm.state;
    
    ekf_larm.run_iteration(dt,z_larm);
    state_est_larm_mocap(i,:) = ekf_larm.state;
    
    %Draw markers
    %for j=1:numel(m_names)
    %    vis.addMarker(m_names{j},trc.data.(m_names{j})(i,:));
    %end
    %vis.update
end

%% Now do the same using IMU data 

mdl_rarm = rlCModel('../Models/right_arm.xml');
mdl_rarm.forwardPosition();

%Figure out the middle of the body
torso_or = (mean(bod_trc.data.SHOULDER_R)+mean(bod_trc.data.SHOULDER_L))/2;
%torso axis will point down along the body (torso origing -> clavical marker)
torso_ax = mean(bod_trc.data.CLAVICAL) - torso_or;
%Remove Z component
torso_ax = torso_ax - dot(torso_ax,[0 0 1]')*[0 0 1];
torso_ax = torso_ax/norm(torso_ax);

%Position the origin
r_shoul_or = mean(bod_trc.data.SHOULDER_R) + 0.04*torso_ax;
mdl_rarm.transforms(1).t(1:3,4) = r_shoul_or;

%Position the elbow, the primary rotation axis is determined by the vector
%between the two elbow markers lateral -> medial

%We will average this many seconds for building the model
mean_time = 2;
mean_indxs = round(1:mean_time*bod_trc.DataRate);

r_elbow_lat = mean(bod_trc.data.ELBOW_R_LAT(mean_indxs,:));
r_elbow_med = mean(bod_trc.data.ELBOW_R_MED(mean_indxs,:));
r_elbow_ax = r_elbow_med - r_elbow_lat;
r_elbow_or = r_elbow_lat + r_elbow_ax/2;
r_elbow_ax = r_elbow_ax/norm(r_elbow_ax);

r_wrist_lat = mean(bod_trc.data.WRIST_R_LAT(mean_indxs,:));
r_wrist_med = mean(bod_trc.data.WRIST_R_MED(mean_indxs,:));
r_wrist_ax = r_wrist_med - r_wrist_lat;
r_wrist_or = r_wrist_lat + r_wrist_ax/2;
r_wrist_ax = r_wrist_ax/norm(r_wrist_ax);

t_indx = find(contains({mdl_rarm.transforms.name},'length_rshoulder_relbow'),1);
trans = mdl_rarm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

%Translation from shoulder to elbow in world frame
t_sho_elb_0 = r_elbow_or - r_shoul_or;
%In shoulder frame
t_sho_elb_f = f_in.t(1:3,1:3)'*t_sho_elb_0';
%Now figure out rotation between shoulder and elbow
%First figure out elbow rotation in world frame
x_ax = r_elbow_ax';
z_ax = r_wrist_or - r_elbow_or;
z_ax = z_ax'/norm(z_ax);
y_ax = cross(z_ax,x_ax);
y_ax = y_ax/norm(y_ax);
z_ax = cross(x_ax,y_ax);
R = [x_ax y_ax z_ax];
trans.t(1:3,1:3) = f_in.t(1:3,1:3)'*R;
trans.t(1:3,4) = t_sho_elb_f;
mdl_rarm.forwardPosition();

%Buld the elbow to wrist transform
t_indx = find(contains({mdl_rarm.transforms.name},'length_relbow_rwrist'),1);
trans = mdl_rarm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

%Translation from elbow to wrist in world frame
t_elb_wri_0 = r_wrist_or - r_elbow_or;
%In shoulder frame
t_elb_wri_f = f_in.t(1:3,1:3)'*t_elb_wri_0';

%Now figure out rotation between elbow and wrist, note, we keep same Z axis
%as before going from the elbow up to wrist and through
x_ax = r_wrist_ax';
z_ax = r_wrist_or - r_elbow_or;
z_ax = z_ax'/norm(z_ax);
y_ax = cross(z_ax,x_ax);
y_ax = y_ax/norm(y_ax);
z_ax = cross(x_ax,y_ax);
R = [x_ax y_ax z_ax];
trans.t(1:3,1:3) = f_in.t(1:3,1:3)'*R;
trans.t(1:3,4) = t_elb_wri_f;
mdl_rarm.forwardPosition();

%Finally make the end effector the middle of the bar and aligned with world
left_u = mean(bar_trc.data.LEFT_U(mean_indxs,:));
left_l = mean(bar_trc.data.LEFT_L(mean_indxs,:));
right_u = mean(bar_trc.data.RIGHT_U(mean_indxs,:));
right_l = mean(bar_trc.data.RIGHT_L(mean_indxs,:));
bar_mid = (left_u+left_l+right_u+right_l)/4;

t_indx = find(contains({mdl_rarm.transforms.name},'length_rwrist_rhand'),1);
trans = mdl_rarm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

t_wri_bar_0 = bar_mid - r_wrist_or;
t_wri_bar_f = f_in.t(1:3,1:3)'*t_wri_bar_0';
trans.t(1:3,1:3) = f_in.t(1:3,1:3)';
trans.t(1:3,4) = t_wri_bar_f;
mdl_rarm.forwardPosition();

%Now in the same exact way build the left arm
mdl_larm = rlCModel('../Models/left_arm.xml');
mdl_larm.forwardPosition();

%Position the origin
l_shoul_or = mean(bod_trc.data.SHOULDER_L) + 0.04*torso_ax;
mdl_larm.transforms(1).t(1:3,4) = l_shoul_or;

%Position the elbow, the primary rotation axis is determined by the vector
%between the two elbow markers lateral -> medial

%We will average this many seconds for building the model
mean_time = 2;
mean_indxs = round(1:mean_time*bod_trc.DataRate);

l_elbow_lat = mean(bod_trc.data.ELBOW_L_LAT(mean_indxs,:));
l_elbow_med = mean(bod_trc.data.ELBOW_L_MED(mean_indxs,:));
l_elbow_ax = l_elbow_med - l_elbow_lat;
l_elbow_or = l_elbow_lat + l_elbow_ax/2;
l_elbow_ax = l_elbow_ax/norm(l_elbow_ax);

l_wrist_lat = mean(bod_trc.data.WRIST_L_LAT(mean_indxs,:));
l_wrist_med = mean(bod_trc.data.WRIST_L_MED(mean_indxs,:));
l_wrist_ax = l_wrist_med - l_wrist_lat;
l_wrist_or = l_wrist_lat + l_wrist_ax/2;
l_wrist_ax = l_wrist_ax/norm(l_wrist_ax);

t_indx = find(contains({mdl_larm.transforms.name},'length_lshoulder_lelbow'),1);
trans = mdl_larm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

%Translation from shoulder to elbow in world frame
t_sho_elb_0 = l_elbow_or - l_shoul_or;
%In shoulder frame
t_sho_elb_f = f_in.t(1:3,1:3)'*t_sho_elb_0';
%Now figure out rotation between shoulder and elbow
%First figure out elbow rotation in world frame
x_ax = l_elbow_ax';
z_ax = l_wrist_or - l_elbow_or;
z_ax = z_ax'/norm(z_ax);
y_ax = cross(z_ax,x_ax);
y_ax = y_ax/norm(y_ax);
z_ax = cross(x_ax,y_ax);
R = [x_ax y_ax z_ax];
trans.t(1:3,1:3) = f_in.t(1:3,1:3)'*R;
trans.t(1:3,4) = t_sho_elb_f;
mdl_larm.forwardPosition();

%Buld the elbow to wrist transform
t_indx = find(contains({mdl_larm.transforms.name},'length_lelbow_lwrist'),1);
trans = mdl_larm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

%Translation from elbow to wrist in world frame
t_elb_wri_0 = l_wrist_or - l_elbow_or;
%In shoulder frame
t_elb_wri_f = f_in.t(1:3,1:3)'*t_elb_wri_0';

%Now figure out rotation between elbow and wrist, note, we keep same Z axis
%as before going from the elbow up to wrist and through
x_ax = l_wrist_ax';
z_ax = l_wrist_or - l_elbow_or;
z_ax = z_ax'/norm(z_ax);
y_ax = cross(z_ax,x_ax);
y_ax = y_ax/norm(y_ax);
z_ax = cross(x_ax,y_ax);
R = [x_ax y_ax z_ax];
trans.t(1:3,1:3) = f_in.t(1:3,1:3)'*R;
trans.t(1:3,4) = t_elb_wri_f;
mdl_larm.forwardPosition();

%Finally make the end effector the middle of the bar and aligned with world
left_u = mean(bar_trc.data.LEFT_U(mean_indxs,:));
left_l = mean(bar_trc.data.LEFT_L(mean_indxs,:));
right_u = mean(bar_trc.data.RIGHT_U(mean_indxs,:));
right_l = mean(bar_trc.data.RIGHT_L(mean_indxs,:));
bar_mid = (left_u+left_l+right_u+right_l)/4;

t_indx = find(contains({mdl_larm.transforms.name},'length_lwrist_lhand'),1);
trans = mdl_larm.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;

t_wri_bar_0 = bar_mid - l_wrist_or;
t_wri_bar_f = f_in.t(1:3,1:3)'*t_wri_bar_0';
trans.t(1:3,1:3) = f_in.t(1:3,1:3)';
trans.t(1:3,4) = t_wri_bar_f;
mdl_larm.forwardPosition();

%% Attach the IMUS 
%This defines the IMU attachement {frame to attach to, imu markers}
imu_attachement_larm = {...
    {'body_lshoulder_lelbow','UPPERARM_L_IMU_L','UPPERARM_L_IMU_T','UPPERARM_L_IMU_R'};...
    ...%{'body_lelbow_lwrist','LOWERARM_L_IMU_L','LOWERARM_L_IMU_T','LOWERARM_L_IMU_R'};...
    {'body_lwrist_lhand','BAR_IMU_L','BAR_IMU_T','BAR_IMU_R'};};

for i=1:numel(imu_attachement_larm)
    f_name =  imu_attachement_larm{i}{1};
    frame = mdl_larm.getFrameByName(f_name);
    
    P = mean(trc.data.(imu_attachement_larm{i}{2})(mean_indxs,:));
    Q = mean(trc.data.(imu_attachement_larm{i}{3})(mean_indxs,:));
    R = mean(trc.data.(imu_attachement_larm{i}{4})(mean_indxs,:));
    [R_imu_0, R_0_imu] = points2rot(P,Q,R);
    t_0 =  mean([P;Q;R])' - frame.t(1:3,4);
    t_f = frame.t(1:3,1:3)'*t_0;
    
    sens = SensorCore(imu_attachement_larm{i}{2}(1:end-2));
    sens.addDecorator('gyroscope');
    sens.addDecorator('accelerometer');
    T = eye(4);
    T(1:3,1:3) = frame.t(1:3,1:3)'*R_0_imu';
    T(1:3,4) = t_f;
    mdl_larm.addSensor(sens,frame.name,T)
end
mdl_larm.forwardPosition();


imu_attachement_rarm = {...
    {'body_rshoulder_relbow','UPPERARM_R_IMU_L','UPPERARM_R_IMU_T','UPPERARM_R_IMU_R'};...
    ...%{'body_relbow_rwrist','LOWERARM_R_IMU_L','LOWERARM_R_IMU_T','LOWERARM_R_IMU_R'};...
    {'body_rwrist_rhand','BAR_IMU_L','BAR_IMU_T','BAR_IMU_R'};};

for i=1:numel(imu_attachement_rarm)
    f_name =  imu_attachement_rarm{i}{1};
    frame = mdl_rarm.getFrameByName(f_name);
    
    P = mean(trc.data.(imu_attachement_rarm{i}{2})(mean_indxs,:));
    Q = mean(trc.data.(imu_attachement_rarm{i}{3})(mean_indxs,:));
    R = mean(trc.data.(imu_attachement_rarm{i}{4})(mean_indxs,:));
    [R_imu_0, R_0_imu] = points2rot(P,Q,R);
    t_0 =  mean([P;Q;R])' - frame.t(1:3,4);
    t_f = frame.t(1:3,1:3)'*t_0;
    
    sens = SensorCore(imu_attachement_rarm{i}{2}(1:end-2));
    sens.addDecorator('gyroscope');
    sens.addDecorator('accelerometer');
    T = eye(4);
    T(1:3,1:3) = frame.t(1:3,1:3)'*R_0_imu';
    T(1:3,4) = t_f;
    mdl_rarm.addSensor(sens,frame.name,T)
end
mdl_rarm.forwardPosition();

%% Set upe IMU measurement Vectors 
time_stamp = '2019_02_07_13_57_16';
imu_dat_path = 'C:\aslab\data\bench\imu\';
r_arm_imu_files = {['00066681EA98_' time_stamp '.header'],...
    ...%['00066681EA9B_' time_stamp '.header'],...
    ['00066681EB52_' time_stamp '.header']};
imus_rarm = tinySensorDataHandle.empty();
num_samples_rarm = [];
for i=1:numel(r_arm_imu_files)
    imu = arsLoader([imu_dat_path r_arm_imu_files{i}]);
    imus_rarm(i) = imu;
    num_samples_rarm(i) = size(imu.accelerometerCalibrated,1);
end

l_arm_imu_files = {['0006667D713A_' time_stamp '.header'],...
    ...%['0006667D7185_' time_stamp '.header'],...
    ['00066681EB52_' time_stamp '.header']};
imus_larm = tinySensorDataHandle.empty();
num_samples_larm = [];
for i=1:numel(l_arm_imu_files)
    imu = arsLoader([imu_dat_path l_arm_imu_files{i}]);
    imus_larm(i) = imu;
    num_samples_larm(i) = size(imu.accelerometerCalibrated,1);
end

min_samples = min([num_samples_rarm num_samples_larm]);

mes_larm = [];
for i = 1:numel(imus_larm)
    mes_larm = [mes_larm imus_larm(i).gyroscopeCalibrated(1:min_samples,:)...
        imus_larm(i).accelerometerCalibrated(1:min_samples,:)];
end
mes_rarm = [];
for i = 1:numel(imus_rarm)
    mes_rarm = [mes_rarm imus_rarm(i).gyroscopeCalibrated(1:min_samples,:)...
        imus_rarm(i).accelerometerCalibrated(1:min_samples,:)];
end

%% Set up and run Multi Chain EKF 
%Reset model
mdl_rarm.position(:) = 0;mdl_rarm.velocity(:) = 0;mdl_rarm.acceleration(:) = 0;
mdl_larm.position(:) = 0;mdl_larm.velocity(:) = 0;mdl_larm.acceleration(:) = 0;

ekf = MC_EKF_Q_DQ_DDQ();
ekf.addModel(mdl_rarm);
ekf.addModel(mdl_larm);
ekf.observation_noise = diag(repmat([0.1 0.1 0.1 1 1 1],1,4));
ekf.covariance = ekf.process_noise;
state_est_imu = zeros(size(mes_rarm,1),ekf.sizeX);

%Add Constraints between the two chains 
C1 = EKF_Constraint_BF('C1',mdl_rarm,'frame_rhand_end',eye(4),mdl_larm,'frame_lhand_end',eye(4));
C1.type(:) = false;C1.type([1 2 3 4 5 6]) = true;
ekf.addConstraint(C1);

vis = rlVisualizer('vis',640,480);
vis.addModel(mdl_rarm);
vis.addModel(mdl_larm);
vis.update();

%% Run EKF and see what happens
dt = 1/50;
for i=1:size(mes_rarm,1)
    ekf.run_iteration(dt,[mes_rarm(i,:) mes_larm(i,:)]');
    state_est_imu(i,:) = ekf.state;
    vis.update();
end


