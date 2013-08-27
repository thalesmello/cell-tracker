var storage, storage_id;
var x_cell, y_cell, n_cells;
var maxima_slice, x_maxima, y_maxima;
var SELECTION_SIZE = 20, MAX_AREA = 100000, ACTIVE_INTENSITY = 8;
var first_slice, last_slice, num_slices;
var measure_keys = newArray("X","Y","Area","Mean","Circ.", "Max");
var cell_status = newArray("AcquisitionOfDye");

macro "Cell Tracker [1]"
{
	Dialog.create("Cell Tracker");
	Dialog.addNumber("Start Slice",getSliceNumber());
	Dialog.addNumber("End Slice", 1);
	Dialog.show();
	start = Dialog.getNumber();
	end = Dialog.getNumber();
	if(start < end) exit("This macro works only backwards");
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
	initialize(start_slice,end_slice);
	if(n_cells == 0) exit("There are no active cells selected");
	for(slice = last_slice; slice!=first_slice-1; slice--)
	{
		setSlice(slice);
		for(i = 0; i<n_cells; i++)
		{
			computeCell(i);
		}
		showProgress(last_slice-slice, num_slices);
	}
	setSlice(start_slice);
	run("Select None");
	loadStatusResults();
}
//-------------------------------------------------------------------
// Initialization Functions
//-------------------------------------------------------------------
function initialize(start_slice,end_slice)
{
	ajustSlices(start_slice,end_slice);
	
	findAndFilterCellCoordinates();
	
	initializeStorage();
	initializeCellStatus();
}
function ajustSlices(start_slice,end_slice)
{
	first_slice = end_slice;
	last_slice = start_slice;
	num_slices = last_slice-first_slice+1;
}
function findAndFilterCellCoordinates()
{
	getSelectionCoordinates(x_init, y_init);
	n = x_init.length;
	n_cells = 0;
	x_cell = newArray(n);
	y_cell = newArray(n);
	for(i = 0; i<n; i++)
	{
		status = doWandCheckMeasures(x_init[i],y_init[i]);
		intensity = getResult("Mean",0);
		if(status == "OK" && intensity >= ACTIVE_INTENSITY)
		{
			x_cell[n_cells] = x_init[i];
			y_cell[n_cells] = y_init[i];
			n_cells++;
		}
	}
}
//-------------------------------------------------------------------
// Computation Functions
//-------------------------------------------------------------------
function computeCell(cell_id)
{
	measureCell(cell_id);
	storeMeasurements(cell_id);
	updateCellCoordinates(cell_id);
	verifyNextStatus(cell_id);
}
function measureCell(cell_id)
{
	xy = findClosestCentroidFasterMaxima(
				x_cell[cell_id],
				y_cell[cell_id]);
	if(xy[0] != -1)
	{
		status = doWandCheckMeasures(xy[0], xy[1]);
		if(status == "OK") return;
	}
	
	status = doWandCheckMeasures(x_cell[cell_id],y_cell[cell_id]);
	if(status == "OK") return;
	
	setNullResults(cell_id);
}
function doWandCheckMeasures(x,y)
{
	run("Select None");
	doWand(x, y, 10.0, "Legacy");
	run("Clear Results");
	run("Set Measurements...",
		"area mean min shape redirect=None decimal=3");
	run("Measure");
	area = getResult("Area",0);
	if(area < MAX_AREA)
	{
		setResult("X",0,x);
		setResult("Y",0,y);
		return "OK";
	}
	return "ERROR";
}
function setNullResults(cell_id)
{
	run("Clear Results");
	keys = measure_keys;
	for(i = 0; i<keys.length; i++)
	{
		setResult(keys[i],0,0);
	}
	setResult("X",0,x_cell[cell_id]);
	setResult("Y",0,y_cell[cell_id]);
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
function updateCellCoordinates(cell_id)
{
	x_cell[cell_id] = getResult("X",0);
	y_cell[cell_id] = getResult("Y",0);
}
//-------------------------------------------------------------------
// Status Functions
//-------------------------------------------------------------------

function initializeCellStatus()
{
	for(i = 0; i<n_cells; i++)
	{
		id = getStatusId(i);
		store("NextStatus",0,id);
		for(j = 0; j<cell_status.length; j++)
		{
			store(cell_status[j],-1,id);
		}
	}
}
function verifyNextStatus(cell_id)
{
	id = getStatusId(cell_id);
	status_id = load("NextStatus",id);
	if(status_id >= cell_status.length) return;
	next_status = cell_status[status_id];
	if(next_status == "AcquisitionOfDye")
	{
		intensity = getResult("Mean",0);
		if(intensity > ACTIVE_INTENSITY) return;
		status_id++;
		store("NextStatus",status_id,id);
		store(next_status,getSliceNumber(),id);
		return;
	}
}
//-------------------------------------------------------------------
// Storage Functions
//-------------------------------------------------------------------
function storeMeasurements(cell_id)
{
	slice = getSliceNumber();
	keys = measure_keys;
	for(i=0; i<keys.length; i++)
	{
		value = getResult(keys[i],0);
		store(keys[i],value,getId(cell_id,slice));
	}
}
function initializeStorage()
{
	num_ids = n_cells*num_slices + n_cells;
	storage = newArray(num_ids);
	for(i=0; i<storage.length; i++)
	{
		storage[i] = "";
	}
	storage_id = -1;
}
function getId(cell_id,slice)
{
	value = cell_id+(slice-first_slice)*n_cells;
	return value;
}
function getStatusId(cell_id)
{
	value = n_cells*num_slices + cell_id;
	return value;
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
}
//-------------------------------------------------------------------
// Result Functions
//-------------------------------------------------------------------
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
			keys = measure_keys;
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
function loadStatusResults()
{
	run("Clear Results");
	row = 0;
	for(cell_id = 0; cell_id<n_cells; cell_id++)
	{
		setResult("Cell", row, cell_id);
		pos_id = getId(cell_id,last_slice);
		x = load("X",pos_id);
		y = load("Y",pos_id);
		setResult("X",row,x);
		setResult("Y",row,y);
		id = getStatusId(cell_id);
		keys = cell_status;
		for(i=0;i<keys.length;i++)
		{
			value = load(keys[i],getStatusId(cell_id));
			setResult(keys[i],row,value);
		}
		row++;
	}
}
//-------------------------------------------------------------------
// Development Functions
//-------------------------------------------------------------------
function loadFluorescentSequence()
{
	run("Image Sequence...", "open=[C:\\Documents and Settings\\mellote\\Desktop\\E C1 2012-06-15-18-34-21\\gfp\\E C1 2012-06-15-18-34-21_GFP_00000.JPG] number=290 starting=1 increment=1 scale=50 file=[] or=[] sort");
};
macro "Load Fluorescent Sequence"
{
	loadFluorescentSequence();
}
function loadMergeSequence()
{
	run("Image Sequence...", "open=[C:\\Documents and Settings\\mellote\\Desktop\\E C1 2012-06-15-18-34-21\\merge\\E C1 2012-06-15-18-34-21_merge_00000.JPG] number=290 starting=1 increment=1 scale=50 file=[] or=[] sort");
};
macro "Load Merge Sequence"
{
	loadMergeSequence();
}
function closeAllWindows()
{
	while(nImages>0)
	close();
}
function validateVisually()
{
	closeAllWindows();
	loadMergeSequence();
	for(slice = first_slice; slice!=last_slice+1; slice++)
	{
		for(cell_id = 0; cell_id<n_cells; cell_id++)
		{
			setSlice(slice);
			x = load("X",getId(cell_id,slice));
			y = load("Y",getId(cell_id,slice));
			createMarker(x,y);
		}
	}
	setSlice(1);
}
function createMarker(x,y)
{
	markerSize = 4;
	setColor(255,255,255);
	fillRect(x-markerSize/2, y-markerSize/2, markerSize, markerSize);
	setColor(0,0,0);
	drawRect(x-markerSize/2, y-markerSize/2, markerSize, markerSize);
}
macro "Run Confirmation"
{
	closeAllWindows();
	loadFluorescentSequence();
	setSlice(290);
	makeRectangle(173, 71, 325, 410);
	trackCells(290, 1);
	validateVisually();
}
