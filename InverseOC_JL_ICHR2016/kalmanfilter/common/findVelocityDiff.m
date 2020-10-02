function dist = findVelocityDiff(featureSet_mocap, featureSet_imu, frameToDiff)
    % find the mocap frames
    allMocapNames = {featureSet_mocap.frameData.name};
    allImuNames = {featureSet_imu.frameData.name};
    for i = 1:length(frameToDiff)
        indMocapFrame(i) = find(ismember(allMocapNames, frameToDiff{i}) == 1);
        indImuFrame(i) = find(ismember(allImuNames, frameToDiff{i}) == 1);
    end
    
    % calculate the rotation between frame 1 and 2
    dist = zeros(length(featureSet_mocap.time), 1);
    for i = 1:length(featureSet_mocap.time)
        R_mocap1 = reshape(featureSet_mocap.frameData(indMocapFrame(1)).position(i, :), 4, 4);
        R_mocap2 = reshape(featureSet_mocap.frameData(indMocapFrame(2)).position(i, :), 4, 4);
        v_mocap1 = featureSet_mocap.frameData(indMocapFrame(1)).velocity(i, 1:3);
        v_mocap2 = featureSet_mocap.frameData(indMocapFrame(2)).velocity(i, 1:3);
        v_mocap = (R_mocap2(1:3, 1:3)*v_mocap2') - (R_mocap1(1:3, 1:3)*v_mocap1');
        
        R_imu1 = reshape(featureSet_imu.frameData(indImuFrame(1)).position(i, :), 4, 4);
        R_imu2 = reshape(featureSet_imu.frameData(indImuFrame(2)).position(i, :), 4, 4);
        v_imu1 = featureSet_imu.frameData(indImuFrame(1)).velocity(i, 1:3);
        v_imu2 = featureSet_imu.frameData(indImuFrame(2)).velocity(i, 1:3);
        v_imu = (R_imu2(1:3, 1:3)*v_imu2') - (R_imu1(1:3, 1:3)*v_imu1');
        
        dist(i) = norm(v_mocap - v_imu);
    end
end