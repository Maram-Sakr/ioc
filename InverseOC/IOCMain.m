% test RL-based cost function derivations with the original files generated
% by PC

% clear all;
clc;
tic;

%% Create and/or look for folder where solutions are going to be saved
% currentDate = datestr(datetime("now"),"yyyy_mm_dd_HH_MM_SS");
% currentDate = 'expressiveTest';
currentDate = 'result09_healthy1';
savePath = sprintf('../Data/IOC/%s/', currentDate);

overwriteFiles = 1;

% confi gFilePath = '../Data/IOC_gitupload_test.json';
% configFilePath = '../Data/IOC_gitupload_jumping2D.json';
% configFilePath = '../Data/IOC_ExpressiveData_test.json';
% configFilePath = '../Data/IOC_IITFatigue_test.json';
configFilePath = '../Data_json/IOC_Healthy1.json';
% configFilePath = '../Data_json/IOC_gitupload_jumping2D.json';
% configFilePath = '../Data_json/IOC_IITFatigue_test.json';

%% Set up internal parameters
% Add paths to directories with model definition and util functions
setPaths();

% Load json file with list of all trials on which IOC will be run
configFile = jsondecode(fileread(configFilePath));
n = length(configFile.Files);

for i=n
    runParam = [];
    configFileI = configFile.Files(i);
    
    % if the source matfile is not found in the json path, search these
    % following locations as well, such as for Sharcnet deployment
    potentialBasePaths = {'/project/6001934/data/', ...
        configFileI.basepath};
    
    % load the specific trialinfo
    fprintf("Processing %s file \n", configFileI.runName);
    [trialInfo] = loadTrialInfo(configFileI, configFile, potentialBasePaths, configFilePath, targetPath);
    
    % does the target folder already exist? 
    subsavePath = fullfile(savePath, trialInfo.runName);
    [status, alreadyExist] = checkMkdir(subsavePath);
    
    if ~alreadyExist || overwriteFiles
        IOCRun(trialInfo, subsavePath);
    end
end

toc