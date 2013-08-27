var storage, storage_id;
var x_cell, y_cell, n_cells;
var regionStart, regionDelta, regionNum;
var maxima_slice, x_maxima, y_maxima;
var SELECTION_SIZE = 20, MAX_AREA = 100000, ACTIVE_INTENSITY = 8;
var first_slice, last_slice, num_slices;
var measure_keys = newArray("X","Y","Area","Mean","Circ.", "Max","Region");
var cell_status = newArray("AcquisitionOfDye");
var rectangle_x0, rectangle_y0, rectangle_w, rectangle_h;
var output_type = "Status";

macro "Cell Tracker [1]"
{
	//This Macro is expected to work in the fluorescent field
	
	//Verify if there is a rectangle selection active
	if(selectionType() != 0)
	{
		exit("You must select a rectangle on the area of cells you wish to track.");
	}
	//Calls dialog box for the input of parameters
	Dialog.create("Cell Tracker");
	Dialog.addNumber("Start Slice",getSliceNumber());
	Dialog.addNumber("End Slice", 1);
	Dialog.addChoice("Output type", newArray("Status","Timeline"), 0);
	Dialog.show();
	start = Dialog.getNumber();
	end = Dialog.getNumber();
	output_type = Dialog.getChoice();
	if(start < end) exit("This macro works only backwards");
	
	//Calls cell tracking function, where the magic happens
	trackCells(start,end);
}
function trackCells(start_slice, end_slice)
{
	//Set up variables and initialize everything that is necessary
	initialize(start_slice,end_slice);
	if(n_cells == 0) exit("There are no active cells selected");
	for(slice = last_slice; slice!=first_slice-1; slice--)
	{
		setSlice(slice);
		for(cell_id = 0; cell_id<n_cells; cell_id++)
		{
			//For each cell in each slice, runs computeCell
			computeCell(cell_id);
		}
		showProgress(last_slice-slice, num_slices);
	}
	setSlice(start_slice);
	run("Select None");
	
	//Output functions
	if(output_type == "Status") loadStatusResults();
	else if (output_type == "Timeline") loadTimelineResults();
}
//-------------------------------------------------------------------
// Initialization Functions
//-------------------------------------------------------------------
function initialize(start_slice,end_slice)
{
	ajustSlices(start_slice,end_slice);
	
	//Get information from the rectangle selection
	getSelectionBounds(rectangle_x0, rectangle_y0, rectangle_w, rectangle_h);
	setUpRegions(20,rectangle_x0,rectangle_x0+rectangle_w);
	
	//Does a pre-selection of cells
	findAndFilterCellCoordinates();
	
	//Set up storage arrays
	initializeStorage();
	initializeCellStatus();
}
function ajustSlices(start_slice,end_slice)
{
	//Ajusts slice variables
	first_slice = end_slice;
	last_slice = start_slice;
	num_slices = last_slice-first_slice+1;
}
function findAndFilterCellCoordinates()
{
	//Does a pre-selection of cells found by the find maxima function,
	//discarding the cells which it discards the cells which initially
	//don't have intensity higher than what is considered as the active
	//threshold used by the status analysis
	run("Find Maxima...", "noise=10 output=[Point Selection]");
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
	//Analysis functions: they are supposed to gather information from
	//the cell and put them in the results table, so the routine functions
	//can do other things with it
	analysisMeasureCell(cell_id);
	analysisComputeRegion(cell_id);
	
	//Rountine functions: they are supposed to read information about the
	//cell from the results table and do something useful with it. For instance,
	//store them for later use, update tracking coordinates and verify cell status.
	routineStoreMeasurements(cell_id);
	routineUpdateCellCoordinates(cell_id);
	rountineVerifyNextStatusId(cell_id);
}
function analysisMeasureCell(cell_id)
{
	xy = findClosestCentroidFasterMaxima(
				x_cell[cell_id],
				y_cell[cell_id]);
				
	//Verifies if a maxima point was found by the function
	if(xy[0] != -1)
	{
		//Verifies measures. If they are ok, the cell data is already in the results
		//table, so it's okay to leave the function.
		status = doWandCheckMeasures(xy[0], xy[1]);
		if(status == "OK") return;
	}
	
	//Tries to run analysis with the previous cells coordinates.
	//If it's okay, leave function.
	status = doWandCheckMeasures(x_cell[cell_id],y_cell[cell_id]);
	if(status == "OK") return;
	
	//If no data was found, set up null data in the results table, for the routine
	//functions to work properly
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
	//Tries to find the maxima point in the current slice that is
	//closest to the point (x,y) and is within the square of size
	//SELECTION_SIZE and centered in (x,y). If no point it found
	//that meets these criteria, the coordinate (-1,-1) is returned.
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
	//Verifies if the maxima points for the current slice are selected.
	//If they are, the function exits. Otherwise, it runs the find maxima
	//function in the current slice. This function is supposed to run only
	//once per slice in order to speed up the macro.
	if(getSliceNumber() != maxima_slice)
	{
		run("Select None");
		makeRectangle(rectangle_x0, rectangle_y0, rectangle_w, rectangle_h);
		run("Find Maxima...", "noise=10 output=[Point Selection]");
		getSelectionCoordinates(x_maxima, y_maxima);
		maxima_slice = getSliceNumber();
	}
}
function isInsideRect(x,y,x0,y0,w,h)
{
	//Simply verifies if the point (x,y) is inside the rectangle that starts
	//at (x0,y0) and has width w and height h.
	condition = (x0<x)&&(x<x0+w)&&(y0<y)&&(y<y0+h);
	return condition;
}
function quadraticDistance(x1,y1,x2,y2)
{
	//Computes the quadratic distance between (x1,y1) and (x2,y2)
	value = (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2);
	return value;
}
function routineUpdateCellCoordinates(cell_id)
{
	//Stores the new coordinates of the cell in the current slice
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
		//Sets up "NextStatusId" indicator as initially 0
		store("NextStatusId",0,id);
		//For every status of the cell_status array, puts
		//a -1 to indicate that status wasn't observed in
		//the cell
		for(j = 0; j<cell_status.length; j++)
		{
			store(cell_status[j],-1,id);
		}
	}
}
function rountineVerifyNextStatusId(cell_id)
{
	id = getStatusId(cell_id);
	next_status_id = load("NextStatusId",id);
	//If there is no next status in the cell_status array, it exits
	if(next_status_id >= cell_status.length) return;
	next_status = cell_status[next_status_id];
	//Below there are the rules to identify if the cell has acquired
	//the next_status or not
	if(next_status == "AcquisitionOfDye")
	{
		intensity = getResult("Mean",0);
		if(intensity > ACTIVE_INTENSITY) return;
	}
	//If the function gets to this point, it means that the cell should
	//advance to the next status
	next_status_id++;
	store("NextStatusId",next_status_id,id);
	store(next_status,getSliceNumber(),id);
	return;
}
//-------------------------------------------------------------------
// Storage Functions
//-------------------------------------------------------------------
function routineStoreMeasurements(cell_id)
{
	//This function stores all the measurements expresed in the array measure_keys
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
	//This function initializes the array storage to work with keys and values,
	//just like a Dictionaty or Map for each id. But the number of ids stored
	//in the array must be expressed in the variable num_ids.
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
	//Returns an unique id to be used for the storage of measurement data
	value = cell_id+(slice-first_slice)*n_cells;
	return value;
}
function getStatusId(cell_id)
{
	//Returns an unique id to be used for the storage of status data
	value = n_cells*num_slices + cell_id;
	return value;
}
function store(key,value,id)
{
	//Stores the pair (key,value) in the specified id
	changeList(id);
	List.set(key,value);
}
function load(key,id)
{
	//Loads the value related to the key in the specified id
	changeList(id);
	value = List.getValue(key);
	return value;
}
function changeList(id)
{
	//Function to switch the lists that are loaded in the system
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
	//Loads data output results in a "Timeline" mode
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
	//Loads data output results in a "Status" mode
	run("Clear Results");
	row = 0;
	for(cell_id = 0; cell_id<n_cells; cell_id++)
	{
		setResult("Cell", row, cell_id);
		pos_id = getId(cell_id,last_slice);
		x = load("X",pos_id);
		y = load("Y",pos_id);
		reg = load("Region", pos_id);
		setResult("X",row,x);
		setResult("Y",row,y);
		setResult("Region",row,reg);
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
// Region Functions
//-------------------------------------------------------------------
function setUpRegions(divisions, x1, x2)
{
	//Set variables to categorize them in regions from 0 to (divisions-1),
	//from the right to the left (the higher the region, the higher the drug concentration)
	//Division => number of divisions
	//x1 => left border of the cells area
	//x2 => right border of the cells area
	regionStart = x1;
	regionDelta = (x2-x1)/divisions;
	regionNum = divisions;
}
function getRegion(x)
{
	//Will compute the region of a cell given its x coordinate
	aux = (x-regionStart)/regionDelta*100;
	value = regionNum-1-(aux-aux%100)/100;
	return value;
}
function analysisComputeRegion(cell_id)
{
	//Computes region and stores it in the results table
	x = getResult("X",0);
	reg = getRegion(x);
	setResult("Region",0,reg);
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
