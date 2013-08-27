var markerSize = 10;
var x_cell = 708;
var y_cell = 240;
var x_centroid, y_centroid;
var selectionSize = 25;
var ACTIVE_THRESHOLD = 15;
var cellDead, dyeReaction;
macro "Keeping Track of Cell"
{
	cellDead = false;
	dyeReaction = false;
	setBatchMode(true);
	loadFluorescentSequence();
	//Test with RE C1 1uMDOX 2012-06-01-17-38-44
	x_array = newArray(nSlices);
	y_array = newArray(nSlices);
	for(i = 1; i<=nSlices; i++)
	{
		setSlice(i);
		computeCell();
		x_array[i-1] = x_cell;
		y_array[i-1] = y_cell;
	}
	loadMergeSequence();
	for(i=1; i<=nSlices; i++)
	{
		setSlice(i);
		createMarker(x_array[i-1],y_array[i-1]);
	}
	setBatchMode(false);
}
macro "Keeping Track of Sellected Cell [1]"
{
	cellDead = false;
	dyeReaction = false;
	if(selectionType() != 10) //Point type
	{
		exit("You must mark the desired cell with the point tool");
	}
	print("Starting analysis...");
	getSelectionCoordinates(xCoordinates, yCoordinates);
	x_cell = xCoordinates[0];
	y_cell = yCoordinates[0];
	setBatchMode(true);
	//Test with RE C1 1uMDOX 2012-06-01-17-38-44
	x_array = newArray(nSlices);
	y_array = newArray(nSlices);
	for(i = 1; i<=nSlices; i++)
	{
		setSlice(i);
		computeCell();
		x_array[i-1] = x_cell;
		y_array[i-1] = y_cell;
	}
	for(i=1; i<=nSlices; i++)
	{
		setSlice(i);
		createMarker(x_array[i-1],y_array[i-1]);
	}
	setSlice(1);
	setBatchMode(false);
}

function loadMergeSequence()
{
	closeAllWindows();
	run("Image Sequence...", "open=[C:\\Documents and Settings\\mellote\\Desktop\\RE C1 1uMDOX 2012-06-01-17-38-44\\merge\\RE C1 1uMDOX 2012-06-01-17-38-44_merge_00000.JPG] number=79 starting=11 increment=10 scale=100 file=[] or=[] sort");
}
macro "Load Merge Sequence"
{
	loadMergeSequence();
}
function loadFluorescentSequence()
{
	closeAllWindows();
	run("Image Sequence...", "open=[C:\\Documents and Settings\\mellote\\Desktop\\RE C1 1uMDOX 2012-06-01-17-38-44\\gfp\\RE C1 1uMDOX 2012-06-01-17-38-44_GFP_00000.JPG] number=79 starting=11 increment=10 scale=100 file=[] or=[] sort");
}
macro "Load Fluorescent Sequence"
{
	loadFluorescentSequence();
}
function createMarker(x,y)
{
	setColor(255,255,255);
	fillRect(x-markerSize/2, y-markerSize/2, markerSize, markerSize);
	setColor(0,0,0);
	drawRect(x-markerSize/2, y-markerSize/2, markerSize, markerSize);
}
function closeAllWindows()
{
	while(nImages>0)
	close();
}
function computeClosestCentroid()
{
	status = findClosestCentroid();
	if(status == "OK")
	{
		x_cell = x_centroid;
		y_cell = y_centroid;
	}
}
//Finds the closest centroid within a square of side "selectionSize".
//Returns "ERROR" if no maxima was found.
//Returns "OK" if a maxima was found, with its coordinates in (x_centroid,y_centroid)
function findClosestCentroid()
{
	x_min = 0;
	y_min = 0;
	dist_min = quadraticDistance(x_min,y_min,x_cell,y_cell);
	makeRectangle(x_cell-selectionSize/2, y_cell-selectionSize/2, selectionSize, selectionSize);
	run("Find Maxima...", "noise=20 output=List");
	if(nResults == 0)
		return "ERROR";
	for(i=0;i<nResults;i++)
	{
		x = getResult("X",i);
		y = getResult("Y",i);
		dist = quadraticDistance(x,y,x_cell,y_cell);
		if(dist < dist_min)
		{
			x_min = x;
			y_min = y;
			dist_min = dist;
		}
	}
	x_centroid = x_min;
	y_centroid = y_min;
	return "OK";
}
function computeCell(){
	status = findClosestCentroid();
	if(status == "OK")
	{
		run("Select None");
		doWand(x_centroid, y_centroid, 20.0, "Legacy");
		run("Clear Results");
		run("Set Measurements...", "  mean centroid redirect=None decimal=3");
		run("Measure");
		intensity = getResult("Mean",0);
		if(intensity > ACTIVE_THRESHOLD)
		{
			x_cell = getResult("X",0);
			y_cell = getResult("Y",0);
			if(cellDead && !dyeReaction)
			{
				dyeReaction = true;
				print("Dye Reaction happened on slice",getSliceNumber());
			}
			return;
		}
	}
	if(!cellDead && !dyeReaction)
	{
		cellDead = true;
		print("Cell died on slice",getSliceNumber());
	}
}
function quadraticDistance(x1,y1,x2,y2)
{
	return (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2);
}
macro "Generate Mean Intensity Plot"
{
	n = newArray(nSlices);
	mean = newArray(nSlices);
	for(i = 0; i<nSlices; i++)
	{
		setSlice(i+1);
		n[i] = i+1;
		run("Select All");
		run("Clear Results");
		run("Measure");
		mean[i] = getResult("Mean",0);
	}
	Plot.create("Intensity of Stack", "Slice", "Avarage Intensity", n, mean);
}
