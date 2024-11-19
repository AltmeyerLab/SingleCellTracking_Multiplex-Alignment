// Generate aligned data from GE screening data and acquisitions
// each  round is combined, image translation, rotation, etc is corrected with SIFT - translation should be used for repetitive acquisitions of plates. 
// missing channels are substituted with black channels (all rounds need the same number of channels) - will not show in final results
// first channel found is always used to compute alignment. TBD: select which channel to be used for alignment
// TBD: add parameters to adjust for noise or calculate noise. Only if needed. Due to the SIFT algorithm this should not be needed.

//UZ, Center for Microscopy -- Janaury 2021

print("\\Clear");
start = getTime();
run("Input/Output...", "jpeg=85 gif=-1 file=.txt use_file");//sets the output from the result window to not include any headers, row indication...

//set some initial variables
suffix = ".tif"; //suffix of files to be analyzed and converted to a 
flagMissingChannel = 0; //a flag to indicate, a channel is missing 0 = no channel missing in all sequences, 1= one or more channel missing
listMissingChannels = newArray();//keep track of missing channels
zsteps = newArray(); //z steps
listNumberChannels = newArray(); //ordered list of number of channels in each input directories
listChannels = newArray(); //ordered list of channels found  in each input directories
numberRows = newArray(); //ordered list of number of rows in each input directories
listWells = newArray();
numberWells = newArray();
listRows = newArray(); //ordered list of rows found  in each input directories
numberColumns = newArray(); //ordered list of number of columns in each input directories
listColumns = newArray(); //ordered list of columns found  in each input directories
listBaseName = newArray(); //ordered list of columns found  in each input directories
numberFields = newArray(); //ordered list of number of fields in each input directories
listFields = newArray(); //ordered list of fields found  in each input directories
inputDirs = newArray(); //store all input directories
pathOrig = newArray(); //store all pathnames of the whole sequence as stored in the filesystem
pathList = newArray();
rowString = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

//Ask for some parameters
#@ String (visibility=MESSAGE, value="Align files from multiple acquisition rounds on a MD HCS system. First channel in each acqusition will be used for alignent. ", required=false) msgA
#@ String (visibility=MESSAGE, value="Alignment channels will be deleted except for first acquisition round. ", required=false) msgB
#@ String (visibility=MESSAGE, value="Sample: (will be used to label the files generated.............", required=false) msg0
#@ String(label="Sample:", "sample name", required=true) parameterSample 
#@ String (visibility=MESSAGE, value="Run in batch mode (does not display any images)...............", required=true) msg1
#@ String (label="Run in batch mode", choices={"Yes", "No"}, style="radioButtonHorizontal", required=true) parameterBatch
#@ String (visibility=MESSAGE, value="Please select if you want to store intermediate results...............", required=true) msg2
#@ String (label="Storage of intermediate results", choices={"Yes", "No"}, style="radioButtonHorizontal", required=true) parameterSaving
#@ String (visibility=MESSAGE, value="Please select the registration type (Rigid is a translation with rotation, without any distortions)...............", required=true) msg3
#@ String (label="Alignment to perform", choices={"Translation", "Rigid", "Affine"}, style="radioButtonHorizontal", required=true) parameterTransformation
#@ String (visibility=MESSAGE, value="Please select all directories with files to be aligned...........", required=false) msg4
#@ File[] (label="Select some directories", style="directories", required=true) directoriesIn //input directories
#@ String (visibility=MESSAGE, value="Please select an output directory...........", required=false) msg5
#@ File (label="Select an output directory", style="directory", required=true) directoryOut //output directory

//allow user to re-sort the input directories to adjust sequence of directories
if (directoriesIn.length>1) {
	Dialog.create("Sequence of the multiplex staining");
	Dialog.addMessage("Select the sequence of the multiplex stainings");
	for (i = 0; i < directoriesIn.length; i++) {
		Dialog.addChoice(i+1, directoriesIn, directoriesIn[i]);
	}
	Dialog.show();
	for (i = 0; i < directoriesIn.length; i++) {
		inputDirs = Array.concat(inputDirs,Dialog.getChoice());
	}
} else {
	inputDirs = directoriesIn;
}
//enter batch mode 
if (indexOf(parameterBatch, "Yes") >=0) {
	setBatchMode(true);
}

//get all pathnames as stored in the filesystem
for (i = 0; i < inputDirs.length; i++) {
	files = getFileList(inputDirs[i]);
	for (f = 0; f < files.length; f++) {
		pathOrig = Array.concat(pathOrig,inputDirs[i]+"\\"+files[f]);
	}
}
for (d = 0; d<inputDirs.length; d++) {


	//find channels written in the filename 'wv'; all directories must be analyzed
	s = 5; //where to find specific information in the main split of a filename
	filenameSplitter = " - ()"; //identifier to split filenames
	channels = newArray(); //channels
	channels=processFolder(inputDirs[d], channels, s);
	//Array.print(channels);
	channels = stripArray(channels);
	//Array.print(channels);
	listChannels = Array.concat(listChannels,channels);
	n= channels.length;
	listNumberChannels = Array.concat(listNumberChannels, n); //store all number of channels
	Array.getStatistics(listNumberChannels, minChannels, maxChannels);//get the maximum of all channels - to expand multiplex rounds with less channels

	//find rows
	s = 0; //where to split channels; only the first sequence / directory is analyzed - the others must have the same organization
	filenameSplitter = " "; //identifier to split filenames
	rows = newArray(); //rows
	rows=processFolder(inputDirs[d], rows, s);
	rows=stripArray(rows);
	listRows = Array.concat(listRows,rows);
	n= rows.length;
	numberRows = Array.concat(numberRows, n); //store all number of rows

	//find columns
	s = 1; //where to split channels; only the first sequence / directory is analyzed - the others must have the same organization
	columns = newArray(); //columns
	filenameSplitter = " -("; //identifier to split filenames
	columns=processFolder(inputDirs[d], columns, s);
	columns=stripArray(columns);
	listColumns = Array.concat(listColumns,columns);
	n= columns.length;
	numberColumns = Array.concat(numberColumns, n); //store all number of columns

	//find fields
	s = 3; //where to split fields; only the first sequence / directory is analyzed - the others must have the same organization
	fields = newArray(); //fields
	filenameSplitter = " - ("; //identifier to split filenames
	fields=processFolder(inputDirs[d], fields, s);
	fields=stripArray(fields);
	listFields = Array.concat(listFields,fields);
	n= fields.length;
	numberFields = Array.concat(numberFields, n); //store all number of fields

	//find Wells
	s = 0; //where to split fields; only the first sequence / directory is analyzed - the others must have the same organization
	wells = newArray(); //fields
	filenameSplitter = "("; //identifier to split filenames
	wells=processFolder(inputDirs[d], wells, s);
	wells=stripArray(wells);
	listWells = Array.concat(listWells,wells);
	n= wells.length;
	numberWells = Array.concat(numberWells, n); //store all number of fields

}
//correct and adjust the channel list - add placeholders = 0 for missing channels in some of the sequences - for alignement, same number of channels needed. .
correctedListChannels = newArray(inputDirs.length * maxChannels);
n=0;
for (i = 0; i < inputDirs.length; i++) {
	for (c = 0; c < maxChannels; c++) {
		index = c +i*maxChannels;
		if (c < listNumberChannels[i]) {
			correctedListChannels[index] = listChannels[n];
			n++;
		}
	}
}
listChannels = correctedListChannels;
print("\nChannels:");
Array.print(listChannels);
print("\nNumber of Channels:");
Array.print(listNumberChannels);
print("\nMax Number of Channels:");
print(maxChannels);
print("\nRows:");
Array.print(listRows);
print("\nColumns:");
Array.print(listColumns);
print("\nFields:");
Array.print(listFields);
print("\nWells:");
Array.print(listWells);




print("\n------------------------ putting your sequence together and generating your datasets in " + directoryOut + " ------------------------");
//generate a variable which can be used to store a text file, to open images, stacks, etc
//assuming the same number of rows, columns, fields are present in all multiplex stainings
for (well = 0; well < wells.length; well++) {
	print("Working on well " + well + 1 + " of " + wells.length);
	if (indexOf(wells[well], " - ") > 0) {
		sWell=replace(wells[well], " - ", "");
		//print(filenameSplit[s]);
	}
	sRow = 1 +  indexOf(rowString, substring(sWell, 0, 1)); //find in the provided string (rowString contains the alphabet) the position of the letter
	sCol = parseInt(substring(sWell, 1, 3));// converts the column from a filename (it is a string) into a number
	sRow = toString(sRow); while (sRow.length() < 3) {sRow = "0" + sRow;} // pads the number with some 0 depending on the number of digits
	sCol = toString(sCol); while (sCol.length() < 2) {sCol = "0" + sCol;} //pads the number
	//fields
	for (field = 0; field < fields.length; field++) {
		//print("Field: "+fields[field]);
		sField = toString(field); while (sField.length() < 5) {sField = "0" + sField;} //compute strings (string.format currently does not work)
		//channels
		run("Clear Results");
		nameStack = parameterSample + "--W" + sRow +sCol + "--P" + sField;
		print("\n\n"+nameStack);

		//channels
		nChannelSeriesCounter = 0;
		t=0; 
		for (i = 0; i < inputDirs.length; i++) {
			//print(ch);
			//assemble a new sorted filelist: Row>Columns>Fields>Channels: all files are assembled from all directories, files are already sorted due to the timestamp correctly
			for (ch = 0; ch < maxChannels; ch++) {
				//walk through the original pathlist and add files matching the matched files to a new sorted listChannels
				if (fields.length > 1) {
					fieldTag = "_s" + fields[field];
					}
					else {
						fieldTag = "";
					}
				matchingPart =inputDirs[i] + "\\" + wells[well] + "(fld " + fields[field] + " wv " + listChannels[ch+i*maxChannels];
				//print(matchingPart);
				
				if (listChannels[ch+i*maxChannels] != 0) {
					for (f = 0; f < pathOrig.length; f++) {
						//print(pathOrig[f]);
						if (indexOf(pathOrig[f], matchingPart)>=0 && endsWith(pathOrig[f], suffix)) {
							file = pathOrig[f];
							//print(file);
							//pathList = Array.concat(pathList,file);
						}
					}
				} else if (listChannels[ch+i*maxChannels] == 0) {
					//print(listChannels[ch+i*maxChannels]);
					//generate one template black image
					if (flagMissingChannel != 1) {
						flagMissingChannel = 1;
						open(pathOrig[2]); // open the first image found, make it 0, save it (will be deleted in the end again
						run("Multiply...", "value=0");
						File.makeDirectory(directoryOut+ "\\helperChannel");
						save(directoryOut+ "\\" + "helperChannel\\emptyChannel.tif");
						close();
					}
					file = directoryOut+ "\\" + "helperChannel\\emptyChannel.tif";
					listMissingChannels = Array.concat(listMissingChannels,ch);
					//print(file);
					//pathList = Array.concat(pathList,file);
				}
				setResult("Column", t, file); //pushes the pathname to the result window
				//print(file);
				//openImage(file, ch);
				//pathList = Array.concat(pathList,file);
				t++;
			}
		}
		//save results to a text file
		saveAs("Results", directoryOut + "\\" + nameStack + ".txt"); //generate a text file
		
		run("Stack From List...", "open=[" + directoryOut + "\\" + nameStack + ".txt" + "] use");
		run("Stack to Hyperstack...", "order=xyczt(default) channels=" + maxChannels + " slices=" + inputDirs.length + " frames=1 display=Color");
		if (indexOf(parameterSaving, "Yes")>=0) {
			//save hyperstack with all images, non aligned
			saveAs("tiff", directoryOut + "\\" + nameStack + ".tif");
		}
		//alignment with sift
		alignmentSIFT(parameterTransformation);
		if (indexOf(parameterSaving, "Yes")>=0) {
			//save aligned stack -> for trouble shooting
			saveAs("tiff", directoryOut + "\\" + nameStack + "-" + parameterTransformation + ".tif");
		}
		//Save individual channels as images
		run("Hyperstack to Stack");
		Stack.getDimensions(width, height, nchannels, nslices, nframes);
		run("Properties...", "channels="+(nchannels*nslices*nframes)+" slices=1 frames=1");
		
		//delete unnecessary channels
		channelsToDelete = newArray(0);
		//alignment channels
		for (i = 1; i < inputDirs.length; i++) {
			channelsToDelete = Array.concat(channelsToDelete, i*maxChannels);
		}
		//empty channels
		if (flagMissingChannel == 1) {
			for (c = 0; c < listChannels.length; c++) {
				if (listChannels[c] == 0 ) {
					channelsToDelete = Array.concat(channelsToDelete, c);
				}
			}
		}
		Array.sort(channelsToDelete);
		//delete channels
		for (i = channelsToDelete.length-1; i >= 0; i--) {
			c = channelsToDelete[i];
			setSlice(c+1);
			run("Delete Slice", "delete=channel");
		}

		//waitForUser;
		if (indexOf(parameterSaving, "Yes")>=0) {
			//save aligned hyperstack of channels
			saveAs("tiff", directoryOut + "\\" + nameStack + "-" + parameterTransformation + "-flat.tif");
		}
		n = nSlices; 
		run("Stack to Images");
		for (i = n; i >=1; i--) {
			//save channels
			run("Grays");
			run("Enhance Contrast", "saturated=0.2");
			sChannel = toString(i); while (sChannel.length() < 5) {sChannel = "0" + sChannel;}
			sTime = toString(1); while (sTime.length() < 5) {sTime = "0" + sTime;}
			saveAs("tiff", directoryOut + "\\" + nameStack + "--Z00000--T" + sTime + "--" + sChannel + ".tif");
			close();
			//waitForUser;
		}
	}
}

run("Clear Results");
x=File.delete(directoryOut+ "\\" + "helperChannel\\emptyChannel.tif");
x=File.delete(directoryOut+ "\\helperChannel");
print("\n------------------------Finished in " + (getTime() - start) / 1000 + " s ------------------------");

//SIFT Alignment
function alignmentSIFT(mode) { 
	if (indexOf(mode, "Rigid")>=0) {
		//run stack alignment  with a rigid transform 
		run("Linear Stack Alignment with SIFT MultiChannel", "registration_channel=1 initial_gaussian_blur=1.60 steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=2048 feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/next_closest_ratio=0.92 maximal_alignment_error=2 inlier_ratio=0.05 expected_transformation=Rigid");
	}
	if (indexOf(mode, "Translation")>=0) {
		//run stack alignment with a translation only
		run("Linear Stack Alignment with SIFT MultiChannel", "registration_channel=1 initial_gaussian_blur=1.60 steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=2048 feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/next_closest_ratio=0.92 maximal_alignment_error=2 inlier_ratio=0.05 expected_transformation=Translation");
	}
	if (indexOf(mode, "Affine")>=0) {
		//run a stack alignment with a affine transformation
		run("Linear Stack Alignment with SIFT MultiChannel", "registration_channel=1 initial_gaussian_blur=1.60 steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=2048 feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/next_closest_ratio=0.92 maximal_alignment_error=2 inlier_ratio=0.05 expected_transformation=Affine");
	}
}
//open images and adjust contrast (optional)
function openImage(path, contrast) {
	open(path);
	//adjust contrast of channel 1
	if (contrast == 0) {
		run("Enhance Contrast...", "saturated=0.3 normalize");
		run("Apply LUT", "stack");
	}
}

//extract information from filenames
function processFolder(input, arr, s) {
	list = getFileList(input);
		for (i = 0; i < list.length; i++) {
			//ignore all non tiff files that may be in the folder
			if (endsWith(list[i], suffix)) {
				filenameSplit = split(list[i], filenameSplitter);
				//store all information sequentially in an array
				/*if (indexOf(filenameSplit[s], " - ") > 0) {
					filenameSplit[s]=replace(filenameSplit[s], " - ", "");
					//print(filenameSplit[s]);
				}*/
				arr = Array.concat(arr, filenameSplit[s]);
			}
		}
	return arr;	
}


//strip multiple entries from an array
function stripArray (arr) {
	Array.sort(arr);
	for (i = 0; i < arr.length -1; i++) {
		if (arr[i]==arr[i+1]) {
			arr = Array.deleteIndex(arr, i+1);
			i= i-1;
		}
	}	
	return arr;
}
