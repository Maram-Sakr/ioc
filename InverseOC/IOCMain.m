% test RL-based cost function derivations with the original files generated by PC

clear;
close all;
% clc;


%% Wanxin's Configurations
configFilePath = '../Data_json/JinConfig/Squat_IIT/IOC_IITFatigue_Test_Sub15.json';
% configFilePath = '../Data_json/JinConfig/Jump/IOC_Github_Jumping2D_Sub2.json';
% configFilePath='../Data_json/JinConfig/HipFlexion/IOC_HipFlexion_Sub1.json';
% configFilePath='../Data_json/JinConfig/KneeHipFlexion/IOC_KneeHipFlexion_Sub1.json';
% configFilePath='../Data_json/JinConfig/SitToStand/IOC_SitToStand_Sub1.json';
% configFilePath='../Data_json/JinConfig/Squat/IOC_Squat_Sub1.json';
% configFilePath = '../Data_json/LinConfig/IOC_IITFatigue_full.json';

%% Create and/or look for folder where solutions are going to be saved
currentDate = 'IOCResults';
savePath = sprintf('../Data/IOC/%s/', currentDate);
overwriteFiles = 1;

%% Set up internal parameters
% Add paths to directories with model definition and util functions
setPaths();

% Load json file with list of all trials on which IOC will be run
configFile = jsondecode(fileread(configFilePath));
n = length(configFile.Files);

for i=3
    runParam = [];
    configFileI = configFile.Files(i);

    % if the source matfile is not found in the json path, search these
    % following locations as well, such as for Sharcnet deployment
    potentialBasePaths = {'/project/6001934/data/', ...
        configFileI.basepath, ...
        'H:/data'};
    
    % load the specific trialinfo
    fprintf("Processing %s file \n", configFileI.runName);
    trialInfo = loadTrialInfo(configFileI, configFile, potentialBasePaths, configFilePath);
    
    % does the target folder already exist? 
    subsavePath = fullfile(savePath, trialInfo.runName);
    [status, alreadyExist] = checkMkdir(subsavePath);
    
    if ~alreadyExist || overwriteFiles
%         IOCRun(trialInfo, subsavePath);
        IOCIncomplete(trialInfo,savePath)
    end
end
