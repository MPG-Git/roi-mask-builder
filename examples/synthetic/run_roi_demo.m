function run_roi_demo(out)
if nargin<1, out=''; end
[here,out,cleanup]=demo_prepare(mfilename('fullpath'),out); %#ok<ASGLU>
addpath(fullfile(fileparts(fileparts(here)),'src'));
data=fullfile(here,'data'); target=fullfile(out,'region_one_mask.nii');
build_roi_mask(fullfile(data,'atlas.nii.gz'),fullfile(data,'labels.txt'),1,target,fullfile(data,'reference_shifted.nii'));
V=spm_vol(target); a=spm_read_vols(V); oracle=zeros(6,6,6); oracle(1:2,2:3,2:3)=1;
assert(isequal(a,oracle),'Mask differs from analytic shifted-cube expectation');
ref=spm_vol(fullfile(data,'reference_shifted.nii')); assert(isequal(V.mat,ref.mat));
if isfile(fullfile(here,'expected','region_one_mask.nii'))
 assert(isequal(a,spm_read_vols(spm_vol(fullfile(here,'expected','region_one_mask.nii')))));
end
fig=figure; fc=onCleanup(@()close(fig)); %#ok<NASGU>
subplot(1,2,1); atlas=spm_read_vols(spm_vol(fullfile(data,'atlas.nii')));
imagesc(atlas(:,:,2)'); axis image; title('Source atlas: z index 2'); colorbar;
subplot(1,2,2); imagesc(a(:,:,2)'); axis image; title('Mask on shifted grid'); colorbar;
print(fig,fullfile(out,'mask_preview.png'),'-dpng','-r120');
demo_verify(here,out,{'VoxelCount','XFirst','XLast','AffineXTranslation'},[nnz(a),1,2,V.mat(1,4)]);
end
