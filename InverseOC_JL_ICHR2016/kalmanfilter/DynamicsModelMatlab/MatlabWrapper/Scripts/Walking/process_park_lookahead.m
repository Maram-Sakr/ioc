%% Walking in the park using alternating constrants
% NOTE ACCIDENTALLY SWITCHED LEFT AND RIGHT FOOT SENSORS DURING COLLECTION
addpath('../../');
addpath('../');

addpath(genpath('C:\asl_git\kalmanfilter\ik_framework\common\ars'));
data_path = 'C:\aslab\data\Gait_lowerbody_2019\Pilot Data\magtest\mocap\';
imu_dat_path = 'C:\aslab\data\Gait_lowerbody_2019\Pilot Data\magtest\imu\';
mdlFilepath = '..\..\Models\avatar_v04_p_bothLegs_zyx_hip.xml';
imu_mdlFilepath = '..\..\Models\avatar_v04_p_bothLegs_zyx_hip.xml';

%Straight Line RD Length of Box
%imu_data_time_stamp = '_2019_06_25_11_23_05';
%CCW Square
imu_data_time_stamp = '_2019_06_25_11_25_10';
%Static in 
imu_gha_static_time_stamp = '_2019_06_25_11_18_34';
imu_gha_dynamic_RL_time_stamp = '_2019_06_25_11_19_27';
imu_gha_dynamic_LL_time_stamp = '_2019_06_25_11_20_06';
imu_gha_dynamic_TF_time_stamp = '_2019_06_25_11_20_45';

%This data is used to build the model, should be static neutral pose
model_build_trc = 'GHA_STD_BF.trc';
%These are the static indeces we use when averaging marker positions for
%model building, should cut out the squat
m_indeces  = 2000:5000;

%This is the IK trc file
ik_trc = 'GHA_STD_BF.trc';

visualize = 1;

%% Load the TRC File and build the model using Harrington 2007 for hip joint positions


%Load TRC data
trc = parseTRC([data_path model_build_trc]);
trcData = trc.data;
%Convert all to meters
m_names = fieldnames(trcData);
m_names = m_names(3:end);
for i=1:numel(m_names)
   trcData.(m_names{i}) = (rotx(pi/2)*trcData.(m_names{i})')'/1000; 
end

%Load the model
mdl = rlCModel(mdlFilepath);
mdl.forwardPosition
vis = rlVisualizer('vis',640,480);
vis.addModel(mdl);
vis.update;

%Put all the actual markers into vis 
for i=1:numel(m_names)
   vis.addMarker(m_names{i},mean(trcData.(m_names{i})(m_indeces,:)));
end

%Rotation calculate based on the mean of mid->front and right for y
%Here we get the world to base transform to match Mocap Data
front = mean((trcData.ASIS_R(m_indeces,:)+trcData.ASIS_L(m_indeces,:))/2);
back = mean((trcData.PSIS_R(m_indeces,:)+trcData.PSIS_L(m_indeces,:))/2);
mid = (front+back)/2;
left = mean(trcData.ASIS_L(m_indeces,:));
right = mean(trcData.ASIS_R(m_indeces,:));

%This is rotation from world to body orieantation in mocap
[~,R] = points2rot([front(1:2) 0],[mid(1:2) 0],[left(1:2) 0]);

lasis = mean(trcData.ASIS_L(m_indeces,:))';
rasis = mean(trcData.ASIS_R(m_indeces,:))';
lback = mean(trcData.PSIS_L(m_indeces,:))';
rback = mean(trcData.PSIS_R(m_indeces,:))';
lknee = (mean(trcData.KNEE_L_LAT(m_indeces,:)',2) + mean(trcData.KNEE_L_MED(m_indeces,:)',2))/2;
rknee = (mean(trcData.KNEE_R_LAT(m_indeces,:)',2) + mean(trcData.KNEE_R_MED(m_indeces,:)',2))/2;
lankle = (mean(trcData.ANKLE_L_LAT(m_indeces,:)',2) + mean(trcData.ANKLE_L_MED(m_indeces,:)',2))/2;
rankle = (mean(trcData.ANKLE_R_LAT(m_indeces,:)',2) + mean(trcData.ANKLE_R_MED(m_indeces,:)',2))/2;
ltoe = (mean(trcData.FOOT_L_LAT(m_indeces,:)',2) + mean(trcData.FOOT_L_MED(m_indeces,:)',2))/2;
rtoe = (mean(trcData.FOOT_R_LAT(m_indeces,:)',2) + mean(trcData.FOOT_R_MED(m_indeces,:)',2))/2;
lheel = mean(trcData.HEEL_L(m_indeces,:)',2);
rheel = mean(trcData.HEEL_R(m_indeces,:)',2);

%Distance between hips as calculated in

%@ARTICLE{harrington2007prediction,
%    author = {Harrington, ME and Zavatsky, AB and Lawson, SEM and Yuan, Z and Theologis,TN},
%    title = {Prediction of the hip joint centre in adults, children, and patients
%    with cerebral palsy based on magnetic resonance imaging},
%    journal = {Journal of biomechanics},
%    year = {2007},
%    volume = {40}
%}

%Pelvis Width calculated using x and y only
PW = norm(lasis(1:2) - rasis(1:2));
%Pelvis Depth calculated using x and y only
PD = norm(abs((lasis(1:2)+rasis(1:2))/2 - (lback(1:2)+rback(1:2))/2));
%Leg Length
LL = (norm(rasis-rheel) + norm(lasis-lheel))/2;

%So going from the middle the joint center is predicted in mm as
x = -0.24*PD-9.9/1000;
y = 0.28*PD+0.16*PW+7.9/1000;
z = -0.16*PW-0.04*LL-7.1/1000;
% Where x is from middle to front, y is from middle to side, and z is
% up
asismid = (lasis + rasis)/2;
hipcentre_static = (lasis + rasis + lback + rback) / 4;
hipcentre_to_asismid = asismid - hipcentre_static;

%Set model's origin to middle of pelvis
mdl.transforms(1).t = eye(4);
mdl.transforms(1).t(1:3,4) = hipcentre_static;

%Set model's mid pelvis orientation
eul_static = rotm2eul(R','XYZ');
mdl.position(4:6) = eul_static;
mdl.forwardPosition();

%Set the transform from middle of pelvis to hip joint centers
%Note that hip joint centers start at post:b_pelvis body while the
%harrington x y z is in x = front, y = side, z = up frames so we rotate it
%since out model is y forward x side z up

%Here we have pelvis middle to hip joint centers in world frame
%hipcentre to left hip joint center
hipcentre_to_lhipjc = ([x y z]' + hipcentre_to_asismid);
%hipcentre to right hip joint center
hipcentre_to_rhipjc = ([x -y z]' + hipcentre_to_asismid);

%We convert it to our model frame 
%Set the transforms
t_indx = find(contains({mdl.transforms.name},'post:b_pelvis_to_pre:b_left_upperleg'),1);
trans = mdl.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;
trans.t(1:3,4) = f_in.t(1:3,1:3)'*hipcentre_to_lhipjc;

t_indx = find(contains({mdl.transforms.name},'post:b_pelvis_to_pre:b_right_upperleg'),1);
trans = mdl.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;
trans.t(1:3,4) = f_in.t(1:3,1:3)'*hipcentre_to_rhipjc;
mdl.forwardPosition();

%Hip to knee
%Left
t_indx = find(contains({mdl.transforms.name},'post:b_left_upperleg_to_pre:b_left_calf'),1);
trans = mdl.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;
t_lhip_to_lknee = lknee-f_in.t(1:3,4);
trans.t(1:3,4) = f_in.t(1:3,1:3)'*t_lhip_to_lknee;
%Right
t_indx = find(contains({mdl.transforms.name},'post:b_right_upperleg_to_pre:b_right_calf'),1);
trans = mdl.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;
t_rhip_to_rknee = rknee-f_in.t(1:3,4);
trans.t(1:3,4) = f_in.t(1:3,1:3)'*t_rhip_to_rknee;
mdl.forwardPosition();

%Knee to Ankle
%Left
t_indx = find(contains({mdl.transforms.name},'post:b_left_calf_to_pre:b_left_foot'),1);
trans = mdl.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;
t_lknee_to_lankle = lankle-f_in.t(1:3,4);
trans.t(1:3,4) = f_in.t(1:3,1:3)'*t_lknee_to_lankle;

%Right
t_indx = find(contains({mdl.transforms.name},'post:b_right_calf_to_pre:b_right_foot'),1);
trans = mdl.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;
t_lknee_to_lankle = rankle-f_in.t(1:3,4);
trans.t(1:3,4) = f_in.t(1:3,1:3)'*t_lknee_to_lankle;
mdl.forwardPosition();

%Ankle to middle of foot
%Left
t_indx = find(contains({mdl.transforms.name},'post:b_left_foot_to_pre:b_left_toe'),1);
trans = mdl.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;
lfoot_mid = (ltoe+lheel)/2;
t_lankle_to_ltoe = [lheel(1) lheel(2) 0]'-f_in.t(1:3,4);
trans.t(1:3,4) = f_in.t(1:3,1:3)'*t_lankle_to_ltoe;
%Right
t_indx = find(contains({mdl.transforms.name},'post:b_right_foot_to_pre:b_right_toe'),1);
trans = mdl.transforms(t_indx);
f_in = trans.frame_in;
f_out = trans.frame_out;
rfoot_mid = (rtoe+rheel)/2;
t_rankle_to_rtoe = [rheel(1) rheel(2) 0]'-f_in.t(1:3,4);
trans.t(1:3,4) = f_in.t(1:3,1:3)'*t_rankle_to_rtoe;
mdl.forwardPosition();

%% Load the TRC that will be used for IK
ik_trc = parseTRC([data_path ik_trc]);
ik_trcData = ik_trc.data;
%Convert all to meters
m_names = fieldnames(ik_trcData);
m_names = m_names(3:end);
for i=1:numel(m_names)
   ik_trcData.(m_names{i}) = (rotx(pi/2)*ik_trcData.(m_names{i})'/1000)'; 
end

%% Position the model such that it matches the first IK TRC frame
first_indeces = 1:5;
front = mean((ik_trcData.ASIS_R(first_indeces,:)+ik_trcData.ASIS_L(first_indeces,:))/2);
back = mean((ik_trcData.PSIS_R(first_indeces,:)+ik_trcData.PSIS_L(first_indeces,:))/2);
mid = (front+back)/2;
left = mean(ik_trcData.ASIS_L(first_indeces,:));
right = mean(ik_trcData.ASIS_R(first_indeces,:));
%This is rotation from world to body orieantation in mocap
[~,R] = points2rot([front(1:2) 0],[mid(1:2) 0],[left(1:2) 0]);
asismid = (lasis + rasis)/2;
hipcentre = mid;
%Set model's origin to middle of pelvis
mdl.transforms(1).t = eye(4);
mdl.transforms(1).t(1:3,4) = hipcentre;
%Set model's mid pelvis orientation
eul = rotm2eul(R','XYZ');
mdl.position(4:6) = eul;
mdl.forwardPosition();


%% Attach Markers
marker_attachement = {...
    {'post:b_pelvis','ASIS_R','ASIS_L','PSIS_R','PSIS_L'};...
    {'post:b_right_upperleg','KNEE_R_MED','KNEE_R_LAT'};...
    {'post:b_left_upperleg','KNEE_L_MED','KNEE_L_LAT'};...
    {'post:b_right_calf','ANKLE_R_LAT','ANKLE_R_MED'};...
    {'post:b_left_calf','ANKLE_L_LAT','ANKLE_L_MED'};...
    {'post:b_right_foot','FOOT_R_LAT','FOOT_R_MED','HEEL_R'};...
    {'post:b_left_foot','FOOT_L_LAT','FOOT_L_MED','HEEL_L'};...
    };

for i=1:numel(marker_attachement)
    f_name =  marker_attachement{i}{1};
    frame = mdl.getFrameByName(f_name);
    
    for j=2:numel(marker_attachement{i})
        m_name = marker_attachement{i}{j};
        
        
        %Figure out the mean position
        marker_pos = ik_trcData.(m_name);
        %Rotate to body frame
        mean_m_pos = mean(marker_pos(first_indeces,:))';
        
        %Create the sensor
        sens = SensorCore(marker_attachement{i}{j});
        sens.addDecorator('position');
        
        %Attach the sensor to the model
        t_w = mean_m_pos-frame.t(1:3,4); %Translation in world frame
        t_f = frame.t(1:3,1:3)'*t_w;     %Translation in frame
        T = eye(4);
        T(1:3,4) = t_f;
        mdl.addSensor(sens,frame.name,T)
    end
end
mdl.forwardPosition();

%% Visualize
if visualize
vis = rlVisualizer('vis',640,480);
mdl.forwardPosition();
vis.addModel(mdl);
%Put all the actual markers into vis 
for i=1:numel(m_names)
   vis.addMarker(m_names{i},mean(ik_trcData.(m_names{i})(first_indeces,:)));
end
vis.update();
end

%% Build measurement vectors
mes = [];
for i=1:numel(marker_attachement)
    for j = 2:numel(marker_attachement{i})
        mes = [mes ik_trcData.(marker_attachement{i}{j})];
    end
end
mes_obj = SensorMeasurement(size(mes,1),numel(mdl.sensors));
[mes_obj.type] = deal(1);
[mes_obj.size] = deal(3);
mes_obj.setMesArray(mes);

%% Set up magik EKF for IK 

ekf = EKF_Q_DQ_DDQ(mdl);
ekf.observation_noise = ekf.observation_noise*0.01;
eta = 10;
dt = 1/ik_trc.DataRate;
%Process noise
dim = numel(mdl.joints);
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

%% Run EKF to converge to first frame

matches = [1:numel(mdl.sensors)]';
matches = [matches matches];
for i=1:100
    z = mes_obj(1,:);    
    ekf.run_iteration(dt,z,matches);
end
vis.update();

%% Run ekf for all frames
state_est = zeros(size(mes,1),numel(ekf.state));
for i=1:size(mes,1)
    
    %This is the measurement for current timestep, must be vertical vector
    z = mes_obj(i,:);    
    ekf.run_iteration(dt,z);
    state_est(i,:) = ekf.state;
    %Draw
    disp(['Frame: ' num2str(i) ' / ' num2str(size(mes,1))]);
    if mod(i,(1/20)/dt) == 0 && visualize
        for j=1:numel(m_names)
            vis.addMarker(m_names{j},ik_trcData.(m_names{j})(i,:));
        end
        vis.update
    end
end


%% Create a new model with IMUs attached to it
mdl_imu = rlCModel(imu_mdlFilepath);
mdl_imu.forwardPosition();

%Make this new model same as trc model
trc_transforms = {mdl.transforms.name};
for i=1:numel(mdl_imu.transforms)
    if(strcmp(mdl_imu.transforms(i).type,'fixed'))
        t_indx = find(contains(trc_transforms,mdl_imu.transforms(i).name),1,'first');
        if ~isempty(t_indx)
            mdl_imu.transforms(i).t = mdl.transforms(t_indx).t;
        end
    end
end
mdl_imu.transforms(1).t(1:3,4) = hipcentre_static;
mdl_imu.position(4:6) = eul_static;
mdl_imu.forwardPosition();

%% Attach IMUS
imu_indeces = m_indeces;

imu_attachement = {...
    {'post:b_pelvis','TORSO_IMU_L','TORSO_IMU_T','TORSO_IMU_R'};...
    {'post:b_right_upperleg','KNEE_R_IMU_L','KNEE_R_IMU_T','KNEE_R_IMU_R'};...
    {'post:b_left_upperleg','KNEE_L_IMU_L','KNEE_L_IMU_T','KNEE_L_IMU_R'};...
    {'post:b_right_calf','ANKLE_R_IMU_L','ANKLE_R_IMU_T','ANKLE_R_IMU_R'};...
    {'post:b_left_calf','ANKLE_L_IMU_L','ANKLE_L_IMU_T','ANKLE_L_IMU_R'};...
    {'post:b_right_foot','FOOT_R_IMU_L','FOOT_R_IMU_T','FOOT_R_IMU_R'};...
    {'post:b_left_foot','FOOT_L_IMU_L','FOOT_L_IMU_T','FOOT_L_IMU_R'};...
    };

pelvis_frame = mdl_imu.getFrameByName('post:b_pelvis:rotateZ');
for i=1:numel(imu_attachement)
    f_name =  imu_attachement{i}{1};
    frame = mdl_imu.getFrameByName(f_name);
    
    P = mean(trcData.(imu_attachement{i}{2})(imu_indeces,:));
    Q = mean(trcData.(imu_attachement{i}{3})(imu_indeces,:));
    R = mean(trcData.(imu_attachement{i}{4})(imu_indeces,:));
    [R_imu_0, R_0_imu] = points2rot(P,Q,R);
    t_0 =  mean([P;Q;R])' - frame.t(1:3,4);
    t_f = frame.t(1:3,1:3)'*t_0;
    
    sens = SensorCore(imu_attachement{i}{2}(1:end-2));
    sens.addDecorator('gyroscope');
    sens.addDecorator('accelerometer');
    T = eye(4);
    %We use GHA to figure out sensor to body rotations and apply that to
    %the sensor data thus all of the sensors are attached with x down, y to
    %the side, and z forward. This is equivalent to applying roty(pi/2) to
    %the post:b_pelvis:rotateZ frame
    
    Rpelvis_frame = pelvis_frame.t(1:3,1:3)'*frame.t(1:3,1:3);
    Rframe_imu = Rpelvis_frame'*roty(pi/2);
    
    T(1:3,1:3) = Rframe_imu;
    T(1:3,4) = t_f;
    mdl_imu.addSensor(sens,frame.name,T)
end
mdl_imu.forwardPosition();

if visualize
vis = rlVisualizer('vis',640,480);
mdl_imu.forwardPosition();
vis.addModel(mdl_imu);
%Put all the actual markers into vis 
for i=1:numel(m_names)
   vis.addMarker(m_names{i},mean(trcData.(m_names{i})(m_indeces,:)));
end
vis.update();
end


%% Attach YAW sensors to each leg 
b = mdl_imu.getFrameByName('post:b_pelvis:rotateZ');

sens = SensorCore('r_yaw');
sens.addDecorator('yaw');
sens.base = b;
f = mdl_imu.getFrameByName('post:b_right_upperleg:rotateZ');
f_to_b = SE3.fastInverse(f.t)*b.t;
T = eye(4);
T(1:3,1:3)=f_to_b(1:3,1:3);
T(1:3,4) = f.t(1:3,1:3)'*[0.1 0 0]';
mdl_imu.addSensor(sens,f.name,T);

sens = SensorCore('l_yaw');
sens.addDecorator('yaw');
sens.base = b;
f = mdl_imu.getFrameByName('post:b_left_upperleg:rotateZ');
f_to_b = SE3.fastInverse(f.t)*b.t;
T = eye(4);
T(1:3,1:3)=f_to_b(1:3,1:3);
T(1:3,4) = f.t(1:3,1:3)'*[0.1 0 0]';
mdl_imu.addSensor(sens,f.name,T);

%% Load IMU DATA, note switched feet compared to the regular data collections
imu_names = {'0006667D7185',...
    '00066681EA9B',...
    '0006667BA9F2',...
    '0006667D713A',...
    '0006667D713B',...
    '00066681EA98',...
    '00066681EA9C',...
    };

%Assosiated GHA with each IMU name
dynamic_gha_stamps = {imu_gha_dynamic_TF_time_stamp,...
    imu_gha_dynamic_RL_time_stamp,...
    imu_gha_dynamic_LL_time_stamp,...
    imu_gha_dynamic_RL_time_stamp,...
    imu_gha_dynamic_LL_time_stamp,...
    imu_gha_dynamic_RL_time_stamp,...
    imu_gha_dynamic_LL_time_stamp...
};

%Hacky bias removal for walkin in 

imus = tinySensorDataHandle.empty();
num_samples = [];
Rs = zeros(3,3,numel(imu_names));
for i=1:numel(imu_names)
    %Load actual data we will be processing
    imu_path = [imu_dat_path imu_names{i} imu_data_time_stamp '.header'];
    imu = arsLoader(imu_path);
    
    %Load GHA data
    imu_path = [imu_dat_path imu_names{i} imu_gha_static_time_stamp '.header'];
    imu_GHA_static = arsLoader(imu_path);
    %Load GHA data
    imu_path = [imu_dat_path imu_names{i} dynamic_gha_stamps{i} '.header'];
    imu_GHA_dynamic = arsLoader(imu_path);
    %Apply GHA calibration to the IMU 
    [R, gyro_bias] = GHA(imu_GHA_static,imu_GHA_dynamic,1,2,1000:3000);
    imu.gyroscopeCalibrated = imu.gyroscopeCalibrated - repmat(gyro_bias,size(imu.gyroscopeCalibrated,1),1);
    imu.applyRotation(R);
    Rs(:,:,i) = R;
    imus(i) = imu;
    
    num_samples(i) = size(imu.accelerometerCalibrated,1);
end
min_samples = min([num_samples]);
mes_imu = [];
for i = 1:numel(imus)
    
    gyro= imus(i).gyroscopeCalibrated(1:min_samples,:);
    accel =imus(i).accelerometerCalibrated(1:min_samples,:);
    
    accel = lowpass(accel,10,imu(1).samplingRate);
    gyro = lowpass(gyro,10,imu(1).samplingRate);
    
    mes_imu = [mes_imu gyro accel];
end

%Add yaw measurement
num_yaw = sum(contains({mdl_imu.sensors.type},'yaw'));
num_imu = sum(contains({mdl_imu.sensors.type},'gyroscope'));
mes_imu = [mes_imu zeros(size(mes_imu,1),num_yaw)];

%Add prismatic acceleration to 0 measurement
%mes = [mes repmat(mdl.g',size(mes,1),1)];


%% Now reset the model and set up the alternating constrained EKF
dof = numel(mdl.joints);
mdl_imu.position(:) = 0;
mdl_imu.velocity(:) = 0;
mdl_imu.acceleration(:) = 0;
mdl_imu.forwardPosition;
mdl_imu.forwardVelocity;
mdl_imu.forwardAcceleration;

dt = 1/imus(1).samplingRate;
%EKF with constrained left leg
ekf_lc = MC_EKF_Q_DQ_DDQ();
ekf_lc.dt = dt;
ekf_lc.addModel(mdl_imu);
%load P_init.mat
ekf_lc.covariance = ekf_lc.process_noise;
                                        %GYRO           ACCEL
ekf_lc.observation_noise = diag(repmat([0.01 0.01 0.01 0.1 0.1 0.1],1,num_imu));
%Force pelvis accel to have smaller noise
ekf_lc.observation_noise(4:6,4:6)  =eye(3)*0.1;

%Yaw noise
num_yaw = sum(contains({mdl_imu.sensors.type},'yaw'));
ekf_lc.observation_noise = blkdiag(ekf_lc.observation_noise,0.0001*eye(num_yaw));


%Add the left foot at current position constraint
fc_l = mdl_imu.getFrameByName('post:b_left_toe');
T = mdl_imu.getFrameByName('post:b_left_toe').t;
C_l = EKF_Constraint_BFConst('LC',mdl_imu,'post:b_left_toe',eye(4),T);
C_l.type(:) = false; C_l.type([4 5 6]) = true;
C_lv = EKF_Constraint_BFConst_vel('LCv',mdl_imu,'post:b_left_toe',eye(4),zeros(6,1));
C_lv.type(:) = false; C_lv.type([4 5 6]) = true;
ekf_lc.addConstraint(C_l);

%EKF with constrained right leg
ekf_rc = MC_EKF_Q_DQ_DDQ();
ekf_rc.dt = dt;
ekf_rc.addModel(mdl_imu);
ekf_rc.covariance = ekf_lc.covariance;
ekf_rc.observation_noise = ekf_lc.observation_noise;
ekf_rc.process_noise = ekf_lc.process_noise;
%Add the left foot at current position constraint
T = mdl_imu.getFrameByName('post:b_right_toe').t;
fc_r = mdl_imu.getFrameByName('post:b_right_toe');
C_r = EKF_Constraint_BFConst('RC',mdl_imu,'post:b_right_toe',eye(4),T);
C_r.type(:) = false; C_r.type([4 5 6]) = true;
C_rv = EKF_Constraint_BFConst_vel('RCv',mdl_imu,'post:b_right_toe',eye(4),zeros(6,1));
C_rv.type(:) = false; C_rv.type([4 5 6]) = true;
ekf_rc.addConstraint(C_r);

%% Visualize
vis = rlVisualizer('vis',640,480);
mdl_imu.forwardPosition();
vis.addModel(mdl_imu);
vis.update();

%% Run EKF and see what happens
ekf_state = zeros(size(mes_imu,1),ekf_lc.sizeX);
%Selected foot -1: left 1:right
cur_foot = zeros(size(mes_imu,1),1);
z_right = zeros(size(mes_imu,1),1);
z_left = zeros(size(mes_imu,1),1);
mes_pred = mes_imu;
%Velocity of the feet
vel_l = zeros(size(mes_imu,1),3);
vel_r = zeros(size(mes_imu,1),3);
%Positions of the constrained feet
foot_pos = zeros(size(mes_imu,1),2);

%This is the look ahead stuff
looking = false;    %This flag becomes true after we load up the first horizon
horizon = 1;       %How far we look ahead
%Saved States
hor_state_l = zeros(horizon,ekf_lc.sizeX);
hor_state_r = zeros(horizon,ekf_rc.sizeX);
%Saved Covariances
hor_cov_l = zeros(ekf_lc.sizeX,ekf_lc.sizeX,horizon);
hor_cov_r = zeros(ekf_rc.sizeX,ekf_rc.sizeX,horizon);
%Saved projected covariances
hor_icov_l = zeros(ekf_lc.sizeZ,ekf_lc.sizeZ,horizon);
hor_icov_r = zeros(ekf_rc.sizeZ,ekf_lc.sizeZ,horizon);
%Jacobians
hor_H_l = zeros(ekf_lc.sizeZ,ekf_lc.sizeX,horizon);
hor_H_r = zeros(ekf_rc.sizeZ,ekf_rc.sizeX,horizon);
%Saved predicted measurements
hor_mes_l = zeros(horizon,ekf_lc.sizeZ);
hor_mes_r = zeros(horizon,ekf_rc.sizeZ);
%The errors
hor_Es_l = zeros(horizon,1);
hor_Es_r = zeros(horizon,1);

%Preload the look ahead
start_indx = 1;
for i=start_indx:start_indx+horizon-1
    indx = i-start_indx+1;
    z = mes_imu(i,:)';
    z_myaw = z(1:end-num_yaw);
    
    %Run Left Constrained and populate horizon vars
    ekf_lc.run_iteration(dt,z);
    hor_state_l(indx,:) = ekf_lc.state;
    hor_cov_l(:,:,indx) = ekf_lc.covariance;
    %Re-run mes prediction
    hor_mes_l(indx,:) = ekf_lc.makeMeasure(ekf_lc.state);
    z_hat_left_myaw = hor_mes_l(indx,1:end-num_yaw)';
    H_left = ekf_lc.makeH(ekf_lc.state); 
    hor_H_l(:,:,indx) = H_left;
    hor_icov_l(:,:,indx) = H_left*ekf_lc.covariance*H_left'+ekf_lc.observation_noise;
    S_left = hor_icov_l(1:end-num_yaw,1:end-num_yaw,indx);
    S_left_i = inv(S_left);
    hor_Es_l(indx) = (z_myaw-z_hat_left_myaw)'*S_left_i*(z_myaw-z_hat_left_myaw);
    
    %Run Right Constrained and populate horizon vars
    ekf_rc.run_iteration(dt,z);
    hor_state_r(indx,:) = ekf_rc.state;
    hor_cov_r(:,:,indx) = ekf_rc.covariance;
    %Re-run mes prediction
    hor_mes_r(indx,:) = ekf_rc.makeMeasure(ekf_rc.state);
    z_hat_right_myaw = hor_mes_r(indx,1:end-num_yaw)';
    H_right = ekf_rc.makeH(ekf_rc.state); 
    hor_H_r(:,:,indx) = H_right;
    hor_icov_r(:,:,indx) = H_right*ekf_rc.covariance*H_right'+ekf_rc.observation_noise;
    S_right = hor_icov_r(1:end-num_yaw,1:end-num_yaw,indx);
    S_right_i = inv(S_right);
    hor_Es_r(indx) = (z_myaw-z_hat_right_myaw)'*S_right_i*(z_myaw-z_hat_right_myaw);
end

%% Decide on the starting foot
El = sum(hor_Es_l)/horizon;
Er = sum(hor_Es_r)/horizon;

if El < Er
   cur_active = 'l'; 
else
   cur_active = 'r';
end
cur_count = 0;
%% Run the rest with looking ahead
for i=start_indx+1:size(mes_imu,1)
    
    %Pull out the actual measurement horizon
    z_hor = mes_imu(i:i+horizon-1,:);
    
    %For the active foot we just need to run the next iteration 
    if cur_active == 'r'
        %Save the current estiamted state with right foot on ground
        cur_state = hor_state_r(1,:)';
        cur_cov = hor_cov_r(:,:,1);
        z_myaw = z_hor(end,1:end-num_yaw)';
        %Run Right Constrained for the last measurement
        ekf_rc.state = hor_state_r(end,:)';
        ekf_rc.covariance = hor_cov_r(:,:,end);
        ekf_rc.run_iteration(dt,z_hor(end,:)');
        vel_l(i+horizon-1,:) = fc_l.v(4:6);
        vel_r(i+horizon-1,:) = fc_r.v(4:6);
        %Shift all the things down and put in the last one
        hor_state_r(1:end-1) = hor_state_r(2:end);
        hor_state_r(end,:) = ekf_rc.state;
        hor_cov_r(:,:,1:end-1) = hor_cov_r(:,:,2:end);
        hor_cov_r(:,:,end) = ekf_rc.covariance;
        %Re-run mes prediction
        hor_mes_r(1:end-1,:) = hor_mes_r(2:end,:);
        hor_mes_r(end,:) = ekf_rc.makeMeasure(ekf_rc.state);
        z_hat_right_myaw = hor_mes_r(end,1:end-num_yaw)';
        H_right = ekf_rc.makeH(ekf_rc.state); 
        hor_H_r(:,:,1:end-1) = hor_H_r(:,:,2:end);
        hor_H_r(:,:,end) = H_right;
        hor_icov_r(:,:,1:end-1) = hor_icov_r(:,:,2:end);
        hor_icov_r(:,:,end) = H_right*ekf_rc.covariance*H_right'+ekf_rc.observation_noise;
        S_right = hor_icov_r(1:end-num_yaw,1:end-num_yaw,end);
        S_right_i = inv(S_right);
        hor_Es_r(1:end-1) = hor_Es_r(2:end);
        hor_Es_r(end) = (z_myaw-z_hat_right_myaw)'*S_right_i*(z_myaw-z_hat_right_myaw);
        
        %Now for the left foot we have to run the entire horizon starting
        %at the first right constrained state
        ekf_lc.state = cur_state;
        ekf_lc.covariance = cur_cov;
        %Run for the entire horizon assuming left foot is constrainted
        for indx = 1:size(z_hor,1)
            %This is the measurement we are looking at
            z = z_hor(indx,:)';
            z_myaw = z(1:end-num_yaw);
            %Run Left Constrained and populate horizon vars
            ekf_lc.run_iteration(dt,z);
            hor_state_l(indx,:) = ekf_lc.state;
            hor_cov_l(:,:,indx) = ekf_lc.covariance;
            %Re-run mes prediction
            hor_mes_l(indx,:) = ekf_lc.makeMeasure(ekf_lc.state);
            z_hat_left_myaw = hor_mes_l(indx,1:end-num_yaw)';
            H_left = ekf_lc.makeH(ekf_lc.state); 
            hor_H_l(:,:,indx) = H_left;
            hor_icov_l(:,:,indx) = H_left*ekf_lc.covariance*H_left'+ekf_lc.observation_noise;
            S_left = hor_icov_l(1:end-num_yaw,1:end-num_yaw,indx);
            S_left_i = inv(S_left);
            hor_Es_l(indx) = (z_myaw-z_hat_left_myaw)'*S_left_i*(z_myaw-z_hat_left_myaw);
        end
    else
        %Save the current estiamted state with right foot on ground
        cur_state = hor_state_l(1,:)';
        cur_cov = hor_cov_l(:,:,1);
        z_myaw = z_hor(end,1:end-num_yaw)';
        %Run Left Constrained for the last measurement
        ekf_lc.state = hor_state_l(end,:)';
        ekf_lc.covariance = hor_cov_l(:,:,end);
        ekf_lc.run_iteration(dt,z_hor(end,:)');
        vel_l(i+horizon-1,:) = fc_l.v(4:6);
        vel_r(i+horizon-1,:) = fc_r.v(4:6);
        %Shift all the things down and put in the last one
        hor_state_l(1:end-1) = hor_state_l(2:end);
        hor_state_l(end,:) = ekf_lc.state;
        hor_cov_l(:,:,1:end-1) = hor_cov_l(:,:,2:end);
        hor_cov_l(:,:,end) = ekf_lc.covariance;
        %Re-run mes prediction
        hor_mes_l(1:end-1,:) = hor_mes_l(2:end,:);
        hor_mes_l(end,:) = ekf_lc.makeMeasure(ekf_lc.state);
        z_hat_left_myaw = hor_mes_l(end,1:end-num_yaw)';
        H_left = ekf_lc.makeH(ekf_lc.state); 
        hor_H_l(:,:,1:end-1) = hor_H_l(:,:,2:end);
        hor_H_l(:,:,end) = H_left;
        hor_icov_l(:,:,1:end-1) = hor_icov_l(:,:,2:end);
        hor_icov_l(:,:,end) = H_left*ekf_lc.covariance*H_left'+ekf_lc.observation_noise;
        S_left = hor_icov_r(1:end-num_yaw,1:end-num_yaw,end);
        S_left_i = inv(S_left);
        hor_Es_l(1:end-1) = hor_Es_l(2:end);
        hor_Es_l(end) = (z_myaw-z_hat_left_myaw)'*S_left_i*(z_myaw-z_hat_left_myaw);
        
        %Now for the left foot we have to run the entire horizon starting
        %at the first right constrained state
        ekf_rc.state = cur_state;
        ekf_rc.covariance = cur_cov;
        %Run for the entire horizon assuming left foot is constrainted
        for indx = 1:size(z_hor,1)
            %This is the measurement we are looking at
            z = z_hor(indx,:)';
            z_myaw = z(1:end-num_yaw);
            %Run Left Constrained and populate horizon vars
            ekf_rc.run_iteration(dt,z);
            hor_state_r(indx,:) = ekf_rc.state;
            hor_cov_r(:,:,indx) = ekf_rc.covariance;
            %Re-run mes prediction
            hor_mes_r(indx,:) = ekf_rc.makeMeasure(ekf_rc.state);
            z_hat_right_myaw = hor_mes_r(indx,1:end-num_yaw)';
            H_right = ekf_rc.makeH(ekf_rc.state); 
            hor_H_r(:,:,indx) = H_right;
            hor_icov_r(:,:,indx) = H_right*ekf_rc.covariance*H_right'+ekf_rc.observation_noise;
            S_right = hor_icov_r(1:end-num_yaw,1:end-num_yaw,indx);
            S_right_i = inv(S_right);
            hor_Es_r(indx) = (z_myaw-z_hat_right_myaw)'*S_right_i*(z_myaw-z_hat_right_myaw);
        end       
    end
    
    %Look at the error difference over the horizon
    Er = sum(hor_Es_r)/horizon;
    El = sum(hor_Es_l)/horizon;
    is_r = isempty(find(hor_Es_l - hor_Es_r < 0,1));
    is_l = isempty(find(hor_Es_r - hor_Es_l < 0,1));
    if cur_active == 'l' && Er < El && norm(vel_r(i,:)) < 1.4 && cur_count > 20
        %We think left leg is swinging, but left leg error is larger than
        %right by a lot, switch constraint to right leg
        cur_active = 'r';
        cur_count = 0;
    elseif cur_active == 'r' && El < Er && norm(vel_l(i,:)) < 1.4 && cur_count > 20
        cur_active = 'l';
        cur_count = 0;
    end
    cur_count = cur_count +1;
    
    if(cur_active == 'l')
        cur_foot(i) = -1;
        ekf_state(i,:) = hor_state_l(1,:);
        mes_pred(i,:)=ekf_lc.makeMeasure(hor_state_l(1,:)');
        %Update constraints by fixing toes to Z = 0 at the current X and Y
        T = fc_r.t;
        T(3,4) = 0;
        C_r.Tw = T;
        foot_pos(i,:) = fc_l.t(1:2,4);
    else
        cur_foot(i) = 1;
        ekf_state(i,:) = hor_state_r(1,:);
        mes_pred(i,:)=ekf_lc.makeMeasure(hor_state_r(1,:)');
        %Update constraints by fixing toes to Z = 0 at the current X and Y
        T = fc_l.t;
        T(3,4) = 0;
        C_l.Tw = T;
        foot_pos(i,:) = fc_r.t(1:2,4);
    end
    
    disp(['Frame: ' num2str(i) '/' num2str(size(mes_imu,1)) ', Foot: ' cur_active ', el-er: ' num2str(Er-El)]);
    if visualize
        vis.update();
    end
    if mod(i,30) == 0 && i > 200 && visualize
        vis.addMarker(num2str(i),[foot_pos(i,:) 0]');
    end
end



    %% Lets take a look at the magnetometer
dof = numel(mdl_imu.joints);
mdl_imu.position = ekf_state(1,1:dof);
mdl_imu.forwardPosition();

%Set Magnetometer Field based on mean of straight line walk
m = [-0.65; -0.75; 0];
m = m/norm(m);
mdl_imu.m = m;

%Run forward position to get rotation imu to world
Rs_world_imu = zeros(3,3,size(mes_imu,1));

%Create a magnetometer sensor
mag_sens = SensorCore('mag');
mag_sens.addDecorator('magnetometer');
pelvis_frame = mdl_imu.getFrameByName('post:b_pelvis');
T = SE3.fastInverse(pelvis_frame.t)*mdl_imu.sensors(1).transform;
mdl_imu.addSensor(mag_sens,pelvis_frame.name,T);

%Visualize
vis = rlVisualizer('vis',640,480);
mdl_imu.forwardPosition();
vis.addModel(mdl_imu);
vis.update();

mag_mes_sim = zeros(size(mes_imu,1),3);

for i=1:size(mes_imu,1)-10
    tic;
    mdl_imu.position = ekf_state(i,1:dof);
    mdl_imu.forwardPosition();
    mag_mes_sim(i,:) = mag_sens.measurement;
    Rs_world_imu(:,:,i) = mdl_imu.sensors(1).transform(1:3,1:3);
    vis.update();
    %pause(0.01-toc)
end

%Remove mag sensor
%mdl_imu.removeSensor(mag_sens);

%%
imu = imus(1);
mag = [imu.data.MagnetometerXUncalibrated imu.data.MagnetometerYUncalibrated ...
    imu.data.MagnetometerZUncalibrated];
mag = mag(1:size(Rs_world_imu,3),:);

%This is the intrinsic calibration stuff
Rai = [-1.395123, -423.23282, 18.50863; -418.288, 3.605, 0.516197; -0.074568, 1.676519, -425.8222];
Rg = inv([40.527225, -3761.8706, 187.26181; -3777.4045, -28.77469, -8.106913; 47.561314, -109.34899, -3796.6243]);
[U,S,V] = svd(Rai,'econ');
Ra = U*eye(3)*V';

%Apply GHA Rotation to the MAG
mag_ub = mag - repmat(mag_bias,size(mag,1),1);
mag_ub_scale = mag_ub./repmat(mag_scale,size(mag_ub,1),1);

%Rotate magnetometer to same frame as accelerometer based on data sheet
mag_ub_scale_rot = (rotx(pi)*rotz(-pi/2)*mag_ub_scale')';
%Apply accelerometer alignment
mag_ub_scale_rot = (Ra*mag_ub_scale_rot')';
%Apply GHA Rotation to the MAG
mag_ub_scale_rot = (Rs(:,:,1)*mag_ub_scale_rot')';

%Constant field in sensor frame
mag_const = mean(mag_ub_scale_rot(1:100,:));
%Constant field in world frame
R_mean = zeros(3,3);
for i=1:100
    R_mean = R_mean + Rs_world_imu(:,:,i);
end
[U S V] = svd(R_mean);
R_mean = U*eye(3)*V';
mag_const_w = R_mean*mean(mag_ub_scale_rot(1:100,:))';

% Now lets to keep only x and y world components 
mag_world_z = [0 0 mag_const_w(3)]';
z_imu = zeros(size(mag_ub_scale_rot));
%Projection onto world Z axis in IMU frame of mag measurements
mag_z = mag_ub_scale_rot;
for i=1:size(mag_ub_scale_rot,1)
    z_imu(i,:) = Rs_world_imu(3,:,i);
    mag_z(i,:) = dot(mag_ub_scale_rot(i,:),Rs_world_imu(3,:,i))*Rs_world_imu(3,:,i);
end
%Magnetometer without the world Z component
mag_no_z = mag_ub_scale_rot - mag_z;
mag_no_z = mag_no_z./repmat(sqrt(sum(mag_no_z.^2,2)),1,3);
mag_no_z_init = mean(mag_no_z(200:1000,:));
mag_no_z_init = mag_no_z_init/norm(mag_no_z_init);

%Try to see what mag should look like
mag_no_z_w = mag_no_z;
for i=1:size(mag_ub_scale_rot,1)
    mag_no_z_w(i,:) = Rs_world_imu(:,:,i)'*[1; 0; 0];
end

