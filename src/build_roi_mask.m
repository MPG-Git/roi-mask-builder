function meta = build_roi_mask(atlasFile, labelFile, indices, outputFile, referenceFile)
% BUILD_ROI_MASK Noninteractive mask creation, shared by the GUI and tests.
% Labels are one per line, with line number equal to the atlas voxel index.
if nargin<5 || isempty(referenceFile), referenceFile=atlasFile; end
for fn={'spm_vol','spm_read_vols','spm_write_vol','spm_reslice'}
    if isempty(which(fn{1})), error('roi:MissingSPM','Add the full SPM12 distribution to the MATLAB path.'); end
end
validateattributes(indices,{'numeric'},{'vector','integer','positive','nonempty'});
labels=splitlines(string(fileread(labelFile))); labels=strtrim(labels);
while ~isempty(labels) && labels(end)=="", labels(end)=[]; end
if any(labels==""), error('roi:Labels','Blank label lines would shift atlas indices.'); end
if any(indices>numel(labels)), error('roi:Labels','Selected index exceeds the label list.'); end
indices=unique(indices(:).','stable');
if ~endsWith(lower(outputFile),'.nii'), error('roi:Output','Output must end in .nii.'); end
if strcmpi(outputFile,atlasFile) || strcmpi(outputFile,referenceFile)
    error('roi:Output','Choose a separate output filename.');
end
scratch=tempname; mkdir(scratch);
cleanup=onCleanup(@() remove_scratch(scratch)); %#ok<NASGU>
atlas=local_nifti(atlasFile,scratch,'atlas');
reference=local_nifti(referenceFile,scratch,'reference');
Va=spm_vol(atlas); Vr=spm_vol(reference);
if numel(Va)~=1 || numel(Vr)~=1, error('roi:Dimensions','Atlas and reference must be single 3-D volumes.'); end
original=spm_read_vols(Va);
if any(~isfinite(original(:))) || any(abs(original(:)-round(original(:)))>1e-6)
    error('roi:IndexedAtlas','Use an integer-valued indexed atlas, not a probability map.');
end
if any(~ismember(indices,unique(original(:))))
    error('roi:AbsentROI','At least one selected index is absent from the source atlas.');
end
resliced=~isequal(Va.dim,Vr.dim) || max(abs(Va.mat(:)-Vr.mat(:)))>=1e-6;
if resliced
    flags=struct('interp',0,'wrap',[0 0 0],'mask',0,'which',1,'mean',0,'prefix','r');
    spm_reslice({reference,atlas},flags);
    Va=spm_vol(fullfile(scratch,'ratlas.nii'));
end
mask=uint8(ismember(round(spm_read_vols(Va)),indices));
if ~any(mask(:)), error('roi:EmptyMask','Selected ROIs do not overlap the reference image.'); end
Vo=Vr; Vo.fname=outputFile; Vo.dt=[2 0]; Vo.pinfo=[1;0;0];
Vo.descrip='Binary ROI mask (nearest-neighbor atlas resampling)';
spm_write_vol(Vo,mask);
meta=struct('atlas_file',atlasFile,'labels_file',labelFile,'reference_file',referenceFile, ...
    'output_file',outputFile,'selected_indices',indices,'selected_names',{cellstr(labels(indices))}, ...
    'resliced',resliced,'voxel_count',nnz(mask),'timestamp',datestr(now,30));
[outdir,name]=fileparts(outputFile);
fid=fopen(fullfile(outdir,[name '.json']),'w');
if fid<0, error('roi:Metadata','Could not create the JSON sidecar.'); end
closer=onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid,jsonencode(meta),'char');
end

function file=local_nifti(source,scratch,name)
if endsWith(lower(source),'.gz')
    target=fullfile(scratch,[name '.nii.gz']); copyfile(source,target);
    files=gunzip(target,scratch); file=files{1};
else
    file=fullfile(scratch,[name '.nii']); copyfile(source,file);
end
end

function remove_scratch(folder)
% Only delete the unique directory created for this invocation.
parent=char(java.io.File(tempdir).getCanonicalPath());
actual=char(java.io.File(folder).getCanonicalPath());
if startsWith(lower(actual),[lower(parent) filesep]) && isfolder(actual)
    rmdir(actual,'s');
end
end
