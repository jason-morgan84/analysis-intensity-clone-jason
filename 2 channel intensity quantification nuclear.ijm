/////////output masks for debugging

//methods for selecting region of interest in image
//0 uses whole image
//1 uses current top ROI
//2 defines region based on presence of fluoresence in region_channel
var region_method = 2
var region_channel = 3
var region_threshold = 1
var minimum_region_size = 100000
var minimum_clone_size = 500
var minimum_nuclear_size = 500

//settings for dealing with z-stacks.
//0 means use current slice (either single slice image or use chosen slice from z-stack)
//1 means z-project
var z_stack_settings = 0

var clone_channel = 2
var clone_background_subtract = 0
var clone_background_radius = 50
var clone_threshold_method = "Otsu"

var analysis1_name = "analysis1"
var analysis1_channel = 1
var analysis1_background = 0
var analysis1_background_radius = 50

var analysis2_name = "analysis2"
var analysis2_channel = 1
var analysis2_background = 0
var analysis2_background_radius = 50

var dapi_channel = 4
var dapi_background_subtract = 0
var dapi_background_radius = 50
var dapi_threshold_method = "Huang"

//end of analysis settings

//close windows at end (0 leaves windows open, 1 leaves original image open, 2 closes all associated images
close_windows = 1

//For debugging purposes, output windows showing each combination of regions used for quantificaiton
output_regions = 0
//output text to log window in wide or long formats (lower case)
output_format = "wide"

//define output variables
var analysis1_clone_non_nuclear_intensity = 0
var analysis1_non_clone_non_nuclear_intensity = 0
var analysis1_clone_nuclear_intensity = 0
var analysis1_non_clone_nuclear_intensity = 0
var analysis1_clone_intensity = 0
var analysis1_non_clone_intensity = 0

var analysis2_clone_non_nuclear_intensity = 0
var analysis2_non_clone_non_nuclear_intensity = 0
var analysis2_clone_nuclear_intensity = 0
var analysis2_non_clone_nuclear_intensity = 0
var analysis2_clone_intensity = 0
var analysis2_non_clone_intensity = 0

setBackgroundColor(255, 255, 255);
setForegroundColor(0, 0, 0);

//get image name and print to log window for output
image=getTitle();


/******************************process slices of interest*************************************/
//if a single slice is required, duplicate currently selected slice for processing
if (z_stack_settings==0)
{
	Stack.getPosition(channel, slice, frame);
	run("Duplicate...", "duplicate slices="+slice);
	name = getTitle();
}

//if z-projecting is required, then perform max intensity z-projection
else if (z_stack_settings==1)
{
	run("Z Project...", "projection=[Max Intensity]");
	name = getTitle();
	//run("Canvas Size...", "width=1020 height=1020 position=Center");
}
	
/******************************get region of interest*************************************/
//if selecting whole region, make the image binary and clear all
if (region_method==0)
{
	duplicate_channel(name, 1,"region");
	run("Make Binary", "background=Light calculate black");
	run("Select All");
	run("Clear");
	run("Select None");
}

//if selecting current ROI, make the image binary, fill to make all black, then clear the region
//of interest and remove all ROIs
else if (region_method==1)
{
	duplicate_channel(name, 1,"region");
	run("Make Binary", "background=Light calculate black");
	run("Select All");
	run("Fill");
	roiManager("Select", 0);
	run("Clear");
	roiManager("Deselect");
	roiManager("Delete");
}

//if selecting based on the given channel, duplicate that channel, blur then threshold for any 
//fluoresence present and fill holes
else if (region_method==2)
{
	duplicate_channel(name, region_channel,"region");
	run("Gaussian Blur...", "sigma=5");	
	setThreshold(region_threshold, 255, "raw");
	run("Convert to Mask");
	run("Fill Holes");
}

//analyse particles to get ROIs for region and clear z-stacked image outside this area
run("Analyze Particles...", "size="+minimum_region_size+"-Infinity pixel add");
selectWindow(name);
roiManager("Deselect");
roiManager("OR");
setBackgroundColor(0, 0, 0);
run("Clear Outside");
run("Select None");

roiManager("Deselect");
roiManager("Delete");


/******************************Mask clone regions************************************/
//duplicate the clone channel for processing and blur
selectWindow(name);
duplicate_channel(name, clone_channel,"clone_mask");
run("Gaussian Blur...", "sigma=3");	

//background subtract if required in settings
if (clone_background_subtract==1)
{
	run("Subtract Background...", "rolling="+clone_background_radius+" sliding");
}
//threshold using method defined in settings
setAutoThreshold(clone_threshold_method+" dark");
run("Convert to Mask");

/******************************Mask nuclei ************************************/
//get DAPI channel and process
duplicate_channel(name, dapi_channel,"dapi_non_clone_mask");
if (dapi_background_subtract==1) run("Subtract Background...", "rolling="+dapi_background_radius+" sliding");
run("Gaussian Blur...", "sigma=3");	

//threshold processed image
setAutoThreshold(dapi_threshold_method+" dark");
run("Convert to Mask");

run("Duplicate...", "title=dapi_clone_mask");

//get mask of dapi positive regions within clones
selectWindow("clone_mask");
run("Analyze Particles...", "size=minimum_clone_size-Infinity pixel add");
selectWindow("dapi_clone_mask");
roiManager("Deselect");
roiManager("OR");
run("Clear Outside");
run("Select None");

//get mask of dapi positive regions outside clones
selectWindow("dapi_non_clone_mask");
roiManager("Deselect");
roiManager("OR");
run("Clear");
run("Select None");

roiManager("Deselect");
roiManager("Delete");

/******************************Measure intensity in each region************************************/

//duplicate and process channels for analysis
duplicate_channel(name, analysis1_channel,analysis1_name);
if (analysis1_background==1) run("Subtract Background...", "rolling="+analysis1_background_radius+" sliding");

duplicate_channel(name, analysis2_channel,analysis2_name);
if (analysis2_background==1) run("Subtract Background...", "rolling="+analysis2_background_radius+" sliding");

//inside clones overall - measures average intensity over all clone regions, in each channel
selectWindow("clone_mask");
run("Analyze Particles...", "size=minimum_clone_size-Infinity pixel add");
selectWindow(analysis1_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
analysis1_clone_intensity=mean;
run("Select None");

selectWindow(analysis2_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
analysis2_clone_intensity=mean;
run("Select None");

//inside clones non-dapi - measures average intensity within clones excluding dapi-positive regions
selectWindow("dapi_clone_mask");
run("Analyze Particles...", "size=minimum_nuclear_size-Infinity pixel add");

selectWindow(analysis1_name);
roiManager("Deselect");
roiManager("XOR");
getStatistics(area,mean);
analysis1_clone_non_nuclear_intensity=mean;
run("Select None");

selectWindow(analysis2_name);
roiManager("Deselect");
roiManager("XOR");
getStatistics(area,mean);
analysis2_clone_non_nuclear_intensity=mean;
run("Select None");

roiManager("Deselect");
roiManager("Delete");

//inside clones dapi - uses mask of dapi within clones to measure average intensity of each channel
selectWindow("dapi_clone_mask");
run("Analyze Particles...", "size=minimum_nuclear_size-Infinity pixel add");

selectWindow(analysis1_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
analysis1_clone_nuclear_intensity=mean;
run("Select None");

selectWindow(analysis2_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
analysis2_clone_nuclear_intensity=mean;
run("Select None");

roiManager("Deselect");
roiManager("Delete");

//outside clones overall
selectWindow("region");
run("Analyze Particles...", "size="+minimum_region_size+"-Infinity pixel add");
selectWindow("clone_mask");
run("Analyze Particles...", "size=minimum_clone_size-Infinity pixel add");

selectWindow(analysis1_name);
roiManager("Deselect");
roiManager("XOR");
getStatistics(area,mean);
analysis1_non_clone_intensity=mean;
run("Select None");

selectWindow(analysis2_name);
roiManager("Deselect");
roiManager("XOR");
getStatistics(area,mean);
analysis2_non_clone_intensity=mean;
run("Select None");

roiManager("Deselect");
roiManager("Delete");

//outside clones dapi
selectWindow("dapi_non_clone_mask");
run("Analyze Particles...", "size=minimum_nuclear_size-Infinity pixel add");

selectWindow(analysis1_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
analysis1_non_clone_nuclear_intensity=mean;
run("Select None");

selectWindow(analysis2_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
analysis2_non_clone_nuclear_intensity=mean;
run("Select None");


//outside clones non-dapi
selectWindow("clone_mask");
roiManager("Deselect");
roiManager("OR");
setForegroundColor(255, 255, 255);
run("Fill");
run("Select None");
roiManager("Deselect");
roiManager("Delete");

run("Analyze Particles...", "size=minimum_nuclear_size-Infinity pixel add");
selectWindow("region");
run("Analyze Particles...", "size="+minimum_region_size+"-Infinity pixel add");



selectWindow(analysis1_name);
roiManager("Deselect");
roiManager("XOR");
getStatistics(area,mean);
analysis1_non_clone_non_nuclear_intensity=mean;
run("Select None");

selectWindow(analysis2_name);
roiManager("Deselect");
roiManager("XOR");
getStatistics(area,mean);
analysis2_non_clone_non_nuclear_intensity=mean;
run("Select None");

roiManager("Deselect");
roiManager("Delete");

if (toLowerCase(output_format)=="wide")
{
	print("image,analysis_name,clone_intensity,non_clone_intensity,clone_nuclear_intensity,non_clone_nuclear_intensity,clone_non_nuclear_intensity,non_clone_non_nuclear_intensity");
	print(image+","+analysis1_name+","+analysis1_clone_intensity+","+analysis1_non_clone_intensity+","+analysis1_clone_nuclear_intensity+","+analysis1_non_clone_nuclear_intensity+","+analysis1_clone_non_nuclear_intensity+","+analysis1_non_clone_non_nuclear_intensity);
	print(image+","+analysis2_name+","+analysis2_clone_intensity+","+analysis2_non_clone_intensity+","+analysis2_clone_nuclear_intensity+","+analysis2_non_clone_nuclear_intensity+","+analysis2_clone_non_nuclear_intensity+","+analysis2_non_clone_non_nuclear_intensity);
}
else if (toLowerCase(output_format)=="long")
{
	print(image+","+analysis1_name+","+"clone_intensity"+","+analysis1_clone_intensity);
	print(image+","+analysis1_name+","+"non_clone_intensity"+","+analysis1_non_clone_intensity);
	print(image+","+analysis1_name+","+"clone_nuclear_intensity"+","+analysis1_clone_nuclear_intensity);
	print(image+","+analysis1_name+","+"non_clone_nuclear_intensity"+","+analysis1_non_clone_nuclear_intensity);
	print(image+","+analysis1_name+","+"clone_non_nuclear_intensity"+","+analysis1_clone_non_nuclear_intensity);
	print(image+","+analysis1_name+","+"non_clone_non_nuclear_intensity"+","+analysis1_non_clone_non_nuclear_intensity);
	print(image+","+analysis2_name+","+"clone_intensity"+","+analysis2_clone_intensity);
	print(image+","+analysis2_name+","+"non_clone_intensity"+","+analysis2_non_clone_intensity);
	print(image+","+analysis2_name+","+"clone_nuclear_intensity"+","+analysis2_clone_nuclear_intensity);
	print(image+","+analysis2_name+","+"non_clone_nuclear_intensity"+","+analysis2_non_clone_nuclear_intensity);
	print(image+","+analysis2_name+","+"clone_non_nuclear_intensity"+","+analysis2_clone_non_nuclear_intensity);
	print(image+","+analysis2_name+","+"non_clone_non_nuclear_intensity"+","+analysis2_non_clone_non_nuclear_intensity);
}
if (close_windows==1)
{
	close("region");
	close(analysis1_name);
	close(analysis2_name);
	close("clone_mask");
	close("dapi_clone_mask");
	close("dapi_non_clone_mask");
	close(name);
}

if (close_windows==2)
{
	close(image);
}


function duplicate_channel(image,channel,title)
{
	selectWindow(image);
	run("Duplicate...", "title="+title+" duplicate channels="+channel );
}
