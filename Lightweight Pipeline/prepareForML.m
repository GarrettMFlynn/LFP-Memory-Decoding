%% PrepareForML.m
% Create Bands
% Normalize Data
% Generate Intervals
% Save Into ML Variable




for ii = 1:length(dataFormat)
    choiceFull = dataFormat{ii};
if ~isempty(regexp(choiceFull,'Spectrum','ONCE'))
    form = 'Spectrum';
%% All Bands
    if ~isempty(cell2mat(regexp(choiceFull,{'theta','alpha','beta','lowGamma','highGamma'})))
        bandType = erase(choiceFull,'Spectrum');
        spectrumFrequencies = HHData.Data.Parameters.SpectrumFrequencies;  
        [HHData] = bandSpectrum(HHData,spectrumFrequencies,bandType);
        if norm(iter) 
            dataToInterval = normalize(HHData.ML.(choiceFull),'STFT',form);
        else
            dataToInterval = HHData.ML.(choiceFull);
        end
[dataML.(choiceFull), HHData.Data.Intervals.Times] = makeIntervals(dataToInterval,HHData.Events.SAMPLE_RESPONSE,HHData.Data.Parameters.Choices.trialWindow,HHData.Data.Parameters.SpectrumTime);
%% Just Spectrum  
    else
       if norm(iter) 
            dataToInterval = normalize(HHData.Data.LFP.Spectrum,'STFT',form);
        else
            dataToInterval = HHData.Data.LFP.Spectrum;
       end
[dataML.(choiceFull), HHData.Data.Intervals.Times] = makeIntervals(dataToInterval,HHData.Events.SAMPLE_RESPONSE,HHData.Data.Parameters.Choices.trialWindow,HHData.Data.Parameters.SpectrumTime);
    end
end



%% Just Signal
if ~isempty(regexp(choiceFull,'Signal','ONCE'))
    form = 'Signal';
       if norm(iter) 
            dataToInterval = normalize(HHData.Data.LFP.LFP,'STFT',form);
        else
            dataToInterval = HHData.Data.LFP.LFP;
        end
[dataSignal,HHData.ML.Times] = makeIntervals(dataToInterval,HHData.Events.SAMPLE_RESPONSE,HHData.Data.Parameters.Choices.trialWindow,HHData.Data.Parameters.SamplingFrequency); 
dataML.(choiceFull) = permute(dataSignal,[3,2,1,4]);
end

%% Extract Images if Desired    
    %     for ii = 1:size(HHData.ML.Data,3)
%         for jj = 1:size(HHData.ML.Data,4)
%     standardImage(HHData.ML.Data(:,:,ii,jj), HHData.Events,parameters, parameters.Derived.samplingFreq, ['Interval ' num2str(jj)], HHData.Channels.sChannels(ii),jj,HHData.ML.Times(:,jj),'% Change', [-500 500], fullfile(parameters.Directories.filePath,['Interval Images'],['Channel_',num2str(ii)]), 'Spectrum',0);
%         end
%     end
end

%% Only Keep a Small Sampling of Additional Parameters
dataML.Channels = HHData.Channels;
dataML.Directory = parameters.Directories.filePath;
dataML.Labels = HHData.Labels;
dataML.WrongResponse = find(HHData.Data.Intervals.Outcome == 0);
dataML.Times = HHData.ML.Times;