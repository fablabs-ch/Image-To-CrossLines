/*
 * Images to CrossLine SVG
 * 
 */
// https://imagej.nih.gov/ij/developer/macro/functions.html
roiManager("Reset");


if(nImages == 0){ // ask to select an image if none open
	path  = File.openDialog("Select An Image");
	inputImage = File.getName(path);
	savingdir  = File.getParent(path);
	savingdir += File.separator;
	open(path);
} else{ // otherwise  get info from the current one
	inputImage = getTitle;
	savingdir  = File.directory;
}

// up to now, handle only 8-bit images
run("8-bit");

// get infos about the imageCalculator
inputImage = getTitle();
getDimensions(width, height, channels, slices, frames);
getVoxelSize(widthPixel, heightPixel, depthPixel, unitPixel);
getStatistics(areaImage, meanImage, minImage, maxImage, stdImage, histogramImage);
getStatistics(currentImageArea, currentImageMean, currentImageMin, currentImageMax,  currentImageStdDev, currentImageHistogram );
	

Dialog.create("CrossLine generator"); // popup window with parameters

Dialog.addMessage("# CutOff: from 0 to 255, value above will be 'transform' ") ;
Dialog.addNumber("CutOff", 100);
//Dialog.addMessage("---------------------------") ;

//Dialog.addMessage("---------------------------") ;
Dialog.addMessage("# Scale : from 0 to < 1 = dowscale, > 1 upscale") ;
Dialog.addNumber("Scale to original", 3);

//Dialog.addMessage("---------------------------") ;
Dialog.addMessage("# Relief Factor : 0 to 1 ; closer to 1 increase the relief effect") ;
Dialog.addNumber("Relief Factor", 0.01);

//Dialog.addMessage("---------------------------") ;
Dialog.addMessage("# Previous Line Factor: 0 to 1 ;\n closer to 1 increase space between a line and the previous one") ;
Dialog.addNumber("Previous Line Factor", 0.8);
//Dialog.addMessage("---------------------------") ;
Dialog.addMessage("# Plur or Minus: -1 will make the lines to ovelap, 1 will help to prevent it)") ;
Dialog.addNumber("Plur or Minus ", 1);
//Dialog.addMessage("---------------------------") ;
Dialog.addMessage("# Signal Density Cutoff : low value will make more lines ") ;
Dialog.addNumber("Signal Density Cutoff", currentImageMean / 3 );
Dialog.addMessage("#Closest lines, min=1, to create effect with signal density this value or a factor 3)") ;
Dialog.addNumber("Closest lines ", 2);

Dialog.addMessage("# The previous parameters will stretch the image verticaly \n scale up the x to compensate ") ;
Dialog.addNumber("corrFactor", 3);

//Dialog.addMessage("---------------------------") ;
Dialog.addCheckbox("Export SVG ?", false) ;

Dialog.show();

/*
scaleFinal			= 10		;
reliefFactor		= 0.02 	;
previousLineFactor	= 0.25 	;
spaceLineFactor		= 1 	; 
corrFactor			= 1.1	;
*/

cutoff 				= Dialog.getNumber();
scaleFinal 			= Dialog.getNumber();
reliefFactor 		= Dialog.getNumber();
previousLineFactor  = Dialog.getNumber();
plusOrMinus			= Dialog.getNumber();
signalDensityCutoff = Dialog.getNumber();
spaceLineFactor 	= Dialog.getNumber();
corrFactor			= Dialog.getNumber();
svgExport			= Dialog.getCheckbox();
setBatchMode(true);

// define output image
outputImage 		= "lineOf_"+inputImage;
newImage(outputImage, "8-bit white", width*corrFactor*scaleFinal, height*corrFactor*scaleFinal, 1);

// prepare some variables and arrays,
// we want to considerate the line above so we declare Current and Prev
xcoordPrev 		= Array.getSequence(width);
ycoordPrev 		= newArray(width);
Array.fill(ycoordPrev, 0);

xcoordCurrent 	= newArray(width);
ycoordCurrent 	= newArray(width);

currentLine	= newArray(width);
yI 		= 0	;
yIPrev	= 0 ;
while ( yI < height ){ // iterate the height of the image
	
	for (xI = 0 ; xI < width; xI ++ ){ // and every pixel per line
		selectImage(inputImage);
		currentLine[xI] 	= getPixel(xI,yI) ;
		xcoordCurrent[xI] 	= xI ;
		ycoordCurrent[xI]	= yI ;
		// take the position of yI but also of the previous line, plusOrMinus to overlap or not
		ycoordCurrent[xI]	+= ( ( ycoordPrev[xI]+plusOrMinus*(yIPrev)) * previousLineFactor); 
		// if the pixel value is above the cutoff value, we add the relief component 
		if (currentLine[xI] > cutoff) {
				ycoordCurrent[xI] 	+= (currentLine[xI] * reliefFactor);
		}
	}


	
	// create and scale up the ROI,
	// the corrFactor could be used to prevent vertical stretching of the output
	selectImage(outputImage);
	makeSelection("polyline", xcoordCurrent,ycoordCurrent );
	run("Scale... ", "x="+(scaleFinal*corrFactor)+" y="+scaleFinal);
	run("Fit Spline");
	Roi.setName("line"+yI);
	roiManager("Add");
	
	// to increment yI we would like to take into account the average intensity of the line
	// to male dense area with more lines
	 Array.getStatistics(currentLine, currentLineMin, currentLineMax, currentLineMean, currentLineStdDev );
	// if (currentLineMean > ( meanImage / 2) ){ // used for signal density
	if (currentLineMean > signalDensityCutoff ){ // replace lines above
		yI += spaceLineFactor;
	} else{
		yI += spaceLineFactor * 3 ;
	}
	// here we asign the current values to the array 'Prev' for the next step 
	xcoordPrev = xcoordCurrent;
	ycoordPrev = ycoordCurrent;
	yIPrev = yI ; // update yIPrev
}


message = "Done";
/////////////////////////////////////////////////// this part is to create the SVG

if (svgExport){
	txt = "";// initiate a text variable
	nR = roiManager("Count");// get the total number of created ROI (here the lines)

	for (i=0; i<nR; i++) {			// for all the ROIs
		roiManager("Select", i);	// select the ith ROI
		tmp = roiToSVGcoord();		// convert ROI to SVG (using function roiToSVGcoord )
		txt+=tmp;					// append to exiting txt
	}

	//	define the file to save
	savingPath 		= savingdir+File.separator+"output.svg";
	//	if the file already exists, add an incremental number to avoid overwriting
	if (File.exists(savingPath)){							
		fileList = getFileList(savingdir);					
		imageIndex = lengthOf(fileList);
		savingPath = savingdir+"output_"+imageIndex+".svg";
	}
	
	// Print data within f
	f = File.open(savingPath);
	print(f,"<svg width=\"1000px\" height=\"1000px\" viewBox=\"0 0 1000 1000\">"+txt+"</svg>");
	File.close(f);

	if (svgExport) message += " and SVG saved in "+savingdir;
}

// make an ouput 
selectImage(outputImage);
setBatchMode(false);
roiManager("Deselect");
roiManager("Set Color", "black");
roiManager("Set Line Width", 1);
roiManager("Show All");
	
showMessage(message);
//close();




function roiToSVGcoord() {
	getSelectionCoordinates(x, y); 
	//corr =2.83464;
	text = "<g><path d='m"; 
	x2 = y2 = 0; 
	for (i = 0; i < x.length; i++) { 
	        text = text + " " + ((x[i] - x2)) + "," + ((y[i] - y2)); 
	        x2 = x[i]; 
	        y2 = y[i]; 
	} 
	//text = text + " z' comp-op=\"xor\" /></g>"; 
	text = text + " ' /></g>"; 
	return text; 
}

