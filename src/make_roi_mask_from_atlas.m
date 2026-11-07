function make_roi_mask_from_atlas()
% make_roi_mask_from_atlas
% -------------------------------------------------------------------------
% UI-driven builder for a binary ROI mask from an indexed atlas NIfTI.
% - Pick atlas (.nii/.nii.gz), label list (.txt; one label per line), ROIs
% - Optional reference NIfTI (output space); else uses atlas space
% - Writes combined mask .nii + JSON provenance
% - Shows visualizations: (Still Working On)
%     Fig 1: Combined mask overlay on the reference
%     Fig 2: Colored overlays of each selected ROI (up to 12 at once)
%
% Requires: SPM12 on the MATLAB path.
% Author: Matt Gunn 
% -------------------------------------------------------------------------

clc; fprintf('=== ROI Mask Builder (Atlas -> Binary Mask) ===\n');

% --- Check SPM ---
needFns = {'spm_vol','spm_read_vols','spm_write_vol','spm_reslice'};
for k = 1:numel(needFns)
    if exist(needFns{k}, 'file') ~= 2
        error('Required SPM function "%s" not found. Please add SPM12 to your MATLAB path.', needFns{k});
    end
end

% --- 1) Atlas ---
[atlasFile, atlasPath] = uigetfile({'*.nii;*.nii.gz','NIfTI (*.nii, *.nii.gz)'}, 'Select indexed atlas NIfTI');
if isequal(atlasFile,0); disp('Canceled.'); return; end
atlasFQ = fullfile(atlasPath, atlasFile);
fprintf('Atlas: %s\n', atlasFQ);

% --- 2) Label list (.txt) ---
[labelFile, labelPath] = uigetfile({'*.txt','Text (*.txt)'}, 'Select label list (1 label per line; order = atlas indices)');
if isequal(labelFile,0); disp('Canceled.'); return; end
labelFQ = fullfile(labelPath, labelFile);
labels = read_label_list_(labelFQ);
if isempty(labels), error('No labels found in %s', labelFQ); end
fprintf('Labels: %s (n=%d)\n', labelFQ, numel(labels));

% --- 3) ROI selection ---
[selIdx, ok] = listdlg( ...
    'ListString', labels, ...
    'SelectionMode', 'multiple', ...
    'PromptString', sprintf('Select ROIs (%d available):', numel(labels)), ...
    'ListSize', [420 640]);
if ~ok || isempty(selIdx), disp('No ROIs selected. Aborting.'); return; end
selNames = labels(selIdx);
fprintf('Selected %d ROI(s).\n', numel(selIdx));

% --- 4) Optional reference space ---
useRef = questdlg('Match output space to a reference NIfTI (reslice atlas if needed)?', ...
                  'Reference space', 'Yes','No (use atlas space)','Yes');
useRefFlag = strcmpi(useRef,'Yes');
if useRefFlag
    [refFile, refPath] = uigetfile({'*.nii;*.nii.gz','NIfTI (*.nii, *.nii.gz)'}, 'Select reference NIfTI');
    if isequal(refFile,0); disp('Canceled.'); return; end
    refFQ = fullfile(refPath, refFile);
else
    refFQ = atlasFQ;
end
fprintf('Reference: %s\n', refFQ);

% --- 5) Output filename ---
defaultOut = default_output_name_(selNames);
[outFile, outPath] = uiputfile({'*.nii','NIfTI (*.nii)'}, 'Save combined mask as...', defaultOut);
if isequal(outFile,0); disp('Canceled.'); return; end
outFQ = fullfile(outPath, outFile);
fprintf('Output: %s\n', outFQ);

% Shared, testable implementation; temporary files never touch the atlas folder.
meta = build_roi_mask(atlasFQ, labelFQ, selIdx, outFQ, refFQ);
fprintf('Wrote %d voxels and JSON metadata to %s\n', meta.voxel_count, outFQ);

end % main


% ======================= helpers =========================================

function labels = read_label_list_(txtPath)
    raw = fileread(txtPath);
    lines = regexp(raw, '\r\n|\n|\r', 'split');
    labels = strtrim(string(lines(:)));
    labels = labels(labels~="");
    labels = cellstr(labels);
end

function tf = same_space_(V1, V2)
    tf = isequal(V1.dim, V2.dim) && max(abs(V1.mat(:)-V2.mat(:))) < 1e-6;
end

function name = default_output_name_(selNames)
    base = 'combined_mask';
    if ~isempty(selNames)
        tokens = regexprep(selNames(1:min(3,end)), '[^\w]+', '');
        tail = strjoin(tokens, '_');
        if strlength(tail) > 0, base = [base '__' char(tail)]; end
    end
    name = [base '.nii'];
end

function write_json_(fname, s)
    try
        txt = jsonencode(s);
        txt = regexprep(txt, ',"', sprintf(',\n  "'));
        txt = regexprep(txt, '^{', sprintf('{\n  '));
        txt = regexprep(txt, '}$', sprintf('\n}'));
        fid = fopen(fname,'w'); if fid<0, error('Cannot open %s', fname); end
        fwrite(fid, txt, 'char'); fclose(fid);
    catch ME
        warning('Could not write JSON sidecar:');
    end
end

function show_combined_overlay_(refFQ, maskFQ, selNames)
    figure('Name','Combined ROI Mask Overlay','Color','w');
    spm_orthviews('Reset');
    spm_orthviews('Image', refFQ);                % background
    spm_orthviews('AddColouredImage', 1, maskFQ, [1 0 0]); % red overlay
    spm_orthviews('Alpha', 1, 0.35);
    spm_orthviews('Redraw');
    ttl = sprintf('Combined Mask (%d ROI%s)', numel(selNames), plural_(numel(selNames)));
    annotation('textbox',[0 0.95 1 0.05],'String',ttl,'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
end

function show_per_roi_overlays_(refFQ, atlasData, Vref, selIdx, selNames, outPath, K)
    % Create temporary single-ROI masks and overlay in distinct colors
    figure('Name','Per-ROI Overlays','Color','w');
    spm_orthviews('Reset');
    spm_orthviews('Image', refFQ);

    cmap = lines(max(K,7)); % distinct colors
    tmpDir = fullfile(outPath, 'tmp_roi_masks_for_viz');
    if ~exist(tmpDir,'dir'), mkdir(tmpDir); end

    for k = 1:K
        idx = selIdx(k);
        thisMask = uint8(atlasData == idx);

        Vtmp = Vref;
        safeName = regexprep(selNames{k}, '[^\w]+', '_');
        Vtmp.fname = fullfile(tmpDir, sprintf('roi_%03d_%s.nii', idx, safeName));
        Vtmp.dt = [2 0];
        spm_write_vol(Vtmp, thisMask);

        spm_orthviews('AddColouredImage', 1, Vtmp.fname, cmap(k, :));
        spm_orthviews('Alpha', 1+k, 0.35); % overlay handles increment
    end

    spm_orthviews('Redraw');
    ttl = sprintf('Selected ROIs (showing %d of %d)', K, numel(selIdx));
    annotation('textbox',[0 0.95 1 0.05],'String',ttl,'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');

    % Legend panel (text)
    leg = arrayfun(@(i) sprintf('%3d: %s', selIdx(i), selNames{i}), 1:K, 'uni', 0);
    uicontrol('Style','listbox','String',leg,'Units','normalized','Position',[0.78 0.05 0.21 0.85]);
    uicontrol('Style','text','String','Temp per-ROI masks saved for visualization:', ...
        'Units','normalized','Position',[0.78 0.91 0.21 0.04],'BackgroundColor','w','HorizontalAlignment','left');
    uicontrol('Style','text','String',tmpDir, ...
        'Units','normalized','Position',[0.78 0.88 0.21 0.03],'BackgroundColor','w','HorizontalAlignment','left');

    fprintf('Per-ROI temp masks (for visualization) saved in: %s\n', tmpDir);
    fprintf('You can delete this folder later if you like.\n');
end

function s = plural_(n)
    s = 's'; if n==1, s=''; end
end
