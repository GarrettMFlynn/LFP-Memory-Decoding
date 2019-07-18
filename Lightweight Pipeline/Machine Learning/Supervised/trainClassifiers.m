function [outMCCs] = trainClassifiers(dataML,passedMLType)

matrixToProcess = dataML.Data;

%% Begin Label Loop
fields = fieldnames(dataML.Labels);
fieldLabels = erase(fields,'Label_');
labels = cell(size(dataML.Labels.(fields{1}),1),1);
numTrials = size(dataML.Labels.(fields{1}),1);
labelMaker;

% BTW Linear is Lasso
learnerNames = {'linear','kernel','knn','naivebayes','svm','tree'};
for learner = 1:size(learnerNames)
    fprintf(['Learner: ',learnerNames{learner},'\n']);
for categoriesToTrain = 1:length(fields)
    fprintf(['\t',fields{categoriesToTrain},'\n']);
    labelCache = cell(numTrials,1);
    currentCategory = dataML.Labels.(fields{categoriesToTrain});
    currentField = fieldLabels{categoriesToTrain};
    for qq = 1:numTrials;
    if strfind(labels{qq},currentField)
        labelCache{qq} = currentField;
    else
        labelCache{qq} = ['Not ' currentField];
    end
    end
    
labelCache = categorical(labelCache);

%% Balance Test Set (not done yet)

%% Start Cross Validation
    if strcmp(learnerNames{learner},'linear')
        ourLinear = templateLinear('Regularization','lasso');
    classifier = fitcecoc(matrixToProcess', labelCache, ...
    'Learners', ourLinear,'ObservationsIn', 'columns','Kfold',10);
    else
          classifier = fitcecoc(matrixToProcess(train,:)', trainingLabels, ...
    'Learners', learnerNames{learner},'ObservationsIn', 'columns','Kfold',10);
    end
    % Pass features to trained classifier
%predictedLabels = predict(classifier, matrixToProcess', 'ObservationsIn', 'columns');
predictedLabels = kfoldPredict(classifier);

% Get the known labels
testLabels =  labelCache;

% Tabulate the results using a confusion matrix.
[confMat,categories] = confusionmat(testLabels, predictedLabels);
%plotconfusion(testLabels, predictedLabels);
saveMCC(categoriesToTrain) = ML_MCC(confMat);
    
end
    outMCCs.(learnerNames{learner}) = saveMCC;
end
end
    