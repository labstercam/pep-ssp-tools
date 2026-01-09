'                          SOE Module - Photometry
'                                      Optec, Inc.
'
'======version history
'
'V2.56, November 2015
'    added PPparms3
'
'V2.53, September 2015
'    added save plot graphic
'
'V2.52, September 2015
'    compiled with LB 4.50
'
'V2.50, October, 2014
'    added Sloan filters
'
'V2.41, September 29, 2013
'    expanded IREX logging
'    changed color of red and blue text boxes
'
'V2.40, September 2013
'    added heliocentric JD and modified PPparms file
'
'V2.30, March 2013
'
'
'=====dimension statements and initial conditions
'
    DIM info$(10,10)
    files "c:\", info$()

' display listbox arrays
'
    DIM SOEData$(200)                   'data lines from reduced RAW data, index var = SOEDataIndex
        SOEData$(1) = "   "             'cannot use listbox unless something is put in before creation

    DIM SOEColorBlue(200)               '(b - v) instrument colorindex for blue star, index var = SOEDataIndex
    DIM SOEColorRed(200)                '(b - v) instrument colorindex for red star, index var = SOEDataIndex

    DIM SOEdeltaBV(200)                 'delta(b - v), index var = SOEDataIndex
    DIM SOEX(200)                       'average air mass for each paired b & v measure, index var = SOEDataIndex

    DIM SOEXdeltaBV(200)                'average air mass * delta(b - v), index var = SOEDataIndex

' working arrays for computing values in SOEData$ listbox table for each filter

    DIM SOEtempData$(200,5)             'intermediate data from IREX_RawFile, index var = SOEtempIndex
                                        'SOEtempData$(x,1) = star name, 12 bytes long
                                        'SOEtempData$(x,2) = Julian date
                                        'SOEtempData$(x,3) = final count or instrument magnitude
                                        'SOEtempData$(x,4) = filter, B or V
                                        'SOEtempData$(x,5) = X, air mass

    DIM SOEStar$(2,4)                   'SOE star names in raw file, index var = SOEIndex value of 2
                                        'SOEStar$(x,1) = star name
                                        'SOEStar$(x,2) = RA
                                        'SOEStar$(x,3) = DEC
                                        'SOEStar$(x,4) = Type, A or B for Star#1, G or K for Star#2

' SOE Star Data file array
'
    DIM SOEitem$(2000,13)               'data items from SOE Star Data file, index var = DataIndex
                                        'SOEitem$(x,1)  = star name, 12 bytes long
                                        'SOEitem$(x,2)  = spectral type
                                        'SOEitem$(x,3)  = RA hour
                                        'SOEitem$(x,4)  = RA minute
                                        'SOEitem$(x,5)  = RA second
                                        'SOEitem$(x,6)  = DEC degree
                                        'SOEitem$(x,7)  = DEC minute
                                        'SOEitem$(x,8)  = DEC second
                                        'SOEitem$(x,9)  = V magnitude
                                        'SOEitem$(x,10) = B-V magnitude
                                        'SOEitem$(x,11) = U-B magnitude
                                        'SOEitem$(x,12) = V-R magnitude
                                        'SOEitem$(x,13) = V-I magnitude

' raw data file arrays
'
    DIM RawData$(500)                   'data lines from raw file of observations, index var = RawIndex
    DIM RDitem$(500,15)                 'data items from raw file of observations, index var = RawIndex
                                        'RDitem$(x,1)  = UT month
                                        'RDitem$(x,2)  = UT day
                                        'RDitem$(x,3)  = UT year
                                        'RDitem$(x,4)  = UT hour
                                        'RDitem$(x,5)  = UT minute
                                        'RDitem$(x,6)  = UT second
                                        'RDitem$(x,7)  = catalog, "T" for transformation star
                                        'RDitem$(x,8)  = object, star name, SKY, SKYNEXT or SKYLAST
                                        'RDitem$(x,9)  = filter, U, B, V, R or I
                                        'RDitem$(x,10) = count 1
                                        'RDitem$(x,11) = count 2
                                        'RDitem$(x,12) = count 3
                                        'RDitem$(x,13) = count 4
                                        'RDitem$(x,14) = integration time, 1 or 10 seconds
                                        'RDitem$(x,15) = scale, 1 10 or 100

    DIM CountFinal(500)                 'average count including integration and scale, index var = RawIndex
    DIM JD(500)                         'Julean date from 2000 for each RawIndex, index var = RawIndex
    DIM JT(500)                         'Julean century from 2000 for each RawIndex, index var = RawIndex

' other arrays
    DIM Xaxis(100)                       'Xaxis() delta(b-v)X
    DIM Yaxis(100)                       'Yaxis() delta(b-v)
'
'=====initialize and start up values
'
VersionNumber$ = "2.56"
PathDataFile$ = "*.raw"                 'default path for data files
PathPlotFile$ = "* .bmp"                'default path for plot files
'
'=====open and read in PPparms data for configuration
'
open "PPparms3.txt" for input as #PPparms
    input #PPparms, Location$           'latitude and longitude in degrees
    input #PPparms, KU                  'first order extinction for U
    input #PPparms, KB                  'first order extinction for B
    input #PPparms, KV                  'first order extinction for V
    input #PPparms, KR                  'first order extinction for R
    input #PPparms, KI                  'first order extinction for I
    input #PPparms, KKbv                'second order extinction for b-v, default = 0
    input #PPparms, Eps                 'transformation coeff. epsilon for V using B-V
    input #PPparms, Psi                 'transformation coeff. Psi for U-B
    input #PPparms, Mu                  'transformation coeff. mu for B-V
    input #PPparms, Tau                 'transformation coeff. for V-R
    input #PPparms, Eta                 'transformation coeff. for V-I
    input #PPparms, EpsR                'transformation coeff. epsilon V using V-R
    input #PPparms, EpsilonFlag         '1 if using epsilon to find V and 0 if using epsilon R
    input #PPparms, JDFlag              '1 if using JD and 0 if using HJD
    input #PPparms, OBSCODE$            'AAVSO observatory code
    input #PPparms, MEDUSAOBSCODE$      'MEDUSA observatory code
    input #PPparms, Ku                  'first order extinction for Sloan u'
    input #PPparms, Kg                  'first order extinction for Sloan g'
    input #PPparms, Kr                  'first order extinction for Sloan r'
    input #PPparms, Ki                  'first order extinction for Sloan i'
    input #PPparms, Kz                  'first order extinction for Sloan z'
    input #PPparms, KKgr                'second order extinction for g-r, default = 0
    input #PPparms, SEps                'transformation coeff. Sloan epsilon for r using g-r
    input #PPparms, SPsi                'transformation coeff. Sloan psi for u-g
    input #PPparms, SMu                 'transformation coeff. Sloan mu for g-r
    input #PPparms, STau                'transformation coeff. Sloan tau for r-i
    input #PPparms, SEta                'transformation coeff. Sloan eta for r-z
    input #PPparms, SEpsR               'transformation coeff.  Sloan epsilon for r using r-i
    input #PPparms, ZPv                 'zero-point constant for v
    input #PPparms, ZPr                 'zero-point constant for r'
    input #PPparms, ZPbv                'zero-point constant for b-v
    input #PPparms, ZPgr                'zero-point constant for g'-r
    input #PPparms, Ev                  'standard error for v
    input #PPparms, Er                  'standard error for r'
    input #PPparms, Ebv                 'standard error for b-v
    input #PPparms, Egr                 'standard error for g'-r'    
close #PPparms

gosub [Find_Lat_Long]

            open "IREX.txt" for output as #IREX
                print #IREX, "SOE Module 2, Version "; VersionNumber$
                print #IREX, "PPparms3"
                print #IREX, "  Location    "; Location$
                print #IREX, "  KU          "; KU
                print #IREX, "  KB          "; KB
                print #IREX, "  KV          "; KV
                print #IREX, "  KR          "; KR
                print #IREX, "  KI          "; KI
                print #IREX, "  KKbv        "; KKbv
                print #IREX, "  Eps         "; Eps
                print #IREX, "  Psi         "; Psi
                print #IREX, "  Mu          "; Mu
                print #IREX, "  Tau         "; Tau
                print #IREX, "  Eta         "; Eta
                print #IREX, "  EpsR        "; EpsR
                print #IREX, "  EpsilonFlag "; EpsilonFlag
                print #IREX, "  JDFlag      "; JDFlag
                print #IREX, "  OBSCODE     "; OBSCODE$
                print #IREX, "  MEDUSAOBSCODE "; MEDUSAOBSCODE$
                print #IREX, "  Ku            "; Ku
                print #IREX, "  Kg            "; Kg
                print #IREX, "  Kr            "; Kr
                print #IREX, "  Ki            "; Ki
                print #IREX, "  Kz            "; Kz
                print #IREX, "  KKgr          "; KKgr
                print #IREX, "  SEps          "; SEps
                print #IREX, "  SPsi          "; SPsi
                print #IREX, "  SMu           "; SMu
                print #IREX, "  STau          "; STau
                print #IREX, "  SEta          "; SEta
                print #IREX, "  SEpsR         "; SEpsR
                print #IREX, "  ZPv           "; ZPv
                print #IREX, "  ZPr           "; ZPr
                print #IREX, "  ZPbv          "; ZPbv
                print #IREX, "  ZPgr          "; ZPgr
                print #IREX, "  Ev            "; Ev
                print #IREX, "  Er            "; Er
                print #IREX, "  Ebv           "; Ebv
                print #IREX, "  Egr           "; Eg                
                print #IREX, "  "
            close #IREX
'
'=====set up main GUI control window
'
[WindowSetup]
    NOMAINWIN
    WindowWidth = 1024 : WindowHeight = 457
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

[ControlSetup]
    Menu        #SOE, "File",_
                      "Open SOE RAW Data File", [Open_File],_
                      "Save Plot Graphic", [Data_Save],_
                      "Quit", [Quit_SOE]
    Menu        #SOE, "Coefficients",_
                      "See Saved K'' Coefficient", [Load_Previous_Coeff],_
                      "Save Coefficient in Results to PPparms", [Save_Coefficients]
    Menu        #SOE, "Help", "About", [About], "Help", [Help]

    graphicbox  #SOE.graphicbox1,   515, 40, 490, 265

    groupbox    #SOE.groupbox1, "SOE Stars File", 11, 310, 350, 85
    groupbox    #SOE.groupbox2, "Results", 375, 310, 310, 85
    groupbox    #SOE.groupbox3, "Least-Squares Analysis", 700, 310, 305, 85

    statictext  #SOE.statictext1,  "(b-v)",          50, 25, 90, 14
    statictext  #SOE.statictext2,  "(b-v)",         170, 25, 90, 14
    statictext  #SOE.statictext3,  chr$(68),        265, 25, 10, 14
    statictext  #SOE.statictext4,  "(b-v)",         275, 25, 50, 14
    statictext  #SOE.statictext5,  "X",             355, 25, 10, 14
    statictext  #SOE.statictext6,  chr$(68),        410, 25, 10, 14
    statictext  #SOE.statictext7,  "(b-v)X",        420, 25, 60, 14
    statictext  #SOE.statictext8,  "K",              540, 350, 15,20
    statictext  #SOE.statictext9,  "bv",             565, 357, 20,16
    statictext  #SOE.statictext10, chr$(34),         553, 350, 10,16
    statictext  #SOE.statictext11, "=",              586, 350, 10,16

    statictext  #SOE.statictext30,"slope",          787, 337, 50, 14
    statictext  #SOE.statictext31,"intercept",      752, 352, 90, 14
    statictext  #SOE.statictext32,"standard error", 710, 367, 132, 14

    button      #SOE.Print, "print",[DataPrint.click], UL, 940, 345, 57, 25
    button      #SOE.Plot, "plot",[PlotData.click], UL, 400, 345, 57, 25

    textbox     #SOE.Results, 600, 345, 65, 25
    textbox     #SOE.Analysis, 844, 335, 88, 50
    textbox     #SOE.FileName, 19, 345, 335, 25
    graphicbox  #SOE.BlueStar, 10, 4, 120, 20
    graphicbox  #SOE.RedStar,  135, 4, 120, 20

    listbox     #SOE.Table, SOEData$(),[SOE_Table.click], 10, 40, 500, 265

    Open "SOE K'' - Johnson/Cousins/Sloan Photometry" for Window as #SOE
    #SOE "trapclose [Quit_SOE]"
    #SOE.graphicbox1 "down; fill White; flush"
    #SOE.BlueStar "fill White; flush"
    #SOE.RedStar "fill White; flush"
    #SOE.graphicbox1 "setfocus; when mouseMove [MouseChange1]"
    #SOE.Table "selectindex 1"
    #SOE "font courier_new 10 14"
                                                    'select Greek characters
    print       #SOE.statictext3,  "!font symbol 10 14"
    print       #SOE.statictext6,  "!font symbol 10 14"
                                                    'make K"bv= for Results Box with italic font
    print       #SOE.statictext9,  "!font courier_new 8 italic"
    print       #SOE.statictext8,  "!font courier_new 14 italic"
    print       #SOE.statictext10, "!font courier_new 12 italic"

    print #SOE.FileName, "open raw data file"

    #SOE.Plot "!Disable"
    #SOE.Print "!Disable"

[loop]

wait

    'MouseX and MouseY contain mouse coordinates
[MouseChange1]

wait
                               'finised setting up, wait here for new command
'
'======menu controls
'
[Open_File]
'
'
    filedialog "Open Data File", PathDataFile$, DataFile$

    for I = len(DataFile$) to 1 step -1             'remember path for opened folder and file
        if mid$(DataFile$,I,1) = "\" then
            ShortDataFile$ = mid$(DataFile$,I+1)
            PathDataFile$ = left$(DataFile$,I)+"*raw"
            exit for
        end if
    next I

    if DataFile$ = "" then
        print #SOE.FileName, "open raw data file"
    else
        files "c:\", DataFile$, info$()
        if val(info$(0, 0)) = 0 then
            notice "cannot create new file"
        else
            print #SOE.Plot, "wait"

            open DataFile$ for input as #RawFile
            for RawIndex = 1 to 4                   'read first 4 lines with line input to capture commas
                line input #RawFile, RawData$(RawIndex)
            next RawIndex
            RawIndex = 4
                while eof(#RawFile)=0               'read rest of data to end of file
                    RawIndex = RawIndex + 1
                    input #RawFile, RawData$(RawIndex)
                wend
                RawIndexMax = RawIndex
            close #RawFile

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Find_File_Name]"
                print #IREX, "filename"
                gosub [Find_File_Name]
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "location latitude =  "; LAT
                print #IREX, "location longitude = "; LONGITUDE
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Convert_RawFile]"
                print #IREX, "raw file data"
                gosub [Convert_RawFile]
                print #IREX, " "
            close #IREX

            gosub [Open_Star_Data]

            gosub [Write_Window_Labels]

            gosub [Total_Count_RawFile]
            gosub [Julian_Day_RawFile]

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [IREX_RawFile]"
                print #IREX, "star           Julean date  final count   filter"
                gosub [IREX_RawFile]
                print #IREX, " "
                if (SOEtempIndexMax MOD 4) <> 0 then
                    notice "you do not have an equal number of paired observations - check IREX file"
                    wait
                end if
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Find_SOE_Stars]"
                print #IREX, "star       SOEIndex       RA          DEC        Type"
                gosub [Find_SOE_Stars]
                print #IREX, " "
            close #IREX

            gosub [Sort_Blue_Red_Stars]

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Create_Intermediate_Table]"
                print #IREX, "star           Julean date  instrument mag    filter        air mass"
                gosub [Create_Intermediate_Table]
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Create_SOE_Table]"
                print #IREX, " Blue Star   Red Star"
                if FilterSystem$ = "1" then
                    print #IREX, "  b - v      b - v    delta(b - v)      X       delta(b-v)X"
                else
                    print #IREX, "  g - r      g - r    delta(g - r)      X       delta(g-r)X"
                end if
                gosub [Create_SOE_Table]
                print #IREX, " "
            close #IREX
        end if
    end if

    #SOE.Print "!Enable"
    #SOE.Plot "!Enable"
    print #SOE.Plot, "Plot"

    print #SOE.graphicbox1, "cls"

Wait
'
[Data_Save]                                      'save bitmap image to disk
    filedialog "Save As...", PathPlotFile$, PlotFile$
    for I = len(PlotFile$) to 1 step -1
        if mid$(PlotFile$,I,1) = "\" then
            ShortPlotFile$ = mid$(PlotFile$,I+1)
            PathPlotFile$ = left$(PlotFile$,I)+"*bmp"
            exit for
        end if
    next I

    if PlotFile$ <> "" then
        print #SOE.graphicbox1, "getbmp plot -2 -2 492 267"
        if (right$(PlotFile$,4) = ".bmp") OR (right$(PlotFile$,4) = ".BMP") then
            bmpsave "plot", PlotFile$
        else
            PlotFile$ = PlotFile$+".bmp"
            bmpsave "plot", PlotFile$
        end if
    end if
wait
'
[Save_Coefficients]
    if FilterSystem$ = "1" then
        print #SOE.Results, "!contents? KKbv"
    else
        print #SOE.Results, "!contents? KKgr"
    end if
    confirm "This will save all non-zero contents of Results"+chr$(13)_
            +"Do you wish to save values?"; Answer$
    if Answer$ = "yes" then
        if FilterSystem$ = "1" AND KKbv <> 0 then
            gosub [Write_PPparms]
        end if
        if FilterSystem$ = "0" AND KKgr <> 0 then
            gosub [Write_PPparms]
        end if
    end if
Wait
'
[Load_Previous_Coeff]
    open "PPparms3.txt" for input as #PPparms
        input #PPparms, Location$           'latitude and longitude in degrees
        input #PPparms, KU                  'first order extinction for U
        input #PPparms, KB                  'first order extinction for B
        input #PPparms, KV                  'first order extinction for V
        input #PPparms, KR                  'first order extinction for R
        input #PPparms, KI                  'first order extinction for I
        input #PPparms, KKbv                'second order extinction for b-v, default = 0
        input #PPparms, Eps                 'transformation coeff. epsilon for V using B-V
        input #PPparms, Psi                 'transformation coeff. Psi for U-B
        input #PPparms, Mu                  'transformation coeff. mu for B-V
        input #PPparms, Tau                 'transformation coeff. for V-R
        input #PPparms, Eta                 'transformation coeff. for V-I
        input #PPparms, EpsR                'transformation coeff. epsilon V using V-R
        input #PPparms, EpsilonFlag         '1 if using epsilon to find V and 0 if using epsilon R
        input #PPparms, JDFlag              '1 if using JD and 0 if using HJD
        input #PPparms, OBSCODE$            'AAVSO observatory code
        input #PPparms, MEDUSAOBSCODE$      'MEDUSA observatory code
        input #PPparms, Ku                  'first order extinction for Sloan u'
        input #PPparms, Kg                  'first order extinction for Sloan g'
        input #PPparms, Kr                  'first order extinction for Sloan r'
        input #PPparms, Ki                  'first order extinction for Sloan i'
        input #PPparms, Kz                  'first order extinction for Sloan z'
        input #PPparms, KKgr                'second order extinction for g-r, default = 0
        input #PPparms, SEps                'transformation coeff. Sloan epsilon for r using g-r
        input #PPparms, SPsi                'transformation coeff. Sloan psi for u-g
        input #PPparms, SMu                 'transformation coeff. Sloan mu for g-r
        input #PPparms, STau                'transformation coeff. Sloan tau for r-i
        input #PPparms, SEta                'transformation coeff. Sloan eta for r-z
        input #PPparms, SEpsR               'transformation coeff.  Sloan epsilon for r using r-i
        input #PPparms, ZPv                 'zero-point constant for v
        input #PPparms, ZPr                 'zero-point constant for r'
        input #PPparms, ZPbv                'zero-point constant for b-v
        input #PPparms, ZPgr                'zero-point constant for g'-r'
        input #PPparms, Ev                  'standard error for v
        input #PPparms, Er                  'standard error for r'
        input #PPparms, Ebv                 'standard error for b-v
        input #PPparms, Egr                 'standard error for g'-r'        
    close #PPparms

    notice "K'' coefficients"+chr$(13)+"K''bv = "+str$(KKbv)+chr$(13)+"K''gr  = "+str$(KKgr)

Wait
'
[About]
    notice "SOE K'' - Johnson/Cousins/Sloan Photometry"+chr$(13)+_
           " version "+VersionNumber$+chr$(13)+_
           " copyright 2015, Gerald Persha."+chr$(13)+_
           " www.sspdataq.com"
Wait
'
[Help]
    run "hh photometry2.chm"
Wait
'
[Quit_SOE]                   'exit program
    confirm "do you wish to exit program?"; Answer$

    if Answer$ = "yes" then
        close #SOE
        END
    else
        wait
    end if

Wait
'
'=====control buttons and control boxes
'
[PlotData.click]
    print#SOE.Plot, "!Enable"

    print #SOE.graphicbox1, "cls"
    print #SOE.graphicbox1, "color black"
    print #SOE.graphicbox1, "font arial 6 12"
    print #SOE.graphicbox1, "place 12 125"
    if FilterSystem$ = "1" then
        print #SOE.graphicbox1, "\(b-v)"
    else
        print #SOE.graphicbox1, "\(g-r)"
    end if
    print #SOE.graphicbox1, "place 230 245"
    if FilterSystem$ = "1" then
        print #SOE.graphicbox1, "\(b-v)X"
    else
        print #SOE.graphicbox1, "\(g-r)X"
    end if
    print #SOE.graphicbox1, "font symbol 8 12"
    print #SOE.graphicbox1, "place 2 125"
    print #SOE.graphicbox1, "\D"
    print #SOE.graphicbox1, "place 220 245"
    print #SOE.graphicbox1, "\D"

    gosub [Draw_Graph_Outline]

    gosub [Create_Regression_Array]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "SOEdataIndex        Xaxis      Yaxis"
        print #IREX, " "

        for SOEdataIndex = 1 to SOEdataIndexMax
            print #IREX, using ("####",SOEdataIndex);"             ";_
                         using("####.###",Xaxis(SOEdataIndex));"   ";_
                         using("####.###",Yaxis(SOEdataIndex))
        next
        print #IREX, " "
    close #IREX

    gosub [Solve_Regression_Matrix]
                                                'output to Analysis textbox the results
    print #SOE.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                         using("####.###", Intercept) + chr$(13) + chr$(10) +_
                         using("####.###", std.error)

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Solve_Regression_Matrix]"
        print #IREX, " Slope      Intercept      std.error"
        print #IREX, using("###.###",Slope)+"       "+_
                     using("###.###",Intercept)+"      "+_
                     using("###.###",std.error)
        print #IREX," "
    close #IREX

    gosub [Draw_Best_Line]

    gosub [Draw_Description]

    print #SOE.graphicbox1, "flush"
    print #SOE.Results, using("##.###", Slope)

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "END OF PLOT"
        print #IREX, " "
    close #IREX

wait
'
[DataPrint.click]

    printerdialog
    if PrinterName$ <> "" then
        print #SOE.graphicbox1, "Print vga"
        dump
    end if
wait
'
'=====subroutines for extracting data from opened raw file
'
[Open_Star_Data]
    if FilterSystem$ = "1" then
        open "SOE Data Version 2.txt" for input as #SOEData
    else
        open "SOE Data Version 2 Sloan.txt" for input as #SOEData
    end if
        DataIndex = 0
        while eof(#SOEData) = 0
            DataIndex = DataIndex + 1
            input #SOEData,SOEitem$(DataIndex,1),_        'star name
                           SOEitem$(DataIndex,2),_      'spectral type
                           SOEitem$(DataIndex,3),_      'RA hour
                           SOEitem$(DataIndex,4),_      'RA minute
                           SOEitem$(DataIndex,5),_      'RA second
                           SOEitem$(DataIndex,6),_      'DEC degree
                           SOEitem$(DataIndex,7),_      'DEC minute
                           SOEitem$(DataIndex,8),_      'DEC second
                           SOEitem$(DataIndex,9),_      'V magnitude, ##.##
                           SOEitem$(DataIndex,10),_     'B-V index, ##.##
                           SOEitem$(DataIndex,11),_     'U-B index, ##.##
                           SOEitem$(DataIndex,12),_     'V-R index, ##.##
                           SOEitem$(DataIndex,13)       'V-I index, ##.##
        wend
        DataIndexMax = DataIndex
    close #SOEData
return
'
[Convert_RawFile]       'extract individual data items from each indexed data line
    For RawIndex = 5 to RawIndexMax                                'skip header and get all raw data
        if len(RawData$(RawIndex)) < 70 then                       'delete any extra junk at end of file
            RawIndexMax = RawIndex-1
            exit for
        end if
        RDitem$(RawIndex,1)  = mid$(RawData$(RawIndex),1,2)        'UT month
        RDitem$(RawIndex,2)  = mid$(RawData$(RawIndex),4,2)        'UT day
        RDitem$(RawIndex,3)  = mid$(RawData$(RawIndex),7,4)        'UT year
        RDitem$(RawIndex,4)  = mid$(RawData$(RawIndex),12,2)       'UT hour
        RDitem$(RawIndex,5)  = mid$(RawData$(RawIndex),15,2)       'UT minute
        RDitem$(RawIndex,6)  = mid$(RawData$(RawIndex),18,2)       'UT second
        RDitem$(RawIndex,7)  = mid$(RawData$(RawIndex),21,1)       'catalog
        RDitem$(RawIndex,8)  = mid$(RawData$(RawIndex),26,12)      'star name
        RDitem$(RawIndex,9)  = mid$(RawData$(RawIndex),41,1)       'filter: U, B, V, R or I
        RDitem$(RawIndex,10) = mid$(RawData$(RawIndex),44,5)       'Count 1
        RDitem$(RawIndex,11) = mid$(RawData$(RawIndex),51,5)       'Count 2
        RDitem$(RawIndex,12) = mid$(RawData$(RawIndex),58,5)       'Count 3
        RDitem$(RawIndex,13) = mid$(RawData$(RawIndex),65,5)       'Count 4
        RDitem$(RawIndex,14) = mid$(RawData$(RawIndex),72,2)       'integration time in seconds: 1 or 10
        RDitem$(RawIndex,15) = mid$(RawData$(RawIndex),75,3)       'scale: 1, 10 or 10

        print #IREX, using("###",RawIndex);"  ";_
                     RDitem$(RawIndex,1);"  ";_
                     RDitem$(RawIndex,2);"  ";_
                     RDitem$(RawIndex,3);"  ";_
                     RDitem$(RawIndex,4);"  ";_
                     RDitem$(RawIndex,5);"  ";_
                     RDitem$(RawIndex,6);"  ";_
                     RDitem$(RawIndex,7);"  ";_
                     RDitem$(RawIndex,8);"  ";_
                     RDitem$(RawIndex,9);"  ";_
                     RDitem$(RawIndex,10);"  ";_
                     RDitem$(RawIndex,11);"  ";_
                     RDitem$(RawIndex,12);"  ";_
                     RDitem$(RawIndex,13);"  ";_
                     RDitem$(RawIndex,14);"  ";_
                     RDitem$(RawIndex,15)
    next

    if RDitem$(5,9) = "u" OR RDitem$(5,9) = "g" OR RDitem$(5,9) = "r" OR RDitem$(5,9) = "i" OR RDitem$(5,9) = "z" then
        FilterSystem$ = "0"
    else
        FilterSystem$ = "1"
    end if

return
'
[Write_Window_Labels]
    if FilterSystem$ = "1" then
        print #SOE.statictext1,  "(b-v)"
        print #SOE.statictext2,  "(b-v)"
        print #SOE.statictext4,  "(b-v)"
        print #SOE.statictext7,  "(b-v)X"
        print #SOE.statictext9,  "bv"
    else
        print #SOE.statictext1,  "(g-r)"
        print #SOE.statictext2,  "(g-r)"
        print #SOE.statictext4,  "(g-r)"
        print #SOE.statictext7,  "(g-r)X"
        print #SOE.statictext9,  "gr"
    end if
return
'
[Total_Count_RawFile]   'compute the total averaged count and scale for gain and integration settings
    For RawIndex = 5 to RawIndexMax
        CountSum =  val(RDitem$(RawIndex,10)) +_                    'Count 1
                    val(RDitem$(RawIndex,11)) +_                    'Count 2
                    val(RDitem$(RawIndex,12)) +_                    'Count 3
                    val(RDitem$(RawIndex,13))                       'Count 4
        Divider = 4                                                 'find divider to get average of Count
        if val(RDitem$(RawIndex,13)) = 0 then
            Divider = Divider - 1
        end if
        if val(RDitem$(RawIndex,12)) = 0 then
            Divider = Divider - 1
        end if
        if val(RDitem$(RawIndex,11)) = 0 then
            Divider = Divider - 1
        end if
        if val(RDitem$(RawIndex,10)) = 0 then
            notice "ERROR"+chr$(13)+_
                   "Only zero count values for star at line "+str$(RawIndex)+chr$(13)+_
                   "REDUCTION STOPPED"
            wait
        end if
        Integration = val(RDitem$(RawIndex,14))                     'find integration time :1 or 10 seconds
        Scale = val(RDitem$(RawIndex,15))                           'find scale factor: 1, 10 or 100
        CountFinal(RawIndex) = int((CountSum/Divider) * (1000/(Integration * Scale)))
    next
return
'
[Julian_Day_RawFile]            'convert UT time and date to Julian, epcoh J2000
    For RawIndex = 5 to RawIndexMax
                                'A = int(UTyear/100)
        A = int(val(RDitem$(RawIndex,3))/100)
        B = 2 - A + int(A/4)
                                'C = int(365.25 * UTyear)
        C = int(365.25 * val(RDitem$(RawIndex,3)))
                                'D = int(30.6001 *(UTmonth + 1))
        D = int(30.6001 * (val(RDitem$(RawIndex,1)) + 1))
                                'JD = B + C + D - 730550.5 + UTday + (UThours + UTmin/60 + UTsec/3600)/24
        JD(RawIndex) = B + C + D - 730550.5 + val(RDitem$(RawIndex,2)) +_
                       (val(RDitem$(RawIndex,4)) + val(RDitem$(RawIndex,5))/60 + val(RDitem$(RawIndex,6))/3600)/24
                                'Julian century
        JT(RawIndex) = JD(RawIndex)/36525
    next
return
'
'
[IREX_RawFile]      'subtract skies from SOE star data
    SOEtempIndex = 1
    for RawIndex = 5 to RawIndexMax
                    'go through raw file and pick out only the SOE stars with the B/g filter
        if (RDitem$(RawIndex,7) = "S")  AND ((RDitem$(RawIndex,9) = "B") OR (RDitem$(RawIndex,9) = "g")) then
                    'find the past sky count to apply
            SkyPastCount = 0
            PastTime = 0
            for I = RawIndex to 5 step -1
                if ((RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = "B")) OR_
                   ((RDitem$(I,8) = "SKYNEXT     ") AND (RDitem$(I,9) = "B")) OR_
                   ((RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = "g")) OR_
                   ((RDitem$(I,8) = "SKYNEXT     ") AND (RDitem$(I,9) = "g"))  then
                    SkyPastCount = CountFinal(I)
                    PastTime = JD(I)
                    exit for
                end if
            next
                    'find the future sky count to apply
            SkyFutureCount = 0
            FutureTime = 0
            for I = RawIndex to RawIndexMax step 1
                if ((RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = "B")) OR_
                   ((RDitem$(I,8) = "SKYLAST     ") AND (RDitem$(I,9) = "B")) OR_
                   ((RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = "g")) OR_
                   ((RDitem$(I,8) = "SKYLAST     ") AND (RDitem$(I,9) = "g")) then
                    SkyFutureCount = CountFinal(I)
                    FutureTime = JD(I)
                    exit for
                end if
            next
                    'subtract sky from Trans star count depending on SKY, SKYNEXT or SKYLAST protocol and change
                    'CountFinal value accordingly
            select case
                case (SkyPastCount = 0) AND (SkyFutureCount = 0)
                    notice "no SKY counts for CCOMP star at line# "; RawIndex
                    wait
                case (SkyPastCount > 0) AND (SkyFutureCount = 0)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyPastCount
                case (SkyPastCount = 0) AND (SkyFutureCount > 0)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyFutureCount
                case else
                        '                           y2 - y1
                        'interpolation:   y = y1 + --------- * (x - x1),  equation 3.26
                        '                           x2 - x1
                    SkyCurrentCount = SkyPastCount + ((SkyFutureCount - SkyPastCount)/(FutureTime - PastTime))*_
                                      (JD(RawIndex) - PastTime)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyCurrentCount
            end select

            SOEtempData$(SOEtempIndex, 1) = RDitem$(RawIndex,8)
            SOEtempData$(SOEtempIndex, 2) = STR$(JD(RawIndex))
            SOEtempData$(SOEtempIndex, 3) = STR$(CountFinal(RawIndex))

            SOEtempData$(SOEtempIndex, 4) = "B/g"

            SOEtempIndex = SOEtempIndex + 1

            print #IREX,    RDitem$(RawIndex,8);"  ";_                              'star name
                            using("#####.#####",JD(RawIndex));"   ";_               'Julean Date
                            using("######", CountFinal(RawIndex));"         ";_     'final average count
                            "B/g"                                                     'filter

        end if
                    'go through raw file and pick out only the SOE stars with the V filter
        if (RDitem$(RawIndex,7) = "S")  AND ((RDitem$(RawIndex,9) = "V") OR (RDitem$(RawIndex,9) = "r"))  then
                    'find the past sky count to apply
            SkyPastCount = 0
            PastTime = 0
            for I = RawIndex to 5 step -1
                if ((RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = "V")) OR_
                   ((RDitem$(I,8) = "SKYNEXT     ") AND (RDitem$(I,9) = "V")) OR_
                   ((RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = "r")) OR_
                   ((RDitem$(I,8) = "SKYNEXT     ") AND (RDitem$(I,9) = "r")) then
                    SkyPastCount = CountFinal(I)
                    PastTime = JD(I)
                    exit for
                end if
            next
                    'find the future sky count to apply
            SkyFutureCount = 0
            FutureTime = 0
            for I = RawIndex to RawIndexMax step 1
                if ((RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = "V")) OR_
                   ((RDitem$(I,8) = "SKYLAST     ") AND (RDitem$(I,9) = "V")) OR_
                   ((RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = "r")) OR_
                   ((RDitem$(I,8) = "SKYLAST     ") AND (RDitem$(I,9) = "r")) then
                    SkyFutureCount = CountFinal(I)
                    FutureTime = JD(I)
                    exit for
                end if
            next
                    'subtract sky from SOE star count depending on SKY, SKYNEXT or SKYLAST protocol and change
                    'CountFinal value accordingly
            select case
                case (SkyPastCount = 0) AND (SkyFutureCount = 0)
                    notice "no SKY counts for COMP star at line# "; RawIndex
                    wait
                case (SkyPastCount > 0) AND (SkyFutureCount = 0)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyPastCount
                case (SkyPastCount = 0) AND (SkyFutureCount > 0)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyFutureCount
                case else
                        '                           y2 - y1
                        'interpolation:   y = y1 + --------- * (x - x1),  equation 3.26
                        '                           x2 - x1
                    SkyCurrentCount = SkyPastCount + ((SkyFutureCount - SkyPastCount)/(FutureTime - PastTime))*_
                                      (JD(RawIndex) - PastTime)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyCurrentCount
            end select

            SOEtempData$(SOEtempIndex, 1) = RDitem$(RawIndex,8)
            SOEtempData$(SOEtempIndex, 2) = STR$(JD(RawIndex))
            SOEtempData$(SOEtempIndex, 3) = STR$(CountFinal(RawIndex))

            SOEtempData$(SOEtempIndex, 4) = "V/r"

            SOEtempIndex = SOEtempIndex + 1

            print #IREX,    RDitem$(RawIndex,8);"  ";_                              'star name
                            using("#####.#####",JD(RawIndex));"   ";_               'Julean Date
                            using("######", CountFinal(RawIndex));"         ";_     'final average count
                            "V/r"                                                     'filter
        end if
    next
    SOEtempIndexMax = SOEtempIndex - 1
return
'
'
[Find_SOE_Stars]
                                        'make list of unique SOE stars contained in the raw file
    SOEIndexMax = 0                     'reset SOE array index to 0, this will result in 1 being
                                        'the first array item
    for RawIndex = 5 to RawIndexMax
                                        'go through raw file and pick out only the SOE stars with
                                        'the selected filter B or V
        if (RDitem$(RawIndex,7) = "S") then
            SOEFlag = 0
                                        'see if the SOE Star is new to the list
            for SOEIndex = 1 to SOEIndexMax
                if SOEStar$(SOEIndex,1) = RDitem$(RawIndex,8) then
                    SOEFlag = 1
                end if
            next
            if SOEFlag = 0 then        'add the new SOE Star to the list
                SOEIndexMax = SOEIndexMax + 1
                SOEStar$(SOEIndexMax,1) = RDitem$(RawIndex,8)
            end if
        end if
    next

    if SOEIndexMax > 2 then
        notice " ERROR: can have only one pair of SOE stars in data file"
        wait
    end if

    for DataIndex = 1 to DataIndexMax
        for SOEIndex = 1 to 2
            if SOEStar$(SOEIndex,1) = left$(SOEitem$(DataIndex,1)+"           ",12) then
                RA =  val(SOEitem$(DataIndex,3)) + val(SOEitem$(DataIndex,4))/60 + val(SOEitem$(DataIndex,5))/3600
                RA = (RA/24) * 360       'convert RA to degrees
                DEC = abs(val(right$(SOEitem$(DataIndex,6),2))) +_
                      val(SOEitem$(DataIndex,7))/60 + val(SOEitem$(DataIndex,8))/3600
                                         'see if  minus sign is in the degree string and make DEC negative if so
                                         'this is need in case of DECd = - 0
                if left$(SOEitem$(DataIndex,6),1) = "-" then
                    DEC = DEC * -1
                end if

                SOEStar$(SOEIndex,2) = STR$(RA)               'RA
                SOEStar$(SOEIndex,3) = STR$(DEC)              'DEC
                SOEStar$(SOEIndex,4) = SOEitem$(DataIndex,2)  'Type

            end if
        next
    next

    for SOEIndex = 1 to SOEIndexMax
        print #IREX, SOEStar$(SOEIndex,1);"   ";_                                'unique SOE star name
                     SOEIndex;"       ";_                                        'index for star
                     using ("###.#####",val(SOEStar$(SOEIndex,2)));"   ";_       'RA
                     using ("###.#####",val(SOEStar$(SOEIndex,3)));"       ";_   'DEC
                     SOEStar$(SOEIndex,4)                                        'Type
    next
return
'
'
[Sort_Blue_Red_Stars]
    for SOEIndex = 1 to 2
        select case
            case  SOEStar$(SOEIndex,4) = "A" OR SOEStar$(SOEIndex,4) = "B"
                print #SOE.BlueStar, "color BLUE"
                print #SOE.BlueStar, "goto 2 15"
                print #SOE.BlueStar, "\"+SOEStar$(SOEIndex,1)
                print #SOE.BlueStar, "flush"
                BlueStar$ = SOEStar$(SOEIndex,1)
            case  SOEStar$(SOEIndex,4) = "K" OR SOEStar$(SOEIndex,4) = "G"
                print #SOE.RedStar, "color RED"
                print #SOE.RedStar, "goto 2 15"
                print #SOE.RedStar, "\"+SOEStar$(SOEIndex,1)
                print #SOE.RedStar, "flush"
                RedStar$ = SOEStar$(SOEIndex,1)
            case else
                notice "blue stars must be type A or B and red stars must be K or G"
                open "IREX.txt" for append as #IREX                             'save to IREX file for diagnostics
                    print #IREX, "processing ended - not valid spectral types"
                    print #IREX, " "
                close #IREX
                wait
         end select
    next
return
'
'
[Create_Intermediate_Table]
    for SOEtempIndex = 1 to SOEtempIndexMax
                                                                        'convert final count to instrument mag.
        SOEtempData$(SOEtempIndex, 3) = str$(-1.0857*log(val(SOEtempData$(SOEtempIndex, 3))))
        JD = val(SOEtempData$(SOEtempIndex, 2))                         'get Julian Day
        gosub [Siderial_Time]                                           'get LMST

        if SOEtempData$(SOEtempIndex, 1) = SOEStar$(1,1) then
            RA = val(SOEStar$(1,2))
            DEC = val(SOEStar$(1,3))
        else
            RA = val(SOEStar$(2,2))
            DEC = val(SOEStar$(2,3))
        end if

        gosub [Find_Air_Mass]

        SOEtempData$(SOEtempIndex, 5) = Str$(AirMass)

        print #IREX, SOEtempData$(SOEtempIndex, 1);"   ";_                                  'star name
                     using ("####.#####",val(SOEtempData$(SOEtempIndex, 2)));"     ";_      'Julean Date
                     using ("###.#####",val(SOEtempData$(SOEtempIndex, 3)));"         ";_   'instrument magnitude
                     SOEtempData$(SOEtempIndex, 4);"        ";_                             'filter
                     using ("##.#####",val(SOEtempData$(SOEtempIndex, 5)))                  'AirMass
   next
return
'
'=====subroutines for creating SOE table for main listbox
'
[Create_SOE_Table]

    redim SOEData$(100)

    SOEdataIndexMax = SOEtempIndexMax/4     'seperate out the paired observations

    for SOEdataIndex = 0 to SOEdataIndexMax - 1
        AirMassTotal = 0
        for Counter = 1 to 3 step 2
            if SOEtempData$(Counter + 4*SOEdataIndex, 1) = BlueStar$ then
               AirMassTotal = AirMassTotal + val(SOEtempData$(Counter + 4*SOEdataIndex, 5)) +_
                                             val(SOEtempData$(Counter + 4*SOEdataIndex + 1, 5))
                if SOEtempData$(Counter + 4*SOEdataIndex, 4) = "B/g" then
                    SOEColorBlue(SOEdataIndex) = val(SOEtempData$(Counter + 4*SOEdataIndex, 3)) -_
                                                 val(SOEtempData$(Counter + 4*SOEdataIndex + 1, 3))
                else
                    SOEColorBlue(SOEdataIndex) = val(SOEtempData$(Counter + 4*SOEdataIndex + 1, 3)) -_
                                                 val(SOEtempData$(Counter + 4*SOEdataIndex, 3))
                end if
            end if
            if SOEtempData$(Counter + 4*SOEdataIndex, 1) = RedStar$ then
                AirMassTotal = AirMassTotal + val(SOEtempData$(Counter + 4*SOEdataIndex, 5)) +_
                                              val(SOEtempData$(Counter + 4*SOEdataIndex + 1, 5))
                if SOEtempData$(Counter + 4*SOEdataIndex, 4) = "B/g" then
                    SOEColorRed(SOEdataIndex) =  val(SOEtempData$(Counter + 4*SOEdataIndex, 3)) -_
                                                 val(SOEtempData$(Counter + 4*SOEdataIndex + 1, 3))
                else
                    SOEColorRed(SOEdataIndex) =  val(SOEtempData$(Counter + 4*SOEdataIndex + 1, 3)) -_
                                                 val(SOEtempData$(Counter + 4*SOEdataIndex, 3))
                end if
            end if
        next

        SOEdeltaBV(SOEdataIndex) = SOEColorBlue(SOEdataIndex)- SOEColorRed(SOEdataIndex)

        SOEX(SOEdataIndex) = AirMassTotal/4

        SOEXdeltaBV(SOEdataIndex) = SOEX(SOEdataIndex) * SOEdeltaBV(SOEdataIndex)

        print #IREX,  using ("###.###", SOEColorBlue(SOEdataIndex));"    ";_
                      using ("###.###", SOEColorRed(SOEdataIndex));"    ";_
                      using ("###.###", SOEdeltaBV(SOEdataIndex));"       ";_
                      using ("###.###", SOEX(SOEdataIndex));"      ";_
                      using ("###.###", SOEXdeltaBV(SOEdataIndex))

        SOEData$(SOEdataIndex) =  "   "+using("##.###",SOEColorBlue(SOEdataIndex))+_
                                  "       "+using("##.###",SOEColorRed(SOEdataIndex))+_
                                  "     "+using("##.###",SOEdeltaBV(SOEdataIndex))+_
                                  "  "+using("##.###",SOEX(SOEdataIndex))+_
                                  "   "+using("##.###",SOEXdeltaBV(SOEdataIndex))

   next
   print #SOE.Table, "reload"
return
'
'====subroutines for file operations
'
[Write_PPparms]
    open "PPparms3.txt" for output as #PPparms
        print #PPparms, Location$                        'latitude and longitude
        print #PPparms, using("#.###",KU)                'first order extinction for U
        print #PPparms, using("#.###",KB)                'first order extinction for B
        print #PPparms, using("#.###",KV)                'first order extinction for V
        print #PPparms, using("#.###",KR)                'first order extinction for R
        print #PPparms, using("#.###",KI)                'first order extinction for I
        print #PPparms, using("##.###",KKbv)             'second order extinction for b-v, default = 0
        print #PPparms, using("##.###",Eps)              'transformation coeff. epislon for V using B-V
        print #PPparms, using("##.###",Psi)              'transformation coeff. psi for U-B
        print #PPparms, using("##.###",Mu)               'transformation coeff. mu for B-V
        print #PPparms, using("##.###",Tau)              'transformation coeff. tau  V-R
        print #PPparms, using("##.###",Eta)              'transformation coeff. eta  V-I
        print #PPparms, using("##.###",EpsR)             'transformation coeff. epislon for V using V-R
        print #PPparms, EpsilonFlag                      '1 if using epsilon to find V and 0 if using epsilon R
        print #PPparms, JDFlag                           '1 if using JD and 0 if using HJD
        print #PPparms, OBSCODE$                         'AAVSO observatory code
        print #PPparms, MEDUSAOBSCODE$                   'MEDUSA observatory code
        print #PPparms, using("#.###",Ku)                'first order extinction for Sloan u'
        print #PPparms, using("#.###",Kg)                'first order extinction for Sloan g'
        print #PPparms, using("#.###",Kr)                'first order extinction for Sloan r'
        print #PPparms, using("#.###",Ki)                'first order extinction for Sloan i'
        print #PPparms, using("#.###",Kz)                'first order extinction for Sloan z'
        print #PPparms, using("##.###",KKgr)             'second order extinction for g-r, default = 0
        print #PPparms, using("##.###",SEps)             'transformation coeff. Sloan epsilon for r using g-r
        print #PPparms, using("##.###",SPsi)             'transformation coeff. Sloan psi for u-g
        print #PPparms, using("##.###",SMu)              'transformation coeff. Sloan mu for g-r
        print #PPparms, using("##.###",STau)             'transformation coeff. Sloan tau for r-i
        print #PPparms, using("##.###",SEta)             'transformation coeff. Sloan eta for r-z
        print #PPparms, using("##.###",SEpsR)            'transformation coeff.  Sloan epsilon for r using r-i
        print #PPparms, using("##.###",ZPv)              'zero-point constant for v
        print #PPparms, using("##.###",ZPr)              'zero-point constant for r'
        print #PPparms, using("##.###",ZPbv)             'zero-point constant for b-v
        print #PPparms, using("##.###",ZPgr)             'zero-point constant for g'-r'
        print #PPparms, using("##.###",Ev)               'standard error for v
        print #PPparms, using("##.###",Er)               'standard error for r'
        print #PPparms, using("##.###",Ebv)              'standard error for b-v
        print #PPparms, using("##.###",Egr)              'standard error for g'-r'        
    close #PPparms
return
'
[Find_File_Name]        'seperate out filename and extension from info() path/filename
    FileNameIndex = len(DataFile$)
    FileNameLength = len(DataFile$)
    while mid$(DataFile$, FileNameIndex,1)<>"\"          'look for the last backlash
        FileNameIndex = FileNameIndex - 1
    wend
    FileNamePath$ = left$(DataFile$, FileNameIndex)
    DataFileName$ = right$(DataFile$, FileNameLength-FileNameIndex)

    print #SOE.FileName, DataFileName$                 'display filename in "File" textbox
    print #IREX, DataFile$
return
'
'=====subroutines for calculations
'
[Find_Lat_Long]         'compute observers latitude and longitude in degrees
    LAT = val(mid$(Location$,2,4))
    if upper$(left$(Location$,1)) = "S" then
        LAT = LAT * -1
    end if
    LONGITUDE = val(mid$(Location$,8,5))
    if upper$(mid$(Location$,7,1)) = "W" then
        LONGITUDE = LONGITUDE * -1
    end if
return
'
[Siderial_Time]         'compute local siderial time
                        'equation by Stephen R. Schmitt found on the web at
                        'http://home.att.net/~srschmitt/celestial2horizon.html
    JT = JD/36525
    MST = 280.46061837 + 360.98564736629 * JD + 0.000387933 * JT * JT - (JT * JT * JT)/38710000
    LMST = MST + LONGITUDE
    if LMST > 0 then
        while (LMST > 360)
            LMST = LMST - 360
        wend
    else
        while (LMST < 0)
            LMST = LMST + 360
        wend
    end if
return
'
[Find_Air_Mass]                              'compute air mass
    HA = LMST - RA                           'find hour angle in degrees
    if HA < 0 then
        HA = HA + 360
    end if

    HAradians = HA * 3.1416/180             'convert to radians
    DECradians = DEC * 3.1416/180
    LATradians = LAT * 3.1416/180

                        'compute secant of zenith angle - distance from zenith in radians
    secZ = 1/(sin(LATradians) * sin(DECradians) + cos(LATradians) * cos(DECradians) * cos(HAradians))
                        'compute air mass using Hardie equation
                        'X = sec Z - 0.0018167(sec Z - 1) - 0.002875(sec Z - 1)^2 - 0.0008083(sec Z - 1)^3
    AirMass = secZ - 0.0018167 * (secZ - 1) - 0.002875 * (secZ - 1)^2 - 0.0008083 * (secZ - 1)^3
return
'
[Create_Regression_Array]
    for SOEdataIndex = 1 to SOEdataIndexMax

                Xaxis(SOEdataIndex) = SOEXdeltaBV(SOEdataIndex -1)
                Yaxis(SOEdataIndex) = SOEdeltaBV(SOEdataIndex -1)
    next
return
'
[Solve_Regression_Matrix]
            'linear least squares routine from Nielson
            'pulled from appendix I.4 of Astronomical Photometry, written by Hendon 1973
            'inputs     Xaxis() delta(b-v)X
            '           Yaxis() delta(b-v)
            'outputs   Slope and Intercept,   Y = aX + b
            'number of elements in array = SOEdataIndexMax
    a2 = 0
    a3 = 0
    c1 = 0
    c2 = 0
    a1 = SOEdataIndexMax
    for I = 1 to SOEdataIndexMax
        a2 = a2 + Xaxis(I)
        a3 = a3 + Xaxis(I) * Xaxis(I)
        c1 = c1 + Yaxis(I)
        c2 = c2 + Yaxis(I) * Xaxis(I)
    next
    det = 1/(a1 * a3 - a2 * a2)
    Intercept = -1 * (a2 * c2 - c1 * a3) * det
    Slope = (a1 * c2 - c1 * a2) * det

            'compute standard error using eq. 3.21
    if SOEdataIndexMax> 2 then
        y.deviation.squared.sum = 0
        for N = 1 to SOEIndexMax
            y.fit = Slope * Xaxis(N) + Intercept
            y.deviation = Yaxis(N) - y.fit
            y.deviation.squared.sum =  y.deviation.squared.sum + y.deviation^2
        next
        std.error = sqr((1/(N-2)) * y.deviation.squared.sum)
    else
        std.error = 0
    end if
return
'
'=====graphics routines
'
[Draw_Graph_Outline]

    print #SOE.graphicbox1, "font arial 6 12"
    print #SOE.graphicbox1, "place 40 235"
    print #SOE.graphicbox1, "\ 0"
    print #SOE.graphicbox1, "place 170 235"
    print #SOE.graphicbox1, "\ -1.0"
    print #SOE.graphicbox1, "place 310 235"
    print #SOE.graphicbox1, "\ -2.0"
    print #SOE.graphicbox1, "place 450 235"
    print #SOE.graphicbox1, "\ -3.0"

    print #SOE.graphicbox1, "line 40 20 40 220"
    print #SOE.graphicbox1, "line 40 220 460 220"
    print #SOE.graphicbox1, "font arial 6 12"

    for I = 1 to 10
        xD =  20 * I
        print #SOE.graphicbox1, "line 40 ";xD;" 45 ";xD
    next
    for I = 0 to 4
        xD = 40 * I + 20
        print #SOE.graphicbox1, "line 40 ";xD;" 50 ";xD
    next
    for I = 1 to 30
        yD = 40 + 14 * I
        print #SOE.graphicbox1, "line ";yD;" 220 ";yD;" 215"
    next
    for I = 0 to 3
        yD = 40 + 140 * I
        print #SOE.graphicbox1, "line ";yD;" 220 ";yD;" 210"
    next
return
'
[Draw_Best_Line]
    print #SOE.graphicbox1, "color black"

    ScaleIntercept = (int(Intercept * 10))/10       'make 0.5 scale with intercept near middle
    ScaleBot = ScaleIntercept + 0.3                 'scale for bottom of graph
    ScaleTop = ScaleBot - 0.5                       'scale for top of graph

    InterceptEnd   = -3.0 * Slope + Intercept       'end of best fit line at X-axis = 3.0

    StartLine = (Intercept - ScaleTop) * 400 + 20
    EndLine = (InterceptEnd - ScaleTop) * 400 + 20
    print #SOE.graphicbox1, "line 40 ";StartLine;" 460 ";EndLine

                                                    'plot data points
    for SOEdataIndex = 1 to SOEdataIndexMax

        Ypoint = (Yaxis(SOEdataIndex) - ScaleTop)* 400 + 20
        Xpoint = abs(Xaxis(SOEdataIndex)) * 140 + 40

        print #SOE.graphicbox1, "place ";Xpoint;" ";Ypoint
        print #SOE.graphicbox1, "circle 3"
    next
                                                    'draw y scale values
    print #SOE.graphicbox1, "color black"
    print #SOE.graphicbox1, "font arial 6 12"
    print #SOE.graphicbox1, "place 10 25"
    ScaleTop$ = "\"+using("###.#", ScaleTop)
    print #SOE.graphicbox1, ScaleTop$
    print #SOE.graphicbox1, "place 10 220"
    ScaleBot$ = "\"+using("###.#", ScaleBot)
    print #SOE.graphicbox1, ScaleBot$
return
'
[Draw_Description]
                                                    'print file name
    print #SOE.graphicbox1, "place 60 300"
    print #SOE.graphicbox1, "\FILE NAME :"
    print #SOE.graphicbox1, "place 160 300"
    GraphicFileName$ = "\"+ShortDataFile$
    print #SOE.graphicbox1, GraphicFileName$ 
                                                    'print start Julian Date
    print #SOE.graphicbox1, "place 60 325"
    print #SOE.graphicbox1, "\START J2000:"
    print #SOE.graphicbox1, "place 160 325"
    GraphicStartJD$ = "\"+Using("####.####", JD(5))
    print #SOE.graphicbox1, GraphicStartJD$ 
                                                    'print end Julian Date
    print #SOE.graphicbox1, "place 60 350"
    print #SOE.graphicbox1, "\END J2000:"
    print #SOE.graphicbox1, "place 160 350"
    GraphicEndJD$ = "\"+Using("####.####", JD(RawIndexMax))
    print #SOE.graphicbox1, GraphicEndJD$ 
                                                    'print slope
    print #SOE.graphicbox1, "place 60 375"
    print #SOE.graphicbox1, "\SLOPE:"
    print #SOE.graphicbox1, "place 160 375"
    GraphicSlope$ = "\"+Using("####.###", Slope)
    print #SOE.graphicbox1, GraphicSlope$ 
                                                    'printer intercept
    print #SOE.graphicbox1, "place 60 400"
    print #SOE.graphicbox1, "\INTERCEPT:"
    print #SOE.graphicbox1, "place 160 400"
    GraphicIntercept$ = "\"+Using("####.###", Intercept)
    print #SOE.graphicbox1, GraphicIntercept$ 
                                                    'print standard error
    print #SOE.graphicbox1, "place 60 425"
    print #SOE.graphicbox1, "\STD. ERROR:"
    print #SOE.graphicbox1, "place 160 425"
    GraphicStd.error$ = "\"+Using("####.###", std.error)
    print #SOE.graphicbox1, GraphicStd.error$ 
                                                    'print stars
    print #SOE.graphicbox1, "place 60 450"
    print #SOE.graphicbox1, "\STARS :"
    for SOEIndex = 1 to SOEIndexMax
        GraphicStar$ = "\"+SOEStar$(SOEIndex,1)
        place$ = "place 160 "+str$(435 + (15*SOEIndex))
        print #SOE.graphicbox1, place$
        print #SOE.graphicbox1, GraphicStar$
    next
return
'
end
