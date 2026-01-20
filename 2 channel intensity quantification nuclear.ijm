

//methods for selecting region of interest in image
//0 uses whole image
//1 uses current top ROI
//2 defines region based on presence of fluoresence in region_channel
var region_method = 1
var region_channel = 1
var region_threshold = 2
var minimum_region_size = 100000

//settings for dealing with z-stacks.
//0 means use current slice (either single slice image or use chosen slice from z-stack)
//1 means z-project
var z_stack_settings = 1

var clone_channel = 2
var clone_background_subtract = 0
var clone_background_radius = 50
var clone_threshold_method = "Otsu"

var analysis1_name = "PTEN"
var analysis1_channel = 1
var analysis1_background = 0

var analysis2_name = "None"
var analysis2_channel = 3
var analysis2_background = 0

var dapi_channel = 4
var dapi_background_subtract = 0
var dapi_background_radius = 50
var dapi_threshold_method = "Huang"

//end of analysis settings

//close windows at end (0 leaves windows open, 1 leaves original image open, 2 closes all associated images
close_windows = 0

//For debugging purposes, output windows showing each combination of regions used for quantificaiton
output_regions = 0

//define output variables
var analysis1_non_nuclear_GFP = 0
var analysis1_non_nuclear_non_GFP = 0
var analysis1_nuclear_GFP = 0
var analysis1_nuclear_non_GFP = 0
var analysis1_GFP = 0
var analysis1_non_GFP = 0

var analysis2_non_nuclear_GFP = 0
var analysis2_non_nuclear_non_GFP = 0
var analysis2_nuclear_GFP = 0
var analysis2_nuclear_non_GFP = 0
var analysis2_GFP = 0
var analysis2_non_GFP = 0

setBackgroundColor(255, 255, 255);
setForegroundColor(0, 0, 0);

//get image name and print to log window for output
image=getTitle();
print("-"+image);

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
	duplicate_channel(name, 1,"Region");
	run("Make Binary", "background=Light calculate black");
	run("Select All");
	run("Clear");
	run("Select None");
}

//if selecting current ROI, make the image binary, fill to make all black, then clear the region
//of interest and remove all ROIs
else if (region_method==1)
{
	duplicate_channel(name, 1,"Region");
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
	duplicate_channel(name, region_channel,"Region");
	run("Gaussian Blur...", "sigma=5");	
	setThreshold(region_threshold, 255, "raw");
	run("Convert to Mask");
	run("Fill Holes");
}
//analyse particles to get ROIs for region to analyse for next section
run("Analyze Particles...", "size="+minimum_region_size+"-Infinity pixel add");



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

//Remove clone areas outside the overall region of interest (defined by current ROIs)
roiManager("Deselect");
roiManager("OR");
setBackgroundColor(0, 0, 0);
run("Clear Outside");
run("Select None");

roiManager("Deselect");
roiManager("Delete");
/*
duplicate_channel(name, analysis1_channel,analysis1_name);
//run("Subtract Background...", "rolling=50 sliding");
duplicate_channel(name, analysis2_channel,analysis2_name);
//run("Subtract Background...", "rolling=50 sliding");

*/
/******************************Mask nuclei ************************************/
duplicate_channel(name, dapi_channel,"Dapi");
if (dapi_background_subtract==1)
{
	run("Subtract Background...", "rolling="+dapi_background_radius+" sliding");
}

run("Gaussian Blur...", "sigma=3");	
setAutoThreshold(dapi_threshold_method+" dark");
run("Convert to Mask");

selectWindow("Region");
run("Analyze Particles...", "size=100000-Infinity pixel add");
selectWindow("Dapi");
roiManager("Deselect");
roiManager("OR");
run("Clear Outside");
run("Select None");
/*

roiManager("Deselect");
roiManager("Delete");

run("Duplicate...", "title=Dapi_GFP");

//mask non-GFP regions for GFP dapi measurements
selectWindow("GFP_mask");
run("Analyze Particles...", "size=500-Infinity pixel add");
selectWindow("Dapi_GFP");
roiManager("Deselect");
roiManager("OR");
run("Clear Outside");
run("Select None");

//mask GFP regions for non-GFP dapi measurements
selectWindow("Dapi");
roiManager("Deselect");
roiManager("OR");
run("Clear");
run("Select None");

roiManager("Deselect");
roiManager("Delete");

//get nucleii (dapi+) in GFP+ region and measure
selectWindow("Dapi_GFP");
run("Analyze Particles...", "size=50-Infinity pixel exclude add");

selectWindow(analysis1_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
print(analysis1_name+" GFP nuclear,"+d2s(mean,3));
run("Select None");

selectWindow(analysis2_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
print(analysis2_name+" GFP nuclear,"+d2s(mean,3));
run("Select None");

roiManager("Deselect");
roiManager("Delete");

//get nucleii (dapi+) in GFP- region and measure
selectWindow("Dapi");
run("Analyze Particles...", "size=50-Infinity pixel add");

selectWindow(analysis1_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
print(analysis1_name+" Non-GFP nuclear,"+d2s(mean,3));

selectWindow(analysis2_name);
roiManager("Deselect");
roiManager("OR");
getStatistics(area,mean);
print(analysis2_name+" Non-GFP nuclear,"+d2s(mean,3));


roiManager("Deselect");
roiManager("Delete");

if (close_windows==1)
{
	close("Region")
	close(analysis1_name)
	close(analysis2_name)
	close("GFP_mask")
	close("Dapi")
	close("Dapi_GFP")
	close(name)
}

if (close_windows==2)
{
	close(image)
}

*/
function duplicate_channel(image,channel,title)
{
	selectWindow(image);
	run("Duplicate...", "title="+title+" duplicate channels="+channel );
}
