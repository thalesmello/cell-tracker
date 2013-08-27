macro "Crop Image of Cell Culture" {
    //Converting images to grayscale, for threshold to work
    run("8-bit");
    //Applying automatic threshold
    setAutoThreshold("Default");
    run("Convert to Mask");
    //Cleaning previous results from the table
    run("Clear Results");
    //Using Analyze particle to find out borders (biggest particles)
    //       -> using minimum area of 5000 to filter small results
    run("Analyze Particles...",
        "size=0-Infinity circularity=0.00-1.00 show=Nothing display");
    //Indexing area results in a list
    areaArray = newArray(nResults); 
    for(i = 0; i<nResults; i++)
    {
        areaArray[i] = getResult("Area", i);
    }
    //Ranking to find out the position of the biggest areas
    //       -> order is from the smallest to the biggest area
    rankArray = Array.rankPositions(areaArray);
    //Getting center of the first border
    x_center = getResult("X", rankArray[rankArray.length-1]);
    y_center = getResult("Y", rankArray[rankArray.length-1]);
    //Fitting rectangle that contains the border
    doWand(x_center,y_center);
    getSelectionBounds(x1, y1, width1, height1);
    //Analogous for the second border
    x_center = getResult("X", rankArray[rankArray.length-2]);
    y_center = getResult("Y", rankArray[rankArray.length-2]);
    doWand(x_center,y_center);
    getSelectionBounds(x2, y2, width2, height2);
    //Verifying if the point (x1,y1) is the one on the left side)
    //      -> Switches in case it isn't
    if(x1>x2)
    {
        aux = x1;
        x1 = x2;
        x2 = aux;
        aux = y1;
        y1 = y2;
        y2 = aux;
    }
    //Calculating position of points of the square to crop center field 
    x1 = x1 + width1;
    y2 = y2 + height2;
    //Reverting image to clear Threshold
    run("Revert");
    //Cropping image
    w = x2-x1;
    h = y2-y1;
    makeRectangle(x1, y1, w,h);
    run("Crop");
}
