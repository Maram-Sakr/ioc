function IOCAnalysis()
    setPaths();
%     nowstr = datestr(now, 'yyyymmddHHMMSS');
    nowstr = '20200316_fatigueEdges';
    nowstr2 = '20200316_fatigueEdges';
      
    basePath = ['D:\results\fatigue_ioc02_weightsAssembled\' nowstr '\'];
    searchString = 'mat_dataInd_*.mat';
    filepathSegments = 'ManualSeg.xlsx';
    outputPath = ['D:\results\fatigue_ioc03_weightsPattern\' nowstr2 '\'];
    checkMkdir(outputPath);
    
    currBasePathDir = dir([basePath searchString]);
    for j = 1:length(currBasePathDir)
        currFileName = currBasePathDir(j).name;
        
        if strcmpi(currFileName(end), '.')
            continue; % it's . or ..
        end

        % load and plot stuff
        filepathCurrDataInd = fullfile(basePath, currFileName);
        filepathCurrWeiCum = strrep(filepathCurrDataInd, 'mat_dataInd', 'mat_weiCum');
        filepathCurrWeiInd = strrep(filepathCurrDataInd, 'mat_dataInd', 'mat_weiInd');
        filepathCsv = fullfile(outputPath, 'analysis.csv');
        calculateMetrics(filepathCurrDataInd, filepathCurrWeiCum, filepathCurrWeiInd, filepathSegments, outputPath, filepathCsv);
    end
end

function loadAndPlotStuff(filepath)
    load(filepath);
    
end

function calculateMetrics(filepathCurrDataInd, filepathCurrWeiCum, filepathCurrWeiInd, filepathSegments, outputPath, filepathCsv)
    outFileSpec = filepathCurrWeiCum(end-27:end-10);
%     outputPath = [outputPath outFileSpec '\'];
    
    outMat = [outputPath, 'mat_', outFileSpec, '.mat'];
    outCsv = [filepathCsv];
    checkExistDir = dir([outputPath '\' outFileSpec]);

    if length(checkExistDir) > 0
        fprintf('%s detected, skipping\n', outFileSpec);
        return;
    end
    
    if ~exist(filepathCurrDataInd, 'file') ||  ~exist(filepathCurrWeiCum, 'file')
        fprintf('Missing %s or %s, skipping\n', filepathCurrDataInd, filepathCurrWeiCum);
        return;
    end
    
    checkMkdir(outputPath);
    
    load(filepathCurrDataInd);
    load(filepathCurrWeiCum);
    
    % load seg info
    trialInfo = matData.trialInfo;
    [segData, segOnlyDataTable, restOnlyDataTable] = loadSegmentInfo(filepathSegments, trialInfo);
    segmentInfo = segData;
    
    % replace trialInfo's load path
    oldLoadPath = trialInfo.path;
    newLoadPath = strrep(oldLoadPath, 'D:\aslab_svn\data_IK\FullBody_IIT_2017', 'D:\results\fatigue_ioc00_ik');
    trialInfo.path = newLoadPath;
    
    model = getModel(trialInfo); % now need to run FK/FD to get dq and tau
    traj = model.loadData(trialInfo);
    allJointNames = {model.model.joints.name};
    
    for i = 1:size(traj.q, 2)
        featureLabel = ['q_' num2str(i) '_' allJointNames{i}];
        stats_q(i) = featureCalc1(trialInfo, featureLabel, traj.trajT, traj.q(:, i), segmentInfo, outputPath, outCsv, outFileSpec);
    end
    for i = 1:size(traj.dq, 2)
        featureLabel = ['dq_' num2str(i) '_' allJointNames{i}];
        stats_dq(i) = featureCalc1(trialInfo, featureLabel, traj.trajT, traj.dq(:, i), segmentInfo, outputPath, outCsv, outFileSpec);
    end
    for i = 1:size(traj.tau, 2)
        featureLabel = ['tau_' num2str(i) '_' allJointNames{i}];
        stats_tau(i) = featureCalc1(trialInfo, featureLabel, traj.trajT, traj.tau(:, i), segmentInfo, outputPath, outCsv, outFileSpec);
    end
    
    for i = 1:size(matSave.weights, 2)
        featureLabel = ['weights_' matData.featureLabels{i}];
        stats_weights(i) = featureCalc1(trialInfo, featureLabel, matSave.t, matSave.weights(:, i), segmentInfo, outputPath, outCsv, outFileSpec);
    end
    
    save(outMat, 'trialInfo', 'segmentInfo', 'stats_q', 'stats_dq', 'stats_tau', 'stats_weights');
end

function stats = featureCalc1(trialInfo, name, t, feature, segData, outputPath, outCsv, outFileSpec)
    figFileSingleWindowSeg =  [name '_singleWindowSeg_' outFileSpec];
    figFileSingleWindowRest =  [name '_singleWindowRest_' outFileSpec];
    figFileMultiWindow =  [name '_multiWindow_' outFileSpec];

    stats.name = name;
    stats.t = t;
    stats.feature = feature;
    stats.segData = segData;
    
    % calculate metrics on single window level
    [segmentStatsSeg_SingleWindow, segmentStatsRest_SingleWindow] = featureCalc_singleWindow(segData, t, feature);
    
    stats.segmentStatsSeg = segmentStatsSeg_SingleWindow;
    stats.segmentStatsRest = segmentStatsRest_SingleWindow;
    
    [h_seg, h_rest, regression_seg, regression_rest] = plotData_SingleWindow(stats);
    figPath = [outputPath, figFileSingleWindowSeg];
    saveas(h_seg, figPath, 'png');
    saveas(h_seg, figPath, 'fig');
    close(h_seg);
    figPath = [outputPath, figFileSingleWindowRest];
    saveas(h_rest, figPath, 'png');
    saveas(h_rest, figPath, 'fig');
    close(h_rest);
    
    stats.regression_seg = regression_seg;
    stats.regression_rest = regression_rest;
    
%     % calculate between window correlations
%     [segmentStatsSeg_MultiWindow, segmentStatsRest_MultiWindow] = featureCalc_multipleWindow(segData, t, feature);
%     
%     stats.segmentStatsSeg_MultiWindow = segmentStatsSeg_MultiWindow;
%     stats.segmentStatsRest_MultiWindow = segmentStatsRest_MultiWindow;
%     
%     featureParams_MultiWindow = {'corrcoef'};
%     
%     [h, Rsq2_seg_multiWindow, Rsq2_rest_multiWindow] = plotData_MultiWindow(stats, featureParams_MultiWindow);
%     figPath = [outputPath, figFileMultiWindow];
%     saveas(h, figPath, 'png');
%     saveas(h, figPath, 'fig');
%     close(h);
    
    if ~exist(outCsv, 'file')
        header = 'Subject,feature';
        for i = 1:length(regression_seg)
            header = [header ',b_seq_' regression_seg(i).name];
        end
        for i = 1:length(regression_rest)
            header = [header ',b_rest_' regression_rest(i).name];
        end
        for i = 1:length(regression_seg)
            header = [header ',Rsq2_seq_' regression_seg(i).name];
        end
        for i = 1:length(regression_rest)
            header = [header ',Rsq2_rest_' regression_rest(i).name];
        end
%         for i = 1:length(featureParams_MultiWindow)
%             header = [header ',Rsq2_seq_' featureParams_MultiWindow{i}];
%         end
%         for i = 1:length(featureParams_MultiWindow)
%             header = [header ',Rsq2_rest_' featureParams_MultiWindow{i}];
%         end
        header = [header '\n'];
    else
        header = '';
    end
     
     fid = fopen(outCsv, 'a');
     fprintf(fid, [header]);
     
     fprintf(fid, '%s,%s', trialInfo.runName, name);
     for i = 1:length(regression_seg)
         fprintf(fid, ',%f',regression_seg(i).b(2));
     end
     for i = 1:length(regression_rest)
         fprintf(fid, ',%f',regression_rest(i).b(2));
     end
     for i = 1:length(regression_seg)
         fprintf(fid, ',%f',regression_seg(i).Rsq2);
     end
     for i = 1:length(regression_rest)
         fprintf(fid, ',%f',regression_rest(i).Rsq2);
     end
     fprintf(fid, '\n');
     fclose(fid);
end

function [segmentStatsSeg, segmentStatsRest] = featureCalc_multipleWindow(segData, t, feature)
    comparisonInds = [];
    comparisonLabels = {};
    
    ind_rest = 0;
    ind_seg = 0;
    
    for i = 1:length(segData)-1
        for j = i+1:length(segData)
            stateI = segData(i).state{1};
            stateJ = segData(j).state{1};
            
            if isnan(segData(i).timeStart) || isnan(segData(j).timeStart)
                continue
            end
        
            switch stateI
                case 'Seg'
                    switch stateJ
                        case 'Seg'
                            comparisonInds = [comparisonInds; i j];
                            comparisonLabels = [comparisonLabels 'Seg'];
                    end
                    
                case 'Rest'
                    switch stateJ
                        case 'Rest'
                            comparisonInds = [comparisonInds; i j];
                            comparisonLabels = [comparisonLabels 'Rest'];
                    end
            end
        end
    end
        
    for i = 1:size(comparisonInds)
        currIndPair = comparisonInds(i, :);
        currStartTimeWin1 = segData(currIndPair(1)).timeStart;
        currEndTimeWin1 = segData(currIndPair(1)).timeEnd;
        currStartTimeWin2 = segData(currIndPair(2)).timeStart;
        currEndTimeWin2 = segData(currIndPair(2)).timeEnd;
        currState = comparisonLabels{i};
        
        [~, currStart1Ind] = findClosestValue(currStartTimeWin1, t);
        [~, currEnd1Ind] = findClosestValue(currEndTimeWin1, t);
        [~, currStart2Ind] = findClosestValue(currStartTimeWin2, t);
        [~, currEnd2Ind] = findClosestValue(currEndTimeWin2, t);

        fprintf('Processing %f to %f vs %f to %f - %s\n', currStartTimeWin1, currEndTimeWin1, currStartTimeWin2, currEndTimeWin2, currState);

        if currStart1Ind < 0
            currStart1Ind = 1;
        end

        if currEnd2Ind > length(feature)
            currEnd2Ind = length(feature);
        end

        currFeature1Tmp = feature(currStart1Ind:currEnd1Ind, :);
        currFeature2Tmp = feature(currStart2Ind:currEnd2Ind, :);
        currT1Tmp = t(currStart1Ind:currEnd1Ind);
        currT2Tmp = t(currStart2Ind:currEnd2Ind);
        lenT1 = length(currT1Tmp)-1;
        lenT2 = length(currT2Tmp)-1;
        dt = mean(diff(currT1Tmp));
        
        % resample length to 5000
        targetLen = 5000;
        newDt1 = lenT1*dt/targetLen;
        newDt2 = lenT2*dt/targetLen;
        newT1 = [1:(targetLen-1)]*newDt1 + currT1Tmp(1);
        newT2 = [1:(targetLen-1)]*newDt2 + currT2Tmp(1);
        currFeature1 = interp1(currT1Tmp, currFeature1Tmp, newT1);
        currFeature2 = interp1(currT2Tmp, currFeature2Tmp, newT2);
        
        segmentStats2.t1 = (currStartTimeWin1+currEndTimeWin1)/2;
        segmentStats2.t2 = (currStartTimeWin2+currEndTimeWin2)/2;

        [R, P] = corrcoef(currFeature1, currFeature2);
        segmentStats2.corrcoef = R(2, 1);
        
%         pdfType = 'norm';
%         pdf1 = pdf(pdfType, currFeature1);
%         pdf2 = pdf(pdfType, currFeature2);
%         kl = KLDiv(pdf1, pdf2);
%         segmentStats2.kl = kl;
        
        switch currState
            case 'Seg'
                ind_seg = ind_seg + 1;
                segmentStatsSeg(ind_seg) = segmentStats2; 

            case 'Rest'
                ind_rest = ind_rest + 1;
                segmentStatsRest(ind_rest) = segmentStats2;
        end
    end
end

function [segmentStatsSeg, segmentStatsRest] = featureCalc_singleWindow(segData, t, feature)
    ind_rest = 0;
    ind_seg = 0;
    
    for i = 1:length(segData)
        currStartTime = segData(i).timeStart;
        currEndTime = segData(i).timeEnd;
        currState = segData(i).state{1};
        [~, currStartInd] = findClosestValue(currStartTime, t);
        [~, currEndInd] = findClosestValue(currEndTime, t);

        if isnan(currStartTime)
            continue
        end

        fprintf('Processing %f to %f - %s\n', currStartTime, currEndTime, currState);

        if currStartInd < 0
            currStartInd = 1;
        end

        if currEndInd > length(feature)
            currEndInd = length(feature);
        end

        currFeature = feature(currStartInd:currEndInd, :);
        currStatsT = (currStartTime+currEndTime)/2;
        
        [hjorth_activity, hjorth_mobility, hjorth_complexity] = hjorthParam(currFeature);
        
        segmentStats(1).name = 'mean';
        segmentStats(1).t = currStatsT;
        segmentStats(1).val = mean(currFeature);
        
        segmentStats(2).name = 'stddev';
        segmentStats(2).t = currStatsT;
        segmentStats(2).val = std(currFeature);
        
        segmentStats(3).name = 'length';
        segmentStats(3).t = currStatsT;
        segmentStats(3).val = length(currFeature);
        
        segmentStats(4).name = 'skewness';
        segmentStats(4).t = currStatsT;
        segmentStats(4).val = skewness(currFeature);
        
        segmentStats(4).name = 'kurtosis';
        segmentStats(4).t = currStatsT;
        segmentStats(4).val = kurtosis(currFeature);
        
        segmentStats(5).name = 'hurst';
        segmentStats(5).t = currStatsT;
        segmentStats(5).val = genhurst(currFeature);
        
        segmentStats(6).name = 'entropy';
        segmentStats(6).t = currStatsT;
        segmentStats(6).val = wentropy(currFeature,'shannon');
        
        segmentStats(7).name = 'hjorth_activity';
        segmentStats(7).t = currStatsT;
        segmentStats(7).val = hjorth_activity;
        
        segmentStats(8).name = 'hjorth_mobility';
        segmentStats(8).t = currStatsT;
        segmentStats(8).val = hjorth_mobility;
        
        segmentStats(9).name = 'hjorth_complexity';
        segmentStats(9).t = currStatsT;
        segmentStats(9).val = hjorth_complexity;
        
        segmentStats(10).name = 'peakFreq';
        segmentStats(10).t = currStatsT;
        segmentStats(10).val = peakFreq(currFeature);

        switch currState
            case 'Seg'
                ind_seg = ind_seg + 1;
                segmentStatsSeg{ind_seg} = segmentStats; 

            case 'Rest'
                ind_rest = ind_rest + 1;
                segmentStatsRest{ind_rest} = segmentStats;
        end
    end
end

function [h_seg, h_rest, regression_seg, regression_rest] = plotData_SingleWindow(stats)
    R_thres = 0.7;
        
    segDataTable = struct2table(stats.segData);
    mask = ismember(segDataTable{:,'state'}, 'Seg');
    segOnlyDataTable = stats.segData(mask);
   
    mask = ismember(segDataTable{:,'state'}, 'Rest');
    restOnlyDataTable = stats.segData(mask);
   
    h_seg = figure('Position', [-1919 69 1920 964.8000]);
    for i = 1:length(stats.segmentStatsSeg{1})
        ax(i+1) = subplot(4, 3, i+1);
        featureParam = stats.segmentStatsSeg{1}(i).name;
        
        segT = [];
        segRaw = [];
        for j = 1:length(stats.segmentStatsSeg)
            segT = [segT stats.segmentStatsSeg{j}(i).t];
            segRaw = [segRaw stats.segmentStatsSeg{j}(i).val];
        end
        regression_seg(i).name = featureParam;
        [regression_seg(i).b, regression_seg(i).Rsq2, X_seg, yCalc2_seg] = linearFit(segT', segRaw');
     
        plAx(1) = plot(segT, segRaw, 'o', 'MarkerSize', 16); hold on
        plot(segT, yCalc2_seg);
        bSegStr = ['b_Seg = ' num2str(regression_seg(i).b(2), '%0.2f') ', R2_Seg = ' num2str(regression_seg(i).Rsq2, '%0.2f')];
        ylabel(bSegStr);
        
        if regression_seg(i).Rsq2 > R_thres
            title([featureParam, ', ' bSegStr]);
        else
            title(featureParam);
        end
    end
    ax(1) = subplot(4, 3, 1);
    plot(stats.t, stats.feature);
    plotBoxes(segOnlyDataTable, plAx(1).Color);
    title([stats.name '_seg']);
    linkaxes(ax, 'x');
    
    h_rest = figure('Position', [-1919 69 1920 964.8000]);
    for i = 1:length(stats.segmentStatsRest{1})
        ax(i+1) = subplot(4, 3, i+1);
        featureParam = stats.segmentStatsSeg{1}(i).name;
        
        restT = [];
        restRaw = [];
        for j = 1:length(stats.segmentStatsRest)
            restT = [segT stats.segmentStatsRest{j}(i).t];
            restRaw = [segRaw stats.segmentStatsRest{j}(i).val];
        end
        regression_rest(i).name = featureParam;
        [regression_rest(i).b, regression_rest(i).Rsq2, X_rest, yCalc2_rest] = linearFit(restT', restRaw');
       
        plAx(2) = plot(restT,	restRaw, 'o', 'MarkerSize', 16); hold on
        plot(restT,yCalc2_rest)
        bRestStr = ['b_Res = ' num2str(regression_rest(i).b(2), '%0.2f') ', R2_Rest = ' num2str(regression_rest(i).Rsq2, '%0.2f')];
        ylabel(bRestStr);
        
        if regression_rest(i).Rsq2 > R_thres
            title([featureParam, ', ' bRestStr]);
        else
            title(featureParam);
        end
    end
    ax(1) = subplot(4, 3, 1);
    plot(stats.t, stats.feature);
    plotBoxes(restOnlyDataTable, plAx(1).Color);
    title([stats.name '_rest']);
    linkaxes(ax, 'x');
end

function [b, Rsq2, X, yCalc2] = linearFit(x, y)
    X = [ones(length(x),1) x];
    b = X\y;
    yCalc2 = X*b;
    Rsq2 = 1 - sum((y - yCalc2).^2)/sum((y - mean(y)).^2);
end

function frqs = peakFreq(signal)
%     FTsignal = fft(signal - mean(signal))/length(signal);
%     [maxpeak, maxpeakindes] = max(abs(FTsignal)*2);

    F=signal;                % Data Channel
    Ts = 0.01;                  % Sampling Interval (s)
    Fs = 1/Ts;                  % Sampling Frequency (Hz)
    Fn = Fs/2;                  % Nyquist Frequency
    F(isnan(F))=[];             % Eliminate �NaN� Values First
    LF = size(F,1);             % Length of Data Vector
    T = linspace(0,1,LF)*Ts;    % Create Time Vector
 
%     figure(1)                   % Plot Data
%     plot(T, F)
%     grid
    FF = fft(F)/LF;             % Fourier Series of Data, Freq Vector
    Fv = linspace(0,1,fix(LF/2)+1)*Fn;
    Iv = 1:length(Fv);          % Index Vector
   
%     figure(2)                   % Plot FFT
%     plot(Fv, abs(FF(Iv)))
%     grid
%     xlabel('Frequency (Hz)')
%     ylabel('Amplitude')
%     axis([0  1500    ylim])
    x = abs(FF);
  
%     figure()
    [pks, locs]=findpeaks(x(Iv));
%     plot(Fv(locs), pks, 'or')
    
if ~isempty(locs)
    frqs = Fv(locs(1));
else
    frqs = 0;
end
%     hold on;
%     plot(x)
%     [pks, locs]=findpeaks(x, 'MinPeakDistance',50, 'minpeakheight',0.002);
end

function [activity, mobility, complexity] = hjorthParam(currFeature)
        %% Hjorth parameters
    % Activity
    activity = var(currFeature);
    
    % Mobility
    mobility = std(diff(currFeature))./std(currFeature);
    
    % Complexity
    complexity = std(diff(diff(currFeature)))./std(diff(currFeature))./mobility;
end

function feat = calculate_features(f)
% CALCULATE_FEATURES computes a set of features that will be
%    later on used to train a LASSO GLM model.
%
%    The set of features include: spectral entropy and Shannons
%    entropy (MacKay, 2003) at six frequency bands: delta (0.14 Hz),
%    theta (48 Hz), alpha (812 Hz), beta (1230 Hz), low-gamma (3070 Hz)
%    and high gamma (70180 Hz), and Shannons entropy in dyadic (between
%    0.00167 and 109 Hz spaced by factors of 2n) frequency bands, the
%    spectral edge at 50% power below 40 Hz, spectral correlation between
%    channels in dyadic frequency bands, the time series correlation matrix
%    and its eigenvalues, fractal dimensions, Hjorth activity, mobility and
%    complexity parameters (Hjorth, 1970), and the statistical skewness and
%    kurtosis of the distribution of time series values.
%
%    Input:
%       f: data structure that includes data and metadata information
%          e.g. f = load('1_1_1.mat');
%   
%    Output:
%       feat: a vector of the abovementioned features
%
%    Reference:
%       http://brain.oxfordjournals.org/content/early/2016/03/29/brain.aww045
%       https://github.com/drewabbot/kaggle-seizure-prediction
%
%  Copyright 2016 The MathWorks, Inc.
%

fName = fieldnames(f);
fs = f.(fName{1}).iEEGsamplingRate;     % Sampling Freq
eegData = f.(fName{1}).data;            % EEG data matrix
[nt,nc] = size(eegData);

subsampLen = floor(fs * 60);            % Num samples in 1 min window
numSamps = floor(nt / subsampLen);      % Num of 1-min samples
sampIdx = 1:subsampLen:numSamps*subsampLen;

feat = []; % Feature vector

for l=2:numSamps
    %% Sample 1-min window
    epoch = eegData(sampIdx(l-1):sampIdx(l),:);
    
    %% Compute Shannon's entropy, spectral edge and correlation matrix
    % Find the power spectrum at each frequency bands
    D = abs(fft(eegData));                  % take FFT of each channel
    D(1,:) = 0;                             % set DC component to 0
    D = bsxfun(@rdivide,D,sum(D));          % normalize each channel
    lvl = [0.1 4 8 12 30 70 180];           % frequency levels in Hz
    lseg = round(nt/fs*lvl)+1;              % segments corresponding to frequency bands
    
    dspect = zeros(length(lvl)-1,nc);
    for n=1:length(lvl)-1
        dspect(n,:) = 2*sum(D(lseg(n):lseg(n+1),:));
    end
    
    % Find the Shannon's entropy
    spentropy = -sum(dspect.*log(dspect));
    
    % Find the spectral edge frequency
    sfreq = fs;
    tfreq = 40;
    ppow = 0.5;
    
    topfreq = round(nt/sfreq*tfreq)+1;
    A = cumsum(D(1:topfreq,:));
    B = bsxfun(@minus,A,max(A)*ppow);
    [~,spedge] = min(abs(B));
    spedge = (spedge-1)/(topfreq-1)*tfreq;
    
    % Calculate correlation matrix and its eigenvalues (b/w channels)
    type_corr = 'Pearson';
    C = corr(dspect,'type',type_corr);
    C(isnan(C)) = 0;    % make NaN become 0
    C(isinf(C)) = 0;    % make Inf become 0
    lxchannels = real(sort(eig(C)));
    
    % Calculate correlation matrix and its eigenvalues (b/w freq)
    C = corr(dspect.','type',type_corr);
    C(isnan(C)) = 0;    % make NaN become 0
    C(isinf(C)) = 0;    % make Inf become 0
    lxfreqbands = real(sort(eig(C)));
    
    %% Spectral entropy for dyadic bands
    % Find number of dyadic levels
    ldat = floor(nt/2);
    no_levels = floor(log2(ldat));
    seg = floor(ldat/2^(no_levels-1));
    
    % Find the power spectrum at each dyadic level
    dspect = zeros(no_levels,nc);
    for n=no_levels:-1:1
        dspect(n,:) = 2*sum(D(floor(ldat/2)+1:ldat,:));
        ldat = floor(ldat/2);
    end
    
    % Find the Shannon's entropy
    spentropyDyd = -sum(dspect.*log(dspect));
    
    % Find correlation between channels
    C = corr(dspect,'type',type_corr);
    C(isnan(C)) = 0;    % make NaN become 0
    C(isinf(C)) = 0;    % make Inf become 0
    lxchannelsDyd = sort(eig(C));
    
    %% Fractal dimensions
    no_channels = nc;
    fd = zeros(3,no_channels);
    
    for n=1:no_channels
        fd(:,n) = wfbmesti(eegData(:,n));
    end
    
    %% Hjorth parameters
    % Activity
    activity = var(eegData);
    
    % Mobility
    mobility = std(diff(eegData))./std(eegData);
    
    % Complexity
    complexity = std(diff(diff(eegData)))./std(diff(eegData))./mobility;
    
    %% Statistical properties
    % Skewness
    skew = skewness(eegData);
    
    % Kurtosis
    kurt = kurtosis(eegData);
    
    %% Compile all the features
    feat = [feat spentropy(:)' spedge(:)' lxchannels(:)' lxfreqbands(:)' spentropyDyd(:)' ...
        lxchannelsDyd(:)' fd(:)' activity(:)' mobility(:)' complexity(:)' skew(:)' kurt(:)'];
end
end

% function perSegmentMetrics()
%     for i = 1:length(segmentInfo)
%         startTime = segmentInfo(i).
%     end
% end