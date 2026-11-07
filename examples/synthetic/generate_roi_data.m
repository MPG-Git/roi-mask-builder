function generate_roi_data(destination)
if nargin<1, destination=fullfile(fileparts(mfilename('fullpath')),'data'); end
assert(~isfolder(destination),'Choose a new destination'); mkdir(destination);
assert(~isempty(which('spm_write_vol')),'Add full SPM12 to the path');
V=struct('fname',fullfile(destination,'atlas.nii'),'dim',[6 6 6], ...
 'dt',[16 0],'mat',eye(4),'pinfo',[1;0;0],'descrip','Synthetic two-region atlas');
a=zeros(6,6,6); a(2:3,2:3,2:3)=1; a(4:5,4:5,4:5)=2; spm_write_vol(V,a);
gzip(V.fname); % Both compressed and uncompressed inputs are supplied.
V.fname=fullfile(destination,'reference_shifted.nii'); V.mat(1,4)=1;
V.descrip='Synthetic reference shifted one voxel in x'; spm_write_vol(V,zeros(6,6,6));
fid=fopen(fullfile(destination,'labels.txt'),'w'); fprintf(fid,'RegionOne\nRegionTwo\n'); fclose(fid);
end
