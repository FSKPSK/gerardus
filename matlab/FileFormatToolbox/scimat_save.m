function scirunnrrd = scimat_save(file, scirunnrrd, touint8, v73)
% SCIMAT_SAVE  Save a SCIMAT struct to a Matlab or MetaImage format that
% can be imported by Seg3D and Seg3D2.
%
% scimat_save(FILE, SCIMAT)
%
%   This function formats the SCIMAT volume and saves it to a .mat or .mha
%   file that can be imported as a segmentation or image volume by Seg3D.
%
%   FILE is a string with the path and name of the output file. Currently,
%   the following output formats are supported:
%
%     .mat: Matlab binary file with a "scirunnrrd" struct (see below for
%           details). This file format can be opened by Seg3D.
%
%     .mha: Uncompressed MetaImage file (developed for the ITK and VTK
%           libraries). The .mha file contains both text metadata and
%           binary image within the same file.
%
%     .png: Portable Network Graphics. PNG uses lossless compression.
%           Binary file. In principle, Matlab limits the image size to
%           2^32-1 bytes. However, if you edit the line in imwrite() that
%           says
%             max32 = double(intmax('uint32'));
%           to
%             max32 = double(intmax('uint64'));
%           Matlab will accept and save larger files to PNG. Watch out,
%           though, because trying to save larger files to other formats
%           that are not PGN may crash Matlab.
%
%     .jp2, .jpx: JPEG2000 with lossless compression. Limited to images
%           smaller than 2^32-1 bytes.
%
%     .tif, .tiff: Tagged Image File Format. Limited to images smaller than
%           2^32-1 bytes. Binary file. Grayscale or RGB images.
%           AdobeDeflate lessless compression.
%
%   SCIMAT is the struct with the image data and metadata (see "help
%   scimat" for details on SCIMAT structs).
%
% scimat_save(FILE, SCIMAT, TOUINT8)
%
%   TOUINT8 is a flag to convert the image data from double to uint8. This
%   will make the volume 8 times smaller. By default, TOUINT8=false.
%
% scimat_save(FILE, SCIMAT, TOUINT8, V73)
%
%   V73 is a boolean flag to save the data to Matlab's HDF5-based MAT file
%   format v7.3. The reason is that if you volume is >= 2GB, Matlab skips
%   saving it and gives the warning message:
%
%      "Warning: Variable 'scirunnrrd' cannot be saved to a MAT-file whose
%      version is older than 7.3.
%      To save this variable, use the -v7.3 switch.
%      Skipping..."
%
%   This is a limitation of the v7 format. Read more here
%
%      http://www.mathworks.com/help/techdoc/rn/bqt6wls.html
%
%   However, note that Seg3D 1.x cannot read v7.3 files. By default,
%   V73=false.
%
% SCIRUNNRRD = scimat_save(...)
%
%   SCIRUNNRRD gives the "scirunnrrd" struct actually saved to the file.
%
% See also: scimat_load.

% Author: Ramon Casero <rcasero@gmail.com>
% Copyright © 2010-2014 University of Oxford
% Version: 0.6.3
% $Rev$
% $Date$
% 
% University of Oxford means the Chancellor, Masters and Scholars of
% the University of Oxford, having an administrative office at
% Wellington Square, Oxford OX1 2JD, UK. 
%
% This file is part of Gerardus.
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details. The offer of this
% program under the terms of the License is subject to the License
% being interpreted in accordance with English Law and subject to any
% action against the University of Oxford being under the jurisdiction
% of the English Courts.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

% check arguments
narginchk(2, 4);
nargoutchk(0, 1);

% defaults
if (nargin < 3 || isempty(touint8))
    touint8 = false;
end
if (nargin < 4 || isempty(v73))
    v73 = false;
end

% get extension of output filename
[~, ~, ext] = fileparts(file);

switch lower(ext)
    
    case '.mat'
        % make x-,y-coordinates compatible with the Seg3D convention
        scirunnrrd = scimat_seg3d2matlab(scirunnrrd);
        
        % Note: the following step has been skipped, as Seg3D2 doesn't
        % expect the dummy dimension
        % add dummy dimension, if necessary, and convert data to uint8, if
        % requested
%         scirunnrrd = scimat_unsqueeze(scirunnrrd, touint8);
        if (touint8)
            scirunnrrd.data = uint8(scirunnrrd.data);
        end
        
        % save data
        if (v73)
            save(file, 'scirunnrrd', '-v7.3');
        else
            save(file, 'scirunnrrd');
        end
        
    case '.mha'
        % swap rows and columns so that we have x-coordinates in the first
        % column, and y-coordinates in the second column, as expected by
        % the MetaImage format
        scirunnrrd.data = permute(scirunnrrd.data, [2 1 3:ndims(scirunnrrd.data)]);
        
        % save data, doing the same permutation of the axis values
        writemetaimagefile(file, scirunnrrd.data, ...
            [scirunnrrd.axis([2 1 3]).spacing], ...
            [scirunnrrd.axis([2 1 3]).min]+[scirunnrrd.axis([2 1 3]).spacing]/2);
        
    case '.png'
        
        % number of colour channels
        numchannels = size(scirunnrrd.data, 3);
        
        % bit depth
        switch class(scirunnrrd.data)
            case 'uint8'
                bitdepth = 8;
        end
        
        % image offset
        offset = scimat_index2world([1 1 1], scirunnrrd);
        
        % write the image to file, including metadata
        %
        % Note: there seems to be a bug in imwrite(), and XOffset, YOffset
        % and OffsetUnit will be created as "other" metadata tags, instead
        % of assigned to the official ones
        imwrite(scirunnrrd.data, file, 'ResolutionUnit', 'meter', ...
            'Software', 'Matlab/Gerardus/scimat_save()', ...
            'XResolution', 1 / scirunnrrd.axis(2).spacing, ...
            'YResolution', 1 / scirunnrrd.axis(1).spacing, ...
            'BitDepth', bitdepth, ...
            'XOffset', sprintf('%0.13e', offset(1)), ...
            'YOffset', sprintf('%0.13e', offset(2)), ...
            'OffsetUnit', 'meter');
        
    case {'.jp2', '.jpx'}
        
        % make sure that the image is not too large. In principle,
        % imwrite() would detect that that size is too large, and give an
        % error. But if we have hacked imwrite() so that it accepts larger
        % images than 4 GB, so that we can save them to .png, if the user
        % tries to save to JPEG2000, this will give a segfault
        max32 = double(intmax('uint32'));
        aux = zeros(1, class(scirunnrrd.data));
        s = whos('aux');
        if ((numel(scirunnrrd.data) * s.bytes) > max32)
            error(message('MATLAB:imagesci:imwrite:tooMuchData'))
        end

        % save image to file
        imwrite(scirunnrrd.data, file, 'Mode', 'lossless');
        
    case {'.tif', '.tiff'}
        
        % "Exporting Image Data and Metadata to TIFF Files"
        % http://www.mathworks.com/help/matlab/import_export/exporting-to-images.html#br_c_iz-6
        
        % create new TIFF file
        t = Tiff(file, 'w');
        
        % set tags
        tagstruct.ImageLength = size(scirunnrrd.data, 1); % rows
        tagstruct.ImageWidth = size(scirunnrrd.data, 2);  % columns
        tagstruct.SamplesPerPixel = size(scirunnrrd.data, 3); % channels per pixel
        tagstruct.Compression = Tiff.Compression.AdobeDeflate;
        switch tagstruct.SamplesPerPixel
            case 1 % grayscale image, black has intensity 0
                tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
            case 3 % RGB image
                tagstruct.Photometric = Tiff.Photometric.RGB;
            otherwise
                error('Input image is not grayscale or RGB')
        end
        switch class(scirunnrrd.data)
            case 'uint8'
                tagstruct.BitsPerSample = 8;
            otherwise
                error('Type not implemented. Input image is not of type uint8.')
        end
        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        tagstruct.Software = 'Gerardus/scimat_save()';
        tagstruct.ResolutionUnit = Tiff.ResolutionUnit.Centimeter; % resolution units are pixel/cm
        tagstruct.XResolution = 1 / (scirunnrrd.axis(2).spacing * 100);
        tagstruct.YResolution = 1 / (scirunnrrd.axis(1).spacing * 100);
        t.setTag(tagstruct);
        
        % write image data to file
        t.write(scirunnrrd.data);
        
        % close TIFF object
        t.close();
        
    otherwise
        error('Unrecognised output file format')
end