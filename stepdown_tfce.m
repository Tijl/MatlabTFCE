function [varargout] = stepdown_tfce(analysis,tails,imgs,varargin)
%STEPDOWN_TFCE general wrapper for specifying analyses. Receives arguments
% from matlab_tfce_gui.m if specificed manually. All intended
% functionality in the package can be accessed via this function or the gui
% input version. This stepdown_tfce and the functions it calls are all
% standalone - i.e. they do not rely on functions from other packages. In
% contrast, matlab_tfce_gui uses (included) functions from the 
% 'NIfTI and ANALYZE tools' package to facilitate file io and the gui.
% Using matlab_tfce directly allows for headless sessions and more
% customization of the file io.
%
% This package offers a standalone implemetation of multiple comparison
% correction for fMRI data. It achieves this through a permutation testing
% approach which controls familywise error rate by comparing voxelwise
% statistics to the maximal statistics obtained from repeating the analysis
% with randomized data. See Nichols & Holmes (2002) for a detailed
% treatment of this approach. 
%
% The maximal statistic technique is combined
% with the threshold free cluster enhancement (TFCE) transformation due to
% Smith & Nichols (2009), which obviates the need for arbitrary voxelwise
% cluster-forming thresholds and instead produces continuous correct
% p-values for all voxels. Although some spatial specifity is lost
% relative to purely voxelwise approach, this approach, like cluster
% corrections, is substantially less conservative due to the fact that
% it capitalizes on spatial dependency in the data. 
%
% [varargout] = stepdown_tfce(analysis,tails,imgs,imgs2,covariate,nperm,H,E,C,dh)
% [pcorr] = stepdown_tfce(analysis,1,imgs,imgs2,covariate,nperm,H,E,C,dh)
% [pcorr_pos,pcorr_neg] = stepdown_tfce(analysis,2,imgs,imgs2,covariate,nperm,H,E,C,dh)
%
% Arguments:
%
% analysis -- type of analysis to perform. Options include:
%   -- 'onesample' -- tests one sample hypothesis mean > 0
%   -- 'paired' -- paired (dependent samples) test mean(imgs) > mean(imgs2)
%   -- 'independent' -- independent (two sample) test mean(imgs) > mean(imgs2)
%   -- 'correlation' -- correlation across subjects of imgs with covariate
%
% tails -- specify a 1 or 2 tailed test (unidirectional or bidirectional)
% that can be combined with any analysis.
%
% imgs -- a 4D matrix of imaging data for analysis. Dimensions are expected
% to be x,y,z,subject.
%
% Optional arguments (can supply [] to skip):
%
% imgs2 -- a second 4D matrix as above, required for paired and independent
% analysis options. Must have same xyz dimensions as imgs, and if the
% analysis is paired, subject number must match as well.
%
% covariate -- a subject x 1 matrix containing an individual difference
% covariate for correlation across subjects with voxelwise activity.
% 
% nperm -- number of permutations to perform. 1000 by default, but 10000
% recommended for publication purposes.
%
% H -- height exponent, default = 2
%
% E -- extent exponent, default = 0.5
%
% C -- connectivity, default = 6 (6 = surface, 18 = edge, 26 = corner)
%
% dh -- step size for cluster formation, default = .1
%
%   More steps will be more precise but will require more time and memory.
%   The H & E default parameter settings match FSL's randomise/fslmaths.
%   The C default setting matches FSL's ramdomise default setting. To
%   match SPM's default cluster forming, use 18 instead.
%
% Output: 
% If tails == 1, a single output image with the same xyz dimensions as imgs
% consisting of corrected p-values with be returned.
%
% If tails == 2, two such output images will be returned, one for the
% 'positive' tail and one for the 'negative' tail of the test,
% respectively.


%% input checks and default setting

% setting defaults
imgs2 = [];
covariate = [];
nperm = 1000;
H = 2;
E = .5;
C = 6;
dh = .1;

% adjusting optional arguments based on input
fixedargn = 3;
if nargin > (fixedargn + 0)
    imgs2 = varargin{1};
end
if nargin > (fixedargn + 1)
    covariate = varargin{2};
end
if nargin > (fixedargn + 2)
    if ~isempty(varargin{3})
        nperm = varargin{3};
    end
end
if nargin > (fixedargn + 3)
    if ~isempty(varargin{4})
        H = varargin{4};
    end
end
if nargin > (fixedargn + 4)
    if ~isempty(varargin{5})
        E = varargin{5};
    end
end
if nargin > (fixedargn + 5)
    if ~isempty(varargin{6})
        C = varargin{6};
    end
end
if nargin > (fixedargn + 6)
    if ~isempty(varargin{7})
        dh = varargin{7};
    end
end

% check that tails are appropriate
if ~(sum(tails==[1 2]))
    error('Inappropriate number of tails (must be 1 or 2)');
end

% check image data
bsize = size(imgs);
if length(bsize) ~= 4
    error('Image data not 4D - must be x-y-z-subject')
end
if ~isempty(imgs2)
    imgs1 = imgs;
    bsize2 = size(imgs2);
    if ~(strcmp(analysis,'independent') || strcmp(analysis,'paired'))
        warning(['The analysis ' analysis ' ignores the imgs2 argument']);
    end
    if sum(bsize(1:3) == bsize(1:3)) ~= 3
        error('XYZ dimensions of imgs and imgs2 do not match');
    end
else
    if (strcmp(analysis,'independent') || strcmp(analysis,'paired'))
        error('The imgs2 argument must be specified for this analysis type.');
    end
end

% check the subject number is the same for paired tests
if strcmp(analysis,'paired')
    if bsize1(4) ~= bsize2(4)
        error('The 4th (subject number) dimension of imgs1 and imgs2 must match for paired tests');
    end
end

% check subject number is high enough
if bsize(4) < 15
    warning('Low N limits number of unique permutations. Approximate (vs. exact) permutation may not be appropriate.');
end

% check covariate
covariate = covariate(:);
if strcmp(analysis,'correlation')
    if length(covariate) ~= bsize(4)
        error('Covariate length does not equal 4th dimension of images');
    end
end

%% analysis calls
% select appropriate analysis
switch analysis
    
    % one sample test (mean > 0)
    case 'onesample'
        if tails == 1
            pcorr = stepdown_tfce_ttest_onesample(imgs,tails,nperm,H,E,C,dh);
        else
            [pcorr_pos,pcorr_neg]= stepdown_tfce_ttest_onesample(imgs,tails,nperm,H,E,C,dh); 
        end
    
    % paired (repeated measures) test (imgs1>imgs2)
    case 'paired'
        imgs = imgs1-imgs2;
        if tails == 1
            pcorr = stepdown_tfce_ttest_onesample(imgs,tails,nperm,H,E,C,dh);
        else
            [pcorr_pos,pcorr_neg]= stepdown_tfce_ttest_onesample(imgs,tails,nperm,H,E,C,dh); 
        end
    
    % independent (two sample) samples test (imgs1>imgs2)
    case 'independent'
        if tails == 1
            pcorr = stepdown_tfce_ttest_independent(imgs1,imgs2,tails,nperm,H,E,C,dh);
        else
            [pcorr_pos,pcorr_neg] = stepdown_tfce_ttest_independent(imgs1,imgs2,tails,nperm,H,E,C,dh);
        end
    
    % covariate-img correlation (R>0)
    case 'correlation'
        if tails == 1
            pcorr = stepdown_tfce_correlation(imgs,covariate,tails,nperm,H,E,C,dh);
        else
            [pcorr_pos,pcorr_neg] = stepdown_tfce_correlation(imgs,covariate,tails,nperm,H,E,C,dh);
        end
        
    % unrecognized analysis input
    otherwise
        error('Analysis type not recognized');
end

%% assign output
if tails == 1
    varargout{1} = pcorr;
else
    varargout{1} = pcorr_pos;
    varargout{2} = pcorr_neg;
end

end
