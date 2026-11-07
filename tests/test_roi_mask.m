function tests=test_roi_mask
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'));
t.TestData.root=root; t.TestData.out=tempname; mkdir(t.TestData.out);
end
function testExactMaskAndMetadata(t)
d=t.TestData.out;
V=struct('fname',fullfile(d,'atlas.nii'),'dim',[6 6 6],'dt',[16 0], ...
 'mat',eye(4),'pinfo',[1;0;0],'descrip','test');
data=zeros(6,6,6); data(2:3,2:3,2:3)=1; data(4:5,4:5,4:5)=2;
spm_write_vol(V,data);
labels=fullfile(d,'labels.txt'); fid=fopen(labels,'w'); fprintf(fid,'Left\nRight\n'); fclose(fid);
out=fullfile(d,'mask.nii'); meta=build_roi_mask(V.fname,labels,2,out);
verifyEqual(t,spm_read_vols(spm_vol(out)),double(data==2));
verifyEqual(t,meta.voxel_count,8);
json=jsondecode(fileread(fullfile(d,'mask.json'))); verifyEqual(t,json.selected_names,{'Right'});
% A compressed atlas and shifted reference require nearest-neighbor reslicing.
gzip(V.fname); ref=V; ref.fname=fullfile(d,'ref.nii'); ref.mat(1,4)=1;
spm_write_vol(ref,zeros(size(data)));
resliced=fullfile(d,'resliced.nii');
build_roi_mask([V.fname '.gz'],labels,1,resliced,ref.fname);
expected=zeros(size(data)); expected(1:2,2:3,2:3)=1;
verifyEqual(t,spm_read_vols(spm_vol(resliced)),expected);
verifyEqual(t,spm_vol(resliced).mat,ref.mat);
verifyFalse(t,isfile(fullfile(d,'ratlas.nii')));
verifyError(t,@()build_roi_mask(V.fname,labels,3,out),'roi:Labels');
end
function testBundledAALAtlas(t)
r=t.TestData.root; atlas=fullfile(r,'examples','AAL3v1_1mm.nii');
labels=fullfile(r,'examples','AAL3_label_list.txt');
out=fullfile(t.TestData.out,'aal.nii');
build_roi_mask(atlas,labels,[1 2],out);
verifyEqual(t,spm_read_vols(spm_vol(out)),double(ismember(spm_read_vols(spm_vol(atlas)),[1 2])));
end
