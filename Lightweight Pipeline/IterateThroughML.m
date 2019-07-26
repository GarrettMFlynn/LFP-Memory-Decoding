

if exist('dataML', 'var')

for chosenFormat = 1:length(dataFormat)
    format = dataFormat{chosenFormat};
    
 dataML.Data = dataML.(format);

 
 
 kMeans = ~isempty(cell2mat(regexp(mlAlgorithms,{'kMeans'})));
 supervisedMethods =  ~isempty(cell2mat(regexp(mlAlgorithms,{'lassoGLM','naiveBayes','SVM','linear','kernel','knn','tree','RUSBoost'})));
 imageMethods = ~isempty(cell2mat(regexp(mlAlgorithms,{'CNN_SVM'})));
 
 
 % Initialize Save Directories and Other Parameters
        if supervisedMethods
            resultsDir = fullfile(parameters.Directories.filePath,['Classifier Results [-',num2str(range),' ',num2str(range),']']);
        end
        
        if kMeans
            kResultsDir =  fullfile(parameters.Directories.filePath,['kMeans Results [-',num2str(range),' ',num2str(range),']']);
            saveBars = fullfile(parameters.Directories.filePath,'MCC Bar Plots');
            
            realCluster = realClusters(dataML.Labels);
            savePCAViz = fullfile(parameters.Directories.filePath,'PCA Scatter Plots');
        end
        
        count = 1;
        
        channelStandard = dataML.Channels.sChannels;
        
        
        
% Unfold Time & Frequency Components into Vectors (or leave as is)
        temp = permute(dataML.Data,[4,3,2,1]);
        dataML.Data = temp(:,:,:)
        clear temp
        
        % Use the following code to reverse a given trial/electrode
        %reshaped = reshape(dataML.Data(1,1,:),size(temp,3),size(temp,4))';
        
for featureIter = 1:length(featureMethod)
    feature = featureMethod{featureIter};
            fprintf(['Conducting ', feature ,' Classification\n']);
            
            for method = 1:length(mlScope)
                name = mlScope{method};
                
                %% Switch Between MCA, CA1, and CA3 Methods
                    fprintf(['\n',name,'\n']);
                    switch name
                        case 'MCA'
                    channelChoices = dataML.Channels.sChannels;
                        case 'CA1'
                    channelChoices = dataML.Channels.CA1_Channels;
                        case 'CA3'
                    channelChoices = dataML.Channels.CA3_Channels;      
                    end
                
                for resolutions_to_retain = resChoice
                    
                    % If Bspline, Include all PCA Components
                    % Else, Iterate Through All Component Rankings
                    if ~bspline
                        switch feature
                            case 'PCA'
                        coeffIter = 1:length(channelChoices)-1;
                            otherwise
                                coeffIter = 1;
                        end
                    else
                        switch feature
                            case 'PCA'
                        coeffIter = length(channelChoices)-1;
                            otherwise
                           coeffIter = 1;
                        end
                    end
                    
                    
                     for coeffRanks_to_retain = coeffIter
                         switch feature
                            case 'PCA'
                        retained = coeffRanks_to_retain;
                            otherwise
                           retained = [];
                         end
                         
                         
                   featureMatrix = dataML;
                   %% Original Features: Concatenated Channel Features
                   % Run when PCA is active OR when Bspline is not active
                    if strcmp(feature,'PCA') || ~bspline
                    featureMatrix.Data  = zeros(size(dataML.Data, 1), size(dataML.Data, 2)*length(channelChoices));
                    for channels = find(ismember(channelStandard,channelChoices))
                        featureMatrix.Data(:,((channels-1)*size(featureMatrix.Data, 2))+1:(channels)*size(featureMatrix.Data, 2)) =  dataML.Data(:,:,channels);
                    end
                    indVar = 'PCA Coefficients (per channel)';
                    end
                   %% PCA Features 
                    if strcmp(feature,'PCA')
                    channelScore = zeros(size(featureMatrix.Data,1),length(CCAChoices),length(CCAChoices)-1);
                for trials = 1:size(featureMatrix.Data,1)
                    temp = squeeze(featureMatrix.Data(trials,:,ismember(channelChoices,CCAChoices)));
                    [~,channelScore(trials,:,:)] = pca(temp');
                end
                    clear temp

                    toPermute = channelScore(:,:,1:coeffRanks_to_retain);
                        rPCA = permute(toPermute,[1,3,2]);
                    
                   featureMatrix.Data = rPCA;
                    end
                   %% BSpline Features
                    if bspline
                        BSplineInput = featureMatrix.Data;
                        disp(['Current number of B-Spline knots: ', mat2str(resolutions_to_retain)]);
                        MCA_BSFeatures = InputTensor2BSplineFeatureMatrix(BSplineInput,resolutions_to_retain,BSOrder);
                        featureMatrix.Data = MCA_BSFeatures;
                        clear MCA_BSFeatures
                        
                        indVar = 'BSpline Resolution';
                        
                    end

                    
                    %% Classification Section
                    % Count the Number of Feature Permutations
                     if bspline && isempty(retained)
                        featureCounter = [feature,'_',num2str(resolutions_to_retain),'Resolution'];
                        elseif bspline && ~isempty(retained)
                            featureCounter = [feature,'_',num2str(retained),'Components_',num2str(resolutions_to_retain),'Resolution'];
                        else
                            featureCounter = [feature,'_',num2str(retained),'Components_'];
                     end
                    
                    
                    % Run K-Means
                    if kMeans
                        [kResults.(name).(featureCounter).clusterIndices] = kMeansClustering(featureMatrix,name);
                        saveBarsFull = fullfile(saveBars,name,featureCounter);
                        [kResults.(name).(featureCounter).MCC,kResults.(name).(featureCounter).MCC_Categories,~,~] = parseClusterAssignments(featureMatrix,kResults.(name).(featureCounter).clusterIndices, name,{featureMatrix.Labels,retained,name,norm(iter),saveBarsFull});
                        count = count + 1;
                    end
                    
                  % Run Supervised Classifiers
                    if supervisedMethods
                        cResults.(name).(featureCounter) = trainClassifiers(featureMatrix,mlAlgorithms,resultsDir,name,feature,retained,resolutions_to_retain);
                    end
                     end
                end
                plotMCCvsFeatures(cResults.(name),resChoice,norm(iter),resultsDir,[name,' ',feature],indVar);
            end
            
            %% Organize Results
            if kMeans 
                kSave
            end
            if supervisedMethods
                classSave;
                visualizeClassifierPerformance(results,norm(iter),fullfile(resultsDir,['MCCs for ',feature]));
            end
    clear cResults
    clear kResults
            
end
end

%% PCA 2D/3D Visualizations

%[kResults.(name).(featureCounter).MCC,kResults.(name).(featureCounter).MCC_Categories,collectedClusterings(:,count),excluded{count}] = parseClusterAssignments(featureMatrix,kResults.(name).(featureCounter).clusterIndices, name,{featureMatrix.Labels,retained,name,norm(iter),saveBarsFull});
%                             if coeffRanks_to_retain ==  2
%                                 PCA2CountMCA = count;
%                             elseif coeffRanks_to_retain ==  3
%                                 for len = 1:size(collectedClusterings,1)
%                                     orderedClustersMCA_PCA = [collectedClusterings(len,PCA2CountMCA) , collectedClusterings(len,count)];
%                                     excludedMCA_PCA = {excluded{PCA2CountMCA} , excluded{count}};
%                                     label = 'All Above';
%                                     createPCAVisualizations(scoreMCA,orderedClustersMCA_PCA,['MCA ' ,label,' ', num2str(nIters-(len-1))],norm(iter),fullfile(savePCAViz,['MCA_' label]),excludedMCA_PCA);
%                                     createPCAVisualizations_RealClusters(scoreMCA,realCluster,'MCA Correct Cluster',norm(iter),fullfile(savePCAViz,['CorrectMCA_' label]),fieldnames(dataML.Labels));
%                                     
%                                 end
%                             end
%                             count = count + 1;
            
            
    
    
%% CNN For Feature Selection (on hiatus)
%     if CNN_SVM
%         CNN_Pipeline;
%         processAllClassestoResults(results,'CNN_SVM');
%         supervisedDir = fullfile(parameters.Directories.filePath,'CNN Results');
%         
%         if ~exist(supervisedDir,'dir')
%             mkdir(supervisedDir);
%         end
%         if norm(iter) == 1
%             save(fullfile(supervisedDir,[parameters.Directories.dataName, 'ResultsNorm.mat']),'results');
%         else
%             save(fullfile(supervisedDir,[parameters.Directories.dataName, 'Results.mat']),'results');
%         end
%     end


end