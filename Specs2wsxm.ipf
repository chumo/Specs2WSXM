#pragma rtGlobals=1		// Use modern global access method.

//HISTORY
// 14.10.2013 New button "make UNIQUE" to create a unique copy of an image, to be represented independently
// 28.08.2013 New button "Import WSXM image" to import an image directly from WSXM with JULIO lut color scale
// 01.04.2010 First release

// ISSUES
// There is a certain offset in the heights of the images converted from wsxm with respect to Image Anilysis.

//----------------------------------------------------------------------------------------------------------------------------------------------------------
//							Specs2wsxm v1
//----------------------------------------------------------------------------------------------------------------------------------------------------------
//					     		     April 2010
//
// 	Specs2wsxm is an IGOR PRO procedure that transforms a .mul file,
//	a .flm file or a .miv file from Specs STM into the separated images and point scans
//	(like IV curves) with the file format of nanotec WSXM program (www.nanotec.es).
//
//		The procedure is freeware in the hope that it will be useful,
// 	but without any warranty. I would be thankful for any suggestion,
// 	comment or bug fixing that could improve this code.
//
//		 	    email address:  jmb.jesus@gmail.com
//					(Jesœs Martínez Blanco)

//----------------------------------------------------------------------------------------------------------------------------------------------------------
//				STRUCTURES
//------------------------------------------------------------------------

Structure ImageHead
// Structure of the Image headers
	variable nr
	variable size
	variable xch
	variable ych
	variable zch
			
	variable yy
	variable mon
	variable dd
	variable hh
	variable mm
	variable ss

	variable xsize
	variable ysize
	variable xshift
	variable yshift
	variable zscale
	variable tilt
			
	variable speed
		
	variable bias
	variable current
	
	string sample
	string title
		
	variable postpr
	variable postd1
	variable constheight
	variable Currfac
	variable R_Nr
	variable unitnr
	variable version
			
	variable spare[16]
endStructure

//------------------------------------------------------------------------

Structure PntscHead
// Structure of the point scan headers
	variable size
	variable type
	variable time4scan
	
	variable minV
	variable maxV
	
	variable xPos
	variable yPos
	
	variable dz
	variable delay
	variable version
	variable indenDelay
	
	variable xPosEnd
	variable yPosEnd
	
	variable Vt_Fw
	variable It_Fw
	variable Vt_Bw
	variable It_Bw

	variable Lscan
endStructure

//----------------------------------------------------------------------------------------------------------------------------------------------------------
//				Prototype FUNCTIONS
//------------------------------------------------------------------------

Function actionPrototype(fname,refnum,jumpto,IH,PH,option)
// prototype function, which also will be executed in case any action function is provided in SweepFILE
	string fname
	variable refnum
	variable jumpto
	STRUCT ImageHead &IH
	STRUCT PntscHead &PH
	variable option 
	//	option 	// 0 for images (eventually with pointscans)
				// 1 for pointscans
				// 2 for cits
				// 3 for image DURING cits
				// 4 for average spectrum in cits
End

//----------------------------------------------------------------------------------------------------------------------------------------------------------

menu "Macros"
	"-"
	"SPECS 2 WSXM panel",mulListingPANEL()
end

//----------------------------------------------------------------------------------------------------------------------------------------------------------

Macro mulListingPANEL()
// creates the necessary waves and variables for creating the panel
	PauseUpdate; Silent 1	
	Dowindow mulselection
	if (V_Flag==1)	
		Dowindow/F mulselection
		abort
	endif
	
	NewDataFolder/O root:MUL
	variable/G root:MUL:numImg=1
	variable/G root:MUL:displayornot
	string/G root:MUL:foldername
	string/G root:MUL:fsuffix
	string/G root:MUL:selectedFile
	string/G root:MUL:infoIMG
	string/G root:MUL:infoPSC
	
	if (waveexists(root:MUL:ListaFiles)==0)
		make/O/T/N=0 root:MUL:ListaFiles
		make/O/N=0 root:MUL:ListaFilesNum
		make/O/W/N=0 root:MUL:data  // The modifier /W stands for signed 16 bits data, like the original SPECS data
		make/O/N=(2,2) root:MUL:Image2D
		make/O/N=(2,2) root:MUL:Image2D_aux
		make/O/N=1 root:MUL:DummySP=nan
		make/O/N=0 root:MUL:SpPosition_X,root:MUL:SpPosition_Y
	endif

	mulselection()
end

//----------------------------------------------------------------------------------------------------------------------------------------------------------

Window mulselection() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(21,49,277,533) as "file SELECTION"
	ListBox listaFiles,pos={11,52},size={115,422},proc=FilesSelector,frame=0
	ListBox listaFiles,listWave=root:MUL:ListaFiles,selWave=root:MUL:ListaFilesNum
	ListBox listaFiles,row= 41,mode= 9
	Button SelDir,pos={7,6},size={119,20},proc=MulSELECTOR,title="SELECT FOLDER"
	Button XInfo,pos={131,173},size={120,40},proc=ExtractInfo,title="Extract Info"
	Button WSXMconverter,pos={131,53},size={120,61},proc=Convert2WSXM,title="Convert selected\rto\rWSXM files"
	SetVariable foldername,pos={8,28},size={239,15},title=" "
	SetVariable foldername,labelBack=(56576,56576,56576)
	SetVariable foldername,value= root:MUL:foldername,noedit= 1
	CheckBox DispCheckBox,pos={151,125},size={77,16},proc=DisplayOption,title="\\Z12DISPLAY ?"
	CheckBox DispCheckBox,variable= root:MUL:displayornot
	Button ImportWSXMbutton,pos={132,305},size={119,58},proc=ImportWSXMimage,title="Import\rWSXM image"
EndMacro

//----------------------------------------------------------------------------------------------------------------------------------------------------------

Function MulSELECTOR(ctrlname): buttoncontrol 
// creates the list of specs files from a selected folder
	string ctrlname

	SVAR foldername=root:MUL:foldername
	
	// to select the folder with the data
	newPath/M="Select the folder with .mul, .flm or .miv files"/O/Q mulPath
	if (V_flag!=0)
		abort
	endif
	PathInfo mulPath
	foldername=S_path

	// creates the list of files
	string filelist=IndexedFile(mulPath,-1,".mul")
	filelist+=IndexedFile(mulPath,-1,".flm")
	filelist+=IndexedFile(mulPath,-1,".miv")

	make/O/T/N=(ItemsInList(filelist)) root:MUL:ListaFiles	
	make/O/N=(ItemsInList(filelist)) root:MUL:ListaFilesNum	
	wave/T ListaFiles=root:MUL:ListaFiles	
	wave ListaFilesNum=root:MUL:ListaFilesNum

	ListaFiles=StringFromList(p,filelist)
	ListaFilesNum=0
end

//------------------------------------------------------------------------

Function SweepFILE(fname,action)
// sweeps through the structure of fname and executes action in certain positions
string fname //name of the mul, flm or miv file, including the extension
string action //name of the fundtion to be executed for each sort of data (in case of invalid name, no action will be executed)

	FUNCREF actionPrototype F=$action

	wave data=root:MUL:data
	
	STRUCT ImageHead IH
	STRUCT PntscHead PH

	SVAR fsuffix=root:MUL:fsuffix
	
	variable refnum,jumpto
	variable nr,adr,num
	
	open/P=mulPath/R refnum as fname
	string extension=WhichExt(fname)

////////-- .miv files				
		if (cmpstr(extension,"miv")==0)
		
		////////-- header of the image BEFORE
			FSetPos refnum,jumpto
			ReadImageHead(refNum,IH)
			jumpto+=128
			
			//-- image BEFORE	
			fsuffix="BEFORE"
			F(fname,refnum,jumpto,IH,PH,0)
			jumpto+=IH.xch*IH.ych*2
			
		////////-- point scans of image BEFORE
			if (IH.unitnr > 0) // in case this image has point scans
			
					for (num=0;num<IH.unitnr;num+=1)
						
						//-- header of the pointscan
						FSetPos refnum,jumpto
						ReadPointScanHead(refNum,PH)		
						jumpto+=128
						
						//-- pointscan itself
						fsuffix="BEFORE_scan"+num2str(num+1)
						F(fname,refnum,jumpto,IH,PH,1)
						jumpto+=PH.size*2
						
					endfor

			endif
		
		////////--  I-V data grid*grid*ssize*2/128 blocks where  ssize=labl.spare[50] - Scan points, grid =labl.spare[51] - Grid points, space=labl.spare[52] - Spacing between points on grid

			F(fname,refnum,jumpto,IH,PH,2)
			jumpto+=IH.spare[4]*IH.spare[4]*IH.spare[3]*2

		////////-- header of the image DURING the scan
				FSetPos refnum,jumpto
				ReadImageHead(refNum,IH)
				jumpto+=128
		
			//-- image DURING	
				fsuffix="DURING"
				F(fname,refnum,jumpto,IH,PH,3)
				jumpto+=IH.xch*IH.ych*2

		////////-- Average Spectrum (doesn't seem to have a header)
				fsuffix="AVERAGE_scan"
				
				//--since this spectrum does not have a header, I provide these values 
				PH.type=15
				PH.size=IH.spare[3]
				PH.dz=IH.spare[7]
				
				F(fname,refnum,jumpto,IH,PH,4)
				jumpto+=IH.spare[3]*2
			
			//-- for returning value at the end of the function
			IH.nr=IH.spare[3]

								
////////-- .mul or .flm files				
		else // then it is .mul or .flm
			
			FStatus refNum	// To know the size of the file with V_logEOF

			if (cmpstr(extension,"mul")==0) // index part of .mul files. The information stored here is not documented.
				FBinRead/F=2 refNum, nr
				FBinRead/F=3 refNum, adr	

				jumpto+=128*adr
			endif
			
			do
			////////-- header of the image
				FSetPos refnum,jumpto
				ReadImageHead(refNum,IH)
				jumpto+=128
				
				//-- image itself
				fsuffix=num2str(IH.nr)
				F(fname,refnum,jumpto,IH,PH,0)
				jumpto+=IH.xch*IH.ych*2
			
			////////-- point scans of image 
				if (IH.unitnr > 0) // in case this image has point scans

					for (num=0;num<IH.unitnr;num+=1)
						
						//-- header of the pointscan
						FSetPos refnum,jumpto
						ReadPointScanHead(refNum,PH)		
						jumpto+=128
						
						//-- pointscan itself
						fsuffix=num2str(IH.nr)+"_scan"+num2str(num+1)	
						F(fname,refnum,jumpto,IH,PH,1)
						jumpto+=PH.size*2

					endfor

				endif

			while(jumpto<V_logEOF)
			
		endif
		
	close refnum
		
	return IH.nr // return this value, which will be used to determine the maximum number of images to display
	
End

//------------------------------------------------------------------------------------------

Function Convert2WSXM(ctrlName) : ButtonControl
// Converts specs files into WSXM files, to be saved in a subfolder
	String ctrlName
	
	variable i
	string fname
	
	//-- Take the list of selected files
	ControlInfo listaFiles
	WAVE/T ListaFiles=root:MUL:ListaFiles		
	WAVE ListaFilesNum=root:MUL:ListaFilesNum
	
	For (i=0;i<numpnts(ListaFiles);i+=1)

		if (ListaFilesNum[i]!=0)
			fname=ListaFiles[i]
	
			//-- Create folder to save WSXM created files
			PathInfo mulPath
			NewPath/C/O/Q filesWSXM  S_path+ReplaceString(".",fname,"~")
			
			//-- Export .mul, .flm or .miv files into WSXM files
			SweepFILE(fname,"ExportAsWSXM")

		endif
	
	endfor

end

//-----------------------------------------------------------------------

Function ExportAsWSXM(fname,refnum,jumpto,IH,PH,option) // function of type actionPrototype
// Will be called by SweepFILE several times depending on the kind of data to export.
	string fname
	variable refnum
	variable jumpto
	STRUCT ImageHead &IH
	STRUCT PntscHead &PH
	variable option
	
	SVAR fsuffix=root:MUL:fsuffix
	string FDataName
	
	switch(option)	// numeric switch
		case 0: // image
			FSetPos refnum,jumpto
			make/O/W/N=(IH.xch,IH.ych) root:MUL:data 
			FBinRead refNum, root:MUL:data

			FDataName=RemoveEnding(RemoveEnding(RemoveEnding(fname,".mul"),"flm"),".miv")+"#"+fsuffix+".stp"
			WriteWSXM_image(FDataName,IH,0)
			break
		case 1: // point scan
			FSetPos refnum,jumpto
			make/O/W/N=(PH.size) root:MUL:data 
			FBinRead refNum, root:MUL:data

			FDataName=RemoveEnding(RemoveEnding(RemoveEnding(fname,".mul"),"flm"),".miv")+"#"+fsuffix+".cur" //Poner quŽ tipo de scan es ()
			WriteWSXM_pointScan(FDataName,PH,IH,0)
			break
		case 2: // CITS
			// for the moment we dont export the IV matrix
			break
		case 3: // image DURING
			FSetPos refnum,jumpto
			make/O/W/N=(IH.xch,IH.ych) root:MUL:data 
			FBinRead refNum, root:MUL:data

			FDataName=RemoveEnding(RemoveEnding(RemoveEnding(fname,".mul"),"flm"),".miv")+"#"+fsuffix+".stp"
			WriteWSXM_image(FDataName,IH,0)
			break
		case 4: // average spectrum
			FSetPos refnum,jumpto		
			make/O/W/N=(IH.spare[3]) root:MUL:data 
			FBinRead refNum, root:MUL:data
			
			FDataName=RemoveEnding(RemoveEnding(RemoveEnding(fname,".mul"),"flm"),".miv")+"#"+fsuffix+".cur" //Poner quŽ tipo de scan es ()
			WriteWSXM_pointScan(FDataName,PH,IH,0)
			break
	endswitch

end

//------------------------------------------------------------------------

Function/S WhichExt(file)
// Determines the extension of the file (mul, flm or miv)
string file

return file[strlen(file)-3,strlen(file)-1]

end

//------------------------------------------------------------------------

Function ReadImageHead(refNum,IH)
// Reads the header of an image into the structure ImageHead
variable refNum
STRUCT ImageHead &IH

variable i
string car,carTOTAL

	FBinRead/F=2 refNum, IH.nr
	FBinRead/F=2 refNum, IH.size
	FBinRead/F=2 refNum, IH.xch
	FBinRead/F=2 refNum, IH.ych
	FBinRead/F=2 refNum, IH.zch
			
	FBinRead/F=2 refNum, IH.yy
	FBinRead/F=2 refNum, IH.mon
	FBinRead/F=2 refNum, IH.dd
	FBinRead/F=2 refNum, IH.hh
	FBinRead/F=2 refNum, IH.mm
	FBinRead/F=2 refNum, IH.ss

	FBinRead/F=2 refNum, IH.xsize
	FBinRead/F=2 refNum, IH.ysize
	FBinRead/F=2 refNum, IH.xshift
	FBinRead/F=2 refNum, IH.yshift
	FBinRead/F=2 refNum, IH.zscale
	FBinRead/F=2 refNum, IH.tilt
			
	FBinRead/F=2 refNum, IH.speed
			
	FBinRead/F=2 refNum, IH.bias
	FBinRead/F=2 refNum, IH.current

//	FReadLine/N=20 refNum, IH.sample
	//the following is necessary to avoid problems with certain escape characters
	carTOTAL=""
		for (i=0;i<20;i+=1)
			FReadLine/N=1 refNum, car
			if (cmpstr("\000",car)!=0 && cmpstr("\007",car)!=0 && cmpstr("\r",car)!=0)
				carTOTAL+=car
			endif
		endfor	
	IH.sample=carTOTAL

//	FReadLine/N=20 refNum, IH.title
	//the following is necessary to avoid problems with certain escape characters
	carTOTAL=""
		for (i=0;i<20;i+=1)
			FReadLine/N=1 refNum, car
			if (cmpstr("\000",car)!=0 && cmpstr("\007",car)!=0 && cmpstr("\r",car)!=0)
				carTOTAL+=car
			endif
		endfor	
	IH.title=carTOTAL
			
	FBinRead/F=2 refNum, IH.postpr
	FBinRead/F=2 refNum, IH.postd1
	FBinRead/F=2 refNum, IH.constheight
	FBinRead/F=2 refNum, IH.Currfac
	FBinRead/F=2 refNum, IH.R_Nr
	FBinRead/F=2 refNum, IH.unitnr
	FBinRead/F=2 refNum, IH.version
			
	for (i=0;i<16;i+=1)
		FBinRead/F=2 refNum, IH.spare[i]
	endfor

end

//------------------------------------------------------------------------

Function ReadPointScanHead(refNum,PH)
// Reads the header of a point scan into the structure PntscHead
variable refNum
STRUCT PntscHead &PH

	FBinRead/F=2 refNum, PH.size
	FBinRead/F=2 refNum, PH.type
	FBinRead/F=2 refNum, PH.time4scan
	
	FBinRead/F=2 refNum, PH.minV
	FBinRead/F=2 refNum, PH.maxV
	
	FBinRead/F=2 refNum, PH.xPos
	FBinRead/F=2 refNum, PH.yPos
	
	FBinRead/F=2 refNum, PH.dz
	FBinRead/F=2 refNum, PH.delay
	FBinRead/F=2 refNum, PH.version
	FBinRead/F=2 refNum, PH.indenDelay
	
	FBinRead/F=2 refNum, PH.xPosEnd
	FBinRead/F=2 refNum, PH.yPosEnd
	
	FBinRead/F=2 refNum, PH.Vt_Fw
	FBinRead/F=2 refNum, PH.It_Fw
	FBinRead/F=2 refNum, PH.Vt_Bw
	FBinRead/F=2 refNum, PH.It_Bw

	FBinRead/F=2 refNum, PH.Lscan

end

//------------------------------------------------------------------------

Function WriteWSXM_image(fname,IH,onlydisplay)
// writes in the hard disk or displays in Igor an Image
string fname
STRUCT ImageHead &IH
variable onlydisplay

wave data=root:MUL:data

  	//-- Calculate correction factor for the raw data
  	variable zcorrection// correction to apply to Z values depending on the gain
	switch(IH.zscale)
		case 5:
			zcorrection=10*(2^-9)
			break
		case 10:
			zcorrection=10*(2^-8)
			break
		case 20:
			zcorrection=10*(2^-7)
			break
		case 50:
			zcorrection=10*(2^-6+2^-8)
			break
		case 135:
			zcorrection=10*(2^-5+2^-6+2^-8+2^-9)
			break
	endswitch
	variable correction= (0.01) * zcorrection	
		//  (0.01): length scales are in 0.1 A units, so now values are in nm
		//  zcorrection: correction to apply to Z values depending on the Z voltage gain or amplification factor (IH.zscale)
			
  if (onlydisplay==1)
  	wave Image2D=root:MUL:Image2D

  	duplicate/O data,Image2D
	Redimension/D Image2D
  	variable imagecorrection=(-1) * correction //(-1): negative representation (bumps are more negative) 	
  	Image2D*= imagecorrection
  	
  	setscale/I x,0,IH.xsize,Image2D
  	setscale/I y,0,IH.ysize,Image2D
  	Label/W=displayfile/Z leftO, "y (A)"
  	Label/W=displayfile/Z bottomO, "x (A)"
  else

	data*=-1 //  (-1): negative representation (bumps are more negative)
	WaveStats/Q/Z data
	V_max*=correction
	V_min*=correction
	variable minZ=V_min
	variable maxZ=V_max
	variable amplitude=(maxZ-minZ)
	
  	//-- Reorder data so that the final one is horizontally mirrored respect to the original one
	Reverse/DIM=0 data
	
	//-- Generate Header
	string header=""
	
	header+="WSxM file copyright Nanotec Electronica"+"\n"
	header+="SxM Image file"+"\n"
	header+="Image header size: "+"\n"

	header+="\n"
	header+="[Control]"+"\n"
	header+="    Angle: "+Num2Str(IH.tilt)+"\n"
	header+="    Set Point: "+Num2Str(IH.current/100)+" nA"+"\n"// current in nanoAmperes
	header+="    Topography Bias: "+FormatLength(IH.bias/(-3276.8))+" V"+"\n" // bias in volts
	header+="    X Amplitude: "+Num2Str(IH.xsize/10)+" nm"+"\n" // xsize in nm
	header+="    X Offset: "+Num2Str(IH.xshift/10)+" nm"+"\n" // xshift in nm
	header+="    XY Gain: 1"	+"\n"
	header+="    Y Amplitude: "+Num2Str(IH.ysize/10)+" nm"+"\n" // xsize in nm
	header+="    Y Offset: "+Num2Str(IH.yshift/10)+" nm"+"\n" // yshift in nm
	header+="    Z Gain: 1"+"\n"
	header+="    X-Frequency: "+Num2Str(IH.ych/(IH.speed*1e-2))+" Hz"+"\n" // taken from speed

	header+="\n"
	header+="[General Info]"+"\n"
	header+="    Head type: STM"+"\n"
	header+="    Acquisition channel: Topography"+"\n"
	header+="    Acquisition primary channel: Topography"+"\n"
	header+="    Acquisition time: "+FormatDate(IH.dd,IH.mon,IH.yy)+", "+FormatTime(IH.hh,IH.mm,IH.ss)+"\n"
	header+="    Image processes: Converted"+"\n"
	header+="    Number of columns: "+num2str(IH.xch)+"\n"
	header+="    Number of rows: "+num2str(IH.ych)+"\n"
	header+="    Z Amplitude: "+FormatLength(amplitude)+" nm" +"\n"
	
	header+="\n"
	header+="[Miscellaneous]"+"\n"
 	header+="    Maximum: "+FormatLength(maxZ)+" nm" +"\n"
    	header+="    Minimum: "+FormatLength(minZ)+" nm" +"\n"
	header+="    Comments: Converted from SPECS files \\nusing Specs2wsxm.ipf \\nby Jesús Martínez Blanco.\\n\\n  SAMPLE="+IH.sample+"\\n  TITLE="+IH.title+"\n"
    
	header+="\n"
	header+="[Header end]"+"\n"
		
	//-- rewrite the third line with the number of bytes of the header
	variable headersize=strlen(header)
	headersize+=strlen(num2str(headersize))
	
	header=ReplaceString("Image header size: ",header,"Image header size: "+num2str(headersize))

	//-- save header and data to the hard disk
	variable refnum
	Open/P=filesWSXM refNum as fname
	fprintf refnum,"%s",header // careful here. header should have a maximum of 1000 characters.
	FBinWrite refNum, data
	close refnum

  endif
  
end

//------------------------------------------------------------------------

Function ImportWSXMimage(ctrlName) : ButtonControl
// Imports an image directly from WSXM with JULIO lut color scale
	String ctrlName

	variable refnum
	
	Open/F=".stp"/D/R/M="Select the WSXM image" refNum
	if (strlen(S_fileName)==0)
		Abort
	endif	
	
	string folder=ParseFilePath(1, S_fileName, ":", 1, 0)
	string filenm=ParseFilePath(0, S_fileName, ":", 1, 0)
	
	NewPath/O/Q WSXMsource, folder
	
	Open/R/P=WSXMsource refNum as filenm
	string buffer
	
	do
		FReadLine refNum, buffer
		
		if (strlen(buffer) == 0) // End of file
			break							
		endif
		
		if (stringmatch(buffer, "*Image header size*")==1)
			variable headersize=Numberbykey("Image header size",buffer,":")
		endif
		if (stringmatch(buffer, "*Number of columns*")==1)
			variable ncols=Numberbykey("    Number of columns",buffer,":")
		endif
		if (stringmatch(buffer, "*Number of rows*")==1)
			variable nrows=Numberbykey("    Number of rows",buffer,":")
		endif
		if (stringmatch(buffer, "*X Amplitude*")==1)
			variable xAmp=Numberbykey("    X Amplitude",buffer,":")
		endif
		if (stringmatch(buffer, "*Y Amplitude*")==1)
			variable yAmp=Numberbykey("    Y Amplitude",buffer,":")
		endif
	while(1)
	
	//convert filenm to a legal igor wave name
	filenm="im"+replacestring(".stp",replacestring("#",replacestring("-",filenm,""),"_"),"")
	
	//load the data into the wave
	make/O/D/N=(nrows,ncols) $filenm
	wave w=$filenm
	FSetPos refNum, headersize
	FBinRead refNum,w
	setscale/i x,xAmp,0,w
	setscale/i y,0,yAmp,w	
	
	//display
	CreatesJULIOlut(w)
	display
	AppendImage w
	ModifyGraph noLabel=2,axThick=0
	ModifyGraph margin=15
	ModifyGraph height={Plan,1,left,bottom}
	Execute/Q/Z "ModifyImage "+filenm+" cindex="+filenm+"_LUT"
	
	//scale bar
	SetDrawLayer UserFront
	SetDrawEnv xcoord= bottom,ycoord= left,linethick= 3,linefgc= (65535,65535,65535)
	DrawLine 5,163.462126742108,36.9296397855867,163.462126742108
	SetDrawEnv fsize= 20,fstyle= 1,textrgb= (65535,65535,65535)
	DrawText 0.0438356164383562,0.0876712328767123,"30 nm"

end

//------------------------------------------------------------------------

Function CreatesJULIOlut(w)
//Creates a JULIOlut color scale
wave w
	make/FREE Rx={0,32,94,152,188,255}
	make/FREE Ry={255,136,57,17,6,6}
	make/FREE Gx={0,17,47,106,182,232,255}
	make/FREE Gy={255,255,234,159,47,7,6}
	make/FREE Bx={0,85,160,220,255}
	make/FREE By={255,255,179,42,4}
	
	make/FREE/N=256 red,green,blue
	
	Interpolate2/T=1/N=256/Y=red Rx,Ry
	Interpolate2/T=1/N=256/Y=green Gx,Gy
	Interpolate2/T=1/N=256/Y=blue Bx,By
	
	red=round(red)
	green=round(green)
	blue=round(blue)
	
	red=red*65535/255
	green=green*65535/255
	blue=blue*65535/255

	make/O/n=(255,3) $(NameOfWave(w)+"_LUT")
	wave LUT=$(NameOfWave(w)+"_LUT")

	LUT[][0]=red[p]
	LUT[][1]=green[p]
	LUT[][2]=blue[p]
	
	LUT=65535-LUT[p][q]
	
	setscale/i x,wavemin(w),wavemax(w),LUT
	
end

//------------------------------------------------------------------------

Function MakeUniqueImage(ctrlName) : ButtonControl
// Creates a unique copy of an image, to be represented independently.
	String ctrlName

	wave Image2D=root:MUL:Image2D
	NVAR numImg=root:MUL:numImg
	SVAR selectedFile=root:MUL:selectedFile
	SVAR infoIMG=root:MUL:infoIMG
	
	string filenm=selectedFile
	
	//convert selectedFile to a legal igor wave name
	filenm="im"+replacestring(".flm",replacestring(".mul",replacestring("#",replacestring("-",filenm,""),"_"),""),"")+"_"+num2str(numImg)
	
	duplicate/O Image2D,$("root:"+filenm) 
	wave w=$("root:"+filenm) 
	
	//ad hoc ------- to recalibrate the image dimension according to piezo constants
	//variable dd=dimdelta(w,0)
	//setscale/p x,0,1.25*dd,w
	//setscale/p y,0,1.25*dd,w
	
	//display
	CreatesJULIOlut(w)
	display
	AppendImage w
	ModifyGraph noLabel=2,axThick=0
	ModifyGraph margin=15
	ModifyGraph height={Plan,1,left,bottom}
	Execute/Q/Z "ModifyImage "+filenm+" cindex="+filenm+"_LUT"
	ControlBar 60
	SetVariable setZmax,pos={1,26},size={87,15},proc=SetLUTcontrast,title="Zmax"
	SetVariable setZmax,limits={-inf,inf,0.05},value= _NUM:wavemax(w)
	SetVariable setZmin,pos={3,42},size={85,15},proc=SetLUTcontrast,title="Zmin"
	SetVariable setZmin,limits={-inf,inf,0.05},value= _NUM:wavemin(w)
	TitleBox ImParam,pos={2,2},size={73,21},title=infoIMG,fSize=10
	Button buttonFlatten,pos={90,25},size={67,32},proc=FlattenImage,title="FLATTEN"

	
	//scale bar
//	SetDrawLayer UserFront
//	SetDrawEnv xcoord= bottom,ycoord= left,linethick= 3,linefgc= (65535,65535,65535)
//	DrawLine 100,100,400,100
//	SetDrawEnv fsize= 20,fstyle= 1,textrgb= (65535,65535,65535)
//	DrawText 0.0438356164383562,0.0876712328767123,"30 nm"
	
End

//------------------------------------------------------------------------

Function SetLUTcontrast(ctrlName,varNum,varStr,varName) : SetVariableControl
// Changes the x scaling of the JulioLUT colorscale to span to the full Z range of the image.
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	string imageLUT=stringfromlist(0,ImageNameList("",";"))+"_LUT"
	wave LUT=$("root:"+imageLUT)
	
	controlinfo setZmin
	variable zmin=v_value
	controlinfo setZmax
	variable zmax=v_value

	setscale/i x,zmin,zmax,LUT

End

//------------------------------------------------------------------------

Function FlattenImage(ctrlName) : ButtonControl
// Flattens an STM image
	String ctrlName
	
	string image=stringfromlist(0,ImageNameList("",";"))
	wave w=$("root:"+image)
	
	variable np=DimSize(w, 0 )
	variable nc=DimSize(w, 1 )
	
	variable i

	for(i=0;i<nc;i+=1)
		imagestats/g={0,np-1,i,i} w
		w[][i]-=V_avg
	endfor

End

//------------------------------------------------------------------------

Function/S FormatLength(value)
// Returns a string with the formatted length so that it has 4 decimal places
// Useful to print in the header distances with good spatial resolution.
	variable value
	string fvalue
	sprintf fvalue, "%.4f", value
	return fvalue
end

//------------------------------------------------------------------------

Function WriteWSXM_pointScan(fname,PH,IH,onlydisplay)
// writes in the hard disk or displays in Igor a point scan
	string fname
	STRUCT PntscHead &PH
	STRUCT ImageHead &IH
	variable onlydisplay

	wave data=root:MUL:data

	//-- Create the X axis in the point scan and the dataScan which is in real values (not 16 bits signed integer like "data")
	make/O/N=(numpnts(data)) root:MUL:xaxis,root:MUL:dataScan
	wave xaxis=root:MUL:xaxis
	wave dataScan=root:MUL:dataScan

	variable scantime,scanheight,Vtstart,Vtstop,Itstart,Itstop,timestop,Zstart,Zstop
	variable timeperpoint,scanlength,angle,Xstart,Ystart,Lprofile
	string textType="",axislabels="",points=""
	
	variable zcorrection// correction to apply to Z values depending on the gain
	switch(IH.zscale)
		case 5:
			zcorrection=10*(2^-9)
			break
		case 10:
			zcorrection=10*(2^-8)
			break
		case 20:
			zcorrection=10*(2^-7)
			break
		case 50:
			zcorrection=10*(2^-6+2^-8)
			break
		case 135:
			zcorrection=10*(2^-5+2^-6+2^-8+2^-9)
			break
	endswitch
	
	//-- parameter assignment as a function of the point scan type:
	switch(PH.type)
	case 0:	// Z vs Vt
		textType="ZV curve file"
		axislabels="    X axis text: V [#x]\n    X axis unit: mV\n    Y axis text: Z [#y]\n    Y axis unit: nm"
		
		scantime=PH.time4scan // (19 ms units)
		Vtstart=PH.minV 
		Vtstop=PH.maxV
			xaxis=Vtstart+p*(Vtstop-Vtstart)/(PH.size-1)
			xaxis*=1000/(-3276.8)
	
			dataScan=data*0.01*zcorrection //(in nm)
		break
	case 1:	// Z vs It
		textType="Generic curve file"
		axislabels="    X axis text: I [#x]\n    X axis unit: nA\n    Y axis text: Z [#y]\n    Y axis unit: nm"
		
		scantime=PH.time4scan // (19 ms units)
		Itstart=PH.minV 
		Itstop=PH.maxV		
			xaxis=Itstart+p*(Itstop-Itstart)/(PH.size-1)
			xaxis*=IH.R_nr/(-3276.8)  
	
			dataScan=data*0.01*zcorrection //(in nm)
		break
	case 2:	// Z vs time
		textType="Generic curve file"
		axislabels="    X axis text: time [#x]\n    X axis unit: us\n    Y axis text: Z [#y]\n    Y axis unit: nm"
	
		scantime=PH.time4scan // (19 ms units)
		timestop=PH.maxV // (µs) timestart I suposse is 0
			xaxis=0+p*(timestop-0)/(PH.size-1)
	
			dataScan=data*0.01*zcorrection //(in nm)
		break
	case 3:	// It vs Vt
		textType="IV curve file"
		axislabels="    X axis text: V [#x]\n    X axis unit: mV\n    Y axis text: I [#y]\n    Y axis unit: nA"

		Vtstart=PH.minV
		Vtstop=PH.maxV	
			xaxis=Vtstart+p*(Vtstop-Vtstart)/(PH.size-1)
			xaxis*=1000/(-3276.8)
	
			dataScan=data*IH.R_nr/(-3276.8)
		break
	case 4:	// It vs Z
		textType="IZ curve file"
		axislabels="    X axis text: Z [#x]\n    X axis unit: nm\n    Y axis text: I [#y]\n    Y axis unit: nA"
	
		scanheight=PH.time4scan
		Zstart=PH.minV
		Zstop=PH.maxV
			xaxis=Zstart+p*(Zstop-Zstart)/(PH.size-1)
			xaxis*=0.01*zcorrection //(in nm)
	
			dataScan=data*IH.R_nr/(-3276.8)	
		break
//-- from case 5 to case 12, the acquisition program doesnt seem to give any of these
	case 5:	// Vt vs Z
		Zstart=PH.minV
		Zstop=PH.maxV
		break
	case 6:	// Vz vs Z
		Zstart=PH.minV
		Zstop=PH.maxV
		break
	case 7:	// It data for Time scan in I vs Z scan
		scanheight=PH.time4scan
		timeperpoint=PH.maxV  // (µs)
		break
	case 8:	// Vt data for Time scan in I vs Z scan
		timeperpoint=PH.maxV // (µs)
		break
	case 9:	// It data for Transverse scan in I vs Z scan
		scanheight=PH.time4scan
		scanlength=PH.minV
		angle=PH.maxV
		break
	case 10:	  // Vt data for Transverse scan in I vs Z scan
		scanlength=PH.minV
		angle=PH.maxV
		break
	case 11:	  // It data for Longitudinal scan in I vs Z scan
		scanheight=PH.time4scan
		scanlength=PH.minV
		break
	case 12:	  // Vt data for Longitudinal scan in I vs Z scan
		scanlength=PH.minV
		break
//----
	case 13:	  // Line scan
		textType="Profile curve file"
		axislabels="    X axis text: Distance [#x]\n    X axis unit: nm\n    Y axis text: Z [#y]\n    Y axis unit: nm"
				
		scantime=PH.time4scan // (19 ms units)
		Xstart=PH.minV
		Ystart=PH.maxV
		
		Lprofile=sqrt((PH.xPosEnd-Xstart)^2+(PH.yPosEnd-Ystart)^2)
		
			xaxis=0+p*(Lprofile-0)/(PH.size-1)
			xaxis*=0.01 //(in nm)
	
			dataScan=data*0.01*zcorrection //(in nm)

		points="    Point 0: ("+num2str(Xstart*0.01)+" nm, "+num2str(Ystart*0.01)+" nm)\n    Point 1: ("+num2str(PH.xPosEnd*0.01)+" nm, "+num2str(PH.yPosEnd*0.01)+" nm)"
		break
	case 14:	  // It vs Vt using Lock-In (very special option)
		textType="IV curve file"
		axislabels="    X axis text: V [#x]\n    X axis unit: mV\n    Y axis text: I [#y]\n    Y axis unit: nA" //diV maybe?
				
		Vtstart=PH.minV
		Vtstop=PH.maxV	
			xaxis=Vtstart+p*(Vtstop-Vtstart)/(PH.size-1)
			xaxis*=1000/(-3276.8)
	
			dataScan=data*IH.R_nr/(-3276.8)
		points="    Point 0: ("+num2str((IH.xsize*0.1/IH.xch)*PH.xPos*0.01)+" nm, "+num2str((IH.ysize*0.1/IH.ych)*PH.yPos*0.01)+" nm)"
		break
	case 15:	// It vs Vt: AVERAGE spectrum from .miv files 
		textType="IV curve file"
		axislabels="    X axis text: V [#x]\n    X axis unit: mV\n    Y axis text: I [#y]\n    Y axis unit: nA"
	
		Vtstart=IH.spare[1]
		Vtstop=IH.spare[2]
			xaxis=Vtstart+p*(Vtstop-Vtstart)/(PH.size-1)
			xaxis*=1000/(-409.6)  // I dont know why it is not 3276.8 (see miv-format.txt from specs)
	
			dataScan=data*IH.R_nr/(-3276.8)
		break
	endswitch
	
	
	if (onlydisplay==1)		
		make/O/N=(18) $("root:MUL:PS_H_"+fname) // header
			wave PSH=$("root:MUL:PS_H_"+fname)
		make/O/N=(PH.size) $("root:MUL:PS_"+fname+"_x") // x axis
			wave PSx=$("root:MUL:PS_"+fname+"_x")
		make/O/N=(PH.size) $("root:MUL:PS_"+fname+"_y") // y axis
			wave PSy=$("root:MUL:PS_"+fname+"_y")
		//-- store header info for future displaying		
		PSH[0]=PH.size
		PSH[1]=PH.type
		PSH[2]=PH.time4scan
		PSH[3]=PH.minV
		PSH[4]=PH.maxV
		PSH[5]=PH.xPos
		PSH[6]=PH.yPos
		PSH[7]=PH.dz
		PSH[8]=PH.delay
		PSH[9]=PH.version
		PSH[10]=PH.indenDelay
		PSH[11]=PH.xPosEnd
		PSH[12]=PH.yPosEnd
		PSH[13]=PH.Vt_Fw
		PSH[14]=PH.It_Fw
		PSH[15]=PH.Vt_Bw
		PSH[16]=PH.It_Bw
		PSH[17]=PH.Lscan
		//-- load data in pointscan waves
		PSx=xaxis
		PSy=dataScan

	else
		//-- Generate Header
		string header=""
	
		header+="WSxM file copyright Nanotec Electronica"+"\n"
		header+=textType+"\n"
		header+="Image header size: "+"\n"

		header+="\n"
		header+="[General Info]"+"\n"
		header+="    Number of lines: 1"+"\n"
		header+="    Number of points: "+num2str(PH.size)+"\n"
		header+=axislabels+"\n"
	
		header+="\n"
		header+="[Miscellaneous]"+"\n"
		if (PH.type==15)
			header+="    Comments: Converted from SPECS files \\nusing Specs2wsxm.ipf \\nby Jesús Martínez Blanco.\\n\\nAverage IV spectrum from .miv file.\\n\\nTip Height off setpoint="+Num2Str(PH.dz*0.1)+" Å"+"\n"
		else
			header+="    Comments: Converted from SPECS files \\nusing Specs2wsxm.ipf \\nby Jesús Martínez Blanco.\\n\\nPosition on image: pixelX="+Num2Str(PH.xPos)+" pixelY="+Num2Str(PH.yPos)+"\\n\\nTip Height off setpoint="+Num2Str(PH.dz*0.1)+" Å"+"\n"
		endif
		header+="    First Forward: Yes"+"\n"
	
		header+="\n"
		header+="[Points List]"+"\n"
		header+=points+"\n"
	    
		header+="\n"
		header+="[Header end]"+"\n"
		
		//-- rewrite the third line with the number of bytes of the header
		variable headersize=strlen(header)
		headersize+=strlen(num2str(headersize))
	
		header=ReplaceString("Image header size: ",header,"Image header size: "+num2str(headersize))

		//-- save header and data to the hard disk
		variable refnum
		Open/P=filesWSXM refNum as fname
		fprintf refnum,"%s",header // careful here. header should have a maximum of 1000 characters.
		wfprintf refNum, "%g %g\n" xaxis,dataScan
		close refnum	
	endif

end

//------------------------------------------------------------------------

Function/S FormatDate(dd,mon,yy)
// returns a string with the formatted date to be printed in the header of the WSXM file
variable dd,mon,yy
	string day=num2str(dd)
	string month=num2str(mon)

	if (strlen(day)<2)
		day="0"+day
	endif
	
	if (strlen(month)<2)
		month="0"+month
	endif
	
	return day+"/"+month+"/"+num2str(yy)
end

//------------------------------------------------------------------------

Function/S FormatTime(hh,mm,ss)
// returns a string with the formatted time to be printed in the header of the WSXM file
variable hh,mm,ss
	string hour=num2str(hh)
	string mins=num2str(mm)
	string secs=num2str(ss)

	if (strlen(hour)<2)
		hour="0"+hour
	endif
	
	if (strlen(mins)<2)
		mins="0"+mins
	endif
	
	if (strlen(secs)<2)
		secs="0"+secs
	endif
	
	return hour+":"+mins+":"+secs
end

//------------------------------------------------------------------------------------------

Function ExtractInfo(ctrlName) : ButtonControl
// Calls SweepFILE to extract info about images and pointscans.
	String ctrlName
	
	WAVE/T ListaFiles=root:MUL:ListaFiles		
	WAVE ListaFilesNum=root:MUL:ListaFilesNum
	
	wavestats/Q/Z ListaFilesNum
		if (V_sum>1)
			DoAlert 0, "You must select one and only one file from the list."
			abort
		endif
	FindLevel/P/Q ListaFilesNum, 1
	string fname=ListaFiles[V_LevelX]// This requieres that only one cell is selected

	print " "
	SweepFILE(fname,"WriteInfo")

end

//------------------------------------------------------------------------------------------

Function WriteInfo(fname,refnum,jumpto,IH,PH,option) // function of type actionPrototype
// Prints in the history area some information about images and scans within the corresponding Specs file
	string fname
	variable refnum
	variable jumpto
	STRUCT ImageHead &IH
	STRUCT PntscHead &PH
	variable option
	
	switch(option)	// numeric switch
		case 0: // image
			print "Image: "+num2str(IH.nr)+",  bias(V): "+num2str(IH.bias/-3276.8)+",  current(nA): "+num2str(IH.current/100)+" R_nr="+num2str(IH.R_nr) +", zscale="+num2str(IH.zscale)+", xshift="+num2str(IH.xshift)+", yshift="+num2str(IH.yshift)
			break
		case 1: // point scan
			print  "   pointscan of type "+num2str(PH.type)
			break
		case 2: // CITS
			print "CITS data of "+ num2str(IH.spare[4])+" x "+ num2str(IH.spare[4])+" spectra with "+num2str(IH.spare[3])+" points each"
			break
		case 3: // image DURING
			print "Image: "+num2str(IH.nr)+",  bias(V): "+num2str(IH.bias/-3276.8)+",  current(nA): "+num2str(IH.current/100)
			break
		case 4: // average scan
			print  "   pointscan of type "+num2str(PH.type)
			break
	endswitch
		
End

//------------------------------------------------------------------------------------------
//  DISPLAY functions
//------------------------------------------------------------------------------------------

Window displayfile() : Graph
	PauseUpdate; Silent 1		// building window...
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:MUL:
	Display /W=(317,47,880,537)/K=1 /L=LeftAux/B=BottomAux SpPosition_Y vs SpPosition_X as "DISPLAY selected file"
	AppendToGraph DummySP
	AppendImage/B=BottomO/L=LeftO Image2D
	ModifyImage Image2D ctab= {*,*,Gold,0}
	AppendImage/B=BottomAux/L=LeftAux Image2D_aux
	ModifyImage Image2D_aux ctab= {*,*,Gold,0}
	SetDataFolder fldrSav0
	ModifyGraph mode(SpPosition_Y)=3
	ModifyGraph marker(SpPosition_Y)=19
	ModifyGraph rgb(SpPosition_Y)=(65535,65535,65535)
	ModifyGraph msize(SpPosition_Y)=2
	ModifyGraph useMrkStrokeRGB(SpPosition_Y)=1
	ModifyGraph zero(left)=1
	ModifyGraph mirror(left)=0,mirror(bottom)=0
	ModifyGraph lblPos(LeftAux)=50,lblPos(BottomAux)=40,lblPos(left)=50,lblPos(bottom)=50
	ModifyGraph lblPos(LeftO)=50,lblPos(BottomO)=40
	ModifyGraph tkLblRot(LeftAux)=90,tkLblRot(LeftO)=90
	ModifyGraph freePos(LeftAux)={0.58,kwFraction}
	ModifyGraph freePos(BottomAux)={0.55,kwFraction}
	ModifyGraph freePos(LeftO)={0,kwFraction}
	ModifyGraph freePos(BottomO)={0.55,kwFraction}
	ModifyGraph axisEnab(LeftAux)={0.55,1}
	ModifyGraph axisEnab(BottomAux)={0.58,1}
	ModifyGraph axisEnab(left)={0,0.4}
	ModifyGraph axisEnab(LeftO)={0.55,1}
	ModifyGraph axisEnab(BottomO)={0,0.42}
	Label LeftAux "y (A)"
	Label BottomAux "x (A)"
	Label LeftO "y (A)"
	Label BottomO "x (A)"
	ShowInfo
	ControlBar 43
	ControlBar/L 80
	GroupBox groupIMAGE,pos={5,130},size={70,95},title="IMAGE"
	GroupBox groupIMAGE,labelBack=(65535,54611,49151)
	GroupBox groupSCAN,pos={5,231},size={70,138},title="SCAN"
	GroupBox groupSCAN,labelBack=(65535,54611,49151)
	SetVariable ImNUM,pos={24,148},size={50,19},proc=DisplayImageNr,title=" "
	SetVariable ImNUM,fSize=12,limits={1,35,1},value= root:MUL:numImg
	ValDisplay maxNumImages,pos={25,170},size={31,17},fSize=12,frame=0
	ValDisplay maxNumImages,limits={0,0,0},barmisc={0,1000},value= #"35"
	TitleBox title1,pos={9,171},size={12,16},title="\\Z12of",frame=0
	CheckBox checkPSpos,pos={8,251},size={61,36},proc=ShowPointScanPositions,title="Show\rPointScan\rpositions"
	CheckBox checkPSpos,value= 1
	SetVariable InfoImage,pos={1,1},size={529,19},title="IMAGE",fSize=12
	SetVariable InfoImage,value= root:MUL:infoIMG
	SetVariable InfoPScan,pos={1,21},size={529,19},title=" SCAN",fSize=12
	SetVariable InfoPScan,value= root:MUL:infoPSC
	CheckBox checkPolFit,pos={8,295},size={64,36},title="Make\rPolynomial\rfitting"
	CheckBox checkPolFit,value= 0
	CheckBox checkDeriv,pos={8,337},size={62,24},proc=CheckRedraw,title="Make\rDerivative"
	CheckBox checkDeriv,value= 0
	TitleBox title0,pos={8,148},size={13,16},title="\\Z12Nr",frame=0
	CheckBox checkPlane,pos={8,196},size={63,24},proc=CheckRedraw,title="Plane\rCorrection"
	CheckBox checkPlane,value= 0
	Button Import,pos={4,88},size={71,36},proc=GenPICTURE,title="generate\rPICTURE"
	Button Import,fColor=(49163,65535,32768)
	Button munique,pos={4,47},size={71,36},proc=MakeUniqueImage,title="make\rUNIQUE"
	Button munique,fColor=(16385,49025,65535)
	SetWindow kwTopWin,hook=DisplayHook,hookevents=1
EndMacro

//------------------------------------------------------------------------------------------

Function DisplayOption(ctrlName,checked) : CheckBoxControl
// shows or hides the display panel
	String ctrlName
	Variable checked
	
	if (checked==1)
		WAVE ListaFilesNum=root:MUL:ListaFilesNum
		wavestats/Q/Z ListaFilesNum
		if (V_sum>1)
			DoAlert 0, "You must select one and only one file from the list."
			abort
		endif
		
		Dowindow DisplayFile
		if (V_Flag==1)	
			Dowindow/F DisplayFile
		else
			Execute/Q/Z "displayfile()"
		endif
		
		FindLevel/P/Q ListaFilesNum, 1
		FilesSelector("",V_LevelX,0,4)	
	else
		DoWindow/K DisplayFile
	endif

End

//------------------------------------------------------------------------------------------

Function FilesSelector(ctrlName,row,col,event) : ListBoxControl
// Displays data relative to the selected file, in case the display checkbox is checked.
	String ctrlName
	Variable row
	Variable col
	Variable event	//1=mouse down, 2=up, 3=dbl click, 4=cell select with mouse or keys
					//5=cell select with shift key, 6=begin edit, 7=end
	NVAR don=root:MUL:displayornot
	
	if (event==4 && don==1)
	
		//-- Build Display window in case it was destroyed
		Dowindow DisplayFile
		if (V_Flag==1)	
			Dowindow/F DisplayFile
		else
			Execute/Q/Z "displayfile()"
		endif
		Dowindow/F mulselection
			
		//-- Store the name of the selected file, to be used somewhere else
		WAVE/T ListaFiles=root:MUL:ListaFiles	
		SVAR selectedFile=root:MUL:selectedFile
		selectedFile=ListaFiles[row]
		
		//-- Read Image Number until the end for .mul and .flm files, and the number of scan points for .miv files	
		string extension=WhichExt(ListaFiles[row])
		
		variable MAXnumImg
		
		if (cmpstr(extension,"miv")==0) // in this case, we also load the IV matrix in Igor, to be used in DisplayImageNr
			MAXnumImg=SweepFILE(ListaFiles[row],"ReadIVmatrix") 
		else // then it is .mul or .flm
			MAXnumImg=SweepFILE(ListaFiles[row],"")
		endif
		
		//-- Update panel	
		NVAR numImg=root:MUL:numImg	
		SetVariable ImNUM win=displayfile, limits={1,MAXnumImg,1}
		if (MAXnumImg<numImg)
			numImg=1
		endif
		Execute/Q/Z "ValDisplay maxNumImages win=displayfile, value="+num2Str(MAXnumImg)
		
		//-- Update DISPLAY panels
			// remove previous spectra from graph
			RemoveAllPS()
			// kill spectra from folder
			KillAllPS() 
			// display the image indicated by numImg
			DisplayImageNr("",numImg,"","")	
			
	endif
	
	return 0
End

//------------------------------------------------------------------------------------------

Function ReadOneImage(fname,refnum,jumpto,IH,PH,option) // function of type actionPrototype
// Reads the data of a single image within .mul or .flm files
	string fname
	variable refnum
	variable jumpto
	STRUCT ImageHead &IH
	STRUCT PntscHead &PH
	variable option 
	
	NVAR numImg=root:MUL:numImg
	WAVE image2D=root:MUL:image2D
	WAVE image2D_aux=root:MUL:image2D_aux
	
	WAVE SpPosition_X=root:MUL:SpPosition_X
	WAVE SpPosition_Y=root:MUL:SpPosition_Y
	
	if (IH.nr==numImg)
		// to count the number of point scans
		variable numPS=-1
		
		switch(option)	
			case 0: //-- Image
				// read the data
				FSetPos refnum,jumpto
				make/O/W/N=(IH.xch,IH.ych) root:MUL:data 
				FBinRead refNum, root:MUL:data
				// display the image
				WriteWSXM_image("",IH,1)
				duplicate/O image2D,image2D_aux
				Label/W=displayfile/Z leftAux, "y (A)"
			  	Label/W=displayfile/Z bottomAux, "x (A)"
				// set info
				SVAR infoIMG=root:MUL:infoIMG
				infoIMG="Bias= "+num2str(IH.bias/-3276.8)+" V;  Current= "+num2str(IH.current/100)+" nA;  Rot= "+num2str(IH.tilt)+" deg;  Size= "+num2str(IH.xsize)+" x "+num2str(IH.ysize)+" A^2"
				break
			case 1: //-- Point Scan
				FSetPos refnum,jumpto
				make/O/W/N=(PH.size) root:MUL:data 
				FBinRead refNum, root:MUL:data		
				//-- insert the spatial coordinates of this scan in the proper waves
				numPS=numpnts(SpPosition_X)
				InsertPoints numPS, 1, SpPosition_X, SpPosition_Y
				SpPosition_X[numPS]=DimOffset(image2D_aux, 0) + PH.xPos *DimDelta(image2D_aux,0)  // assuming that pixel numbering goes for instance from 0 to 255 (not from 1 to 256)
				SpPosition_Y[numPS]=DimOffset(image2D_aux, 1) + PH.yPos *DimDelta(image2D_aux,1)				
				//-- load this scan in waves	
				WriteWSXM_pointScan(num2str(numPS),PH,IH,1) // I use fname string to pass the pointscan number	
				break
		endswitch
	
		// set info
		SVAR infoPSC=root:MUL:infoPSC
		infoPSC="This image has "+num2str(numPS+1)+" point scans."
	endif
			
End

//------------------------------------------------------------------------------------------

Function ReadIVmatrix(fname,refnum,jumpto,IH,PH,option) // function of type actionPrototype
// Reads the data of a .miv file
	string fname
	variable refnum
	variable jumpto
	STRUCT ImageHead &IH
	STRUCT PntscHead &PH
	variable option 
	
	NVAR numImg=root:MUL:numImg
	WAVE image2D=root:MUL:image2D
	WAVE image2D_aux=root:MUL:image2D_aux
	
	WAVE SpPosition_X=root:MUL:SpPosition_X
	WAVE SpPosition_Y=root:MUL:SpPosition_Y
	
	switch(option)	
		case 2:  //-- CITS
			// read the data
			FSetPos refnum,jumpto
			make/O/W/N=(IH.spare[3],IH.spare[4],IH.spare[4]) root:MUL:data 
			wave data=root:MUL:data 
			FBinRead refNum, data
			// scale and transform in currents	
			Redimension/D data
			variable a=IH.spare[1]*1000/(-409.6)
			variable b=IH.spare[2]*1000/(-409.6)
			setscale/I x,a,b,data // I dont know why it is not 3276.8 (see miv-format.txt from specs)
			data/=(-3276.8)
			// creates an auxiliary wave with the x axis information to be used in DisplayHook
			make/o/n=(IH.spare[3]) root:MUL:SpAux
			wave SpAux=root:MUL:SpAux
			SpAux=a+p*(b-a)/(IH.spare[3]-1)
			// set info
			SVAR infoPSC=root:MUL:infoPSC
			infoPSC="CITS data of "+ num2str(IH.spare[4])+" x "+ num2str(IH.spare[4])+" spectra with "+num2str(IH.spare[3])+" points each, at a tip offset of "+num2str(IH.spare[7]*0.1)+" "
			break
		case 3: //-- for loading the image DURING (topography measured during the scan) into image2D_aux
			// read the data
			FSetPos refnum,jumpto
			make/O/W/N=(IH.xch,IH.ych) root:MUL:Image2D_aux 
			FBinRead refNum, root:MUL:Image2D_aux
			wave Image2D_aux=root:MUL:Image2D_aux
			// bumps are more negative
			Image2D_aux*= (-1)
		  	setscale/I x,0,IH.xsize,Image2D_aux
		  	setscale/I y,0,IH.ysize,Image2D_aux	  	
		  	// generate the grid of scan positions
			GenGrid(IH)
			// set info
			SVAR infoIMG=root:MUL:infoIMG
			infoIMG="Bias= "+num2str(IH.bias/-3276.8)+" V;  Current= "+num2str(IH.current/100)+" nA;  Rot= "+num2str(IH.tilt)+" deg;  Size= "+num2str(IH.xsize)+" x "+num2str(IH.ysize)+" A^2"
			//Apply image transformations in case it is required
			controlinfo/W=displayfile checkPlane
			if (V_Value==1)
				MakePlaneCorr("root:MUL:Image2D_aux")
			endif
			break
	endswitch
		
End

//------------------------------------------------------------------------------------------

Function DisplayImageNr(ctrlName,varNum,varStr,varName) : SetVariableControl
// Displays a particular image within a .mul or .flm file, or a particular energy cut within a CITS (.miv files)
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	WAVE/T ListaFiles=root:MUL:ListaFiles		
	WAVE ListaFilesNum=root:MUL:ListaFilesNum
		
	wavestats/Q/Z ListaFilesNum
		if (V_sum>1)
			DoAlert 0, "You must select one and only one file from the list."
			abort
		endif
	FindLevel/P/Q ListaFilesNum, 1
	string fname=ListaFiles[V_LevelX]// This requieres that only one cell is selected
	string extension=WhichExt(fname)		
			
	if (cmpstr(extension,"miv")==0)
		wave data=root:MUL:data
		variable gridX=DimSize(data,1)
		variable gridY=DimSize(data,2)
		make/O/N=(gridX,gridY) root:MUL:Image2D
		wave Image2D=root:MUL:Image2D
		Image2D=data[varNum-1][p][q]		
			SetScale/I x, 0, gridX-1,  Image2D
			SetScale/I y, 0, gridY-1,  Image2D
		  	Label/W=displayfile/Z leftO, "Grid Coord Y"
		  	Label/W=displayfile/Z bottomO, "Grid Coord X"
	else // then it is .mul or .flm
		//-- remove previous spectra from graph
		RemoveAllPS()
		//-- kill spectra from folder
		KillAllPS() 
		//-- reset SpPosition waves 
		make/O/N=0 root:MUL:SpPosition_X,root:MUL:SpPosition_Y
		//-- read a particular image with its point scans
		SweepFILE(fname,"ReadOneImage")
		//-- Apply image transformations in case it is required
		controlinfo/W=displayfile checkPlane
		if (V_Value==1)
			MakePlaneCorr("root:MUL:Image2D")
		endif
	endif
	
end

//------------------------------------------------------------------------------------------

Function MakePlaneCorr(wname)
// Substraction of a plane on the image wname
string wname

		String savedDF= GetDataFolder(1)
		SetDataFolder root:MUL
	
		Duplicate/O $wname,$(wname+"_fit")
		CurveFit/Q/N/NTHR=0 poly2D 1, $wname /D=$(wname+"_fit")
		
		wave W_coef
		wave Img=$wname
		Img-=W_coef[1]*x+W_coef[2]*y
		
		setdatafolder savedDF
end

//------------------------------------------------------------------------------------------

Function GenGrid(IH)
// Generates the grid of coordinates of the IV scans in a CITS
	STRUCT ImageHead &IH
	
	WAVE SpPosition_X=root:MUL:SpPosition_X
	WAVE SpPosition_Y=root:MUL:SpPosition_Y
	
	make/O/n=(IH.spare[4]*IH.spare[4]) root:MUL:SpPosition_X,root:MUL:SpPosition_Y

	variable i,j,c

	for (i=0;i<IH.spare[4];i+=1)
		for (j=0;j<IH.spare[4];j+=1)
			SpPosition_X[c]=i*IH.spare[5]
			SpPosition_Y[c]=j*IH.spare[5]
			c+=1
		endfor
	endfor

	//-- to center the grid, we need some offset
	SpPosition_X+=(IH.xch-IH.spare[5]*(IH.spare[4]-1))/2
	SpPosition_Y+=(IH.ych-IH.spare[5]*(IH.spare[4]-1))/2

	//-- to convert the grid units from pixels to Angstroms
	SpPosition_X*=IH.xsize/IH.xch
	SpPosition_Y*=IH.ysize/IH.ych
	
	//-- axis labels
	Label/W=displayfile/Z leftAux, "y (A)"
	Label/W=displayfile/Z BottomAux, "x (A)"

end

//------------------------------------------------------------------------------------------

Function DisplayHook (infoStr)
// this function executes when an action takes place on the displayfile panel
	String infoStr

	variable xpixel,ypixel
	string SpNr
	String event= StringByKey("EVENT",infoStr)
	variable modifiers= Str2Num(StringByKey("MODIFIERS",infoStr))
	
	// uncheck the display checkbox in the main panel if the display window is killed
	if  (cmpstr(event,"kill")==0)
		NVAR displayornot=root:MUL:displayornot
		displayornot=0
	endif
	
	if  (cmpstr(event,"mouseup")==0)

		xpixel=str2num(StringByKey("MOUSEX",infoStr))
		ypixel=str2num(StringByKey("MOUSEY",infoStr))
		SpNr=StringByKey("HITPOINT",TraceFromPixel(xpixel, ypixel, "ONLY:SpPosition_Y"))
 
		SVAR selectedFile=root:MUL:selectedFile
		string extension=WhichExt(selectedFile)
		
		// in the case of .miv files, you can also represent the pointscan clicking on the CITS energy cuts
		if (strlen(SpNr)==0 && cmpstr(extension,"miv")==0)
			wave Image2D=root:MUL:Image2D	
			variable ImX=round(AxisValFromPixel("displayfile", "BottomO", xpixel ))
			variable ImY=round( AxisValFromPixel("displayfile", "LeftO", ypixel ))
			if (ImX>=0 && ImX<DimSize(Image2D, 0) && ImY>=0 && ImY<DimSize(Image2D, 1))
				SpNr= num2str(ImY+DimSize(Image2D, 1)*ImX)
			endif
		endif
		
		wave SpAux=root:MUL:SpAux
				
		if (strlen(SpNr)!=0) // i.e., if we have clicked on a pointscan
			
			variable sptype
			
			//-- Do not remove the former/s spectra from the graph if Command (Macintosh ) or Ctrl (Windows ) is down.
			if (modifiers!=8)
				RemoveAllPS()
			endif
			
			if (cmpstr(extension,"miv")==0)	
				duplicate/O SpAux,$("root:MUL:PS_"+SpNr+"_x"),$("root:MUL:PS_"+SpNr+"_y")
				WAVE PS_x=$("root:MUL:PS_"+SpNr+"_x")
				WAVE PS_y=$("root:MUL:PS_"+SpNr+"_y")
	
				WAVE data=root:MUL:data
				variable nrows=dimsize(data,1)
				variable SpNumber=str2Num(SpNr)
				variable clm=mod(SpNumber,nrows)
				variable row=trunc(SpNumber/nrows)

				PS_y=data[p][row][clm]
				PS_x=SpAux
				
				RemoveFromGraph/Z $("PS_"+SpNr+"_y") // in case it existed already
				appendtograph PS_y vs PS_x
				
				// axis labels
				Label/W=displayfile/Z left, "Current (nA)"
				Label/W=displayfile/Z bottom, "Bias (mV)"				
			
				// for .miv files, the point scans are of type 3 (IV curves)
				sptype=3
				
			else // then it is .mul or .flm	
				WAVE PS_H=$("root:MUL:PS_H_"+SpNr)
				WAVE PS_x=$("root:MUL:PS_"+SpNr+"_x")
				WAVE PS_y=$("root:MUL:PS_"+SpNr+"_y")
				
				RemoveFromGraph/Z $("PS_"+SpNr+"_y") // in case it existed already
				appendtograph/Q PS_y vs PS_x
				
				// asign point scan type
				sptype=PS_H[1]
				
				// set info
				SVAR infoPSC=root:MUL:infoPSC
				string stype
				switch(sptype)
					case 0:
						stype="Z vs V"
						Label/W=displayfile/Z left, "Height (nm)"
						Label/W=displayfile/Z bottom, "Bias (mV)"	
						break				
					case 1:
						stype="Z vs I"
						Label/W=displayfile/Z left, "Height (nm)"
						Label/W=displayfile/Z bottom, "Current (nA)"	
						break	
					case 2:
						stype="Z vs time"
						Label/W=displayfile/Z left, "Height (nm)"
						Label/W=displayfile/Z bottom, "Time (µs)"	
						break	
					case 3:
						stype="I vs V"
						Label/W=displayfile/Z left, "Current (nA)"
						Label/W=displayfile/Z bottom, "Bias (mV)"	
						break	
					case 4:
						stype="I vs Z"
						Label/W=displayfile/Z left, "Current (nA)"
						Label/W=displayfile/Z bottom, "Height (nm)"	
						break	
					default:
						stype="Indeterminate"
						Label/W=displayfile/Z left, ""
						Label/W=displayfile/Z bottom, ""	
				endswitch
				infoPSC="Scan type= "+stype+";  Scan points= "+num2str(PS_H[0])+";  Tip Offset= "+num2str(PS_H[7]*0.1)+" A"
				
			endif
		
			//-- polynomial fitting to the spectrum (normally degree 10 is enough)
			controlinfo/W=displayfile checkPolFit
			if (V_Value==1)
				duplicate/O $("root:MUL:PS_"+SpNr+"_y"),$("root:MUL:PS_"+SpNr+"_fit")
				wave  PS_fit=$("root:MUL:PS_"+SpNr+"_fit")
				String savedDF= GetDataFolder(1)
				SetDataFolder root:MUL
				CurveFit/Q/N/NTHR=0 poly 15, $("root:MUL:PS_"+SpNr+"_y") /X=$("root:MUL:PS_"+SpNr+"_x") /D=$("root:MUL:PS_"+SpNr+"_fit")
				setdatafolder savedDF
			
				RemoveFromGraph/Z $("PS_"+SpNr+"_fit") // in case it existed already
				appendtograph/Q PS_fit vs PS_x
				ModifyGraph rgb($("PS_"+SpNr+"_fit"))=(0,0,65535)
			endif
			
			//-- derivative
			controlinfo/W=displayfile checkDeriv
			if (V_Value==1)
				if (cmpstr(note(PS_y),"derived")!=0)
					Differentiate $("root:MUL:PS_"+SpNr+"_y") /X=$("root:MUL:PS_"+SpNr+"_x")
					if (waveexists($("root:MUL:PS_"+SpNr+"_fit"))==1)
						Differentiate $("root:MUL:PS_"+SpNr+"_fit") /X=$("root:MUL:PS_"+SpNr+"_x")
					endif
					Note/K PS_y,"derived"
				endif
				switch(sptype)
					case 0:
						Label/W=displayfile/Z left, "dZ / dV (nm / mV)"
						Label/W=displayfile/Z bottom, "Bias (mV)"
						break				
					case 1:
						Label/W=displayfile/Z left, "dZ / dI (nm / nA)"
						Label/W=displayfile/Z bottom, "Current (nA)"
						break	
					case 2:
						Label/W=displayfile/Z left, "dZ / dt (nm / µs)"
						Label/W=displayfile/Z bottom, "Time (µs)"
						break	
					case 3:
						Label/W=displayfile/Z left, "dI / dV (nA / mV)"
						Label/W=displayfile/Z bottom, "Bias (mV)"
						break	
					case 4:
						Label/W=displayfile/Z left, "dI / dZ (nA / nm)"
						Label/W=displayfile/Z bottom, "Height (nm)"
						break	
					default:
						Label/W=displayfile/Z left, ""
						Label/W=displayfile/Z bottom, ""
				endswitch
			endif

		endif
		
	endif
	
	return 0				// 0 if nothing done, else 1 or 2
End

//------------------------------------------------------------------------------------------

Function RemoveAllPS()
// remove all waves of the form PS_* from the window displayfile
	
	string Tlist=TraceNameList("displayfile", ";", 1 )
	string PS
	variable numPS=ItemsInList(Tlist)
	variable i
	for (i=0;i<numPS;i+=1)
		PS=StringFromList(i, Tlist)
		if (cmpstr(PS[0,2],"PS_")==0)
			RemoveFromGraph $PS
		endif
	endfor

	Label/W=displayfile/Z left, ""
	Label/W=displayfile/Z bottom, ""
end

//------------------------------------------------------------------------------------------

Function KillAllPS()
// delete the spectra waves which are no longer needed from the data folder.
	String savedDF= GetDataFolder(1)
	SetDataFolder root:MUL
		string Slist=WaveList("PS_*",";", "")
		string PS
		variable numPS=ItemsInList(Slist)
		variable i
	
		for (i=0;i<numPS;i+=1)
			PS=StringFromList(i, Slist)
			Killwaves/Z $PS
		endfor
		
	SetDataFolder savedDF
end

//------------------------------------------------------------------------------------------

Function ShowPointScanPositions(ctrlName,checked) : CheckBoxControl
// Shows or hides the position of the point scans on the image.
	String ctrlName
	Variable checked

	if (checked==1)
		ModifyGraph zColor(SpPosition_Y)=0
	else
		ModifyGraph zColor(SpPosition_Y)={root:MUL:SpPosition_Y,-2,-1,Grays,0}
		ModifyGraph zColorMin(SpPosition_Y)=NaN
		ModifyGraph zColorMax(SpPosition_Y)=NaN
	endif

End

//------------------------------------------------------------------------------------------

Function CheckRedraw(ctrlName,checked) : CheckBoxControl
// Reload the data in the display window as you would select a file from the list.
	String ctrlName
	Variable checked
	
	WAVE ListaFilesNum=root:MUL:ListaFilesNum
	
	FindLevel/P/Q ListaFilesNum, 1
	
	FilesSelector("",V_LevelX,0,4)
	
	Dowindow/F DisplayFile
	
End

//------------------------------------------------------------------------------------------

Function GenPICTURE(ctrlName) : ButtonControl
// Generates an independent picture
	String ctrlName
		
	//-- determine the name of the picture
	string listpic=PICTList("WSXM_*",";","")
	variable i,mnum
	for (i=0;i<itemsinlist(listpic);i+=1)
		mnum=max(NumberByKey("WSXM", StringFromList(i, listpic), "_"),mnum)
	endfor
	string pictname="WSXM_"+num2str(mnum+1)

	//-- if the clipboard contains a picture, ask whether to load it from there
	loadpict/Z/Q "Clipboard"
	if (V_flag==1) // there is a picture in the clipboard
		DoAlert 1, "Do you want to use the picture in the clipboard?"
		if (V_flag==1) // "Yes" was clicked
			loadpict/Q "Clipboard",$pictname
		else // "Yes" was NOT clicked
			SavePICT/E=-5/B=144/WIN=displayfile/O/P=mulPath as "displayfile"
			loadpict/Q/P=mulPath "displayfile",$pictname
		endif
	else // there isn't a picture in the clipboard
		SavePICT/E=-5/B=144/WIN=displayfile/O/P=mulPath as "displayfile"
		loadpict/Q/P=mulPath "displayfile",$pictname	
	endif
	
	//-- Display clipboard image with STM parameters taken from info panel	
	variable pWidth=str2num(StringByKey("PHYSWIDTH",PICTInfo(pictname),":",";")) 
	variable pHeight=str2num(StringByKey("PHYSHEIGHT",PICTInfo(pictname),":",";"))
	
	NVAR numImg=root:MUL:numImg
	SVAR selectedFile=root:MUL:selectedFile
	SVAR infoIMG=root:MUL:infoIMG
	SVAR infoPSC=root:MUL:infoPSC
	
	variable tilt= numberbykey("Rot=",infoIMG," "," ")
	variable voltage= numberbykey("Bias=",infoIMG," "," ")
	variable current=  numberbykey("Current=",infoIMG," "," ")
	variable xsize= numberbykey("Size=",infoIMG," "," ")
	variable ysize= numberbykey("x",infoIMG," "," ")
	
	Display/K=1/W=(250,   70,   250+pWidth,   70+pHeight+(20+45)*0.925)	// 0.925 is an empirical factor to make the picture fitting in the window
	ModifyGraph gbRGB=(49152,65280,32768)
	TextBox/N=text0/F=0/B=1/A=LT/X=1/Y=1 "\\Z12"+selectedFile+"  \f02\f03Image "+num2str(numImg)+"\f00  R="+num2str(tilt)+" deg\r  "+num2str(voltage)+" V    "+num2str(current)+" nA    "+num2str(xsize)+" x "+num2str(ysize)+" A\S2"
	SetDrawLayer UserBack
	SetDrawEnv xcoord= abs,ycoord= abs
	DrawPICT 0,45,1,1,$pictname
	SetDrawLayer UserFront
	ControlBar 20
	Button SaveClipBoard,pos={2,2},size={122,17},proc=SaveToClip,title="Save to Clipboard"
	
End

//------------------------------------------------------------------------------------------

Function SaveToClip(ctrlName) : ButtonControl
// Saves the picture in the clipboard
	String ctrlName
	SavePICT/E=-5/B=144/M as "Clipboard"
End




