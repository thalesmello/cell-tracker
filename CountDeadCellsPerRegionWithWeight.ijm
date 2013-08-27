var divisions, region, region_x0, region_y0;
var region_delta, region_h, region_w, start_slice, end_slice;
var tolerance, bright_tolerance, n_slices, cells_array, total_array, file;
macro "Count Dead Cells [1]"
{
	//Verifies if a rectangle selection is active
	if(selectionType() != 0)
	{
		exit("You must select a rectangle of the area of analysis.");
	}
	
	//Batch mode to make algorithm run faster
	setBatchMode(true);
	
	//Calls Dialog Box to set parameters
	callDialogBox();
	
	//Open dialog box to select the output file
	file = File.open("");
	
	//Counts cells on the bright field
	readBrightField();
	
	//Open sequence in the fluorescent field
	openFluorescentField();
	
	//Reads regions on the fluorescent field
	readFluorescentField();
	
	//Prints the data to the output file
	printOutputFile();
	
	//Closes window of fluorescent sequence
	close();
	
	//Exits batch mode
	setBatchMode(false);
}
function callDialogBox()
{
	divisions = 5;
	Dialog.create("Cell Tracker");
	Dialog.addNumber("Start Slice",1);
	Dialog.addNumber("End Slice", nSlices);
	Dialog.addNumber("Num of Divisions", divisions);
	Dialog.addNumber("Fluorescent Field Noise", 10);
	Dialog.addNumber("Bright Field Tolerance",50);
	Dialog.show();
	//Getting the start and end slice numbers
	start_slice = Dialog.getNumber();
	end_slice = Dialog.getNumber();
	//Will make sure start_slice<=end_slice
	aux1 = start_slice;
	aux2 = end_slice;
	start_slice = minOf(aux1,aux2);
	end_slice = maxOf(aux1, aux2);
	divisions = Dialog.getNumber();
	tolerance = Dialog.getNumber();
	bright_tolerance = Dialog.getNumber();
	n_slices = end_slice-start_slice+1;
	cells_array = newArray(divisions*n_slices);
	total_array = newArray(divisions);
}
function readBrightField()
{
	getSelectionBounds(region_x0, region_y0, region_w, region_h);
	region_delta = region_w/divisions;
	prepareRegionReading(bright_tolerance);
	for(region = 0; region<divisions; region++)
	{
		total_cells = readRegion();
		total_array[region] = total_cells;
	}
}
function prepareRegionReading(tol)
{
	run("Clear Results");
	run("Select None");
	makeRectangle(region_x0,region_y0,region_w,region_h);
	run("Set Measurements...", "area mean min centroid shape redirect=None decimal=3");
	run("Find Maxima...", "noise=" + tol + " output=List");
}
function readRegion()
{
	count = 0;
	for(i=0; i<nResults; i++)
	{
		x = getResult("X",i);
		count = count + calculateRegionWeight(x);
	}
	return count;
}
function calculateRegionWeight(x)
{
	mu = region_x0+(divisions-region-1)*region_delta+region_delta/2;
	if(region==0 && x>mu) return 1;
	if(region==(divisions-1) && x<mu) return 1;
	delta = abs(mu-x);
	transition = region_delta/2;
	stable_delta = (region_delta-transition)/2;
	if(delta<=stable_delta){
		return 1;
	}
	else if(delta<=(region_delta+transition)/2)
	{
		x = delta-stable_delta;
		weight = 1-x/transition;
		return weight;
	}
	else
	{
		return 0;
	}
}
function openFluorescentField()
{
	path = getDirectory("image");
	path = File.getParent(path) + File.separator + "gfp" + File.separator;
	list = getFileList(path);
	run("Image Sequence...", "open=["+path+list[0]+"] number="+list.length+" starting=1 increment=1 scale=100 file=[] or=[] sort use");
}
function readFluorescentField()
{
	for(slice = start_slice; slice!=end_slice+1; slice++)
	{
		setSlice(slice);
		prepareRegionReading(tolerance);
		for(region = 0; region<divisions; region++)
		{
			dead_cells = readRegion();
			cells_array[region + divisions*(slice-start_slice)] = dead_cells;
		}
		showProgress(slice-start_slice+1,n_slices);
	}
}
function printOutputFile()
{
	print(file, cells_array.length);
	for(slice = start_slice; slice!=end_slice+1; slice++)
	{
		for(region = 0; region<divisions; region++)
		{
			dead_cells = cells_array[region + divisions*(slice-start_slice)];
			dead_cells_str = d2s(dead_cells,1);
			print(file,region);
			print(file,slice-1); //The -1 makes t0=0
			print(file,dead_cells_str);
		}
	}
	for(region = 0; region<divisions; region++)
	{
		dead_cells = cells_array[region + divisions*(end_slice-start_slice)];
		total_cells = total_array[region];
		live_cells = total_cells-dead_cells;
		live_cells_str = d2s(live_cells,1);
		print(file, live_cells_str);
	}
}
