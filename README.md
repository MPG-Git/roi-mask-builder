# roi-mask-builder
A tiny, UI-driven MATLAB tool to build **combined binary ROI masks** from an **indexed atlas NIfTI** (e.g., AAL3)

## Setup and use

This is a standalone MATLAB/SPM tool, not an EEGLAB plugin. Install the
[full SPM12 distribution](https://github.com/spm/spm12), then run:

```matlab
addpath('/path/to/spm12');
addpath('/path/to/roi-mask-builder/src');
make_roi_mask_from_atlas;
```

Choose an indexed atlas, its label file, the ROI names, an optional reference
image, and a separate output `.nii` file. Label line 1 must describe voxel
value 1, line 2 value 2, and so on; sparse atlases need placeholder lines for
unused indices. A probability atlas is not supported. Reference resampling
uses nearest-neighbor interpolation and assumes both images already share
the same world-coordinate system; it does not perform anatomical registration.

The output is a binary NIfTI plus JSON provenance. Compressed inputs are
unpacked in a temporary directory. Visualization overlays remain unavailable.
Batch use is also supported:

```matlab
meta = build_roi_mask('atlas.nii.gz','labels.txt',[1 2],'mask.nii','reference.nii');
r = runtests('/path/to/roi-mask-builder/tests'); assertSuccess(r);
```

## Authors
**Matthew P. Gunn, PhD**
- Creator & Lead Developer  
- Designed and built the tool to streamline mask generation for collaborators and clinical partners.

**Dominic J. Grisafe, MD PhD**  
- Co-Creator & Clinical Contributor  
- Provided the motivating use-case and domain insights that led to the development of this tool, ensuring its relevance for psychiatry and neuroimaging workflows.

## Citation
Gunn, M. P., & Grisafe, D. J. (2025). *roi-mask-builder: A MATLAB tool for generating combined binary ROI masks from indexed atlas NIfTI files.* GitHub. https://github.com/MPG-Git/roi-mask-builder
