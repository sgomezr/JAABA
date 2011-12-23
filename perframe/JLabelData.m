classdef JLabelData < handle
  
  properties (Access=public)

    % type of target (mainly used for plotting
    targettype = 'fly';
    
    % current selection
    
    % currently selected  experiment
    expi = 0;
    % currently selected flies
    flies = [];
    
    % last-used trajectories (one experiment, all flies)
    trx = {};

    % last-used per-frame data (one fly)
    perframedata = {};
    
    % computed and cached window features
    windowdata = struct('X',[],'exp',[],'flies',[],'t',[],...
      'labelidx_old',[],'labelidx_new',[],'featurenames',{{}},...
      'predicted',[],'predicted_probs',[],'isvalidprediction',[],...
      'distNdx',[],'scores',[],'scoreNorm',[],'binVals',[],'bins',[]);
    
    scoredata = struct('scores',[],'predicted',[],...
          'exp',[],'flies',[],'t',[],'timestamp',[]);
    
    % constant: radius of window data to compute at a time
    windowdatachunk_radius = 500;
    
    % total number of experiments
    nexps = 0;
    
    % labels struct array
    % labels(expi) is the labeled data for experiment expi
    % labels(expi).t0s are the start frames of all labeled sequences for
    % experiment expi
    % labels(expi).t1s are the corresponding end frames of all labeled
    % sequences for experiment expi
    % labels(expi).names is the cell array of the corresponding behavior
    % names for all labeled sequences for experiment expi
    % labels(expi).flies is the nseq x nflies_labeled matrix of the
    % corresponding flies for all labeled sequences for experiment expi
    % t0s{j}, t1s{j}, names{j}, and flies(j,:) correspond to each other. 
    % labels(expi).off is the offset so that labels(expi).t0s(j) +
    % labels(expi).off corresponds to the frame of the movie (since the
    % first frame for the trajectory(s) may not be 1.
    % labels(expi).timestamp is the Matlab timestamp at which labels(expi)
    % was last set
    labels = struct('t0s',{},'t1s',{},'names',{},'flies',{},'off',{},'timestamp',{});
    
    % labels for the current experiment and flies, represented as an array
    % such that labelidx(t+labelidx_off) is the index of the behavior for
    % frame t of the movie. labelidx(i) == 0 corresponds to
    % unlabeled/unknown, otherwise labelidx(i) corresponds to behavior
    % labelnames{labelidx{i})
    labelidx = [];
    labelidx_off = 0;
    
    % first frame that all flies currently selected are tracked
    t0_curr = 0;
    % last frame that all flies currently selected are tracked
    t1_curr = 0;
    
    % predicted label for current experiment and flies, with the same type
    % of representation as labelidx
    predictedidx = [];
    scoresidx = [];
    scoreTS = [];
    
    % whether the predicted label matches the true label. 0 stands for
    % either not predicted or not labeled, 1 for matching, 2 for not
    % matching. this has the same representation as labelidx.
    erroridx = [];
    
    % TODO: remove this
    % predictedidx for unlabeled data, same representation as labelidx
    suggestedidx = [];
    
    % names of behaviors, corresponding to labelidx
    labelnames = {};
    
%     % colors for plotting each behavior
%     labelcolors = [.7,0,0;0,0,.7];
%     unknowncolor = [0,0,0];
    
    % number of behaviors, including 'none'
    nbehaviors = 0;

    % statistics of labeled data per experiment
    % labelstats(expi).nflies_labeled is the total number of flies labeled,
    % labelstats(expi).nbouts_labeled is the total number of bouts of
    % behaviors labeled, labelstats(expi).datestr is the last time
    % labels(expi) was stored. 
    labelstats = struct('nflies_labeled',{},'nbouts_labeled',{},...
      'datestr',{});
    
    % computing per-frame properties
    perframe_params = {};
    landmark_params = {};
    
    % classifier
    
    % type of classifier to use
%    classifiertype = 'ferns';
    classifiertype = 'boosting';
    
    % currently learned classifier. structure depends on the type of
    % classifier. if empty, then no classifier has been trained yet. 
    % ferns:
    % classifier is a struct with the following fields (M is the number of
    % ferns, S is the fern depth, N is the number of training examples). 
    %   .fids     - [MxS] feature ids for each fern for each depth
    %   .thrs     - [MxS] threshold corresponding to each fid
    %   .pFern    - [2^SxHxM] learned log probs at fern leaves
    %   .bayes    - if true combine probs using bayes assumption
    %   .inds     - [NxM] cached indices for original training data
    %   .H        - number classes
    classifier = [];
    
    % Classifiers Time Stamp
    classifierTS = 0;
    
    % parameters to learning the classifier. struct fields depend on type
    % of classifier.
    % TODO
    classifier_params = struct;
    
    % Keep track if the scores have been validated.
    isValidated = false;
    
    % stuff cached during prediction
    predict_cache = struct;
    
    % name of file containing config parameters
    configfilename = '';
    
    % constant: files per experiment directory
    filetypes = {'movie','trx','label','perframedir','clipsdir'};%,'scores'};
    
    % config parameters
    
    % locations of files within experiment directories
    moviefilename = 0;
    trxfilename = 0;
    labelfilename = 0;
    perframedir = 0;
    clipsdir = 0;
    scores = 0;
    
    % file containing feature parameters
    featureparamsfilename = 0;
    
    % in case we don't want to write to the experiment directory, we will
    % mirror the experiment directory structure in the rootoutput dir
    % this can be the same as the input root directory
    rootoutputdir = 0;

    % name of classifier file to save/load classifier from
    classifierfilename = '';
    
    % experiment info: expi indexes the following
    
    % cell array of input experiment directory paths
    expdirs = {};
    
    % cell array of corresponding experiment names (last part of path)
    expnames = {};
    
    % cell array of corresponding output experiment directory paths
    outexpdirs = {};
    
    % array of number of flies in each experiment
    nflies_per_exp = [];
    
    % cell array of arrays of first frame of each trajectory for each
    % experiment: firstframes_per_exp{expi}(fly) is the first frame of the
    % trajectory of fly for experiment expi. 
    firstframes_per_exp = {};
    % cell array of arrays of end frame of each trajectory for each
    % experiment: endframes_per_exp{expi}(fly) is the last frame of the
    % trajectory of fly for experiment expi. 
    endframes_per_exp = {};
    
    % sex per experiment, fly
    frac_sex_per_exp = {};
    sex_per_exp = {};
    
    % whether sex is computed
    hassex = false;
    % whether sex is computed on a per-frame basis
    hasperframesex = false;
    
    % constant: stuff stored in classifier mat file
    classifiervars = {'expdirs','outexpdirs','expnames',...
      'nflies_per_exp','sex_per_exp','frac_sex_per_exp',...
      'firstframes_per_exp','endframes_per_exp',...
      'moviefilename','trxfilename','labelfilename','perframedir','clipsdir','featureparamsfilename',...
      'configfilename','rootoutputdir','classifiertype','classifier','trainingdata','classifier_params',...
      'classifierTS','confThresholds','scoreNorm'};%'windowfilename',
    
    % last used path for loading experiment
    defaultpath = '';
    
    % parameters of window features, represented as a struct
    windowfeaturesparams = struct;
    
    % parameters of window features, represented as a cell array of
    % parameter name, parameter value, so that it can be input to
    % ComputeWindowFeatures
    windowfeaturescellparams = {};
    
    % per-frame features that are used
    perframefns = {};
    perframeunits = {};

    % experiment/file management

    % matrix of size numel(file_types) x nexps, where
    % fileexists(filei,expi) indicates whether file filetypes{filei} exists
    % for experiment expi
    fileexists = [];
    
    % timestamps indicating time the files were last edited, same structure
    % as fileexists
    filetimestamps = [];
    
    % whether all necessary files for all experiments exist
    allfilesexist = true;

    % whether we can generate any missing files
    filesfixable = true;
    
    % functions for writing text to a status bar
    setstatusfn = '';
    clearstatusfn = '';
    
    % data for show similar frames.
    frameFig = [];
    distMat = [];
    bagModels = {};
    binVals = [];
    bins = [];
    confThresholds = zeros(1,2);
    
    % Retrain properly
    doUpdate = true;
  end
  
  methods (Access=private)
    
    
  end
    
  methods (Access=public,Static=true)

    % movie, trx, and perframedir are required for each experiment
    function res = IsRequiredFile(file)
      res = ismember(file,{'movie','trx','perframedir'});
    end    
    
    % perframedir can be generated
    function res = CanGenerateFile(file)
      res = ismember(file,{'perframedir'});
    end
    
    % which files should go in the output directory
    function res = IsOutputFile(file)
      res = ismember(file,{'label','clipsdir','scores'});
    end
    
    % which files are stored individually per fly (none anymore -- used to
    % be window files)
    function res = IsPerFlyFile(file)
      res = ismember(file,{});
    end
    
    function valid = CheckExp(expi)
      if numel(expi) ~= 1,
        error('Usage: expi must be a scalar');
        valid = false;
      else
        valid = true;
      end
    end
    
    function valid = CheckFlies(flies)
      if size(flies,1) ~= 1,
        error('Usage: one set of flies must be selected');
        valid = false;
      else
        valid = true;
      end
    end      

  end
  
  methods (Access=public)

    %
    % obj = JLabelData(configfilename,...)
    %
    % constructor: first input should be the config file name. All other
    % inputs are optional. if configfilename is not input, user will be
    % prompted for it. 
    % 
    % optional inputs: 
    %
    % TODO: debug this
    % override stuff set in the config file: 
    %
    % moviefilename, trxfilename, labelfilename, perframedir, clipsdir: names of
    % files within experiment directories: 
    % featureparamsfilename: file containing feature parameters
    % rootoutputdir: in case we don't want to write to the experiment
    % directory, we will mirror the experiment directory structure in the
    % rootoutputdir this can be the same as the input root directory
    %
    % defaultpath: default location to look for experiments
    % setstatusfn: handle to function that inputs sprintf-like input and
    % outputs the corresponding string to a status bar.
    % clearstatusfn: handle to function that returns the status to the
    % default string
    % classifierfilename: name of classifier file to save/load classifier from
    %    
    function obj = JLabelData(varargin)
 
      if nargin == 0 || isempty(varargin{1}),
        [filename,pathname] = uigetfile('*.xml','Choose config XML file');
        if ~ischar(filename),
          return;
        end
        configfilename = fullfile(pathname,filename);
        if ~isempty(varargin),
          varargin = varargin(2:end);
        end
      else
        configfilename = varargin{1};
        varargin = varargin(2:end);
      end
      
      if mod(numel(varargin),2) ~= 0,
        error('Number of inputs to JLabelData constructor must be even');
      end
      
      % config file
      [success,msg] = obj.SetConfigFileName(configfilename);
      if ~success,
        error(msg);
      end
      
      % parse optional arguments in order
      s = varargin(1:2:end);
      v = varargin(2:2:end);
      
      % movie
      i = find(strcmpi(s,'moviefilename'),1);
      if ~isempty(i),
        [success,msg] = obj.SetMovieFileName(v{i});
        if ~success,
          error(msg);
        end

      end
      
      % trx
      i = find(strcmpi(s,'trxfilename'),1);
      if ~isempty(i),
        [success,msg] = obj.SetTrxFileName(v{i});
        if ~success,
          error(msg);
        end
      end
      
      % label
      i = find(strcmpi(s,'labelfilename'),1);
      if ~isempty(i),
        [success,msg] = obj.SetLabelFileName(v{i});
        if ~success,
          error(msg);
        end
      end
      
      % perframedir
      i = find(strcmpi(s,'perframedir'),1);
      if ~isempty(i),
        [success,msg] = obj.SetPerFrameDir(v{i});
        if ~success,
          error(msg);
        end
      end

      % clipsdir
      i = find(strcmpi(s,'clipsdir'),1);
      if ~isempty(i),
        [success,msg] = obj.SetClipsDir(v{i});
        if ~success,
          error(msg);
        end
      end

      % featureparamsfilename
      i = find(strcmpi(s,'featureparamsfilename'),1);
      if ~isempty(i),
        [success,msg] = obj.SetFeatureParamsFileName(v{i});
        if ~success,
          error(msg);
        end
      end
      
      % rootoutputdir
      i = find(strcmpi(s,'rootoutputdir'),1);
      if ~isempty(i),
        [success,msg] = obj.SetRootOutputDir(v{i});
        if ~success,
          error(msg);
        end
      end
      
      % classifier
      i = find(strcmpi(s,'classifierfilename'),1);
      if ~isempty(i),
        [success,msg] = obj.SetClassifierFileName(v{i});
        if ~success,
          error(msg);
        end
      end
      
      % default path
      i = find(strcmpi(s,'defaultpath'),1);
      if ~isempty(i),
        [success,msg] = obj.SetDefaultPath(v{i});
        if ~success,
          warning(msg);
        end
      end
      
      i = find(strcmpi(s,'setstatusfn'),1);
      if ~isempty(i),
        obj.setstatusfn = v{i};
      end

      i = find(strcmpi(s,'clearstatusfn'),1);
      if ~isempty(i),
        obj.clearstatusfn = v{i};
      end
      
      % make sure everything gets set, one way or another
      requiredfns = {'moviefilename','trxfilename','labelfilename'}; % 'windowfilename',
      for i = 1:numel(requiredfns),
        fn = requiredfns{i};
        if isnumeric(obj.(fn)),
          error('%s did not get initialized',fn);
        end
      end
      
      % initialize the status table describing what required files exist
      [success,msg] = obj.UpdateStatusTable();
      if ~success,
        error(msg);
      end
      
    end

    function idx = FlyNdx(obj,expi,flies)
      idx = obj.windowdata.exp == expi & all(bsxfun(@eq,obj.windowdata.flies,flies),2);
    end
    
    function val = IsCurFly(obj,expi,flies)
      val = all(flies == obj.flies) && (expi==obj.expi);
    end
    
    % [success,msg] = SetConfigFileName(obj,configfilename)
    % Set and read config file. 
    % Reads the XML config file, then sets all the file names and paths.
    % I think this currently needs to be called before experiments, labels
    % are loaded in, as locations of files, behaviors can be modified by
    % this step. 
    % labelnames, nbehaviors are also set by the config file. If not
    % included explicitly, the 'None' behavior is added. 'None' is put at
    % the end of the behavior list. 
    function [success,msg] = SetConfigFileName(obj,configfilename)
      
      success = false;
      msg = '';
      if ~ischar(configfilename),
        return;
      end
%       try
        configparams = ReadXMLParams(configfilename);
%       catch ME,
%         msg = sprintf('Error reading config file %s: %s',configfilename,getReport(ME));
%         return;
%       end
      obj.configfilename = configfilename;
      if isfield(configparams,'file'),
        if isfield(configparams.file,'moviefilename'),
          [success1,msg] = obj.SetMovieFileName(configparams.file.moviefilename);
          if ~success1,
            return;
          end
        end
        if isfield(configparams.file,'trxfilename'),
          [success1,msg] = obj.SetTrxFileName(configparams.file.trxfilename);
          if ~success1,
            return;
          end
        end
        if isfield(configparams.file,'labelfilename'),
          [success1,msg] = obj.SetLabelFileName(configparams.file.labelfilename);
          if ~success1,
            return;
          end
        end
        if isfield(configparams.file,'perframedir'),
          [success1,msg] = obj.SetPerFrameDir(configparams.file.perframedir);
          if ~success1,
            return;
          end
        end
        if isfield(configparams.file,'clipsdir'),
          [success1,msg] = obj.SetClipsDir(configparams.file.clipsdir);
          if ~success1,
            return;
          end
        end
        if isfield(configparams.file,'rootoutputdir'),
          [success1,msg] = obj.SetRootOutputDir(configparams.file.rootoutputdir);
          if ~success1,
            return;
          end
        end
        if isfield(configparams.file,'featureparamfilename'),
          [success1,msg] = obj.SetFeatureParamsFileName(configparams.file.featureparamfilename);
          if ~success1,
            return;
          end
        end
        if isfield(configparams,'perframe'),
          if isfield(configparams.perframe,'params'),
            obj.perframe_params = configparams.perframe.params;
          end
          if isfield(configparams.perframe,'landmark_params'),
            obj.landmark_params = configparams.perframe.landmark_params;
          end
        end
        if isfield(configparams,'targets'),
          if isfield(configparams.targets,'type'),
            obj.targettype = configparams.targets.type;
          end
        end
      end
      
      if isfield(configparams,'behaviors'),
        
        % read in behavior names
        if isfield(configparams.behaviors,'names'),
          obj.labelnames = configparams.behaviors.names;
          if ~iscell(obj.labelnames),
            obj.labelnames = {obj.labelnames};
          end
          % add none label
          if ~ismember('none',lower(obj.labelnames)),
            obj.labelnames{end+1} = 'None';
          end
        else
          obj.labelnames = {'Behavior','None'};
        end
                  
        obj.nbehaviors = numel(obj.labelnames);
        
%         % colors
%         if isfield(configparams.behaviors,'labelcolors'),
%           if numel(configparams.behaviors.labelcolors) == obj.nbehaviors*3,
%             obj.labelcolors = configparams.behaviors.labelcolors;
%           end
%         end
%         if isfield(configparams.behaviors,'unknowncolor'),
%           if numel(configparams.behaviors.unknowncolor) == 3,
%             obj.unknowncolor = configparams.behaviors.unknowncolor;
%           end
%         end
        
        % rearrange so that None is the last label
        nonei = find(strcmpi('None',obj.labelnames),1);
        obj.labelnames = obj.labelnames([1:nonei-1,nonei+1:obj.nbehaviors,nonei]);
        
      end
      
      if isfield(configparams,'learning'),
        if isfield(configparams.learning,'classifiertype'),
          obj.SetClassifierType(configparams.learning.classifiertype);
        end
      end
      
    end
    
    % [success,msg] = PreLoadWindowData(obj,expi,flies,ts)
    % Compute and store the window data for experiment expi, flies flies,
    % and all frames ts. 
    % This function finds all frames that currently do not have window data
    % cached. In a loop, it finds the first frame that is missing window
    % data, and computes window data for all frames in a chunk of size
    % 2*obj.windowdatachunk_radius + 1 after this frame using the function
    % ComputeWindowDataChunk. Then, it updates the frames that are missing
    % window data. It proceeds in this loop until there are not frames
    % in the input ts missing window data. 
    function [success,msg] = PreLoadWindowData(obj,expi,flies,ts)
      
      success = false; msg = '';
      obj.CheckExp(expi); obj.CheckFlies(flies);
      
      % which frames don't have window data yet
      if isempty(obj.windowdata.exp),
        missingts = ts;
        tscurr = [];
      else      
        idxcurr = obj.FlyNdx(expi,flies);
        tscurr = obj.windowdata.t(idxcurr);
        missingts = setdiff(ts,tscurr);
      end
        
      % no frames missing data?
      if isempty(missingts),
        success = true;
        return;
      end

      % get labels for current flies -- will be used when filling in
      % windowdata
      [labelidx,t0_labelidx] = obj.GetLabelIdx(expi,flies);

      % total number of frames to compute window data for -- used for
      % showing prctage complete. 
      nts0 = numel(missingts);
      
      while true,

        % choose a frame missing window data
        %t = missingts(1);
        t = median(missingts);
        if ~ismember(t,missingts),
          t = missingts(argmin(abs(t-missingts)));
        end
        
        % update the status
        obj.SetStatus('Computing window data for exp %s, fly%s: %d%% done...',...
          obj.expnames{expi},sprintf(' %d',flies),round(100*(nts0-numel(missingts))/nts0));

        % compute window data for a chunk starting at t
        [success1,msg,t0,t1,X,feature_names] = obj.ComputeWindowDataChunk(expi,flies,t,'center');
        if ~success1, warning(msg); return; end
        
        % only store window data that isn't already cached
        tsnew = t0:t1;
        idxnew = ~ismember(tsnew,tscurr);
        m = nnz(idxnew);

        % add to windowdata
        obj.windowdata.X(end+1:end+m,:) = X(idxnew,:);
        obj.windowdata.exp(end+1:end+m,1) = expi;
        obj.windowdata.flies(end+1:end+m,:) = repmat(flies,[m,1]);
        obj.windowdata.t(end+1:end+m,1) = tsnew(idxnew);
        obj.windowdata.labelidx_old(end+1:end+m,1) = 0;
        obj.windowdata.labelidx_new(end+1:end+m,1) = labelidx(t0-t0_labelidx+1:t1-t0_labelidx+1);
        obj.windowdata.predicted(end+1:end+m,1) = 0;
        obj.windowdata.scores(end+1:end+m,1) = 0;
        obj.windowdata.isvalidprediction(end+1:end+m,1) = false;

        % remove from missingts all ts that were computed in this chunk
        missingts(missingts >= t0 & missingts <= t1) = [];

        % stop if we're done
        if isempty(missingts),
          obj.ClearStatus();
          break;
        end
        
      end
      
      % store feature_names -- these shouldn't really change
      obj.windowdata.featurenames = feature_names;
      
      success = true;
      
    end

    % [success,msg,t0,t1,X,feature_names] = ComputeWindowDataChunk(obj,expi,flies,t)
    % Computes a chunk of windowdata near frame t for experiment expi and
    % flies flies. if mode is 'start', then the chunk will start at t. if
    % it is 'center', the chunk will be centered at t. if mode is 'end',
    % the chunk will end at t. by default, mode is 'center'. 
    % t0 and t1 define the bounds of the chunk of window data computed. X
    % is the nframes x nfeatures window data, feature_names is a cell array
    % of length nfeatures containing the names of each feature. 
    %
    % This function first chooses an interval of frames around t, depending 
    % on the mode. it then chooses a subinterval of this interval that
    % covers all frames in this interval that do not have window data. This
    % defines t0 and t1. 
    % 
    % It then loops through all the per-frame features, and calls
    % ComputeWindowFeatures to compute all the window data for that
    % per-frame feature. 
    %
    % To predict over the whole movie we use forceCalc which
    % forces the function to recalculate all the features even though they
    % were calculated before.
    function [success,msg,t0,t1,X,feature_names] = ComputeWindowDataChunk(obj,expi,flies,t,mode,forceCalc)
      
      success = false; msg = '';
      
      if ~exist('mode','var'), mode = 'center'; end
      if ~exist('forceCalc','var'), forceCalc = false; end
      
      % choose frames to compute:
      
      % bound at start and end frame of these flies
      T0 = max(obj.GetTrxFirstFrame(expi,flies));
      T1 = min(obj.GetTrxEndFrame(expi,flies));
      
      switch lower(mode),
        case 'center',
          % go forward r to find the end of the chunk
          t1 = min(t+obj.windowdatachunk_radius,T1);
          % go backward 2*r to find the start of the chunk
          t0 = max(t1-2*obj.windowdatachunk_radius,T0);
          % go forward 2*r again to find the end of the chunk
          t1 = min(t0+2*obj.windowdatachunk_radius,T1);
        case 'start',
          t0 = max(t,T0);
          t1 = min(t0+2*obj.windowdatachunk_radius,T1);
        case 'end',
          t1 = min(t,T1);
          t0 = max(t1-2*obj.windowdatachunk_radius,T0);
        otherwise
          error('Unknown mode %s',mode);
      end
      
      % find a continuous interval that covers all uncomputed ts between t0
      % and t1
      off = 1-t0;
      n = t1-t0+1;
      docompute = true(1,n);
      if ~isempty(obj.windowdata.exp) && ~forceCalc,
        tscomputed = obj.windowdata.t(obj.FlyNdx(expi,flies));
        tscomputed = tscomputed(tscomputed >= t0 & tscomputed <= t1);
        docompute(tscomputed+off) = false;
      end
      
      X = [];
      feature_names = {};
      if ~any(docompute),
        t1 = t0-1;
        success = true;
        return;
      end
      
      t0 = find(docompute,1,'first') - off;
      t1 = find(docompute,1,'last') - off;
      i0 = t0 - obj.GetTrxFirstFrame(expi,flies) + 1;
      i1 = t1 - obj.GetTrxFirstFrame(expi,flies) + 1;
      
%       try

        % loop through per-frame fields
        for j = 1:numel(obj.perframefns),
          fn = obj.perframefns{j};

          % get per-frame data
          if ~isempty(obj.flies) && obj.IsCurFly(expi,flies),
            perframedata = obj.perframedata{j};
          else
            perframedir = obj.GetFile('perframedir',expi);
            perframedata = load(fullfile(perframedir,[fn,'.mat']));
            perframedata = perframedata.data{flies(1)};
          end
          
          i11 = min(i1,numel(perframedata));
          [x_curr,feature_names_curr] = ...
              ComputeWindowFeatures(perframedata,obj.windowfeaturescellparams.(fn){:},'t0',i0,'t1',i11);
          if i11 < i1,
            x_curr(:,end+1:end+i1-i11) = nan;
          end
            
          % add the window data for this per-frame feature to X
          nold = size(X,1);
          nnew = size(x_curr,2);
          if nold > nnew,
            warning('Number of examples for per-frame feature %s does not match number of examples for previous features',fn);
            x_curr(:,end+1:end+nold-nnew) = nan;
          elseif nnew > nold && ~isempty(X),
            warning('Number of examples for per-frame feature %s does not match number of examples for previous features',fn);
            X(end+1:end+nnew-nold,:) = nan;
          end
          X = [X,x_curr']; %#ok<AGROW>
          % add the feature names
          feature_names = [feature_names,cellfun(@(s) [{fn},s],feature_names_curr,'UniformOutput',false)]; %#ok<AGROW>
        end
%       catch ME,
%         msg = getReport(ME);
%         return;
%       end
      
      success = true;
     
    end
    
    function ClearWindowFeatures(obj)
      % Clears window features and predictions for a clean start when selecting
      % features.
      obj.windowdata.X = [];
      obj.windowdata.exp = [];
      obj.windowdata.flies=[];
      obj.windowdata.t=[];
      obj.windowdata.labelidx_old=[];
      obj.windowdata.labelidx_new=[];
      obj.windowdata.featurenames={{}};
      obj.windowdata.predicted=[];
      obj.windowdata.predicted_probs=[];
      obj.windowdata.isvalidprediction=[];
      obj.windowdata.distNdx=[];
      obj.windowdata.scores=[];
      obj.windowdata.scoreNorm=[];
      obj.windowdata.binVals=[];
      obj.windowdata.bins=[];
      
      obj.UpdatePredictedIdx();

    end
  
    % change/set the name of the movie within the experiment directory
    % will fail if movie files don't exist for any of the current
    % experiment directories (checked by CheckMovies)
    function [success,msg] = SetMovieFileName(obj,moviefilename)

      success = false; msg = '';

      if ischar(moviefilename),
        if ischar(obj.moviefilename) && strcmp(moviefilename,obj.moviefilename),
          success = true;
          return;
        end
        oldmoviefilename = obj.moviefilename;
        obj.moviefilename = moviefilename;
        [success1,msg] = obj.CheckMovies();
        if ~success1,
          obj.moviefilename = oldmoviefilename;
          return;
        end
        [success,msg] = obj.UpdateStatusTable('movie');
      end
      
    end
    
    % [successes,msg] = CheckMovies(obj,expis)
    % check that the movie files exist and can be read for the input
    % experiments.
    function [successes,msg] = CheckMovies(obj,expis)
      
      successes = []; msg = '';
      
      if nargin < 2,
        expis = 1:obj.nexps;
      end
      
      if isempty(expis),
        return;
      end
      
      successes = true(1,numel(expis));
      for i = 1:numel(expis),
        moviefilename = obj.GetFile('movie',expis(i));
        obj.SetStatus('Checking movie %s...',moviefilename);
        
        % check for file existence
        if ~exist(moviefilename,'file'),
          successes(i) = false;
          msg1 = sprintf('File %s missing',moviefilename);
          if isempty(msg),
            msg = msg1;
          else
            msg = sprintf('%s\n%s',msg,msg1);
          end
        else
          
          % try reading a frame
%           try
            [readframe,~,movie_fid] = ...
              get_readframe_fcn(moviefilename);
            if movie_fid <= 0,
              error('Could not open movie %s for reading',moviefilename);
            end
            readframe(1);
            fclose(movie_fid);
%           catch ME,
%             successes(i) = false;
%             msg1 = sprintf('Could not parse movie %s: %s',moviefilename,getReport(ME));
%             if isempty(msg),
%               msg = msg1;
%             else
%               msg = sprintf('%s\n%s',msg,msg1);
%             end
%           end
          
        end
      end
      
      obj.ClearStatus();
      
    end
    
    % [success,msg] = SetTrxFileName(obj,trxfilename)
    % set the name of the trx file within the experiment directory. this
    % does not currently check for missing/bad trx files, or replace
    % preloaded trx data, so you really shouldn't call it if expdirs are
    % loaded. (TODO)
    function [success,msg] = SetTrxFileName(obj,trxfilename)
      
      success = false;
      msg = '';
      if ischar(trxfilename),
        if ischar(obj.trxfilename) && strcmp(trxfilename,obj.trxfilename),
          success = true;
          return;
        end
        obj.trxfilename = trxfilename;
        [success,msg] = obj.UpdateStatusTable('trx');        
        % TODO: check that trx are parsable, remove bad experiments, update
        % preloaded trx
      end
      
    end
    
    % [success,msg] = SetLabelFileName(obj,labelfilename)
    % set the name of the label file within the experiment directory. this
    % does not currently update labelidx, and probably should not be called
    % once an experiment is open. 
    function [success,msg] = SetLabelFileName(obj,labelfilename)
      
      success = false;
      msg = '';

      if ischar(labelfilename),
        if ischar(obj.labelfilename) && strcmp(labelfilename,obj.labelfilename),
          success = true;
          return;
        end

        % reload labels from file
        for expi = 1:obj.nexps,
          [success1,msg] = obj.LoadLabelsFromFile(expi);
          if ~success1,
            return;
          end
        end
        
        obj.labelfilename = labelfilename;
        [success,msg] = obj.UpdateStatusTable('label');   
        
      end
      
    end
    
    function [success,msg] = SetClassifierType(obj,classifiertype)

      success = true;
      msg = '';
      
      % TODO: retrain classifier if necessary
      if strcmpi(classifiertype,obj.classifiertype),
        return;
      end
      
      obj.classifiertype = classifiertype;
      
    end
    
    % [success,msg] = LoadLabelsFromFile(obj,expi)
    % If the label file exists, this function loads labels for experiment
    % expi into obj.labels. Otherwise, it sets the labels to be empty. This
    % does not currently update the windowdata and labelidx (TODO). 
    function [success,msg] = LoadLabelsFromFile(obj,expi)
      
      success = false;
      msg = '';
      
      labelfilename = obj.GetFile('label',expi);
      if exist(labelfilename,'file'),

        obj.SetStatus('Loading labels for %s',obj.expdirs{expi});

%         try
          loadedlabels = load(labelfilename,'t0s','t1s','names','flies','off','timestamp');
          obj.labels(expi).t0s = loadedlabels.t0s;
          obj.labels(expi).t1s = loadedlabels.t1s;
          obj.labels(expi).names = loadedlabels.names;
          obj.labels(expi).flies = loadedlabels.flies;
          obj.labels(expi).off = loadedlabels.off;
          obj.labelstats(expi).nflies_labeled = size(loadedlabels.flies,1);
          obj.labelstats(expi).nbouts_labeled = numel([loadedlabels.t0s{:}]);
          obj.labelstats(expi).datestr = datestr(loadedlabels.timestamp,'yyyymmddTHHMMSS');
%         catch ME,
%           msg = getReport(ME);
%           obj.ClearStatus();
%           return;
%         end
        
        obj.ClearStatus();
        
      else
        
        obj.labels(expi).t0s = {};
        obj.labels(expi).t1s = {};
        obj.labels(expi).names = {};
        obj.labels(expi).flies = [];
        obj.labels(expi).off = [];
        obj.labels(expi).timestamp = [];
        obj.labelstats(expi).nflies_labeled = 0;
        obj.labelstats(expi).nbouts_labeled = 0;
        obj.labelstats(expi).datestr = 'never';

      end
      
      % TODO: update windowdata
      
      success = true;
      
    end
 
    
    % [success,msg] = SetPerFrameDir(obj,perframedir)
    % Sets the per-frame directory name within the experiment directory.
    % Currently, this does not change the cached per-frame data or check
    % that all the per-frame files necessary are within the directory
    % (TODO).
    function [success,msg] = SetPerFrameDir(obj,perframedir)
      
      success = false; msg = '';

      if ischar(perframedir),
        if ischar(obj.perframedir) && strcmp(perframedir,obj.perframedir),
          success = true;
          return;
        end

        obj.perframedir = perframedir;
        
        % TODO: check per-frame directories are okay, remove bad
        % experiments
        
        [success,msg] = obj.UpdateStatusTable('perframedir');
      end
      
    end

    % [success,msg] = SetClipsDir(obj,clipsdir)
    % Sets the clips directory name within the experiment directory.
    function [success,msg] = SetClipsDir(obj,clipsdir)
      
      success = false;
      msg = '';

      if ischar(clipsdir),
        for i = 1:numel(obj.expdirs),
          clipsdircurr = fullfile(obj.expdirs{i},clipsdir);
          if exist(obj.expdirs{i},'dir') && ~exist(clipsdircurr,'dir'),
            mkdir(clipsdircurr);
          end
        end
        if ischar(obj.clipsdir) && strcmp(clipsdir,obj.clipsdir),
          success = true;
          return;
        end

        obj.clipsdir = clipsdir;        
        [success,msg] = obj.UpdateStatusTable('clipsdir');
      end
      
    end

    % [success,msg] = SetDefaultPath(obj,defaultpath)
    % sets the default path to load experiments from. only checks for
    % existence of the directory.
    function [success,msg] = SetDefaultPath(obj,defaultpath)
      
      success = false;
      msg = '';
      
      if ischar(defaultpath),
        
        if ~isempty(defaultpath) && ~exist(defaultpath,'file'),
          msg = sprintf('defaultpath directory %s does not exist',defaultpath);
          return;
        end
          
        obj.defaultpath = defaultpath;
        success = true;
      end

    end
    
    % [success,msg] = SetRootOutputDir(obj,rootoutputdir)
    % sets the root directory for outputing files. currently, it does not
    % update labels, etc. or recheck for the existence of all the required
    % files. (TODO)
    function [success,msg] = SetRootOutputDir(obj,rootoutputdir)
      
      success = true;
      msg = '';
      if ischar(rootoutputdir),
        if ischar(obj.rootoutputdir) && strcmp(obj.rootoutputdir,rootoutputdir),
          success = true;
          return;
        end
        if ~exist(rootoutputdir,'file'),
          msg = sprintf('root output directory %s does not exist',rootoutputdir);
          success = false;
          return;
        end
        obj.rootoutputdir = rootoutputdir;
        for i = 1:obj.nexps,
          obj.outexpdirs{i} = fullfile(rootoutputdir,obj.expnames{i});
        end
        % TODO: check all files are okay, remove bad experiments
        
        [success,msg] = obj.UpdateStatusTable();
      end
      
    end    
    
    % [success,msg] = SetClassifierFileName(obj,classifierfilename)
    % Sets the name of the classifier file. If the classifier file exists, 
    % it loads the data stored in the file. This involves removing all the
    % experiments and data currently loaded, setting the config file,
    % setting all the file names set in the config file, setting the
    % experiments to be those listed in the classifier file, clearing all
    % the previously computed window data and computing the window data for
    % all the labeled frames. 
    function [success,msg] = SetClassifierFileName(obj,classifierfilename)
      
      success = false;
      msg = '';
      
      obj.classifierfilename = classifierfilename;
      if ~isempty(classifierfilename) && exist(classifierfilename,'file'),
%         try
          obj.SetStatus('Loading classifier from %s',obj.classifierfilename);

          loadeddata = load(obj.classifierfilename,obj.classifiervars{:});

          % remove all experiments
          obj.RemoveExpDirs(1:obj.nexps);
          
          % set config file
          if ~strcmp(obj.configfilename,'configfilename'),
            obj.SetConfigFileName(loadeddata.configfilename);
          end

          % set movie
          [success,msg] = obj.SetMovieFileName(loadeddata.moviefilename);
          if ~success,error(msg);end

          % trx
          [success,msg] = obj.SetTrxFileName(loadeddata.trxfilename);
          if ~success,error(msg);end
      
          % label
          [success,msg] = obj.SetLabelFileName(loadeddata.labelfilename);
          if ~success,error(msg);end
      
          % perframedir
          [success,msg] = obj.SetPerFrameDir(loadeddata.perframedir);
          if ~success,error(msg);end

          % clipsdir
          [success,msg] = obj.SetClipsDir(loadeddata.clipsdir);
          if ~success,error(msg);end
          
          % featureparamsfilename
          [success,msg] = obj.SetFeatureParamsFileName(loadeddata.featureparamsfilename);
          if ~success,error(msg);end
      
          % rootoutputdir
          [success,msg] = obj.SetRootOutputDir(loadeddata.rootoutputdir);
          if ~success,error(msg); end
           
          % set experiment directories
          obj.SetExpDirs(loadeddata.expdirs,loadeddata.outexpdirs,...
            loadeddata.nflies_per_exp,loadeddata.sex_per_exp,loadeddata.frac_sex_per_exp,...
            loadeddata.firstframes_per_exp,loadeddata.endframes_per_exp); 

          [success,msg] = obj.UpdateStatusTable();
          if ~success, error(msg); end
          
          % update cached data
%           obj.windowdata = struct('X',[],'exp',[],'flies',[],'t',[],...
%             'labelidx_old',[],'labelidx_new',[],'featurenames',{{}},...
%             'predicted',[],'predicted_probs',[],'isvalidprediction',[]);
          [success,msg] = obj.PreLoadLabeledData();
          if ~success,error(msg);end
                                       
          obj.classifier = loadeddata.classifier;
          obj.classifiertype = loadeddata.classifiertype;
          obj.classifierTS = loadeddata.classifierTS;
          obj.classifier_params = loadeddata.classifier_params;
          obj.windowdata.scoreNorm = loadeddata.scoreNorm;
          obj.confThresholds = loadeddata.confThresholds;
          % predict for all loaded examples
          obj.PredictLoaded();
          
          % set labelidx_old
          obj.SetTrainingData(loadeddata.trainingdata);

          if strcmp(obj.classifiertype,'boosting'),
            [obj.windowdata.binVals, obj.windowdata.bins] = findThresholds(obj.windowdata.X);
          end
          
          % make sure inds is ordered correctly
          if ~isempty(obj.classifier),
            switch obj.classifiertype,
              
              case 'ferns',
                waslabeled = obj.windowdata.labelidx_old ~= 0;
                obj.classifier.inds = obj.predict_cache.last_predicted_inds(waslabeled,:);
            
            end
          end
          
          % clear the cached per-frame, trx data
          obj.ClearCachedPerExpData();
          
%         catch ME,
%           errordlg(getReport(ME),'Error loading classifier from file');
%         end
        
        obj.ClearStatus();
        
        obj.classifierfilename = classifierfilename;
        
      end

    end
    
    function SetClassifierFileNameBatch(obj,classifierfilename)

      success = false;
      msg = '';
      
      obj.classifierfilename = classifierfilename;
      if ~isempty(classifierfilename) && exist(classifierfilename,'file'),
%         try
          obj.SetStatus('Loading classifier from %s',obj.classifierfilename);

          loadeddata = load(obj.classifierfilename,obj.classifiervars{:});

%{          
          % remove all experiments
          obj.RemoveExpDirs(1:obj.nexps);
          % set experiment directories
          obj.SetExpDirs(loadeddata.expdirs,loadeddata.outexpdirs,...
            loadeddata.nflies_per_exp,loadeddata.sex_per_exp,loadeddata.frac_sex_per_exp,...
            loadeddata.firstframes_per_exp,loadeddata.endframes_per_exp); 
%}
          [success,msg] = obj.UpdateStatusTable();
          if ~success, error(msg); end
                                       
          obj.classifier = loadeddata.classifier;
          obj.classifiertype = loadeddata.classifiertype;
          obj.classifierTS = loadeddata.classifierTS;
          obj.classifier_params = loadeddata.classifier_params;
          obj.windowdata.scoreNorm = loadeddata.scoreNorm;
          obj.confThresholds = loadeddata.confThresholds;
      end
    end

    % [success,msg] = PreLoadLabeledData(obj)
    % This function precomputes any missing window data for all labeled
    % training examples by calling PreLoadWindowData on all labeled frames.
    function [success,msg] = PreLoadLabeledData(obj)

      success = false; msg = '';
      
      for expi = 1:obj.nexps,
        for i = 1:size(obj.labels(expi).flies,1),
          
          flies = obj.labels(expi).flies(i,:);
          labels_curr = obj.GetLabels(expi,flies);
          ts = [];
          
          for j = 1:numel(labels_curr.t0s),
            ts = [ts,labels_curr.t0s(j):labels_curr.t1s(j)]; %#ok<AGROW>
          end
          
          [success1,msg] = obj.PreLoadWindowData(expi,flies,ts);
          if ~success1,return;end            
          
        end
      end
      success = true;
      
    end
    
    % Save prediction scores for the whole experiment.
    % The scores are stored as a cell array.
    function SaveScores(obj,allScores,expi)
      scoreFileName = sprintf('scores_%s.mat',obj.labelnames{1});
      sfn = fullfile(obj.rootoutputdir,obj.expnames{expi},scoreFileName);
      obj.SetStatus('Saving scores for experiment %s to %s',obj.expnames{expi},sfn);

      didbak = false;
      if exist(sfn,'file'),
        [didbak,msg] = copyfile(sfn,[sfn,'~']);
        if ~didbak,
          warning('Could not create backup of %s: %s',sfn,msg);
        end
      end
      timestamp = obj.classifierTS;
      save(sfn,'allScores','timestamp');
    end
    
    function LoadScores(obj,expi)
      scoreFileName = sprintf('scores_%s.mat',obj.labelnames{1});
      sfn = fullfile(obj.rootoutputdir,obj.expnames{expi},scoreFileName);
      obj.SetStatus('Loading scores for experiment %s from %s',obj.expnames{expi},sfn);

      if exist(sfn,'file'),
        load(sfn,'allScores','timestamp');
        for ndx = 1:numel(allScores.scores)
          if obj.scoredata.exp
            idxcurr = obj.scoredata.exp == expi & all(bsxfun(@eq,obj.scoredata.flies,ndx),2);
          else
            idxcurr = [];
          end
          if any(idxcurr), continue; end
          tStart = allScores.tStart(ndx);
          tEnd = allScores.tEnd(ndx);
          sz = tEnd-tStart+1;
          curScores = allScores.scores{ndx}(tStart:tEnd);
          obj.scoredata.scores(end+1:end+sz) = curScores;
          obj.scoredata.predicted(end+1:end+sz) = -sign(curScores)*0.5+1.5;
          obj.scoredata.exp(end+1:end+sz,1) = expi;
          obj.scoredata.flies(end+1:end+sz,1) = ndx;
          obj.scoredata.t(end+1:end+sz) = tStart:tEnd;
          obj.scoredata.timestamp(end+1:end+sz) = timestamp;
        end
      end
      obj.UpdatePredictedIdx();

      if isempty(obj.windowdata.scoreNorm) || isnan(obj.windowdata.scoreNorm)
        if ~isempty(obj.scoredata.scores)
          scoreNorm = prctile(abs(obj.scoredata.scores),80);
          obj.windowdata.scoreNorm = scoreNorm;
        end
      end

      obj.ClearStatus();

    end
    
    % SaveClassifier(obj)
    % This function saves the current classifier to the file
    % ons.classifierfilename. It first constructs a struct representing the
    % training data last used to train the classifier, then adds all the
    % data described in obj.classifiervars. 
    function SaveClassifier(obj)
      
      
      s = struct;
      s.classifierTS = obj.classifierTS;
      s.trainingdata = obj.SummarizeTrainingData();
%       try
        for i = 1:numel(obj.classifiervars),
          fn = obj.classifiervars{i};
          if isfield(s,fn),
          % elseif isprop(obj,fn),
          % isprop doesn't work right on 2010b
          elseif ismember(fn,properties(obj))
            s.(fn) = obj.(fn);
          elseif isstruct(obj.windowdata) && isfield(obj.windowdata,fn),
            s.(fn) = obj.windowdata.(fn);
          else
            error('Unknown field %s',fn);
          end
            
        end
        save(obj.classifierfilename,'-struct','s');
%       catch ME,
%         errordlg(getReport(ME),'Error saving classifier to file');
%       end      
      
    end

    % SaveLabels(obj,expis)
    % For each experiment in expis, save the current set of labels to file.
    % A backup of old labels is made if they exist and stored in
    % <labelfilename>~
    function SaveLabels(obj,expis)
      
      if nargin<2
        expis = 1:obj.nexps;
      end
      
      % store labels in labelidx
      obj.StoreLabels();
      
      for i = expis,
        
        lfn = GetFile(obj,'label',i,true);
        obj.SetStatus('Saving labels for experiment %s to %s',obj.expnames{i},lfn);

        didbak = false;
        if exist(lfn,'file'),
          [didbak,msg] = copyfile(lfn,[lfn,'~']);
          if ~didbak,
            warning('Could not create backup of %s: %s',lfn,msg);
          end
        end

        t0s = obj.labels(i).t0s; %#ok<NASGU>
        t1s = obj.labels(i).t1s; %#ok<NASGU>
        names = obj.labels(i).names; %#ok<NASGU>
        flies = obj.labels(i).flies; %#ok<NASGU>
        off = obj.labels(i).off; %#ok<NASGU>
        timestamp = obj.labels(i).timestamp; %#ok<NASGU>
        
%         try
          save(lfn,'t0s','t1s','names','flies','off','timestamp');
%         catch ME,
%           if didbak,
%             [didundo,msg] = copyfile([lfn,'~'],lfn);
%             if ~didundo, warning('Error copying backup file for %s: %s',lfn,msg); end
%           end
%           errordlg(sprintf('Error saving label file %s: %s.',lfn,getReport(ME)),'Error saving labels');
%         end
      end
      
      [success,msg] = obj.UpdateStatusTable('label');
      if ~success,
        error(msg);
      end

      obj.ClearStatus();
    end

    % [success,msg] = SetExpDirs(obj,[expdirs,outexpdirs,nflies_per_exp,firstframes_per_exp,endframes_per_exp])
    % Changes what experiments are currently being used for this
    % classifier. This function calls RemoveExpDirs to remove all current
    % experiments not in expdirs, then calls AddExpDirs to add the new
    % experiment directories. 
    function [success,msg] = SetExpDirs(obj,expdirs,outexpdirs,nflies_per_exp,...
        sex_per_exp,frac_sex_per_exp,firstframes_per_exp,endframes_per_exp)

      success = false;
      msg = '';
      
      if isnumeric(expdirs),
        return;
      end
      
      if nargin < 2,
        error('Usage: obj.SetExpDirs(expdirs,[outexpdirs],[nflies_per_exp])');
      end
      
      isoutexpdirs = nargin > 2 && ~isnumeric(outexpdirs);
      isnflies = nargin > 3 && ~isempty(nflies_per_exp);
      issex = nargin > 4 && ~isempty(sex_per_exp);
      isfracsex = nargin > 5 && ~isempty(frac_sex_per_exp);
      isfirstframes = nargin > 6 && ~isempty(firstframes_per_exp);
      isendframes = nargin > 7 && ~isempty(endframes_per_exp);
      
      % check inputs
      
      % sizes must match
      if isoutexpdirs && numel(expdirs) ~= numel(outexpdirs),
        error('expdirs and outexpdirs do not match size');
      end
      if isnflies && numel(expdirs) ~= numel(nflies_per_exp),
        error('expdirs and nflies_per_exp do not match size');
      end
      
      oldexpdirs = obj.expdirs;
      
      % remove oldexpdirs
      
      [success1,msg] = obj.RemoveExpDirs(find(~ismember(oldexpdirs,expdirs))); %#ok<FNDSB>
      if ~success1,
        return;
      end

      % add new expdirs
      idx = find(~ismember(expdirs,oldexpdirs));
      success = true;
      for i = idx,
        params = cell(1,nargin-1);
        params{1} = expdirs{i};
        if isoutexpdirs,
          params{2} = outexpdirs{i};
        end
        if isnflies,
          params{3} = nflies_per_exp(i);
        end
        if issex,
          params{4} = sex_per_exp{i};
        end
        if isfracsex,
          params{5} = frac_sex_per_exp{i};
        end
        if isfirstframes,
          params{6} = firstframes_per_exp{i};
        end
        if isendframes,
          params{7} = endframes_per_exp{i};
        end
        [success1,msg1] = obj.AddExpDir(params{:});
        success = success && success1;
        if isempty(msg),
          msg = msg1;
        else
          msg = sprintf('%s\n%s',msg,msg1);
        end
      end

    end

    function nflies = GetNumFlies(obj,expi)
      nflies = obj.nflies_per_exp(expi);
    end
    
    % [success,msg] = GetTrxInfo(obj,expi)
    % Fills in nflies_per_exp, firstframes_per_exp, and endframes_per_exp
    % for experiment expi. This may require loading in trajectories. 
    function [success,msg] = GetTrxInfo(obj,expi,canusecache,trx)
      success = true;
      msg = '';
      if nargin < 3,
        canusecache = true;
      end
      istrxinput = nargin >= 4;
      
      obj.SetStatus('Reading trx info for experiment %s',obj.expdirs{expi});
      if numel(obj.nflies_per_exp) < expi || ...
          numel(obj.sex_per_exp) < expi || ...
          numel(obj.frac_sex_per_exp) < expi || ...
          numel(obj.firstframes_per_exp) < expi || ...
          numel(obj.endframes_per_exp) < expi || ...
          isnan(obj.nflies_per_exp(expi)),
        if ~istrxinput,

          trxfile = fullfile(obj.expdirs{expi},obj.GetFileName('trx'));
          if ~exist(trxfile,'file'),
            msg = sprintf('Trx file %s does not exist, cannot count flies',trxfile);
            success = false;
          else
          
            if isempty(obj.expi) || obj.expi == 0,
              % TODO: make this work for multiple flies
              obj.PreLoad(expi,1);
              trx = obj.trx;
            elseif canusecache && expi == obj.expi,
              trx = obj.trx;
            else
%               try
                % REMOVE THIS
                global CACHED_TRX; %#ok<TLEV>
                global CACHED_TRX_EXPNAME; %#ok<TLEV>
                if isempty(CACHED_TRX) || isempty(CACHED_TRX_EXPNAME) || ...
                    ~strcmp(obj.expnames{expi},CACHED_TRX_EXPNAME),
                  hwait = mywaitbar(0,sprintf('Loading trx to determine number of flies for %s',obj.expnames{expi}),'interpreter','none');
                  trx = load_tracks(trxfile);
                  if ishandle(hwait), delete(hwait); end
                  CACHED_TRX = trx;
                  CACHED_TRX_EXPNAME = obj.expnames{expi};
                else
                  fprintf('DEBUG: Using CACHED_TRX. REMOVE THIS\n');
                  trx = CACHED_TRX;
                end
%               catch ME,
%                 msg = sprintf('Could not load trx file for experiment %s to count flies: %s',obj.expdirs{expi},getReport(ME));
%               end
            end
          end
        end
        obj.nflies_per_exp(expi) = numel(trx);
        obj.firstframes_per_exp{expi} = [trx.firstframe];
        obj.endframes_per_exp{expi} = [trx.endframe];

        obj.hassex = obj.hassex || isfield(trx,'sex');
        
        % store sex info
        tmp = repmat({nan},[1,numel(trx)]);
        obj.frac_sex_per_exp{expi} = struct('M',tmp,'F',tmp);
        obj.sex_per_exp{expi} = repmat({'?'},[1,numel(trx)]);
        if isfield(trx,'sex'),
          if numel(trx) > 1,
            obj.hasperframesex = iscell(trx(1).sex);
          end
          if obj.hasperframesex,
            for fly = 1:numel(trx),
              n = numel(trx(fly).sex);
              nmale = nnz(strcmpi(trx(fly).sex,'M'));
              nfemale = nnz(strcmpi(trx(fly).sex,'F'));
              obj.frac_sex_per_exp{expi}(fly).M = nmale/n;
              obj.frac_sex_per_exp{expi}(fly).F = nfemale/n;
              if nmale > nfemale,
                obj.sex_per_exp{expi}{fly} = 'M';
              elseif nfemale > nmale,
                obj.sex_per_exp{expi}{fly} = 'F';
              else
                obj.sex_per_exp{expi}{fly} = '?';
              end
            end
          else
            for fly = 1:numel(trx),
              obj.sex_per_exp{expi}{fly} = trx(fly).sex;
              if strcmpi(trx(fly).sex,'M'),
                obj.frac_sex_per_exp{expi}(fly).M = 1;
                obj.frac_sex_per_exp{expi}(fly).F = 0;
              elseif strcmpi(trx(fly).sex,'F'),
                obj.frac_sex_per_exp{expi}(fly).M = 0;
                obj.frac_sex_per_exp{expi}(fly).F = 1;
              end
            end
          end
        end
      end
      obj.ClearStatus();
      
    end
    
    % [success,msg] = AddExpDir(obj,expdir,outexpdir,nflies_per_exp,firstframes_per_exp,endframes_per_exp)
    % Add a new experiment to the GUI. If this is the first experiment,
    % then it will be preloaded. 
    function [success,msg] = AddExpDir(obj,expdir,outexpdir,nflies_per_exp,sex_per_exp,frac_sex_per_exp,firstframes_per_exp,endframes_per_exp)

      success = false; msg = '';
      
      if isnumeric(expdir), return; end
      
      if nargin < 2,
        error('Usage: obj.AddExpDirs(expdir,[outexpdir],[nflies_per_exp])');
      end

      % make sure directory exists
      if ~exist(expdir,'file'),
        msg = sprintf('expdir %s does not exist',expdir);
        return;
      end
      
      isoutexpdir = nargin > 2 && ~isnumeric(outexpdir);
      istrxinfo = nargin > 7 && ~isempty(nflies_per_exp);

      % base name
      [~,expname] = myfileparts(expdir);
      
      % expnames and rootoutputdir must match
      if isoutexpdir,
        [rootoutputdir,outname] = myfileparts(outexpdir); %#ok<*PROP>
        if ~strcmp(expname,outname),
          msg = sprintf('expdir and outexpdir do not match base names: %s ~= %s',expname,outname);
          return;
        end
        if ischar(obj.rootoutputdir) && ~strcmp(rootoutputdir,obj.rootoutputdir),
          msg = sprintf('Inconsistent root output directory: %s ~= %s',rootoutputdir,obj.rootoutputdir);
          return;
        end
      elseif ~ischar(obj.rootoutputdir),
        outexpdir = expdir;
        rootoutputdir = 0;
      else
        rootoutputdir = obj.rootoutputdir;        
      end
      
      if ischar(obj.rootoutputdir) && ~isoutexpdir,
        outexpdir = fullfile(rootoutputdir,expname);
      end
      
      % create missing outexpdirs
      if ~exist(outexpdir,'dir'),
        [success1,msg1] = mkdir(rootoutputdir,expname);
        if ~success1,
          msg = (sprintf('Could not create output directory %s, failed to set expdirs: %s',outexpdir,msg1));
          return;
        end
      end

      % create clips dir
      clipsdir = obj.GetFileName('clipsdir');
      outclipsdir = fullfile(outexpdir,clipsdir);
      if ~exist(outclipsdir,'dir'),
        [success1,msg1] = mkdir(outexpdir,clipsdir);
        if ~success1,
          msg = (sprintf('Could not create output clip directory %s, failed to set expdirs: %s',outclipsdir,msg1));
          return;
        end
      end

      % okay, checks succeeded, start storing stuff
      obj.nexps = obj.nexps + 1;
      obj.expdirs{end+1} = expdir;
      obj.expnames{end+1} = expname;
      obj.rootoutputdir = rootoutputdir;
      obj.outexpdirs{end+1} = outexpdir;
      
      % load labels for this experiment
      [success1,msg] = obj.LoadLabelsFromFile(obj.nexps);
      if ~success1,
        obj.RemoveExpDirs(obj.nexps);
        return;
      end

      % preload this experiment if this is the first experiment added
      if obj.nexps == 1,
        % TODO: make this work with multiple flies
        obj.PreLoad(obj.nexps,1);
      end
      
      
      % get trxinfo
      if istrxinfo,
        obj.nflies_per_exp(end+1) = nflies_per_exp;
        obj.sex_per_exp{end+1} = sex_per_exp;
        obj.frac_sex_per_exp{end+1} = frac_sex_per_exp;
        obj.firstframes_per_exp{end+1} = firstframes_per_exp;
        obj.endframes_per_exp{end+1} = endframes_per_exp;
        
        if obj.nexps == 1 % This will set hassex and hasperframesex.
          [success1,msg1] = obj.GetTrxInfo(obj.nexps,true,obj.trx);
          if ~success1,
            msg = sprintf('Error getting basic trx info: %s',msg1);
            obj.RemoveExpDirs(obj.nexps);
            return;
          end
        end
        
      else
        obj.nflies_per_exp(end+1) = nan;
        obj.sex_per_exp{end+1} = {};
        obj.frac_sex_per_exp{end+1} = struct('M',{},'F',{});
        obj.firstframes_per_exp{end+1} = [];
        obj.endframes_per_exp{end+1} = [];
        [success1,msg1] = obj.GetTrxInfo(obj.nexps);
        if ~success1,
          msg = sprintf('Error getting basic trx info: %s',msg1);
          obj.RemoveExpDirs(obj.nexps);
          return;
        end
      end
      
      [success1,msg1] = obj.UpdateStatusTable('',obj.nexps);
      if ~success1,
        msg = msg1;
        obj.RemoveExpDirs(obj.nexps);
        return;
      end
      
      
      % save default path
      obj.defaultpath = expdir;
      
      success = true;
      
    end
   
    % [success,msg] = RemoveExpDirs(obj,expi)
    % Removes experiments in expi from the GUI. If the currently loaded
    % experiment is removed, then a different experiment may be preloaded. 
    function [success,msg] = RemoveExpDirs(obj,expi)
      
      success = false;
      msg = '';
      
      if any(obj.nexps < expi) || any(expi < 1),
        msg = sprintf('expi = %s must be in the range 1 < expi < nexps = %d',mat2str(expi),obj.nexps);
        return;
      end

      obj.expdirs(expi) = [];
      obj.expnames(expi) = [];
      obj.outexpdirs(expi) = [];
      obj.nflies_per_exp(expi) = [];
      obj.sex_per_exp(expi) = [];
      obj.frac_sex_per_exp(expi) = [];
      obj.firstframes_per_exp(expi) = [];
      obj.endframes_per_exp(expi) = [];
      obj.nexps = obj.nexps - numel(expi);
      obj.labels(expi) = [];
      obj.labelstats(expi) = [];
      % TODO: exp2labeloff

      % update current exp, flies
      if ~isempty(obj.expi) && obj.expi > 0 && ismember(obj.expi,expi),
        
        % change to different experiment, by default choose fly 1
        % TODO: allow for more than one fly to be selected at once
        obj.expi = 0;
        obj.flies = nan(size(obj.flies));
        % TODO: may want to save labels somewhere before just overwriting
        % labelidx
        if obj.nexps > 0,
          obj.PreLoad(obj.nexps,1);
        end

      end
      
      % TODO: windowdata_labeled, etc
      
      success = true;
      
    end

    % res = GetFileName(obj,file)
    % Get base name of file of the input type file.
    function res = GetFileName(obj,file)
      switch file,
        case 'movie',
          res = obj.moviefilename;
        case 'trx',
          res = obj.trxfilename;
        case 'label',
          res = obj.labelfilename;
%         case 'window',
%           res = obj.windowfilename;
        case {'perframedir','perframe'},
          res = obj.perframedir;
        case {'clipsdir','clips'},
          res = obj.clipsdir;
        otherwise
          error('Unknown file type %s',file);
      end
    end
    
    % [filename,timestamp] = GetFile(obj,file,expi)
    % Get the full path to the file of type file for experiment expi. 
    function [filename,timestamp] = GetFile(obj,file,expi,dowrite)
      
      if nargin < 4,
        dowrite = false;
      end
      
      % base name
      fn = obj.GetFileName(file);
      
      % if this is an output file, only look in output experiment directory
      if dowrite && JLabelData.IsOutputFile(file),
        expdirs_try = obj.outexpdirs(expi);
      else
        % otherwise, first look in output directory, then look in input
        % directory
        expdirs_try = {obj.outexpdirs{expi},obj.expdirs{expi}};
      end
      
      % initialize timestamp = -inf if we never set
      timestamp = -inf;

      % loop through directories to look in
      for j = 1:numel(expdirs_try),
        expdir = expdirs_try{j}; 
        
        % are there per-fly files?
        if JLabelData.IsPerFlyFile(file),
          
          % if per-fly, then there will be one file per fly
          filename = cell(1,obj.nflies_per_exp(expi));
          [~,name,ext] = fileparts(fn);
          file_exists = true;
          for fly = 1:obj.nflies_per_exp(expi),
            filename{fly} = fullfile(expdir,sprintf('%s_fly%02d%s',name,fly,ext));
          end
          
          % check this directory, get timestamp
          timestamp = -inf;
          for fly = 1:obj.nflies_per_exp(expi),
            % doesn't exist? then just return timestamp = -inf
            if ~exist(filename{fly},'file');
              file_exists = false;
              timestamp = -inf;
              break;
            end
            tmp = dir(filename{fly});
            timestamp = max(tmp.datenum,timestamp);
          end
          
          % file exists? then don't search next directory
          if file_exists,
            break;
          end
          
        else
          
          % just one file to look for
          filename = fullfile(expdir,fn);
          if exist(filename,'file'),
            tmp = dir(filename);
            timestamp = tmp.datenum;
            break;
          end
          
        end
        
      end
      
    end
    
    % [success,msg] = GenerateMissingFiles(obj,expi)
    % Generate required, missing files for experiments expi. 
    % TODO: implement this!
    function [success,msg] = GenerateMissingFiles(obj,expi)
      
      success = true;
      msg = '';
      
      for i = 1:numel(obj.filetypes),
        file = obj.filetypes{i};
        if obj.IsRequiredFile(file) && obj.CanGenerateFile(file) && ...
            ~obj.FileExists(file,expi),
          fprintf('Generating %s for %s...\n',file,obj.expnames{expi});
          switch file,
%             case 'window',
%               [success1,msg1] = obj.GenerateWindowFeaturesFiles(expi);
%               success = success && success1;
%               if ~success1,
%                 msg = [msg,'\n',msg1]; %#ok<AGROW>
%               end
            case 'perframedir',
              [success1,msg1] = obj.GeneratePerFrameFiles(expi);
              success = success && success1;
              if ~success1,
                msg = [msg,'\n',msg1]; %#ok<AGROW>
              end
          end
        end
      end
      [success1,msg1] = obj.UpdateStatusTable();
      success = success && success1;
      if isempty(msg),
        msg = msg1;
      else
        msg = sprintf('%s\n%s',msg,msg1);
      end
      
    end
    
    function [success,msg] = GeneratePerFrameFiles(obj,expi)
      success = false; %#ok<NASGU>
      msg = '';
      
      perframedir = obj.GetFile('perframedir',expi);
      if exist(perframedir,'dir'),
        res = questdlg('Do you want to overwrite existing files or keep them?',...
          'Regenerate files?','Overwrite','Keep','Keep');
        dooverwrite = strcmpi(res,'Overwrite');
      else
        dooverwrite = true;
      end
      expdir = obj.expdirs{expi};
      
      hwait = mywaitbar(0,sprintf('Initializing perframe directory for %s',expdir),'interpreter','none');

      perframetrx = Trx('trxfilestr',obj.GetFileName('trx'),...
        'moviefilestr',obj.GetFileName('movie'),...
        'perframedir',obj.GetFileName('perframedir'),...
        'landmark_params',obj.landmark_params,...
        'perframe_params',obj.perframe_params,...
        'rootwritedir',obj.rootoutputdir);
      
      perframetrx.AddExpDir(expdir,'dooverwrite',dooverwrite);
      
      for i = 1:numel(obj.perframefns),
        fn = obj.perframefns{i};
        file = fullfile(perframedir,[fn,'.mat']);
        if ~dooverwrite && exist(file,'file'),
          continue;
        end
        hwait = mywaitbar(i/numel(obj.perframefns),hwait,sprintf('Computing %s and saving to file %s',fn,file));
        perframetrx.(fn); %#ok<VUNUS>
          
      end
      
      if ishandle(hwait),
        delete(hwait);
      end
      
      success = true;
      
    end
    
    % [success,msg] = SetFeatureParamsFileName(obj,featureparamsfilename)
    % Sets the name of the file describing the features to use to
    % featureparamsfilename. These parameters are read in. Currently, the
    % window data and classifier, predictions are not changed. (TODO)
    function [success,msg] = SetFeatureParamsFileName(obj,featureparamsfilename)
      success = false;
      msg = '';
      
      if ischar(obj.featureparamsfilename) && strcmp(featureparamsfilename,obj.featureparamsfilename),
        success = true;
        return;
      end
      
      if obj.nexps > 0,
        msg = 'Currently, feature params file can only be changed when no experiments are loaded';
        return;
      end
%       try
        [windowfeaturesparams,windowfeaturescellparams] = ...
          ReadPerFrameParams(featureparamsfilename); %#ok<PROP>
%       catch ME,
%         msg = sprintf('Error reading feature parameters file %s: %s',...
%           params.featureparamsfilename,getReport(ME));
%         return;
%       end
      obj.SetPerframeParams(windowfeaturesparams,windowfeaturescellparams); %#ok<PROP>
      obj.featureparamsfilename = featureparamsfilename;
      obj.perframefns = fieldnames(obj.windowfeaturescellparams);
      if numel(obj.perframedata) ~= numel(obj.perframefns),
        obj.perframedata = cell(1,numel(obj.perframefns));
        obj.perframeunits = cell(1,numel(obj.perframefns));
      end
      success = true;
    end
    
    function SetPerframeParams(obj,windowfeaturesparams,windowfeaturescellparams)
      obj.windowfeaturesparams = windowfeaturesparams; %#ok<PROP>
      obj.windowfeaturescellparams = windowfeaturescellparams; %#ok<PROP>
    end  
    
    function [windowfeaturesparams,windowfeaturescellparams] = GetPerframeParams(obj)
      windowfeaturesparams = obj.windowfeaturesparams; %#ok<PROP>
      windowfeaturescellparams = obj.windowfeaturescellparams; %#ok<PROP>
    end  
    
    function perframeFeatures = GetAllPerframeFeatures(obj)
    % Finds all the *.mat in perframe directory. 
    % TODO: Better way to find the list of all the perframe features
      
      if isempty(obj.expi),
        perframeFeatures = {};
        return;
      end
      
      pfdir = fullfile(obj.expdirs{1},obj.GetFileName('perframedir'));
      pfList = dir(fullfile(pfdir,'*.mat'));
      for ndx = 1:numel(pfList)
        perframeFeatures{ndx} = pfList(ndx).name(1:end-4);
      end
      
    end
    
    % [filenames,timestamps] = GetPerFrameFiles(obj,file,expi)
    % Get the full path to the per-frame mat files for experiment expi
    function [filenames,timestamps] = GetPerframeFiles(obj,expi,dowrite)
      
      if nargin < 3,
        dowrite = false;
      end
      
      fn = obj.GetFileName('perframedir');
      
      % if this is an output file, only look in output experiment directory
      if dowrite && JLabelData.IsOutputFile('perframedir'),
        expdirs_try = obj.outexpdirs(expi);
      else
        % otherwise, first look in output directory, then look in input
        % directory
        expdirs_try = {obj.outexpdirs{expi},obj.expdirs{expi}};
      end
      
      filenames = cell(1,numel(obj.perframefns));
      timestamps = -inf(1,numel(obj.perframefns));
      
      for i = 1:numel(obj.perframefns),

        % loop through directories to look in
        for j = 1:numel(expdirs_try),
          expdir = expdirs_try{j};
          filename = fullfile(expdir,fn,[obj.perframefns{i},'.mat']);
          
          if exist(filename,'file'),
            filenames{i} = filename;
            tmp = dir(filename);
            timestamps(i) = tmp.datenum;
          elseif j == 1,
            filenames{i} = filename;
          end
          
        end
      end
    end
    
    % [success,msg] = UpdateStatusTable(obj,filetypes,expis)
    % Update the tables of what files exist for what experiments. This
    % returns false if all files were in existence or could be generated
    % and now they are/can not. 
    function [success,msg] = UpdateStatusTable(obj,filetypes,expis)

      msg = '';
      success = false;

      if nargin > 1 && ~isempty(filetypes),
        [ism,fileis] = ismember(filetypes,obj.filetypes);
        if any(~ism),
          msg = 'Unknown filetypes';
          return;
        end
      else
        fileis = 1:numel(obj.filetypes);
      end
      if nargin <= 2 || isempty(expis),
        expis = 1:obj.nexps;
      end
      
      % initialize fileexists table
      obj.fileexists(expis,fileis) = false;
      obj.filetimestamps(expis,fileis) = nan;
      
      
      % loop through all file types
      for filei = fileis,
        file = obj.filetypes{filei};
        % loop through experiments
        for expi = expis,
          
          if strcmpi(file,'perframedir'),
            [fn,timestamps] = obj.GetPerframeFiles(expi);
            obj.fileexists(expi,filei) = all(cellfun(@(s) exist(s,'file'),fn));
            obj.filetimestamps(expi,filei) = max(timestamps);
          else
          
            % check for existence of current file(s)
            [fn,obj.filetimestamps(expi,filei)] = obj.GetFile(file,expi);
            if iscell(fn),
              obj.fileexists(expi,filei) = all(cellfun(@(s) exist(s,'file'),fn));
            else
              obj.fileexists(expi,filei) = exist(fn,'file');
            end
            
          end
          
        end
      end

      % store old values to see if latest change broke something
      old_filesfixable = obj.filesfixable;
      old_allfilesexist = obj.allfilesexist;

      % initialize summaries to true
      obj.filesfixable = true;
      obj.allfilesexist = true;

      for filei = 1:numel(obj.filetypes),
        file = obj.filetypes{filei};
        % loop through experiments
        for expi = 1:obj.nexps,
          
          % if file doesn't exist and is required, then not all files exist
          if ~obj.fileexists(expi,filei),
            if JLabelData.IsRequiredFile(file),
              obj.allfilesexist = false;
              % if furthermore file can't be generated, then not fixable
              if ~JLabelData.CanGenerateFile(file),
                obj.filesfixable = false;                
                msg1 = sprintf('%s missing and cannot be generated.',fn);
                if isempty(msg),
                  msg = msg1;
                else
                  msg = sprintf('%s\n%s',msg,msg1);
                end
              end
            end
          end
          
        end
      end

      % fail if was ok and now not ok
      success = ~(old_allfilesexist || old_filesfixable) || ...
        (obj.allfilesexist || obj.filesfixable);
      
    end

    % [fe,ft] = FileExists(obj,file,expi)
    % Returns whether the input file exists for the input experiment. 
    function [fe,ft] = FileExists(obj,file,expi)
      filei = find(strcmpi(file,obj.filetypes),1);
      if isempty(filei),
        error('file type %s does not match any known file type',file);
      end
      if nargin < 3,
        expi = 1:obj.nexps;
      end
      fe = obj.fileexists(expi,filei);
      ft = obj.filetimestamps(expi,filei);
    end

    % A generic function that return track info.
    function out = GetTrxValues(obj,infoType,expi,flies,ts)

      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,1);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end

      if nargin < 4,     % No flies given
        switch infoType
          case 'Trx'
            out = obj.trx;
          case 'X'
            out = {obj.trx.x};
          case 'Y'
            out = {obj.trx.y};
          case 'A'
            out = {obj.trx.a};
          case 'B'
            out = {obj.trx.b};
          case 'Theta'
            out = {obj.trx.theta};
          otherwise
            error('Incorrect infotype requested from GetTrxValues with less than 4 arguments');
        end
        return;

      
      elseif nargin < 5, % No ts given
        switch infoType
          case 'Trx'
            out = obj.trx(flies);
          case 'X'
            out = {obj.trx(flies).x};
          case 'Y'
            out = {obj.trx(flies).y};
          case 'A'
            out = {obj.trx(flies).a};
          case 'B'
            out = {obj.trx(flies).b};
          case 'Theta'
            out = {obj.trx(flies).theta};
          case 'X1'
            out = [obj.trx(flies).x];
          case 'Y1'
            out = [obj.trx(flies).y];
          case 'A1'
            out = [obj.trx(flies).a];
          case 'B1'
            out = [obj.trx(flies).b];
          case 'Theta1'
            out = [obj.trx(flies).theta];
          otherwise
            error('Incorrect infotype requested from GetTrxValues');
        end
        return
      else               % Everything is given
        nflies = numel(flies);
        fly = flies(1);
        switch infoType
          case 'Trx'
            c = cell(1,nflies);
            trx = struct('x',c,'y',c,'a',c,'b',c,'theta',c,'ts',c,'firstframe',c,'endframe',c);
            for i = 1:numel(flies),
              fly = flies(i);
              js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
              trx(i).x = obj.trx(fly).x(js);
              trx(i).y = obj.trx(fly).y(js);
              trx(i).a = obj.trx(fly).a(js);
              trx(i).b = obj.trx(fly).b(js);
              trx(i).theta = obj.trx(fly).theta(js);
              trx(i).ts = js-obj.trx(fly).off;
              trx(i).firstframe = trx(i).ts(1);
              trx(i).endframe = trx(i).ts(end);
            end
            out = trx;
          case 'X'
            x = cell(1,nflies);
            for i = 1:numel(flies),
              fly = flies(i);
              js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
              x{i} = obj.trx(fly).x(js);
            end
            out = x;
          case 'Y'
            x = cell(1,nflies);
            for i = 1:numel(flies),
              fly = flies(i);
              js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
              x{i} = obj.trx(fly).y(js);
            end
            out = x;
          case 'A'
            x = cell(1,nflies);
            for i = 1:numel(flies),
              fly = flies(i);
              js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
              x{i} = obj.trx(fly).a(js);
            end
            out = x;
          case 'B'
            x = cell(1,nflies);
            for i = 1:numel(flies),
              fly = flies(i);
              js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
              x{i} = obj.trx(fly).b(js);
            end
            out = x;
          case 'Theta'
            x = cell(1,nflies);
            for i = 1:numel(flies),
              fly = flies(i);
              js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
              x{i} = obj.trx(fly).theta(js);
            end
            out = x;
          case 'X1'
            out = obj.trx(fly).x(ts + obj.trx(fly).off);
          case 'Y1'
            out = obj.trx(fly).y(ts + obj.trx(fly).off);
          case 'A1'
            out = obj.trx(fly).a(ts + obj.trx(fly).off);
          case 'B1'
            out = obj.trx(fly).b(ts + obj.trx(fly).off);
          case 'Theta1'
            out = obj.trx(fly).theta(ts + obj.trx(fly).off);
          otherwise
            error('Incorrect infotype requested from GetTrxValues');
         end
      end
      
    end
    
    
    % [x,y,theta,a,b] = GetTrxPos1(obj,expi,fly,ts)
    % Returns the position for the input experiment, SINGLE fly, and
    % frames. If ts is not input, then all frames are returned. 
    function pos = GetTrxPos1(obj,expi,fly,ts)

      pos = struct;
      
      if all(expi ~= obj.expi),
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,fly);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end

      switch obj.targettype,

        case 'fly',

          if nargin < 4,
            pos.x = obj.trx(fly).x;
            pos.y = obj.trx(fly).y;
            pos.theta = obj.trx(fly).theta;
            pos.a = obj.trx(fly).a;
            pos.b = obj.trx(fly).b;
            return;
          end
          
          pos.x = obj.trx(fly).x(ts + obj.trx(fly).off);
          pos.y = obj.trx(fly).y(ts + obj.trx(fly).off);
          pos.theta = obj.trx(fly).theta(ts + obj.trx(fly).off);
          pos.a = obj.trx(fly).a(ts + obj.trx(fly).off);
          pos.b = obj.trx(fly).b(ts + obj.trx(fly).off);
         
        case 'larva',
          
          if nargin < 4,
            pos.x = obj.trx(fly).x;
            pos.y = obj.trx(fly).y;
            pos.skeletonx = obj.trx(fly).skeletonx;
            pos.skeletony = obj.trx(fly).skeletony;
            return;
          end
          
          pos.x = obj.trx(fly).x(ts + obj.trx(fly).off);
          pos.y = obj.trx(fly).y(ts + obj.trx(fly).off);
          pos.skeletonx = obj.trx(fly).skeletonx(:,ts + obj.trx(fly).off);
          pos.skeletony = obj.trx(fly).skeletony(:,ts + obj.trx(fly).off);
          
      end
    end

    % x = GetSex(obj,expi,fly,ts)
    % Returns the sex for the input experiment, SINGLE fly, and
    % frames. If ts is not input, then all frames are returned. 
    function sex = GetSex(obj,expi,fly,ts,fast)

      if ~obj.hassex,
        sex = '?';
        return;
      end
      
      if nargin < 5,
        fast = false;
      end
      
      if ~obj.hasperframesex || fast,
        sex = obj.sex_per_exp{expi}(fly);
        return;
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,fly);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end
      
      if nargin < 4,
        sex = obj.trx(fly).sex;
        return;
      end
      
      sex = obj.trx(fly).sex(ts + obj.trx(fly).off);

    end

    % x = GetSex1(obj,expi,fly,t)
    % Returns the sex for the input experiment, SINGLE fly, and
    % SINGLE frame. 
    function sex = GetSex1(obj,expi,fly,t)

      if ~obj.hassex,
        sex = '?';
        return;
      end
            
      if ~obj.hasperframesex,
        sex = obj.sex_per_exp{expi}(fly);
        if iscell(sex),
          sex = sex{1};
        end
        return;
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,fly);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end
            
      sex = obj.trx(fly).sex{t + obj.trx(fly).off};

    end
    
    % x = GetSexFrac(obj,expi,fly)
    % Returns a struct indicating the fraction of frames for which the sex
    % of the fly is M, F
    function sexfrac = GetSexFrac(obj,expi,fly)

      sexfrac = obj.frac_sex_per_exp{expi}(fly);

    end

    
    % t0 = GetTrxFirstFrame(obj,expi,flies)
    % Returns the firstframes for the input experiment and flies. If flies
    % is not input, then all flies are returned. 
    function t0 = GetTrxFirstFrame(obj,expi,flies)

      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if nargin < 3,
        t0 = obj.firstframes_per_exp{expi};
        return;
      end

      t0 = obj.firstframes_per_exp{expi}(flies);
      
    end

    % t1 = GetTrxEndFrame(obj,expi,flies)
    % Returns the endframes for the input experiment and flies. If flies
    % is not input, then all flies are returned. 
    function t1 = GetTrxEndFrame(obj,expi,flies)

      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if nargin < 3,
        t1 = obj.endframes_per_exp{expi};
        return;
      end

      t1 = obj.endframes_per_exp{expi}(flies);
      
    end

    function SetConfidenceThreshold(obj,thresholds,ndx)
      obj.confThresholds(ndx) = thresholds;
    end
    
    function thresholds = GetConfidenceThreshold(obj,ndx)
      thresholds =obj.confThresholds(ndx) ;
    end
    
    % [success,msg] = PreLoad(obj,expi,flies)
    % Preloads data associated with the input experiment and flies. If
    % neither the experiment nor flies are changing, then we do nothing. If
    % there is currently a preloaded experiment, then we store the labels
    % in labelidx into labels using StoreLabels. We then load from labels
    % into labelidx for the new experiment and flies. We load the per-frame
    % data for this experiment and flies. If this is a different
    % experiment, then we load in the trajectories for this experiment.  
    function [success,msg] = PreLoad(obj,expi,flies)
      
      success = false;
      msg = '';
      
      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end

      if numel(unique(flies)) ~= numel(flies),
        msg = 'flies must all be unique';
        return;
      end
      
      diffexpi = isempty(obj.expi) || expi ~= obj.expi;
      diffflies = diffexpi || numel(flies) ~= numel(obj.flies) || ~all(flies == obj.flies);
      % nothing to do
      if ~diffflies,
        success = true;
        return;
      end

      if ~isempty(obj.expi) && obj.expi > 0,
        % store labels currently in labelidx to labels
        obj.StoreLabels();
      end
      
      if diffexpi,
        
        % load trx
%         try
          trxfilename = obj.GetFile('trx',expi);
          
          obj.SetStatus('Loading trx for experiment %s',obj.expnames{expi});
                    
          % TODO: remove this
          global CACHED_TRX; %#ok<TLEV>
          global CACHED_TRX_EXPNAME; %#ok<TLEV>
          if isempty(CACHED_TRX) || isempty(CACHED_TRX_EXPNAME) || ...
              ~strcmp(obj.expnames{expi},CACHED_TRX_EXPNAME),
            obj.trx = load_tracks(trxfilename);
            CACHED_TRX = obj.trx;
            CACHED_TRX_EXPNAME = obj.expnames{expi};
          else
            fprintf('DEBUG: Using CACHED_TRX. REMOVE THIS\n');
            obj.trx = CACHED_TRX;
          end
          % store trx_info, in case this is the first time these trx have
          % been loaded
          [success,msg] = obj.GetTrxInfo(expi,true,obj.trx);
          if ~success,
            return;
          end
          
%         catch ME,
%           msg = sprintf('Error loading trx from file %s: %s',trxfilename,getReport(ME));
%           if ishandle(hwait),
%             delete(hwait);
%             drawnow;
%           end
%           return;
%         end
 
      end

      % set labelidx from labels
      obj.SetStatus('Caching labels for experiment %s, flies%s',obj.expnames{expi},sprintf(' %d',flies));
      [obj.labelidx,obj.t0_curr,obj.t1_curr] = obj.GetLabelIdx(expi,flies);
      obj.labelidx_off = 1 - obj.t0_curr;
      
      % load perframedata
      obj.SetStatus('Loading per-frame data for %s, flies %s',obj.expdirs{expi},mat2str(flies));
      perframedir = obj.GetFile('perframedir',expi);
      for j = 1:numel(obj.perframefns),
        fn = obj.perframefns{j};
        file = fullfile(perframedir,[fn,'.mat']);
        if ~exist(file,'file'),
          msg = sprintf('Per-frame data file %s does not exist',file);
          return;
        end
%         try
          tmp = load(file);
          obj.perframedata{j} = tmp.data{flies(1)};
          obj.perframeunits{j} = tmp.units;
%         catch ME,
%           msg = getReport(ME);
%         end
      end
      
      obj.expi = expi;
      obj.flies = flies;

      obj.UpdatePredictedIdx();
      obj.ClearStatus();
           
      success = true;
      
    end
    
    % ClearCachedPerExpData(obj)
    % Clears all cached data for the currently loaded experiment
    function ClearCachedPerExpData(obj)
      obj.trx = {};
      obj.expi = 0;
      obj.flies = nan(size(obj.flies));
      obj.perframedata = {};
      obj.labelidx = [];
      obj.labelidx_off = 0;
      obj.t0_curr = 0;
      obj.t1_curr = 0;
      obj.predictedidx = [];
      obj.scoresidx = [];
      obj.erroridx = [];
      obj.suggestedidx = [];
    end
    
    % [labelidx,T0,T1] = GetLabelIdx(obj,expi,flies)
    % Returns the labelidx for the input experiment and flies read from
    % labels. 
    function [labelidx,T0,T1] = GetLabelIdx(obj,expi,flies,T0,T1)

      if ~isempty(obj.expi) && numel(flies) == numel(obj.flies) && obj.IsCurFly(expi,flies),
        if nargin < 4,
          labelidx = obj.labelidx;
          T0 = obj.t0_curr;
          T1 = obj.t1_curr;
        else
          labelidx = obj.labelidx(T0+obj.labelidx_off:T1+obj.labelidx_off);
        end
        return;
      end
      
      if nargin < 4,
        T0 = max(obj.GetTrxFirstFrame(expi,flies));
        T1 = min(obj.GetTrxEndFrame(expi,flies));
      end
      n = T1-T0+1;
      off = 1 - T0;
      labels_curr = obj.GetLabels(expi,flies);
      labelidx = zeros(1,n);
      for i = 1:obj.nbehaviors,
        for j = find(strcmp(labels_curr.names,obj.labelnames{i})),
          t0 = labels_curr.t0s(j);
          t1 = labels_curr.t1s(j);
          if t0>T1 || t1<T0; continue;end
          t0 = max(T0,t0);
          t1 = min(T1,t1);
          labelidx(t0+off:t1-1+off) = i;
        end
      end
      
    end

    % [perframedata,T0,T1] = GetPerFrameData(obj,expi,flies,prop,T0,T1)
    % Returns the per-frame data for the input experiment, flies, and
    % property. 
    function [perframedata,T0,T1] = GetPerFrameData(obj,expi,flies,prop,T0,T1)

      if ischar(prop),
        prop = find(strcmp(prop,handles.perframefn),1);
        if isempty(prop),
          error('Property %s is not a per-frame property');
        end
      end
      
      if obj.IsCurFly(expi,flies) 
        if nargin < 5,
          perframedata = obj.perframedata{prop};
          T0 = obj.t0_curr;
          T1 = obj.t0_curr + numel(perframedata) - 1;
        else
          T0 = max(T0,obj.t0_curr);
          T1 = min(T1,obj.t0_curr+numel(obj.perframedata{prop})-1);
          i0 = T0 - obj.t0_curr + 1;
          i1 = T1 - obj.t0_curr + 1;
          perframedata = obj.perframedata{prop}(i0:i1);
        end
        return;
      end
      
      perframedir = obj.GetFile('perframedir',expi);
      tmp = load(fullfile(perframedir,[obj.perframefns{prop},'.mat']));
      if nargin < 5,
        T0 = max(obj.GetTrxFirstFrame(expi,flies));
        % TODO: generalize to multi-fly
        perframedata = tmp.data{flies(1)};
        T1 = T0 + numel(perframedata) - 1;
        return;
      end
      off = 1 - GetTrxFirstFrame(expi,flies);
      i0 = T0 + off;
      i1 = T1 + off;
      perframedata = tmp.data{flies(1)}(i0:i1);

    end

    % perframedata = GetPerFrameData1(obj,expi,flies,prop,t)
    % Returns the per-frame data for the input experiment, flies, and
    % property. 
    function perframedata = GetPerFrameData1(obj,expi,flies,prop,t)

%       if ischar(prop),
%         prop = find(strcmp(prop,handles.perframefn),1);
%         if isempty(prop),
%           error('Property %s is not a per-frame property');
%         end
%       end
      
      if ~isempty(obj.expi) && expi == obj.expi && numel(flies) == numel(obj.flies) && all(flies == obj.flies),
        is = t-obj.t0_curr+1;
        badidx = is > numel(obj.perframedata{prop});
        if any(badidx),
          perframedata = nan(size(is));
          perframedata(~badidx) = obj.perframedata{prop}(is(~badidx));
        else
          perframedata = obj.perframedata{prop}(is);
        end
        return;
      end
      
      perframedir = obj.GetFile('perframedir',expi);
      tmp = load(fullfile(perframedir,[obj.perframefns{prop},'.mat']));
      off = 1 - obj.GetTrxFirstFrame(expi,flies);
      perframedata = tmp.data{flies(1)}(t+off);

    end

    
    function [prediction,T0,T1] = GetPredictedIdx(obj,expi,flies,T0,T1)

      if ~isempty(obj.expi) && numel(flies) == numel(obj.flies) && obj.IsCurFly(expi,flies),
        if nargin < 4,
          prediction = struct('predictedidx',obj.predictedidx,...
                              'scoresidx', obj.scoresidx,...
                              'latest', obj.scoreTS>=obj.classifierTS,...
                              'isValidated', obj.isValidated);
          T0 = obj.t0_curr;
          T1 = obj.t1_curr;
        else
          prediction = struct(...
            'predictedidx', obj.predictedidx(T0+obj.labelidx_off:T1+obj.labelidx_off),...
            'scoresidx',  obj.scoresidx(T0+obj.labelidx_off:T1+obj.labelidx_off),...
            'latest', obj.scoreTS(T0+obj.labelidx_off:T1+obj.labelidx_off)>=obj.classifierTS,...
            'isValidated', obj.isValidated);          
        end
        return;
      end
      
      if nargin < 4,
        T0 = max(obj.GetTrxFirstFrame(expi,flies));
        T1 = min(obj.GetTrxEndFrame(expi,flies));
      end
      
      n = T1-T0+1;
      off = 1 - T0;
      prediction = struct('predictedidx', zeros(1,n),...
                         'scoresidx', zeros(1,n),...
                         'latest', false(1,n),...
                         'isValidated', obj.isValidated);
      
      if ~isempty(obj.scoredata.exp)                 
        idxcurr = obj.scoredata.exp == expi & all(bsxfun(@eq,obj.scoredata.flies,flies),2) &...
          obj.scoredata.t' >= T0 & obj.scoredata.t' <= T1;
        prediction.predictedidx(obj.scoredata.t(idxcurr)+off) = ...
          obj.scoredata.predicted(idxcurr);
        prediction.scoresidx(obj.scoredata.t(idxcurr)+off) = ...
          obj.scoredata.scores(idxcurr);      
        prediction.latest(obj.scoredata.t(idxcurr)+off) = ...
          obj.scoredata.timestamp(idxcurr)>=obj.classifierTS;      
      end
      
      if ~isempty(obj.windowdata.exp)
        idxcurr = obj.FlyNdx(expi,flies) & ...
          obj.windowdata.t >= T0 & obj.windowdata.t <= T1 & ...
          obj.windowdata.isvalidprediction;
        prediction.predictedidx(obj.windowdata.t(idxcurr)+off) = ...
          obj.windowdata.predicted(idxcurr);
        prediction.scoresidx(obj.windowdata.t(idxcurr)+off) = ...
          obj.windowdata.scores(idxcurr);
        prediction.latest(obj.windowdata.t(idxcurr)+off) = ...
          true;
      end
    end
    
    % [idx,T0,T1] = IsBehavior(obj,behaviori,expi,flies,T0,T1)
    % Returns whether the behavior is labeled as behaviori for experiment
    % expi, flies from frames T0 to T1. If T0 and T1 are not input, then
    % firstframe to endframe are used. 
    function [idx,T0,T1] = IsBehavior(obj,behaviori,expi,flies,T0,T1)

      if ~isempty(obj.expi) && expi == obj.expi && numel(flies) == numel(obj.flies) && all(flies == obj.flies),
        if nargin < 4,
          idx = obj.labelidx == behaviori;
          T0 = obj.t0_curr;
          T1 = obj.t1_curr;
        else
          idx = obj.labelidx(T0+obj.labelidx_off:T1+obj.labelidx_off) == behaviori;
        end
        return;
      end
      
      if nargin < 4,
        T0 = max(obj.GetTrxFirstFrame(expi,flies));
        T1 = min(obj.GetTrxEndFrame(expi,flies));
      end
      n = T1-T0+1;
      off = 1 - T0;
      labels_curr = obj.GetLabels(expi,flies);
      idx = false(1,n);
      for j = find(strcmp(labels_curr.names,obj.labelnames{behaviori})),
        t0 = labels_curr.t0s(j);
        t1 = labels_curr.t1s(j);
        idx(t0+off:t1-1+off) = true;
      end
      
    end

    % labels_curr = GetLabels(obj,expi,flies)
    % Returns the labels for the input 
    function labels_curr = GetLabels(obj,expi,flies)

      labels_curr = struct('t0s',[],'t1s',[],'names',{{}},'off',0);
      
      if nargin < 2 || isempty(expi),
        expi = obj.expi;
      end
      
      if nargin < 3 || isempty(flies),
        flies = obj.flies;
      end

      % cache these labels if current experiment and flies selected
      if expi == obj.expi && all(flies == obj.flies),
        obj.StoreLabels();
      end

      [ism,fliesi] = ismember(flies,obj.labels(expi).flies,'rows');
      if ism,
        labels_curr.t0s = obj.labels(expi).t0s{fliesi};
        labels_curr.t1s = obj.labels(expi).t1s{fliesi};
        labels_curr.names = obj.labels(expi).names{fliesi};
        labels_curr.off = obj.labels(expi).off(fliesi);
      else
%         if expi ~= obj.expi,
%           error('This should never happen -- only should get new labels for current experiment');
%         end
        t0_curr = max(obj.GetTrxFirstFrame(expi,flies));
        labels_curr.off = 1-t0_curr;
      end

      
    end

    % Store labels cached in labelidx for the current experiment and flies
    % to labels structure. This is when the timestamp on labels gets
    % updated. 
    function StoreLabels(obj)
      
      % flies not yet initialized
      if isempty(obj.flies) || all(isnan(obj.flies)) || isempty(obj.labelidx),
        return;
      end
      
      obj.StoreLabels1(obj.expi,obj.flies,obj.labelidx,obj.labelidx_off);
            
      % preload labeled window data while we have the per-frame data loaded
      ts = find(obj.labelidx~=0) - obj.labelidx_off;
      [success,msg] = obj.PreLoadWindowData(obj.expi,obj.flies,ts);
      if ~success,
        warning(msg);
      end

      % update windowdata's labelidx_new
      if ~isempty(obj.windowdata.exp),
        idxcurr = obj.windowdata.exp == obj.expi & ...
          all(bsxfun(@eq,obj.windowdata.flies,obj.flies),2);
        obj.windowdata.labelidx_new(idxcurr) = obj.labelidx(obj.windowdata.t(idxcurr)+obj.labelidx_off);
      end
      
      %obj.UpdateWindowDataLabeled(obj.expi,obj.flies);
      
    end

    function StoreLabels1(obj,expi,flies,labelidx,labelidx_off)
      
      % update labels
      newlabels = struct('t0s',[],'t1s',[],'names',{{}},'flies',[]);
      for j = 1:obj.nbehaviors,
        [i0s,i1s] = get_interval_ends(labelidx==j);
        if ~isempty(i0s),
          n = numel(i0s);
          newlabels.t0s(end+1:end+n) = i0s - labelidx_off;
          newlabels.t1s(end+1:end+n) = i1s - labelidx_off;
          newlabels.names(end+1:end+n) = repmat(obj.labelnames(j),[1,n]);
        end
      end
      [ism,j] = ismember(flies,obj.labels(expi).flies,'rows');
      if ~ism,
        j = size(obj.labels(expi).flies,1)+1;
      end
      obj.labels(expi).t0s{j} = newlabels.t0s;
      obj.labels(expi).t1s{j} = newlabels.t1s;
      obj.labels(expi).names{j} = newlabels.names;
      obj.labels(expi).flies(j,:) = flies;
      obj.labels(expi).off(j) = labelidx_off;
      obj.labels(expi).timestamp = now;

      % store labelstats
      obj.labelstats(expi).nflies_labeled = numel(unique(obj.labels(expi).flies));
      obj.labelstats(expi).nbouts_labeled = numel(newlabels.t1s);
      obj.labelstats(expi).datestr = datestr(obj.labels(expi).timestamp,'yyyymmddTHHMMSS');
            
    end

    function isstart = IsLabelStart(obj,expi,flies,ts)
      
      if obj.expi == expi && all(flies == obj.flies),
        isstart = obj.labelidx(ts+obj.labelidx_off) ~= 0 & ...
          obj.labelidx(ts+obj.labelidx_off-1) ~= obj.labelidx(ts+obj.labelidx_off);
      else
        [ism,fliesi] = ismember(flies,obj.labels(expi).flies,'rows');
        if ism,
          isstart = ismember(ts,obj.labels(expi).t0s{fliesi});
        else
          isstart = false(size(ts));
        end
      end
      
    end

    function ClearLabels(obj,expi,flies)
      
      if obj.nexps == 0,
        return;
      end
      
      timestamp = now;
      
      % use all experiments by default
      if nargin < 2,
        expi = 1:obj.nexps;
      end
      
      % delete all flies by default
      if nargin < 3,
        for i = expi(:)',
          obj.labels(expi).t0s = {};
          obj.labels(expi).t1s = {};
          obj.labels(expi).names = {};
          obj.labels(expi).flies = [];
          obj.labels(expi).off = [];
          obj.labels(expi).timestamp = [];
          obj.labelstats(expi).nflies_labeled = 0;
          obj.labelstats(expi).nbouts_labeled = 0;
          obj.labelstats(expi).datestr = datestr(timestamp,'yyyymmddTHHMMSS');
        end
      else
        if numel(expi) > 1,
          error('If flies input to ClearLabels, expi must be a single experiment');
        end
        % no labels
        if numel(obj.labels) < expi,
          return;
        end
        % which index of labels
        [~,flyis] = ismember(obj.labels(expi).flies,flies,'rows');
        for flyi = flyis(:)',
          % keep track of number of bouts so that we can update stats
          ncurr = numel(obj.labels(expi).t0s{flyi});
          obj.labels(expi).t0s{flyi} = [];
          obj.labels(expi).t1s{flyi} = [];
          obj.labels(expi).names{flyi} = {};
          obj.labels(expi).timestamp(flyi) = timestamp;
          % update stats
          obj.labelstats(expi).nflies_labeled = obj.labelstats(expi).nflies_labeled - 1;
          obj.labelstats(expi).nbouts_labeled = obj.labelstats(expi).nbouts_labeled - ncurr;
        end
        obj.labelstats(expi).datestr = datestr(timestamp,'yyyymmddTHHMMSS');
      end
      
      % clear labelidx if nec
      if ismember(obj.expi,expi) && ((nargin < 3) || ismember(obj.flies,flies,'rows')),
        obj.labelidx(:) = 0;
      end
      
      % clear windowdata labelidx_new
      for i = expi(:)',
        if nargin < 3,
          idx = obj.windowdata.exp == i;
        else
          idx = obj.windowdata.exp == i & ismember(obj.windowdata.flies,flies,'rows');
        end
        obj.windowdata.labelidx_new(idx) = 0;
        obj.UpdateErrorIdx();
      end
      
    end
    
    % SetLabel(obj,expi,flies,ts,behaviori)
    % Set label for experiment expi, flies, and frames ts to behaviori. If
    % expi, flies match current expi, flies, then we only set labelidx.
    % Otherwise, we set labels. 
    function SetLabel(obj,expi,flies,ts,behaviori)
      
      if obj.IsCurFly(expi,flies),
        obj.labelidx(ts+obj.labelidx_off) = behaviori;
      else
        [labelidx,T0] = obj.GetLabelIdx(expi,flies);
        labelidx(ts+1-T0) = behaviori;
        obj.StoreLabels1(expi,flies,labelidx,1-T0);        
      end
      
    end
    
    % Train(obj)
    % Updates the classifier to reflect the current labels. This involves
    % first loading/precomputing the training features. Then, the clasifier
    % is trained/updated. Finally, predictions for the currently loaded
    % window data are updated. Currently, the only implemented classifier is 
    % random ferns. If the classifier exists, then it is updated instead of
    % retrained from scratch. This involves three steps -- replacing labels
    % for frames which have changed label, removing examples for frames
    % which have been removed the training set, and adding new examples for
    % newly labeled frames. If the classifier has not yet been trained, it
    % is trained from scratch. 
    function Train(obj,doFastUpdates)
      
      % load all labeled data
      [success,msg] = obj.PreLoadLabeledData();
%       success = true;
%       for expi = 1:obj.nexps,
%         for i = 1:numel(obj.labels(expi).t0s),
%           flies = obj.labels(expi).flies(i,:);
%           ts = [];
%           for j = 1:numel(obj.labels(expi).t0s{i}),
%             ts = [ts,obj.labels(expi).t0s{i}(j):obj.labels(expi).t1s{i}(j)]; %#ok<AGROW>
%           end
%           ts = unique(ts);
%           [success,msg] = obj.PreLoadWindowData(expi,flies,ts);
%           if ~success,
%             break;
%           end
%         end
%       end
      if ~success,
        warning(msg);
        return;
      end

      islabeled = obj.windowdata.labelidx_new ~= 0;
      if ~any(islabeled),
        return;
      end
      
      switch obj.classifiertype,
      
        case 'ferns',
          if isempty(obj.classifier),
            
            % train classifier
            obj.SetStatus('Training fern classifier from %d examples...',numel(islabeled));

            s = struct2paramscell(obj.classifier_params);
            obj.classifier = fernsClfTrain( obj.windowdata.X(islabeled,:), obj.windowdata.labelidx_new(islabeled), s{:} );
            obj.windowdata.labelidx_old = obj.windowdata.labelidx_new;
                        
          else
            
            % new data added to windowdata at the end, so classifier.inds still
            % matches windowdata(:,1:Nprev)
            Nprev = numel(obj.windowdata.labelidx_old);
            Ncurr = numel(obj.windowdata.labelidx_new);
            waslabeled = obj.windowdata.labelidx_old(1:Nprev) ~= 0;
            islabeled = obj.windowdata.labelidx_new(1:Nprev) ~= 0;
            
            % replace labels for examples that have been relabeled:
            % islabeled & waslabeled will not change
            idx_relabel = islabeled & waslabeled & (obj.windowdata.labelidx_new(1:Nprev) ~= obj.windowdata.labelidx_old(1:Nprev));
            if any(idx_relabel),
              obj.SetStatus('Updating fern classifier for %d relabeled examples...',nnz(idx_relabel));
              [obj.classifier] = fernsClfRelabelTrainingData( obj.windowdata.labelidx_old(waslabeled), ...
                obj.windowdata.labelidx_new(waslabeled), obj.classifier );
              % update labelidx_old
              obj.windowdata.labelidx_old(idx_relabel) = obj.windowdata.labelidx_new(idx_relabel);
            end
            
            % remove training examples that were labeled but now aren't
            idx_remove = waslabeled & ~islabeled(1:Nprev);
            if any(idx_remove),
              obj.SetStatus('Removing %d training examples from fern classifier',nnz(idx_remove));
              [obj.classifier] = fernsClfRemoveTrainingData(obj.windowdata.labelidx_old(waslabeled), idx_remove(waslabeled), obj.classifier );
              % update labelidx_old
              obj.windowdata.labelidx_old(idx_remove) = 0;
            end
            % update islabeled and waslabeled
            islabeled = obj.windowdata.labelidx_new ~= 0;
            waslabeled = [obj.windowdata.labelidx_old ~= 0;false(Ncurr-Nprev,1)];
            % now only examples with islabeled should be in training set
            
            % add training examples that are labeled now but weren't before
            idx_add = ~waslabeled(islabeled);
            if any(idx_add),
              obj.SetStatus('Adding %d new examples to fern classifier...',nnz(idx_add));
              [obj.classifier] = fernsClfAddTrainingData( obj.windowdata.X(islabeled,:), ...
                obj.windowdata.labelidx_new(islabeled), find(idx_add), obj.classifier );
              % update labelidx_old
              obj.windowdata.labelidx_old(~waslabeled&islabeled) = ...
                obj.windowdata.labelidx_new(~waslabeled&islabeled);
            end
            
            % labelidx_old and new should match
            if ~all(obj.windowdata.labelidx_old == obj.windowdata.labelidx_new),
              error('Sanity check: labelidx_old and labelidx_new should match');
            end
          end
          
          obj.classifierTS = now();
          obj.windowdata.isvalidprediction(:) = false;
          obj.windowdata.scoreNorm = [];
          obj.isValidated = false;
          % predict for all window data
          obj.PredictLoaded();
          
        case 'boosting',
          oldNumPts = sum(obj.windowdata.labelidx_old ~= 0);
          newNumPts = sum(obj.windowdata.labelidx_new ~= 0);
          newData = newNumPts - oldNumPts;

          if isempty(obj.classifier) || (newData/oldNumPts)>0.3 || ~doFastUpdates,
            obj.SetStatus('Training boosting classifier from %d examples...',nnz(islabeled));

            [obj.windowdata.binVals, obj.windowdata.bins] = findThresholds(obj.windowdata.X);
            [obj.classifier, outScores] =...
                boostingWrapper( obj.windowdata.X(islabeled,:), ...
                                 obj.windowdata.labelidx_new(islabeled),obj,...
                                 obj.windowdata.binVals,...
                                 obj.windowdata.bins(:,islabeled));
            
            obj.windowdata.distNdx.exp = obj.windowdata.exp(islabeled);
            obj.windowdata.distNdx.flies = obj.windowdata.flies(islabeled);
            obj.windowdata.distNdx.t = obj.windowdata.t(islabeled);
            obj.windowdata.distNdx.labels = obj.windowdata.labelidx_new(islabeled);
          else
            tic;
            obj.SetStatus('Updating boosting classifier with %d examples...',newData);
            
            oldBinSize = size(obj.windowdata.bins,2);
            newData = size(obj.windowdata.X,1) - size(obj.windowdata.bins,2);
            if newData>0
              obj.windowdata.bins(:,end+1:end+newData) = findThresholdBins(obj.windowdata.X(oldBinSize+1:end,:),obj.windowdata.binVals);
            end
            
            
            [obj.classifier, outScores] = boostingUpdate(obj.windowdata.X(islabeled,:),...
                                          obj.windowdata.labelidx_new(islabeled),...
                                          obj.classifier,obj.windowdata.binVals,...
                                          obj.windowdata.bins(:,islabeled));
            toc;
          end
          obj.classifierTS = now();
          obj.windowdata.labelidx_old = obj.windowdata.labelidx_new;
          obj.windowdata.scoreNorm = [];
          % To later find out where each example came from.

          obj.windowdata.predicted = zeros(numel(islabeled),1);
          obj.windowdata.predicted(islabeled) = -sign(outScores)*0.5+1.5;
          
          obj.windowdata.scores = zeros(numel(islabeled),1);
          obj.windowdata.scores(islabeled) = outScores;
          obj.windowdata.isvalidprediction(islabeled) = true;
          obj.windowdata.isvalidprediction(~islabeled) = false;
          
          obj.PredictLoaded();
      end

      obj.ClearStatus();
      
      % all predictions invalid now
      
    end

    function crossError = CrossValidate(obj)
      [success,msg] = obj.PreLoadLabeledData();
      
      if ~success, warning(msg);return;end

      islabeled = obj.windowdata.labelidx_new ~= 0;

      if ~any(islabeled),                        return; end
      if ~strcmp(obj.classifiertype,'boosting'); return; end

      obj.SetStatus('Cross validating the classifier for %d examples...',nnz(islabeled));
      
      oldBinSize = size(obj.windowdata.bins,2);
      newData = size(obj.windowdata.X,1) - size(obj.windowdata.bins,2);
      if newData>0 && ~isempty(obj.windowdata.binVals)
        obj.windowdata.bins(:,end+1:end+newData) = findThresholdBins(obj.windowdata.X(oldBinSize+1:end,:),obj.windowdata.binVals);
      else
        [obj.windowdata.binVals, obj.windowdata.bins] = findThresholds(obj.windowdata.X);
      end
      
      [crossError,crossScores]=...
        crossValidate( obj.windowdata.X(islabeled,:), ...
        obj.windowdata.labelidx_new(islabeled),obj,...
        obj.windowdata.binVals,...
        obj.windowdata.bins(:,islabeled));
      
      obj.windowdata.predicted(islabeled) = -sign(crossScores)*0.5+1.5;
      obj.windowdata.scores(islabeled) = crossScores;
      obj.windowdata.isvalidprediction(islabeled) = true;
      obj.isValidated = true;
      obj.ClearStatus();
    end
      
    
    function DoBagging(obj)
      [success,msg] = obj.PreLoadLabeledData();
      
      if ~success, warning(msg);return;end

      islabeled = obj.windowdata.labelidx_new ~= 0;

      if ~any(islabeled),                        return; end
      if ~strcmp(obj.classifiertype,'boosting'); return; end
      if isempty(obj.classifier), obj.Train;             end

      obj.SetStatus('Bagging the classifier for %d examples...',nnz(islabeled));
      
      oldBinSize = size(obj.windowdata.bins,2);
      newData = size(obj.windowdata.X,1) - size(obj.windowdata.bins,2);
      if newData>0 && ~isempty(obj.windowdata.binVals)
        obj.windowdata.bins(:,end+1:end+newData) = findThresholdBins(obj.windowdata.X(oldBinSize+1:end,:),obj.windowdata.binVals);
      else
        [obj.windowdata.binVals, obj.windowdata.bins] = findThresholds(obj.windowdata.X);
      end
      
      [obj.bagModels, obj.distMat] =...
        doBagging( obj.windowdata.X(islabeled,:), ...
        obj.windowdata.labelidx_new(islabeled),obj,...
        obj.windowdata.binVals,...
        obj.windowdata.bins(:,islabeled));
      
      obj.windowdata.distNdx.exp = obj.windowdata.exp(islabeled);
      obj.windowdata.distNdx.flies = obj.windowdata.flies(islabeled);
      obj.windowdata.distNdx.t = obj.windowdata.t(islabeled);
      obj.windowdata.distNdx.labels = obj.windowdata.labelidx_new(islabeled);
      
      obj.ClearStatus();
    end
    
    function InitSimilarFrames(obj)
      obj.frameFig = showSimilarFrames;
      showSimilarFrames('SetJLabelData',obj.frameFig,obj);
      showSimilarFrames('CacheTracksLabeled',obj.frameFig);
    end
    
    function SimilarFrames(obj,curTime)

      
      if isempty(obj.frameFig), obj.InitSimilarFrames(), end
      
      distNdx = find( (obj.windowdata.distNdx.exp == obj.expi) & ...
        (obj.windowdata.distNdx.flies == obj.flies) & ...
        (obj.windowdata.distNdx.t == curTime) ,1);
      
      windowNdx = find( (obj.windowdata.exp == obj.expi) & ...
        (obj.windowdata.flies == obj.flies) & ...
        (obj.windowdata.t == curTime) ,1);


      if isempty(distNdx) % The example was not part of the training data.
        outOfTraining = 1;
        curX = obj.windowdata.X(windowNdx,:);
        curD = zeros(1,length(obj.bagModels)*length(obj.bagModels{1}));
        count = 1;
        for bagNo = 1:length(obj.bagModels)
          curModel = obj.bagModels{bagNo};
          for j = 1:length(curModel)
            curWk = curModel(j);
            dd = curX(curWk.dim)*curWk.dir;
            tt = curWk.tr*curWk.dir;
            curD(count) = (dd>tt)*curWk.alpha;
            count = count+1;
          end
        end
      else
        outOfTraining = 0;
        curD = obj.distMat(distNdx,:);
      end

      % Compute the distance 
      diffMat = zeros(size(obj.distMat));
      for ndx = 1:size(diffMat,2);
        diffMat(:,ndx) = abs(obj.distMat(:,ndx)-curD(ndx));
      end
      dist2train = nanmean(diffMat,2)*200;
      [rr rrNdx] = sort(dist2train,'ascend');
      
      if~outOfTraining
        rr = rr(2:end);
        curEx = rrNdx(1); rrNdx = rrNdx(2:end);
      else
        curEx = [];
      end
      
      % Find 5 closest pos and neg examples.
      % This looks complicated then it should be.
      % DEBUG: find values of actual labels 
     
      trainLabels =  obj.windowdata.distNdx.labels;
      allPos = rrNdx(trainLabels(rrNdx)>1.5);
      allNeg = rrNdx(trainLabels(rrNdx)<1.5);
      
      
      curP = zeros(1,5);
      curN = zeros(1,5);
      count = 0;
      for ex = allPos'
        if count>4; break; end;
        isClose = 0;
        if obj.windowdata.exp(windowNdx) == obj.windowdata.distNdx.exp(ex) &&...
           obj.windowdata.flies(windowNdx) == obj.windowdata.distNdx.flies(ex) && ...
           abs( (obj.windowdata.t(windowNdx) - obj.windowdata.distNdx.t(ex))<5),
           continue; 
        end
        
        for used = curP(1:count)
          if obj.windowdata.distNdx.exp(used) == obj.windowdata.distNdx.exp(ex) &&...
             obj.windowdata.distNdx.flies(used) == obj.windowdata.distNdx.flies(ex) && ...
             abs( (obj.windowdata.distNdx.t(used) - obj.windowdata.distNdx.t(ex))<5),
             isClose = 1; 
             break; 
          end
        end
        
        if isClose; continue; end;
        count = count+1;
        curP(count) = ex;
      end
      
      count = 0;
      for ex = allNeg'
        if count>4; break; end;
        isClose = 0;
        if obj.windowdata.exp(windowNdx) == obj.windowdata.distNdx.exp(ex) &&...
           obj.windowdata.flies(windowNdx) == obj.windowdata.distNdx.flies(ex) && ...
           abs( (obj.windowdata.t(windowNdx) - obj.windowdata.distNdx.t(ex))<5),
           continue; 
        end
        
        for used = curN(1:count)
          if obj.windowdata.distNdx.exp(used) == obj.windowdata.distNdx.exp(ex) &&...
             obj.windowdata.distNdx.flies(used) == obj.windowdata.distNdx.flies(ex) && ...
             abs( (obj.windowdata.distNdx.t(used) - obj.windowdata.distNdx.t(ex))<5),
             isClose = 1; 
             break; 
          end
        end
        
        if isClose; continue; end;
        count = count+1;
        curN(count) = ex;
      end
      
      varForSSF.curFrame.expNum = obj.windowdata.exp(windowNdx);
      varForSSF.curFrame.flyNum = obj.windowdata.flies(windowNdx);
      varForSSF.curFrame.curTime = obj.windowdata.t(windowNdx);
      
      for k = 1:4
        varForSSF.posFrames(k).expNum = obj.windowdata.distNdx.exp(curP(k));
        varForSSF.posFrames(k).flyNum = obj.windowdata.distNdx.flies(curP(k));
        varForSSF.posFrames(k).curTime = obj.windowdata.distNdx.t(curP(k));
        varForSSF.negFrames(k).expNum = obj.windowdata.distNdx.exp(curN(k));
        varForSSF.negFrames(k).flyNum = obj.windowdata.distNdx.flies(curN(k));
        varForSSF.negFrames(k).curTime = obj.windowdata.distNdx.t(curN(k));
      end
      showSimilarFrames('setFrames',obj.frameFig,varForSSF);
    end
    
    % PredictLoaded(obj)
    % Runs the classifier on all preloaded window data. 
    function PredictLoaded(obj)
      
      if isempty(obj.classifier),
        return;
      end
      
      % apply classifier
      switch obj.classifiertype,
        
        case 'ferns',
          obj.SetStatus('Applying fern classifier to %d windows',size(obj.windowdata.X,1));
          [obj.windowdata.predicted,...
            obj.windowdata.predicted_probs,...
            obj.predict_cache.last_predicted_inds] = ...
            fernsClfApply(obj.windowdata.X,obj.classifier);
          obj.windowdata.isvalidprediction(:) = true;
          s = exp(obj.windowdata.predicted_probs);
          s = bsxfun(@rdivide,s,sum(s,2));
          scores = max(s,[],2);
          idx0 = obj.windowdata.predicted == 1;
          idx1 = obj.windowdata.predicted > 1;
          obj.windowdata.scores(idx1) = -scores(idx1);
          obj.windowdata.scores(idx0) = scores(idx0);
          obj.ClearStatus();
        case 'boosting',
          
          toPredict = ~obj.windowdata.isvalidprediction;
          obj.SetStatus('Applying boosting classifier to %d windows',sum(toPredict));
          scores = myBoostClassify(obj.windowdata.X(toPredict,:),obj.classifier);
          obj.windowdata.predicted(toPredict) = -sign(scores)*0.5+1.5;
          obj.windowdata.scores(toPredict) = scores;
          obj.windowdata.isvalidprediction(toPredict) = true;
          obj.ClearStatus();
          
      end
            
      % transfer to predictidx for current fly
      if ~isempty(obj.expi) && obj.expi > 0 && ~isempty(obj.flies) && all(obj.flies > 0),
        obj.UpdatePredictedIdx();
      end
      
    end
    
    % SetTrainingData(obj,trainingdata)
    % Sets the labelidx_old of windowdata based on the input training data.
    % This reflects the set of labels the classifier was last trained on. 
    function SetTrainingData(obj,trainingdata)

      for i = 1:numel(trainingdata),
        [ism,labelidx] = ismember(trainingdata(i).names,obj.labelnames);
        if any(~ism),
          tmp = unique(trainingdata(i).names(~ism));
          error('Unknown labels %s',sprintf('%s ',tmp{:})); %#ok<SPERR>
        end
        isexp = obj.windowdata.exp == i;
        for j = 1:numel(trainingdata(i).t0s),
          t0 = trainingdata(i).t0s(j);
          t1 = trainingdata(i).t1s(j);
          l = labelidx(j);
          flies = trainingdata(i).flies(j,:);
          isflies = isexp & all(bsxfun(@eq,obj.windowdata.flies,flies),2);
          ist = isflies & obj.windowdata.t >= t0 & obj.windowdata.t < t1;
          if nnz(ist) ~= (t1-t0),
            error('Sanity check: number of training examples does not match windowdata');
          end
          obj.windowdata.labelidx_old(ist) = l;
        end
      end
            
    end

    % trainingdata = SummarizeTrainingData(obj)
    % Summarize labelidx_old into trainingdata, which is similar to the
    % form of labels.
    function trainingdata = SummarizeTrainingData(obj)
      
      trainingdata = struct('t0s',{},'t1s',{},'names',{},'flies',{});
      waslabeled = obj.windowdata.labelidx_old;
      for expi = 1:obj.nexps,
        trainingdata(expi) = struct('t0s',[],'t1s',[],'names',{{}},'flies',[]);
        isexp = waslabeled & obj.windowdata.exp == expi;
        if ~any(isexp),
          continue;
        end
        fliess = unique(obj.windowdata.flies(isexp,:),'rows');
        for fliesi = 1:size(fliess,1),
          flies = fliess(fliesi,:);
          isflies = isexp & all(bsxfun(@eq,obj.windowdata.flies,flies),2);
          labelidxs = setdiff(unique(obj.windowdata.labelidx_old(isflies)),0);
          for labelidxi = 1:numel(labelidxs),
            labelidx = labelidxs(labelidxi);
            islabel = isflies & labelidx == obj.windowdata.labelidx_old;
            ts = sort(obj.windowdata.t(islabel));
            breaks = find(ts(1:end-1)+1~=ts(2:end));
            t1s = ts(breaks)+1;
            t0s = ts(breaks+1);
            t0s = [ts(1);t0s];%#ok<AGROW>
            t1s = [t1s;ts(end)+1];%#ok<AGROW>
            n = numel(t0s);
            trainingdata(expi).t0s(end+1:end+n,1) = t0s;
            trainingdata(expi).t1s(end+1:end+n,1) = t1s;
            trainingdata(expi).names(end+1:end+n,1) = repmat(obj.labelnames(labelidx),[1,n]);
            trainingdata(expi).flies(end+1:end+n,:) = repmat(flies,[n,1]);
          end
        end
      end

    end

    % UpdatePredictedIdx(obj)
    % Updates the stored predictedidx and erroridx fields to reflect
    % windowdata.predicted
    function UpdatePredictedIdx(obj)
      
      if obj.expi == 0,
        return;
      end
      
      n = obj.t1_curr - obj.t0_curr + 1;
      obj.predictedidx = zeros(1,n);
      obj.scoresidx = zeros(1,n);
      obj.scoreTS = zeros(1,n);
      
      % Scores from loaded scores.
      if obj.scoredata.exp,
        idxcurr = obj.scoredata.exp == obj.expi & all(bsxfun(@eq,obj.scoredata.flies,obj.flies),2);
        obj.predictedidx(obj.scoredata.t(idxcurr)-obj.t0_curr+1) = ...
          obj.scoredata.predicted(idxcurr);
        obj.scoresidx(obj.scoredata.t(idxcurr)-obj.t0_curr+1) = ...
          obj.scoredata.scores(idxcurr);      
        obj.scoreTS(obj.scoredata.t(idxcurr)-obj.t0_curr+1) = ...
          obj.scoredata.timestamp(idxcurr);      
      end
      
      if isempty(obj.windowdata.exp),
        return;
      end
      
      % Overwrite by scores from windowdata.
      idxcurr = obj.FlyNdx(obj.expi,obj.flies) & ...
        obj.windowdata.isvalidprediction;
      obj.predictedidx(obj.windowdata.t(idxcurr)-obj.t0_curr+1) = ...
        obj.windowdata.predicted(idxcurr);
      obj.scoresidx(obj.windowdata.t(idxcurr)-obj.t0_curr+1) = ...
        obj.windowdata.scores(idxcurr);      
      obj.scoreTS(obj.windowdata.t(idxcurr)-obj.t0_curr+1) = ...
        obj.classifierTS;      

      obj.UpdateErrorIdx();
            
    end
    
    % UpdatePredictedIdx(obj)
    % Updates the stored erroridx and suggestedidx from predictedidx
    function UpdateErrorIdx(obj)

      if obj.expi == 0,
        return;
      end
      
      n = obj.t1_curr - obj.t0_curr + 1;
      obj.erroridx = zeros(1,n);
      obj.suggestedidx = zeros(1,n);
      idxcurr = obj.predictedidx ~= 0 & obj.labelidx ~= 0;
      obj.erroridx(idxcurr) = double(obj.predictedidx(idxcurr) ~= obj.labelidx(idxcurr))+1;
      
      idxcurr = obj.predictedidx ~= 0 & obj.labelidx == 0;
      obj.suggestedidx(idxcurr) = obj.predictedidx(idxcurr);
    end

    % Predict(obj,expi,flies,ts)
    % Runs the behavior classifier on the input experiment, flies, and
    % frames. This involves first precomputing the window data for these
    % frames, then applying the classifier. 
    function Predict(obj,expi,flies,ts)
      
      % TODO: don't store window data just because predicting. 
      
      if isempty(obj.classifier),
        return;
      end

      if isempty(ts),
        return;
      end
            
      % compute window data
      [success,msg] = obj.PreLoadWindowData(expi,flies,ts);
      if ~success,
        warning(msg);
        return;
      end
      
      % indices into windowdata
      idxcurr = obj.FlyNdx(expi,flies) & ...
        ~obj.windowdata.isvalidprediction & ismember(obj.windowdata.t,ts);
      
      % apply classifier
      switch obj.classifiertype,
        
        case 'ferns',
          obj.SetStatus('Applying fern classifier to %d windows',nnz(idxcurr));
          [obj.windowdata.predicted(idxcurr),...
            obj.windowdata.predicted_probs(idxcurr,:)] = ...
            fernsClfApply(obj.windowdata.X(idxcurr,:),obj.classifier);
          obj.windowdata.isvalidprediction(idxcurr) = true;

          s = exp(obj.windowdata.predicted_probs);
          s = bsxfun(@rdivide,s,sum(s,2));
          scores = max(s,[],2);
          idxcurr1 = find(idxcurr);
          idx0 = obj.windowdata.predicted(idxcurr) == 1;
          idx1 = obj.windowdata.predicted(idxcurr) > 1;
          obj.windowdata.scores(idxcurr1(idx1)) = -scores(idx1);
          obj.windowdata.scores(idxcurr1(idx0)) = scores(idx0);
          
          obj.ClearStatus();
        case 'boosting',

          obj.SetStatus('Applying boosting classifier to %d windows',nnz(idxcurr));
          scores = myBoostClassify(obj.windowdata.X(idxcurr,:),obj.classifier);
          obj.windowdata.predicted(idxcurr) = -sign(scores)*0.5+1.5;
          obj.windowdata.scores(idxcurr) = scores;
          obj.windowdata.isvalidprediction(idxcurr) = true;
          obj.ClearStatus();

      end
           
      obj.UpdatePredictedIdx();
      
    end
    
    function PredictWholeMovie(obj,expi)
      
      if isempty(obj.classifier),
        return;
      end
      
      scoresA = {}; tStartAll = []; tEndAll = [];
      numFlies = obj.GetNumFlies(expi);
      parfor flies = 1:numFlies
        tStart = obj.GetTrxFirstFrame(expi,flies);
        tEnd = obj.GetTrxEndFrame(expi,flies);
        
        scores = nan(1,tEnd);
        t1 = tStart;
        while (t1<tEnd)
          cTic = tic;
          [success1,msg,t0,t1,X,~] = obj.ComputeWindowDataChunk(expi,flies,t1,'start',true);
 
%{          
          if ~success1,
            warning(msg);
            return;
          end
          switch obj.classifiertype,
            
            case 'ferns',
              return;
              obj.SetStatus('Applying fern classifier to %d windows',nnz(idxcurr));
              [obj.windowdata.predicted(idxcurr),...
                obj.windowdata.predicted_probs(idxcurr,:)] = ...
                fernsClfApply(obj.windowdata.X(idxcurr,:),obj.classifier);
              obj.windowdata.isvalidprediction(idxcurr) = true;
              
              s = exp(obj.windowdata.predicted_probs);
              s = bsxfun(@rdivide,s,sum(s,2));
              scores = max(s,[],2);
              idxcurr1 = find(idxcurr);
              idx0 = obj.windowdata.predicted(idxcurr) == 1;
              idx1 = obj.windowdata.predicted(idxcurr) > 1;
              obj.windowdata.scores(idxcurr1(idx1)) = -scores(idx1);
              obj.windowdata.scores(idxcurr1(idx0)) = scores(idx0);
              
              obj.ClearStatus();
            case 'boosting',
%}
          scores(t0:t1) = myBoostClassify(X,obj.classifier);
              
%{
           end
%}          
           t1 = t1+1;
          tt = toc(cTic);
          timeRemainingFly = (tEnd-t1)/(t1-t0)*tt;
          timeRemainingAll = (tEnd-t1)/(t1-t0)*tt + ...
            (numFlies-flies)*(tEnd-tStart)/(t1-t0)*tt;
          fprintf('Prediction for fly %d/%d: %d%% done. Time Remaining: Current Fly:%ds, Current Movie:%ds\n',...
            flies,numFlies,round( (t1-tStart)/(tEnd-tStart)*100),...
            round(timeRemainingFly),round(timeRemainingAll));
%{
          obj.SetStatus('Prediction for fly %d/%d: %d%% done. Time Remaining: Current Fly:%ds, Current Movie:%ds',...
            flies,numFlies,round( (t1-tStart)/(tEnd-tStart)*100),...
            round(timeRemainingFly),round(timeRemainingAll));
%}          
        end % While loop.
        scoresA{flies} = scores;
        tStartAll(flies) = tStart;
        tEndAll(flies) = tEnd;
      end % Fly loop
      allScores = struct;
      allScores.scores = scoresA;
      allScores.tStart = tStartAll;
      allScores.tEnd = tEndAll;
      obj.SaveScores(allScores,expi);
      obj.ClearStatus();

      
   end
   
   function scores = NormalizeScores(obj,scores)

     if isempty(obj.windowdata.scoreNorm) || isnan(obj.windowdata.scoreNorm)
       isLabeled = obj.windowdata.labelidx_old~=0;
       wScores = obj.windowdata.scores(isLabeled);
       scoreNorm = prctile(abs(wScores),80);
       obj.windowdata.scoreNorm = scoreNorm;
     end
     
     scoreNorm = obj.windowdata.scoreNorm;
     scores(scores<-scoreNorm) = -scoreNorm;
     scores(scores>scoreNorm) = scoreNorm;
     scores = scores/scoreNorm;
   end
   
    % SetStatus(obj,<sprintf-like arguments>)
    % Update an associated status text according to the input sprintf-like
    % arguments.
    function SetStatus(obj,varargin)

      if isempty(obj.setstatusfn),
        fprintf(varargin{:});
        fprintf('\n');
      else
        obj.setstatusfn(sprintf(varargin{:}));
        drawnow;
      end
      
    end

    % ClearStatus(obj)
    % Return an associated status text to the default. 
    function ClearStatus(obj)
      
      if ~isempty(obj.clearstatusfn),
        obj.clearstatusfn();
        drawnow;
      end
    
    end
    
    function SetStatusFn(obj,statusfn)
      obj.setstatusfn = statusfn;
    end
    
    function SetClearStatusFn(obj,clearfn)
      obj.clearstatusfn = clearfn;
    end    
    
    function ShowSelectFeatures(obj)
      selHandle = SelectFeatures;
      SelectFeatures('setJLDobj',selHandle,obj);
      SelectFeatures('createWindowTable',selHandle);
      SelectFeatures('createPfTable',selHandle);
      uiwait(selHandle);
    end
    
  end
    
end

% Old commented functions

%{    
%     function AddWindowDataLabeled(obj,expi,flies)
%       
%       if numel(expi) ~= 1,
%         error('expi must be a scalar');
%       end
%       
%       if nargin < 3,
%         flies = (1:obj.nflies_per_exp(expi))';
%       end
%       
%       for i = 1:size(flies,1),
%         flies_curr = flies(i,:);
%         
%         % labels for this experiment, fly
%         labels_curr = obj.GetLabels(expi,flies_curr);
%         
%         % no labels?
%         if isempty(labels_curr.t0s),
%           continue;
%         end
%         
%         % loop through all behaviors
%         n = max(labels_curr.t1s);
%         idx = zeros(1,n);
%         for j = 1:obj.nbehaviors,
%           for k = find(strcmp(labels_curr.names,obj.labelnames{j})),
%             t0 = labels_curr.t0s(k);
%             t1 = labels_curr.t1s(k);
%             idx(t0+obj.labels_bin_off:t1+obj.labels_bin_off,j) = j;
%           end
%         end
%         m = nnz(idx);
%         if obj.expi == expi && all(flies_curr == obj.flies),
%           obj.windowdata_labeled(:,end+1:end+m) = obj.windowdata_curr(:,idx~=0);
%         else
%           windowfilenames = obj.GetFile('window',expi);
%           % TODO: make this work for multiple flies
%           windowdata_curr = load(windowfilenames{flies_curr(1)});
%           obj.windowdata_labeled(:,end+1:end+m) = windowdata_curr(:,idx~=0);
%         end
%         obj.exp_labeled(end+1:end+m) = expi;
%         obj.flies_labeled(end+1:end+m,:) = repmat(flies_curr,[m,1]);
%         obj.isintrainingset(end+1:end+m) = false;
%         obj.labelidx_labeled(end+1:end+m) = idx;
%         
%       end
%       
%     end
%}

%{
%       function UpdateWindowDataLabeled(obj)
% 
%       % indices into cached data for current experiment and flies
%       idxcurr = obj.exp_labeled' == obj.expi & all(bsxfun(@eq,obj.flies_labeled,obj.flies),2);
%       
%       % frames of current experiment and flies that have old labeled data
%       
%       % indices into cached data that are for this exp, these flies, have
%       % labelidx_old
%       idxcurr1 = idxcurr & obj.labelidx_old_labeled ~= 0;
%       % which frames for expi, flies that have labelidx_old ~= 0
%       tsold = obj.ts_labeled(idxcurr1);
%       % indices into labels_bin that have labelidx_old ~= 0
%       idxold = tsold+obj.labels_bin_off;
%             
%       % keep/add windowdata if labelidx_old ~= 0 or if labels_bin ~= 0
%       % indices into labels_bin for which new labelidx_new ~= 0
%       cacheidx = any(obj.labels_bin,2);
%       % or labelidx_old ~= 0
%       cacheidx(idxold) = true;
%       m = nnz(cacheidx);
% 
%       % labelidx_old for these frames
%       labelidx_old = zeros(1,m);
%       labelidx_old(idxold) = obj.labelidx_old_labeled(idxcurr1);
%       
%       % remove all data from the cache for the current exp, flies
%       obj.windowdata_labeled(:,idxcurr) = [];
%       obj.exp_labeled(idxcurr) = [];
%       obj.flies_labeled(idxcurr,:) = [];
%       obj.labelidx_old_labeled(idx) = [];
%       obj.labelidx_new_labeled(idx) = [];
%       obj.ts_labeled(idx) = [];
%       
%       % convert labels_bin to integer
%       n = size(obj.labels_bin,1);
%       labelidx = zeros(1,n);
%       for i = 1:obj.nbehaviors,
%         labelidx(obj.labels_bin(:,i)) = i;
%       end
%       
%       % add this data      
%       obj.windowdata_labeled(:,end+1:end+m) = obj.windowdata_curr(:,cacheidx);
%       obj.exp_labeled(end+1:end+m) = obj.expi;
%       obj.flies_labeled(end+1:end+m,:) = repmat(obj.flies,[m,1]);
%       obj.labelidx_old_labeled(end+1:end+m) = labelidx_old;
%       obj.labelidx_new_labeled(end+1:end+m) = labelidx;
%       obj.ts_labeled(end+1:end+m) = find(cacheidx) + obj.labels_bin_off;
% 
%     end
%}

%{    
%     function RemoveFromWindowDataLabeled(obj,expi,flies)
% 
%       idx = ismember(obj.exp_labeled,expi);
%       if nargin >= 3,
%         idx = idx & ismember(obj.flies_labeled,flies,'rows');
%       end
%       obj.windowdata_labeled(:,idx) = [];
%       obj.exp_labeled(idx) = [];
%       obj.flies_labeled(idx,:) = [];
%       obj.isintrainingset(idx) = [];
%       obj.labelidx_labeled(idx) = [];
%       
%     end
%}

%{
%     % [success,msg] = LoadTrx(obj,expi)
%     % Load trajectories for input experiment. This should only be called by
%     % PreLoad()!. 
%     function [success,msg] = LoadTrx(obj,expi)
% 
%       success = false;
%       msg = '';
%       
%       if numel(expi) ~= 1,
%         error('expi must be a scalar');
%       end
% 
%       if expi < 1,
%         msg = 'expi not yet set';
%         return;
%       end
%       
%       % load trx
%       try
%         trxfilename = obj.GetFile('trx',expi);
%   
%         hwait = mywaitbar(0,'Loading trx');
%   
%         % TODO: remove this
%         global CACHED_TRX; %#ok<TLEV>
%         global CACHED_TRX_EXPNAME; %#ok<TLEV>
%         if isempty(CACHED_TRX) || isempty(CACHED_TRX_EXPNAME) || ...
%             ~strcmp(obj.expnames{expi},CACHED_TRX_EXPNAME),
%           obj.trx = load_tracks(trxfilename);
%           CACHED_TRX = obj.trx;
%           CACHED_TRX_EXPNAME = obj.expnames{expi};
%         else
%           fprintf('DEBUG: Using CACHED_TRX. REMOVE THIS\n');
%           obj.trx = CACHED_TRX;
%         end
%       catch ME,
%         msg = sprintf('Error loading trx from file %s: %s',trxfilename,getReport(ME));
%         if ishandle(hwait),
%           delete(hwait);
%           drawnow;
%         end
%         return;
%       end
% 
%       if ishandle(hwait),
%         delete(hwait);
%         drawnow;
%       end
%       success = true;
%       
%     end
%}    

%{ 
%     function [success,msg] = LoadWindowData(obj,expi,flies)
% 
%       success = false;
%       msg = '';
%       
%       windowfilenames = obj.GetFile('window',expi);
%       % TODO: make this work for multiple flies
%       try
%         obj.windowdata_curr = load(windowfilenames{flies(1)});
%       catch ME,
%         msg = getReport(ME);
%         return;
%       end
%       
%       success = true;
%       
%     end
%}    

%{
    % trx = GetTrx(obj,expi,flies,ts)
    % Returns the trajectories for the input experiment, flies, and frames.
    % If this is the currently preloaded experiment, then the preloaded
    % trajectories are used. Otherwise, the input experiment is preloaded.
    % If flies is not input, then all flies are returned. If ts is not
    % input, then all frames are returned. 
    function trx = GetTrx(obj,expi,flies,ts)
      
      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,1);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end

      if nargin < 3,
        trx = obj.trx;
        return;
      end
      
      if nargin < 4,
        trx = obj.trx(flies);
        return;
      end
      
      nflies = numel(flies);
      c = cell(1,nflies);
      trx = struct('x',c,'y',c,'a',c,'b',c,'theta',c,'ts',c,'firstframe',c,'endframe',c);
      for i = 1:numel(flies),
        fly = flies(i);
        js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
        trx(i).x = obj.trx(fly).x(js);
        trx(i).y = obj.trx(fly).y(js);
        trx(i).a = obj.trx(fly).a(js);
        trx(i).b = obj.trx(fly).b(js);
        trx(i).theta = obj.trx(fly).theta(js);
        trx(i).ts = js-obj.trx(fly).off;
        trx(i).firstframe = trx(i).ts(1);
        trx(i).endframe = trx(i).ts(end);
      end
    end

    % x = GetTrxX(obj,expi,flies,ts)
    % Returns the x-positions for the input experiment, flies, and frames.
    % This is a cell array with an entry for each fly. If flies is not
    % input, then all flies are returned. If ts is not input, then all
    % frames are returned. 
    function x = GetTrxX(obj,expi,flies,ts)
      
      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        if nargin < 3,
          [success,msg] = obj.PreLoad(expi,1);
        else
          [success,msg] = obj.PreLoad(expi,flies(1));
        end
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end

      if nargin < 3,
        x = {obj.trx.x};
        return;
      end
      
      if nargin < 4,
        x = {obj.trx(flies).x};
        return;
      end
      
      nflies = numel(flies);
      x = cell(1,nflies);
      for i = 1:numel(flies),
        fly = flies(i);
        js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
        x{i} = obj.trx(fly).x(js);
      end
    end
    
    % x = GetTrxX1(obj,expi,fly,ts)
    % Returns the x-positions for the input experiment, SINGLE fly, and
    % frames. If ts is not input, then all frames are returned. 
    function x = GetTrxX1(obj,expi,fly,ts)
      
      if all(expi ~= obj.expi),
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,fly);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end
      
      if nargin < 4,
        x = obj.trx(fly).x;
        return;
      end
      
      x = obj.trx(fly).x(ts + obj.trx(fly).off);

    end

    % y = GetTrxY(obj,expi,flies,ts)
    % Returns the y-positions for the input experiment, flies, and frames.
    % This is a cell array with an entry for each fly. If flies is not
    % input, then all flies are returned. If ts is not input, then all
    % frames are returned. 
    function y = GetTrxY(obj,expi,flies,ts)
      
      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,1);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end

      if nargin < 3,
        y = {obj.trx.y};
        return;
      end
      
      if nargin < 4,
        y = {obj.trx(flies).y};
        return;
      end
      
      nflies = numel(flies);
      y = cell(1,nflies);
      for i = 1:numel(flies),
        fly = flies(i);
        js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
        y{i} = obj.trx(fly).y(js);
      end
    end
    
    % y = GetTrxY1(obj,expi,fly,ts)
    % Returns the y-positions for the input experiment, SINGLE fly, and
    % frames. If ts is not input, then all frames are returned. 
    function y = GetTrxY1(obj,expi,fly,ts)
      
      if all(expi ~= obj.expi),
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,fly);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end
      
      if nargin < 4,
        y = obj.trx(fly).y;
        return;
      end
      
      y = obj.trx(fly).y(ts + obj.trx(fly).off);

    end

    % a = GetTrxA(obj,expi,flies,ts)
    % Returns the quarter major axis lengths for the input experiment,
    % flies, and frames. This is a cell array with an entry for each fly.
    % If flies is not input, then all flies are returned. If ts is not
    % input, then all frames are returned. 
    function a = GetTrxA(obj,expi,flies,ts)
      
      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,1);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end

      if nargin < 3,
        a = {obj.trx.a};
        return;
      end
      
      if nargin < 4,
        a = {obj.trx(flies).a};
        return;
      end
      
      nflies = numel(flies);
      a = cell(1,nflies);
      for i = 1:numel(flies),
        fly = flies(i);
        js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
        a{i} = obj.trx(fly).a(js);
      end
    end
    
    % a = GetTrxA1(obj,expi,fly,ts)
    % Returns the quarter-major-axes for the input experiment, SINGLE fly, and
    % frames. If ts is not input, then all frames are returned. 
    function a = GetTrxA1(obj,expi,fly,ts)
      
      if all(expi ~= obj.expi),
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,fly);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end
      
      if nargin < 4,
        a = obj.trx(fly).a;
        return;
      end
      
      a = obj.trx(fly).a(ts + obj.trx(fly).off);

    end
    
    % b = GetTrxB(obj,expi,flies,ts)
    % Returns the quarter minor axis lengths for the input experiment,
    % flies, and frames. This is a cell array with an entry for each fly.
    % If flies is not input, then all flies are returned. If ts is not
    % input, then all frames are returned. 
    function b = GetTrxB(obj,expi,flies,ts)
      
      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,1);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end

      if nargin < 3,
        b = {obj.trx.b};
        return;
      end
      
      if nargin < 4,
        b = {obj.trx(flies).b};
        return;
      end
      
      nflies = numel(flies);
      b = cell(1,nflies);
      for i = 1:numel(flies),
        fly = flies(i);
        js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
        b{i} = obj.trx(fly).b(js);
      end
    end
    
    % b = GetTrxB1(obj,expi,fly,ts)
    % Returns the quarter-minor-axes for the input experiment, SINGLE fly, and
    % frames. If ts is not input, then all frames are returned. 
    function b = GetTrxB1(obj,expi,fly,ts)
      
      if all(expi ~= obj.expi),
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,fly);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end
      
      if nargin < 4,
        b = obj.trx(fly).b;
        return;
      end
      
      b = obj.trx(fly).b(ts + obj.trx(fly).off);

    end
    
    % theta = GetTrxTheta(obj,expi,flies,ts)
    % Returns the orientations for the input experiment,
    % flies, and frames. This is a cell array with an entry for each fly.
    % If flies is not input, then all flies are returned. If ts is not
    % input, then all frames are returned. 
    function theta = GetTrxTheta(obj,expi,flies,ts)
      
      if numel(expi) ~= 1,
        error('expi must be a scalar');
      end
      
      if expi ~= obj.expi,
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,1);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end

      if nargin < 3,
        theta = {obj.trx.theta};
        return;
      end
      
      if nargin < 4,
        theta = {obj.trx(flies).theta};
        return;
      end
      
      nflies = numel(flies);
      theta = cell(1,nflies);
      for i = 1:numel(flies),
        fly = flies(i);
        js = min(obj.trx(fly).nframes,max(1,ts + obj.trx(fly).off));
        theta{i} = obj.trx(fly).theta(js);
      end
    end

    % theta = GetTrxTheta1(obj,expi,fly,ts)
    % Returns the orientations for the input experiment, SINGLE fly, and
    % frames. If ts is not input, then all frames are returned. 
    function theta = GetTrxTheta1(obj,expi,fly,ts)
      
      if all(expi ~= obj.expi),
        % TODO: generalize to multiple flies
        [success,msg] = obj.PreLoad(expi,fly);
        if ~success,
          error('Error loading trx for experiment %d: %s',expi,msg);
        end
      end
      
      if nargin < 4,
        theta = obj.trx(fly).theta;
        return;
      end
      
      theta = obj.trx(fly).theta(ts + obj.trx(fly).off);

    end
    %}

%{    
%     function [success,msg] = GenerateWindowFeaturesFiles(obj,expi,doforce)
%       
%       success = false;
%       msg = '';
%       
%       if ~exist('doforce','var'),
%         doforce = false;
%       end
% 
%       hwait = mywaitbar(0,'Computing window features...');
% 
%       filenames = obj.GetFile('window',expi);
%       perframedir = obj.GetFile('perframedir',expi);
%       for fly = 1:obj.nflies_per_exp(expi),
%         filename = filenames{fly};
%         if ~doforce && exist(filename,'file'),
%           fprintf('File %s exists, skipping\n',filename);
%           continue;
%         end
%         try
%         X = [];
%         feature_names = {};
%         for j = 1:numel(obj.perframefns),
%           fn = obj.perframefns{j};
%           perframedata = load(fullfile(perframedir,[fn,'.mat']));
%           hwait = mywaitbar((fly-1+(j-1)/numel(obj.perframefns))/obj.nflies_per_exp(expi),hwait,...
%             sprintf('Computing %s window features (%d/%d) for fly %d/%d',fn,j,numel(obj.perframefns),fly,numel(perframedata.data)));
%           [x_curr,feature_names_curr] = ...
%             ComputeWindowFeatures(perframedata.data{fly},obj.windowfeaturescellparams.(fn){:});
%           nold = size(X,2);
%           nnew = size(x_curr,2);
%           if nold > nnew,
%             x_curr(:,end+1:end+nold-nnew) = nan;
%           elseif nnew > nold,
%             X(:,end+1:end+nnew-nold) = nan;
%           end
%           X = [X;x_curr]; %#ok<AGROW>
%           feature_names = [feature_names,cellfun(@(s) [{fn},s],feature_names_curr,'UniformOutput',false)]; %#ok<AGROW>
%         end
%         hwait = mywaitbar(fly/obj.nflies_per_exp(expi),hwait,sprintf('Saving window features for fly %d/%d to file...',fly,obj.nflies_per_exp(expi)));
%         save(filename,'X','feature_names');
%         catch ME,
%           msg = getReport(ME);
%           return;
%         end
%       end
%       if exist('hwait','var') && ishandle(hwait),
%         delete(hwait);
%       end
%       
%     end
%}

%{    
%     function [success,msg] = SetWindowFileName(obj,windowfilename)
%       
%       success = false;
%       msg = '';
% 
%       if ischar(windowfilename),
%         obj.windowfilename = windowfilename;
%         if ischar(obj.windowfilename) && strcmp(windowfilename,obj.windowfilename),
%           success = true;
%           return;
%         end
% 
%         % TODO: check window data for existing experiments, remove bad experiments, update
%         % windowdata_labeled, etc. 
%         
%         [success,msg] = obj.UpdateStatusTable('window');
%       end
%       
%     end
%}
    