var markerSize = 10;
var x_cell;
var y_cell;
var x_array;
var y_array;
macro "Keeping Track of Cell"
{
	loadFluorescentSequence();
	//Test with RE C1 1uMDOX 2012-06-01-17-38-44
	//Defining position of cell that dies and then is colored by dye
	//Position in the first cell
	x_cell = 976;
	y_cell = 592;
	x_array = newArray(nSlices);
	y_array = newArray(nSlices);
	run("Make Binary", "calculate");
	run("Watershed", "stack");
	run("Set Measurements...", "area mean min centroid redirect=None decimal=3");
	for(i = 1; i<=nSlices; i++)
	{
		setSlice(i);
		run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Nothing display clear slice");
		findClosestCentroid();
		x_array[i-1] = x_cell;
		y_array[i-1] = y_cell;
	}
	loadMergeSequence();
	for(i=1; i<=nSlices; i++)
	{
		setSlice(i);
		createMarker(x_array[i-1],y_array[i-1]);
	}
	
}
function loadMergeSequence()
{
	closeAllWindows();
	run("Image Sequence...", "open=[C:\\Documents and Settings\\mellote\\Desktop\\RE C1 1uMDOX 2012-06-01-17-38-44\\merge\\RE C1 1uMDOX 2012-06-01-17-38-44_merge_00000.JPG] number=79 starting=10 increment=10 scale=100 file=[] or=[] sort");
}
macro "Load Merge Sequence"
{
	loadMergeSequence();
}
function loadFluorescentSequence()
{
	closeAllWindows();
	run("Image Sequence...", "open=[C:\\Documents and Settings\\mellote\\Desktop\\RE C1 1uMDOX 2012-06-01-17-38-44\\gfp\\RE C1 1uMDOX 2012-06-01-17-38-44_GFP_00000.JPG] number=79 starting=10 increment=10 scale=100 file=[] or=[] sort");
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
function findClosestCentroid()
{
	x_min = 0;
	y_min = 0;
	dist_min = quadraticDistance(x_min,y_min,x_cell,y_cell);
	for(i=0;i<nResults;i++)
	{
		x = getResult("X", i);
		y = getResult("Y", i);
		if(quadraticDistance(x,y,x_cell,y_cell) < dist_min)
		{
			x_min = x;
			y_min = y;
			dist_min = quadraticDistance(x_min,y_min,x_cell,y_cell);
		}
	}
	x_cell = x_min;
	y_cell = y_min;
}
function quadraticDistance(x1,y1,x2,y2)
{
	return (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2);
}
