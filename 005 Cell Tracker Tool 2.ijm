var storage, storage_id;
var x_cell, y_cell, n_cells;
var first_slice, last_slice, step;
var maxima_slice, x_maxima, y_maxima;
var SELECTION_SIZE = 25, ACTIVE_THRESHOLD = 10, MAX_AREA = 100000;

macro "Cell Tracker [1]"
{
	Dialog.create("Cell Tracker");
	Dialog.addNumber("Start Slice",getSliceNumber());
	Dialog.addNumber("End Slice", nSlices);
	Dialog.show();
	start = Dialog.getNumber();
	end = Dialog.getNumber();
	trackCells(start,end);
}
function trackCells(start_slice, end_slice)
{
	if(selectionType() == 0)
	{
		run("Find Maxima...", "noise=10 output=[Point Selection]");
	}
	if(selectionType() != 10) //Point type
	{
		exit("You must mark the desired cell" +
			"with the Point Selection Tool");
	}
	ajustSlices(start_slice,end_slice);
	initialize();
	setBatchMode(true);
	for(slice = start_slice; slice!=end_slice+step; slice+=step)
	{
		setSlice(slice);
		for(i = 0; i<x_cell.length; i++)
		{
			computeCell(i);
		}
		if(step>0) showProgress(slice-first_slice,getNumSlices());
		else showProgress(last_slice-slice,getNumSlices());
	}
	setSlice(start_slice);
	run("Select None");
	loadTimelineResults();
	setBatchMode(false);
}
function ajustSlices(start_slice,end_slice)
{
	if(start_slice <= end_slice) step = 1;
	else step = -1;
	if(step > 0)
	{
		first_slice = start_slice;
		last_slice = end_slice;
	}
	else
	{
		first_slice = end_slice;
		last_slice = start_slice;
	}
}
function initialize()
{
	getSelectionCoordinates(x_cell, y_cell);
	n_cells = x_cell.length;
	
	storage = newArray(n_cells*getNumSlices());
	for(i=0; i<storage.length; i++)
	{
		storage[i] = "";
	}
	storage_id = -1;
}
function computeCellOrganized(cell_id)
{
	//Should locate closest maxima -> Leave all desired results in the Results table
	//Routines should take care of storing data/classify status/etc
}
function computeCell(cell_id){
	xy = findClosestCentroidFasterMaxima(
				x_cell[cell_id],
				y_cell[cell_id]);
	if(xy[0] != -1)
	{
		run("Select None");
		doWand(xy[0], xy[1], 10.0, "Legacy");
		run("Clear Results");
		run("Set Measurements...",
			"area mean min shape redirect=None decimal=3");
		run("Measure");
		area = getResult("Area",0);
		intensity = getResult("Mean",0);
		if(area < MAX_AREA)
		{
			x_cell[cell_id] = xy[0];
			y_cell[cell_id] = xy[1];
			storeMeasurements(cell_id);
		}
		else storeNullMeasurements(cell_id);
	}
	else
	{
		storeNullMeasurements(cell_id);
	}
	store("X",x_cell[i],getId(cell_id,getSliceNumber()));
	store("Y",y_cell[i],getId(cell_id,getSliceNumber()));
}
function shouldNotComputeCell(cell_id)
{
	value = cell_burst[cell_id] && fluorescent[cell_id];
	return value;
}
function findClosestCentroid(x,y)
{
	x_min = 0;
	y_min = 0;
	dist_min = quadraticDistance(x_min,y_min,x,y);
	makeRectangle(x-SELECTION_SIZE/2,
		y-SELECTION_SIZE/2,
		SELECTION_SIZE,
		SELECTION_SIZE);
	run("Find Maxima...", "noise=10 output=List");
	if(nResults == 0)
		return newArray(-1,-1);
	for(i=0;i<nResults;i++)
	{
		x_i = getResult("X",i);
		y_i = getResult("Y",i);
		dist = quadraticDistance(x_i,y_i,x,y);
		if(dist < dist_min)
		{
			x_min = x_i;
			y_min = y_i;
			dist_min = dist;
		}
	}
	xy = newArray(x_min,y_min);
	return xy;
}
function findClosestCentroidFasterMaxima(x,y)
{
	x_min = 0;
	y_min = 0;
	dist_min = quadraticDistance(x_min,y_min,x,y);
	updateMaximaCoordinates();
	found_point = false;
	for(i=0;i<x_maxima.length;i++)
	{
		x_i = x_maxima[i];
		y_i = y_maxima[i];
		if(isInsideRect(
			x_i,y_i,
			x-SELECTION_SIZE/2,
			y-SELECTION_SIZE/2,
			SELECTION_SIZE,
			SELECTION_SIZE))
		{
			found_point = true;
			dist = quadraticDistance(x_i,y_i,x,y);
			if(dist < dist_min)
			{
				x_min = x_i;
				y_min = y_i;
				dist_min = dist;
			}
		}
	}
	if(!found_point) return newArray(-1,-1);
	xy = newArray(x_min,y_min);
	return xy;
}
function updateMaximaCoordinates()
{
	if(getSliceNumber() != maxima_slice)
	{
		run("Select None");
		run("Find Maxima...", "noise=10 output=[Point Selection]");
		getSelectionCoordinates(x_maxima, y_maxima);
		maxima_slice = getSliceNumber();
	}
}
function isInsideRect(x,y,x0,y0,w,h)
{
	condition = (x0<x)&&(x<x0+w)&&(y0<y)&&(y<y0+h);
	return condition;
}
function quadraticDistance(x1,y1,x2,y2)
{
	value = (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2);
	return value;
}
function storeMeasurements(cell_id)
{
	slice = getSliceNumber();
	keys = newArray("Area","Mean","Circ.","Max");
	for(i=0; i<keys.length; i++)
	{
		value = getResult(keys[i],0);
		store(keys[i],value,getId(cell_id,slice));
	}
}
function storeNullMeasurements(cell_id)
{
	slice = getSliceNumber();
	keys = newArray("Area","Mean","Circ.", "Max");
	for(i=0; i<keys.length; i++)
	{
		store(keys[i],0,getId(cell_id,slice));
	}
}
function store(key,value,id)
{
	changeList(id);
	List.set(key,value);
}
function load(key,id)
{
	changeList(id);
	value = List.getValue(key);
	return value;
}
function getId(cell_id,slice)
{
	value = cell_id+(slice-first_slice)*n_cells;
	return value;
}
function changeList(id)
{
	if(id != storage_id)
	{
		if(storage_id != -1)
		{
			list = List.getList();
			storage[storage_id] = list;
		}
		list = storage[id];
		List.setList(list);
		storage_id = id;
	}
}
function loadTimelineResults()
{
	run("Clear Results");
	row = 0;
	for(cell_id = 0; cell_id<n_cells; cell_id++)
	{
		for(slice = first_slice; slice!=last_slice+1; slice++)
		{
			setResult("Cell", row, cell_id);
			setResult("Slice", row, slice);
			keys = newArray("Area","Mean","Max","X","Y","Circ.");
			for(i=0;i<keys.length;i++)
			{
				value = load(keys[i],getId(cell_id,slice));
				setResult(keys[i],row,value);
			}
			row++;
		}
	}
	updateResults();
}
function getNumSlices()
{
	num = last_slice-first_slice+1;
	return num;
}
function loadFluorescentSequence()
{
	run("Image Sequence...", "open=[C:\\Documents and Settings\\mellote\\Desktop\\E C1 2012-06-15-18-34-21\\gfp\\E C1 2012-06-15-18-34-21_GFP_00000.JPG] number=788 starting=1 increment=1 scale=100 file=[] or=[] sort use");}
macro "Load Fluorescent Sequence"
{
	loadFluorescentSequence();
}
