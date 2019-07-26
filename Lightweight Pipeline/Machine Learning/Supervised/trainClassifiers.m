function [outMCCs] = trainClassifiers(dataML,mlAlgorithms,resultsDir,typeML,feature,pcaIter,resIter)

close all;

wrong = dataML.WrongResponse;

% Remove K-Means
notK = find(~ismember(mlAlgorithms,'kMeans'));
for ii = 1:length(notK)
usableAlgorithms{ii} = mlAlgorithms{notK(ii)};
end

switch feature
    case 'PCA'
        pcaFlag = 1;
        allVec = 1:size(dataML.Data,1);
        dataML.Data = permute(dataML.Data,[1,3,2]);
        matrixToProcess = dataML.Data(allVec~=wrong,:);
        
    case 'Raw'
        pcaFlag = 0;
        allVec = 1:size(dataML.Data,1);
        matrixToProcess = dataML.Data(allVec~=wrong,:);
        
end

%% Begin Label Loop
fields = fieldnames(dataML.Labels);
fieldLabels = erase(fields,'Label_');
labels = cell(size(dataML.Labels.(fields{1}),1),1);
numTrials = size(dataML.Labels.(fields{1}),1);
labelMaker;

% BTW Linear is Lasso
for learner = 1:length(usableAlgorithms)
    learnerChoices = find(learnerTypes);
    fprintf(['Learner: ',usableAlgorithms{learnerChoices(learner)},'\n']);
    for categoriesToTrain = 1:length(fieldLabels)
        fprintf(['\t',fields{categoriesToTrain},'\n']);
        labelCache = cell(numTrials,1);
        currentCategory = dataML.Labels.(fields{categoriesToTrain});
        currentField = fieldLabels{categoriesToTrain};
        for qq = 1:numTrials;
            if strfind(labels{qq},currentField)
                labelCache{qq} = currentField;
            else
                labelCache{qq} = ['~',currentField];
            end
        end
        
        labelCache = labelCache(allVec~=wrong);
        labelCacheCat = categorical(labelCache);
        clear classifier
        %% Custom Loss Function
        %         binaryLabels = ismember(labelCache,currentField);
        %               crossEntropy = @(~,S,~,~)mean(min(-S,[],2));
        
        %% Begin Model Testing
        done = 0;
        if ~strcmp(usableAlgorithms{learnerChoices(learner)},'kernel') && ~strcmp(usableAlgorithms{learnerChoices(learner)},'naivebayes')
            if ~strcmp(usableAlgorithms{learnerChoices(learner)},'LassoGLM')
                % Lasso
                if strcmp(usableAlgorithms{learnerChoices(learner)},'linear')
                    ourLinear = templateLinear('Learner','svm','Regularization','lasso');
                    classifier = fitcecoc(matrixToProcess', labelCacheCat, ...
                        'Learners', ourLinear,'ObservationsIn', 'columns','Kfold',10);
                    clear ourLinear
                    % KNN
                elseif strcmp(usableAlgorithms{learnerChoices(learner)},'knn')
                    ourKNN = templateKNN('NSMethod','exhaustive','Distance','cosine');
                    classifier = fitcecoc(matrixToProcess', labelCacheCat, ...
                        'Learners', ourKNN,'ObservationsIn', 'columns','Kfold',10);
                    clear ourKNN
                    % RusBoost (unbalanced classes)
                elseif strcmp(usableAlgorithms{learnerChoices(learner)},'RUSBoost')
                    N = ceil(length(labelCacheCat)/10);         % Number of observations in training samples
                    t = templateTree('MaxNumSplits',N);
                    classifier = fitcensemble(matrixToProcess,labelCacheCat,'Method',usableAlgorithms{learnerChoices(learner)}, ...
                        'NumLearningCycles',1000,'Learners',t,'LearnRate',0.1,'nprint',100,'KFold',10);
                    clear t
                else
                    % SVM or Trees
                    classifier = fitcecoc(matrixToProcess', labelCacheCat, ...
                        'Learners', usableAlgorithms{learnerChoices(learner)},'ObservationsIn', 'columns','Kfold',10);
                end
                % Pass features to trained classifier
                %predictedLabels = predict(classifier, matrixToProcess', 'ObservationsIn', 'columns');
                predictedLabels = kfoldPredict(classifier);
                
                % Get the known labels
                testLabels =  labelCacheCat;
                
                % Tabulate the results using a confusion matrix.
                [confMat,categories] = confusionmat(testLabels, predictedLabels);
                conf = confusionchart(testLabels,predictedLabels);
                
                % Lasso GLM
            else
                binaryLabels = ismember(labelCacheCat,currentField);
                [Coefficients, FitInfo] = lassoglm(matrixToProcess, binaryLabels, 'binomial','MaxIter',25,'CV', 10,'Lambda',power(10,0:-.1:-2));
                legend('show') % Show legend
                lp = lassoPlot(Coefficients,FitInfo,'plottype','CV');
                
                %% Save  Lasso Plot
                if nargin > 4 && pcaFlag == 1
                    if ~isempty(resIter)
                        lassoDir = fullfile(resultsDir,'Lasso Plots',typeML,['PCA' ,num2str(pcaIter)],['Resolution' ,num2str(resIter)]);
                    else
                        lassoDir = fullfile(resultsDir,'Lasso Plots',typeML,['PCA' num2str(pcaIter)]);
                    end
                elseif nargin > 4 && pcaFlag == 0 && ~isempty(resIter)
                    lassoDir = fullfile(resultsDir,'Lasso Plots',typeML,['Resolution' num2str(resIter)]);
                else
                    lassoDir = fullfile(resultsDir,'Lasso Plots',typeML);
                end
                
                if ~exist(lassoDir,'dir');
                    mkdir(lassoDir);
                end
                
                if nargin > 4 && pcaFlag == 1
                    if ~isempty(resIter)
                        title(['PCA',num2str(pcaIter),'Resolution',num2str(resIter),' ',usableAlgorithms{learnerChoices(learner)},' ',typeML,' ',currentField]);
                        saveas(lp,fullfile(lassoDir,['PCA',num2str(pcaIter),'Resolution',num2str(resIter),'_',usableAlgorithms{learnerChoices(learner)},'_',typeML,'_',currentField,'.png']));
                        close all
                    else
                        title(['PCA',num2str(pcaIter),' ',usableAlgorithms{learnerChoices(learner)},' ',typeML,' ',currentField]);
                        saveas(lp,fullfile(lassoDir,['PCA',num2str(pcaIter),'_',usableAlgorithms{learnerChoices(learner)},'_',typeML,'_',currentField,'.png']));
                        close all
                    end
                elseif nargin > 4 && pcaFlag == 0 && ~isempty(resIter)
                    title(['Raw Resolution',num2str(resIter),' ',usableAlgorithms{learnerChoices(learner)},' ',typeML,' ',currentField]);
                    saveas(lp,fullfile(lassoDir,['Raw_Resolution',num2str(resIter),'_',usableAlgorithms{learnerChoices(learner)},'_',typeML,'_',currentField,'.png']));
                    close all
                else
                    title(['Raw ',usableAlgorithms{learnerChoices(learner)},' ',typeML,' ',currentField]);
                    saveas(lp,fullfile(lassoDir,['Raw_',usableAlgorithms{learnerChoices(learner)},'_',typeML,'_',currentField,'.png']));
                    close all
                end
                
                % Continue with Lasso Prediction
                indx = FitInfo.IndexMinDeviance;
                cnst = FitInfo.Intercept(indx);
                B0 = Coefficients(:,indx);
                nonzeros = sum(B0 ~= 0);
                B1 = [cnst;B0];
                predictions = glmval(B1,matrixToProcess,'logit');
                
                lassoPredictions = (predictions >= .5);
                for ii = 1:length(predictions)
                    if lassoPredictions(ii)
                        realPredicts{ii} = currentField;
                    else
                        realPredicts{ii} = ['~',currentField];
                    end
                end
                [confMat,categories] = confusionmat(labelCache, realPredicts);
                conf = confusionchart(labelCache,realPredicts);
            end
            done = 1;
            %% Incorporate Models with Long Execution on Raw Data
            %  Due to the Size of our Inputs, Naive Bayes and Gaussian Are Not Feasible for Raw Data Analyses
        else
            if size(matrixToProcess,2) < 5000
                % Naive Bayes or Gaussian
                classifier = fitcecoc(matrixToProcess', labelCache, ...
                    'Learners', usableAlgorithms{learnerChoices(learner)},'ObservationsIn', 'columns','Kfold',10);
                predictedLabels = kfoldPredict(classifier);
                testLabels =  labelCache;
                [confMat,categories] = confusionmat(testLabels, predictedLabels);
                conf = confusionchart(testLabels,predictedLabels);
                saveMCC.(fieldLabels{categoriesToTrain}) = ML_MCC(confMat);
                done = 1;
            end
        end
        
        
        
        
        %% Confusion Save
        if ~done
            fprintf('Not Done\n');
        else
            if nargin > 4 && pca == 1
                if ~isempty(resIter)
                    confusionDir = fullfile(resultsDir,'Confusion Matrices',typeML,['PCA' ,num2str(pcaIter)],['Resolution' ,num2str(resIter)]);
                else
                    confusionDir = fullfile(resultsDir,'Confusion Matrices',typeML,['PCA' num2str(pcaIter)]);
                end
            elseif nargin > 4 && pcaFlag == 0 && ~isempty(resIter)
                confusionDir = fullfile(resultsDir,'Confusion Matrices',typeML,['Resolution' num2str(resIter)]);
            else
                confusionDir = fullfile(resultsDir,'Confusion Matrices',typeML);
            end
            
            if ~exist(confusionDir,'dir');
                mkdir(confusionDir);
            end
            
            if nargin > 4 && pcaFlag == 1
                if ~isempty(resIter)
                    title(['PCA',num2str(pcaIter),'Resolution',num2str(resIter),' ',usableAlgorithms{learnerChoices(learner)},' ',typeML,' ',currentField]);
                    saveas(conf,fullfile(confusionDir,['PCA',num2str(pcaIter),'Resolution',num2str(resIter),'_',usableAlgorithms{learnerChoices(learner)},'_',typeML,'_',currentField,'.png']));
                    close all
                else
                    title(['PCA',num2str(pcaIter),' ',usableAlgorithms{learnerChoices(learner)},' ',typeML,' ',currentField]);
                    saveas(conf,fullfile(confusionDir,['PCA',num2str(pcaIter),'_',usableAlgorithms{learnerChoices(learner)},'_',typeML,'_',currentField,'.png']));
                    close all
                end
            elseif nargin > 4 && pcaFlag == 0 && ~isempty(resIter)
                title(['Raw Resolution',num2str(resIter),' ',usableAlgorithms{learnerChoices(learner)},' ',typeML,' ',currentField]);
                saveas(conf,fullfile(confusionDir,['Raw_Resolution',num2str(resIter),'_',usableAlgorithms{learnerChoices(learner)},'_',typeML,'_',currentField,'.png']));
                close all
            else
                title(['Raw ',usableAlgorithms{learnerChoices(learner)},' ',typeML,' ',currentField]);
                saveas(conf,fullfile(confusionDir,['Raw_',usableAlgorithms{learnerChoices(learner)},'_',typeML,'_',currentField,'.png']));
                close all
            end
            saveMCC.(fieldLabels{categoriesToTrain}) = ML_MCC(confMat);
        end
        
        
    end
    if ~strcmp(usableAlgorithms{learnerChoices(learner)},'kernel') && ~strcmp(usableAlgorithms{learnerChoices(learner)},'naivebayes')
        outMCCs.(usableAlgorithms{learnerChoices(learner)}) = saveMCC;
    else
        if size(matrixToProcess,2) < 5000
            outMCCs.(usableAlgorithms{learnerChoices(learner)}) = saveMCC;
        end
    end
end
end

