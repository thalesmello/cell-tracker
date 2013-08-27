var n_cells;
var first_slice, last_slice;
var markerSize = 10;
var x_cell, y_cell;
var storage, storage_id;
var x_maxima, y_maxima;
var selectionSize = 25;
var ACTIVE_THRESHOLD = 15;
var step;

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
	if(selectionType() != 10) //Point type
	{
		exit("You must mark the desired cell" +
			"with the Point Selection Tool");
	}
	start_slice = getSliceNumber();
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
	initialize();
	setBatchMode(true);
	for(slice = start_slice; slice!=end_slice+step; slice+=step)
	{
		setSlice(slice);
		for(i = 0; i<x_cell.length; i++)
		{
			computeCell(i);
		}
		showProgress(slice,nSlices);
	}
	setSlice(start_slice);
	run("Select None");
	loadTimelineResults();
	setBatchMode(false);
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
//Finds the closest centroid within a square of side "selectionSize".
//Returns "ERROR" if no maxima was found.
//Returns "OK" with closest maxima in (x_maxima,y_maxima)
function computeCell(cell_id){
	status = findClosestCentroid(
				x_cell[cell_id],
				y_cell[cell_id]);
	if(status == "OK")
	{
		run("Select None");
		doWand(x_maxima, y_maxima, 20.0, "Legacy");
		run("Clear Results");
		run("Set Measurements...",
			"area mean centroid shape redirect=None decimal=3");
		run("Measure");
		storeMeasurements(cell_id);
		intensity = getResult("Mean",0);
		if(intensity > ACTIVE_THRESHOLD)
		{
			x_cell[cell_id] = getResult("X",0);
			y_cell[cell_id] = getResult("Y",0);
		}
	}
	else if(status == "ERROR")
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
	makeRectangle(x-selectionSize/2,
		y-selectionSize/2,
		selectionSize,
		selectionSize);
	run("Find Maxima...", "noise=20 output=List");
	if(nResults == 0)
		return "ERROR";
	for(i=0;i<nResults;i++)
	{
		x_i = getResult("X",i);
		y_i = getResult("Y",i);
		dist = quadraticDistance(x_i,y_i,x,y);
		if(dist < dist_min)
		{
			x_min = x;
			y_min = y;
			dist_min = dist;
		}
	}
	x_maxima = x_min;
	y_maxima = y_min;
	return "OK";
}
function quadraticDistance(x1,y1,x2,y2)
{
	value = (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2);
	return value;
}
function storeMeasurements(cell_id)
{
	slice = getSliceNumber();
	keys = newArray("Area","Mean","Circ.");
	for(i=0; i<keys.length; i++)
	{
		value = getResult(keys[i],0);
		store(keys[i],value,getId(cell_id,slice));
	}
}
function storeNullMeasurements(cell_id)
{
	slice = getSliceNumber();
	keys = newArray("Area","Mean","Circ.");
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
			keys = newArray("Area","Mean","X","Y","Circ.");
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
