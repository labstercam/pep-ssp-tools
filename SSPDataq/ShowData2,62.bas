'                             Show Data Module - Photometry
'                                      Optec, Inc.
'
'======version history
' V2.62, February 2019
' added parabolic anaylsis
'
' V2.61, February 2019
' added parabolic curve fitting to BRNO
'
' V2.60, February 2019
' added error for BRNO output
'
' V2.59, March 2018
' corrected negative square root in Eclipsing Binary Analysis
'
' V2.58, October 2016
' changed error calculation in eclipsing Bianary analysis
'
' V2.57, September 2016
' improved MEDUZA format
'
' V2.56, November 2015
' added output in MEDUZA, BRNO format
'
' V2.55, October 2015
' added output to ETD format

' V2.54, September 2015
' added Period Search
' added submit minima parameters
' increased font size for cursor values
'
' V2.53, September,2015
' added 0.02 and 0.20 mag scales
' expanded Y axis by 2x
' chaged AAVSO submisssion to include append
'
' V2.52, September, 2015
' compiled with LB 4.50
'
' V2.50, October, 1014
' added Sloan filters
'
' V2.46, September 4, 2014
' fixed error in start date for index
'
' V2.45, February 2, 2014
' added probable error in eclipsing binary analysis
'
' V2.44, January 2014
' minor changes in format & cleaned up code
'
' V2.43, November 6, 2013
' added Analysis - Time of Minimum and Phase
'
' V2.42, September 28, 2013
' added cursor values printed to StartTime and StarMag textboxes
'
' V2.41, September 25, 2013
' corrected error range when entering date - now 1000 to 9999 JD
' increased cursor vales to 3 decimal places
'
' V2.40, september 2013
' fixed missing data point error
' added header info for AAVSO file from PPparms
' added HJD feature
'
' V2.31, may 2013
' fixed Julian day error
' fixed extra space in V mag for AAVSO output
' improved file saving
' added 5 min time div
'
' V2.30, march 2013
' corrected FastIndex not resetting to 0
'
' V2.10
' added color index
' added labels
' added AAVSO file making
'
' V2.00
'
'=====dimension statements and initial conditions
'
    DIM info$(10,10)
    files "c:\", info$()

    DIM TimeScale$(15)                  'time scale selections
    DIM TimeScaleArray(15)              'x-axis legend for marks every 10 divisions
    DIM TimeScaleArray$(15)

    DIM MagScale$(7)                    'magnitude scale selections
    DIM MagScaleArray(20)               'y-axis legend marks every division
    DIM MagScaleArray$(20)              'y-axis legend marks every division

    DIM TimeString$(3000,2)             'JD and magnitude array file for processing with PERIOD04
    DIM TimeSeriesData$(3000)           'JD and magnitude array file for ETD/BRNO format
    DIM ErrorMag(200)

    DIM X(200)                          'time in JD for error estimate in BRNO
    DIM Y(200)                          'magnitude for error estimate in BRNO

    DIM VarData$(3000)                  'data lines from variable file of observations, index var = VarIndex
    DIM VarItemJD$(3000)                'temporary array used in MEDUZA for HJD to JD conversion
    DIM VarItem$(3000,17)               'data items from variable file of observations, index var = VarIndex
                                        'VarItem$(x,1)  = UT day
                                        'VarItem$(x,2)  = UT month
                                        'VarItem$(x,3)  = UT year
                                        'VarItem$(x,4)  = UT hour
                                        'VatItem$(x,5)  = UT minute
                                        'VarItem$(x,6)  = UT second
                                        'VarItem$(x,7)  = Julian Datae J2000
                                        'VarItem$(x,8)  = V magnitude
                                        'VarItem$(x,9)  = V standard error
                                        'VarItem$(x,10) = U-B
                                        'VarItem$(x,11) = U-B standard error
                                        'VarItem$(x,12) = B-V
                                        'VarItem$(x,13) = B-V standard error
                                        'VarItem$(x,14) = V-R
                                        'VarItem$(x,15) = V-R standard error
                                        'VarItem$(x,16) = V-I
                                        'VarItem$(x,17) = V-I standard error

    DIM AAVSOitem$(3000,15)             'data lines for making AAVSO format output, index var = VarIndex
                                        'AAVSOitem$(x,1)  = VAR$, variable star name
                                        'AAVSOitem$(x,2)  = JD in JDN, add 2451545 to J2000 date
                                        'AAVSOitem$(x,3)  = magnitude
                                        'AAVSOitem$(x,4)  = magnitude standard error
                                        'AAVSOitem$(x,5)  = filter, U, B, V, R, or I
                                        'AAVSOitem$(x,6)  = YES, used transformation coefficients
                                        'AAVSOitem$(x,7)  = STD, magnitude type is standard
                                        'AAVSOitem$(x,8)  = COMP$, comparison star name
                                        'AAVSOitem$(x,9)  = na, instrument magnitude of comparison
                                        'AAVSOitem$(x,10) = na, name of check star
                                        'AAVSOitem$(x,11) = na, instrument magnitude of check star
                                        'AAVSOitem$(x,12) = na, airmass of onservation
                                        'AAVSOitem$(x,13) = Group$, grouping identifier
                                        'AAVSOitem$(x,14) = CHART$, chart name
                                        'AAVSOitem$(x,15) = na, notes to data line

    DIM MEDUZAitem$(3000,8)             'data lines for making MEDUZA format output, index var = VarIndex
                                        'MEDUZAitem$(x,1) = VAR$, variable star name
                                        'MEDUZAitem$(x,2) = JD in JDN, add 2451545 to J2000 date
                                        'MEDUZAitem$(x,3) = magnitude
                                        'MEDUZAitem$(x,4) = calender date
                                        'MEDUZAitem$(x,5) = observer's code
                                        'MEDUZAitem$(x,6) = magnitude standard error
                                        'MEDUZAitem$(x,7) = COMP$, comparison star name
                                        'MEDUZAitem$(x,8) = filter with METHOD: PEP+Filter
    DIM FastData$(10000)
    DIM FastItem$(10000,5)
    DIM FastCounts(10000)
    DIM FastTime(10000)
    DIM DrawLabel(50)

    DIM DateDecending(100)
    DIM DateAscending(100)
    DIM MagDecending(100)
    DIM MagAscending(100)
    DIM MagDiff(100)
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
    input #PPparms, Eps                 'transformation coeff. epislon for V
    input #PPparms, Psi                 'transformation coeff. psi for U-B
    input #PPparms, Mu                  'transformation coeff. mu for B-V
    input #PPparms, Tau                 'transformation coeff. tau for V-R
    input #PPparms, Eta                 'transformation coeff. eta for V-I
    input #PPparms, EpsR                'transformation coeff. epislon for V-R
    input #PPparms, EpsilonFlag         '1 if using epsilon and 0 if using epsilon R
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
'
'=====initialize and start up values
'
    VersionNumber$     = "2.62"
    PathDataFile$      = "* .var"       'default path for data files
    PathPlotFile$      = "* .bmp"       'default path for plot files
    PathDataFastFile$  = "* .raw"       'default path for fast data files
    PathAAVSO$         = "* .txt"       'default path for AAVSO format data files
    PathMEDUZA$        = "* .txt"       'default path for MEDUZA format data files
    PathTimeString$    = "* .txt"       'default path for Period04 data files
    PathTimeStringCSV$ = "* .csv"       'default path for Period Search data files

    ConnectDotFlag = 0                  'use dots for plotting
    CursorID$ = "A"                     'default to A cursor at start up
    CursorFlag.B = 0                    'turn off cursor B values and B-A values
    CursorFlag = 0                      'no cursor
    PlotErrorFlag = 0                   'do not plot error limits
    AAVSOFlag = 0                       'AAVSO export window is closed
    ETDFlag = 0                         'ETD export window is closed
    BRNOFlag = 0                        'BRNO export window is closed
    MEDUZAFlag = 0                      'MEDUZA export window is closed
    PlotFlag = 0                        'Plot = 0 fast data, 1 plot V, 2 plot index
    FilterSystem$ = "1"                 '1 = Johnson/Cousin, 0 = Sloan
    LabelCounter = 0
'
'=====set up main GUI control window
'
[WindowSetup]
    NOMAINWIN
    WindowWidth = 1024 : WindowHeight = 732
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

[ControlSetup]
    Menu        #show, " File ",          "Open Var File", [OpenFile],_
                                          "Open Fast File", [OpenFastFile],_
                                          "Save Plot", [DataSave],_
                                          "Export AAVSO Format", [AAVSO],_
                                          "Export data in MEDUZA Format", [MEDUZA],_
                                          "Export Time Series in BRNO Format", [BRNO],_
                                          "Export Time Series in ETD Format", [ETD],_
                                          "Quit", [QuitShowData]
    Menu        #show, " Config ",        "Plot Dots", [PlotDots],_
                                          "Plot Lines",[PlotLines],_
                                          "Plot Std. Error",[PlotErrors],_
                                          "Select Johnson/Cousins", [SelectJohnson],_
                                          "Select Sloan", [SelectSloan]
    Menu        #show, " Cursor ",        "Cursor A", [CursorA],_
                                          "Cursor B", [CursorB],_
                                          "Cursor C (est. time of minimum)", [CursorC]
    Menu        #show, " Edit ",          "Edit Title",[EditTitle],_
                                          "Edit File Info",[EditFileInfo],_
                                          "Add Label",[AddLabel],_
                                          "Undo Label",[DeleteLabel]
    Menu        #show, " Analysis ",      "Eclipsing Binary Analysis", [FindMin],_
                                          "Phase Plot", [FindPeriod],_
                                          "Period Search", [PeriodSearch],_
                                          "Fourier Analysis", [FindFourier],_
                                          "Parabolic Curve Fit", [FindParabolic]
    Menu        #show, "Help",            "About", [About],_
                                          "Help", [Help]

    graphicbox  #show.graphicbox1,   11, 7, 995, 575

    groupbox    #show.groupbox1, "Variable Star File", 11, 585, 250, 85
    groupbox    #show.groupbox2, "Time Scale", 272, 585, 116, 85
    groupbox    #show.groupbox3, "Mag Scale", 399, 585, 116, 85
    groupbox    #show.groupbox7, "Plot", 526, 585, 63, 85
    groupbox    #show.groupbox4, "Move Date", 600, 585, 134, 85
    groupbox    #show.groupbox5, "Move Mag", 744, 585, 110, 85
    groupbox    #show.groupbox6, "Plot Colors", 864, 585, 140,85

    textbox     #show.FileName, 19, 620, 235, 23
    textbox     #show.StartDate, 608, 642, 90, 23
    textbox     #show.StartMag, 752, 642, 65, 23

    statictext  #show.StartDateText, "Enter Start Date", 615,627,90,15
    statictext  #show.StartMagText, "Enter Max Mag", 748,627,80,15

    button      #show.Plot, "",[Plot],UL, 532, 605, 51, 27
    button      #show.PlotIndex, "", [PlotIndex],UL, 532, 635, 51, 27

    button      #show.MoveTimeLeftFast, "<<",[MoveTimeLeftFast],UL, 608, 600, 25, 25
    button      #show.MoveTimeLeft, "<",[MoveTimeLeft], UL, 640, 600, 25, 25
    button      #show.MoveTimeRight, ">",[MoveTimeRight], UL, 672, 600, 25, 25
    button      #show.MoveTimeRightFast, ">>",[MoveTimeRightFast],UL, 703, 600, 25, 25
    button      #show.EnterDate, "",[EnterStartDate],UL, 703, 640, 25, 25

    button      #show.MoveMagUp, "",[MoveMagUp], UL, 769, 600, 25, 25
    button      #show.MoveMagDown, "",[MoveMagDown], UL, 800, 600, 25, 25
    button      #show.EnterMag, "", [EnterMag], UL, 822, 640, 25, 25

    button      #show.PlotU, "U", [PlotU], UL, 874, 600, 22, 22
    button      #show.PlotB, "B", [PlotB], UL, 907, 600, 22, 22
    button      #show.PlotR, "R", [PlotR], UL, 940, 600, 22, 22
    button      #show.PlotI, "I", [PlotI], UL, 973, 600, 22, 22

    button      #show.PlotBV, "B-V", [PlotBV], UL, 874, 623, 57, 20
    button      #show.PlotUB, "U-B", [PlotUB], UL, 874, 645, 57, 20
    button      #show.PlotVR, "V-R", [PlotVR], UL, 940, 623, 57, 20
    button      #show.PlotVI, "V-I", [PlotVI], UL, 940, 645, 57, 20

    combobox    #show.TimeScale, TimeScale$(),[TimeScale], 280, 620, 100, 25
    combobox    #show.Magnitude, MagScale$(), [MagScale], 407, 620, 100, 25

    Open "Plot/Analyze Data - Johnson/Cousins/Sloan Photometry" for Window as #show

    #show "trapclose [QuitShowData]"
    #show.graphicbox1 "down; fill White; flush"
    #show "font courier_new 10 14"

    print #show.StartDateText, "!font ariel 8"
    print #show.StartMagText, "!font ariel 8"

    print #show.EnterDate, "«"
    print #show.EnterMag,  "«"

    print #show.MoveMagUp, "!font symbol 10 12"
    print #show.MoveMagUp, "Ù"
    print #show.MoveMagDown, "!font symbol 10 12"
    print #show.MoveMagDown, "Ú"

    print #show.MoveTimeLeftFast, "!disable"
    print #show.MoveTimeLeft, "!disable"
    print #show.MoveTimeRight, "!disable"
    print #show.MoveTimeRightFast, "!disable"
    print #show.EnterDate, "!disable"

    print #show.MoveMagUp, "!disable"
    print #show.MoveMagDown, "!disable"
    print #show.EnterMag, "!disable"

    print #show.PlotU, "!disable"
    print #show.PlotB, "!disable"
    print #show.PlotR, "!disable"
    print #show.PlotI, "!disable"

    print #show.PlotUB, "!disable"
    print #show.PlotBV, "!disable"
    print #show.PlotVR, "!disable"
    print #show.PlotVI, "!disable"

    print #show.TimeScale, "disable"
    print #show.Magnitude, "disable"

    print #show.graphicbox1, "setfocus; when leftButtonDown [FindPosition]"
    print #show.graphicbox1, "setfocus; when rightButtonDown [EraseCursor]"

    print #show.PlotU, "!font arial 10"
    print #show.PlotB, "!font arial 10"
    print #show.PlotR, "!font arial 10"
    print #show.PlotI, "!font arial 10"

    gosub [Draw_Graph_Outline]

    print #show.FileName, "open data file"

Wait                                'finished setting up, wait here for new command
'
'======menu controls
'
[OpenFile]                                          'opens variable star file
    filedialog "Open Data File", PathDataFile$, DataFile$

    for I = len(DataFile$) to 1 step -1             'remember path for opened folder and file
        if mid$(DataFile$,I,1) = "\" then
            ShortDataFile$ = mid$(DataFile$,I+1)
            PathDataFile$ = left$(DataFile$,I)+"*var"
            exit for
        end if
    next I

    if DataFile$ = "" then
        wait
    else
        open DataFile$ for input as #VarFile
        files "c:\", DataFile$, info$()
        if val(info$(0, 0)) = 0 then
            notice "cannot create new file"
        else
            gosub [Find_File_Name]                  'extract filename from path and print in file box

            open "IREX.txt" for output as #IREX
                print #IREX, "ShowData2, Version "; VersionNumber$
                print #IREX, "filename, output from [Find_File_Name] ";DataFileName$
                print #IREX, " "
            close #IREX

            CompStar$ = ""
            VarStar$ = ""
            VarIndex = 0
            FileHeaderFlag = 0
                while eof(#VarFile)=0               'read variable data to end of file
                    VarIndex = VarIndex + 1
                    line input #VarFile, VarData$(VarIndex)
                    if left$(VarData$(VarIndex),1) = "#" then
                        FileHeaderFlag = 1
                        VarIndex = 0
                    end if
                wend
                VarIndexMax = VarIndex
            close #VarFile
            if FileHeaderFlag = 1 then              'read the header info only if it exists
                open DataFile$ for input as #VarFile
                input #VarFile, Temp$, FilterSystem$, JDFlag, CompStar$, VarStar$
                close #VarFile
            else
                FilterSystem$ = "1"
                JDFlag = 1
            end if
        end if
    end if
                                                    'get file name without type
    PlotFileName$ = upper$(left$(DataFileName$, (len(DataFileName$) - 4)))

    Redim TimeScale$(15)
    TimeScale$(1)  = " 1.000m"
    TimeScale$(2)  = " 2.000m"
    TimeScale$(3)  = " 5.000m"
    TimeScale$(4)  = "10.000m"
    TimeScale$(5)  = " 1.000h"
    TimeScale$(6)  = " 2.000h"
    TimeScale$(7)  = " 5.000h"
    TimeScale$(8)  = "10.000h"
    TimeScale$(9)  = " 1.000d"
    TimeScale$(10) = " 2.000d"
    TimeScale$(11) = " 5.000d"
    TimeScale$(12) = "10.000d"
    TimeScale$(13) = "20.000d"
    print #show.TimeScale, "reload"
    print #show.TimeScale, "select ";"select"

    Redim MagScale$(7)
    MagScale$(1)   = " 0.01"
    MagScale$(2)   = " 0.02"
    MagScale$(3)   = " 0.05"
    MagScale$(4)   = " 0.10"
    MagScale$(5)   = " 0.20"
    MagScale$(6)   = " 0.50"
    MagScale$(7)   = " 1.00"
    print #show.Magnitude, "reload"
    print #show.Magnitude, "select ";""

    gosub [ConvertVarFile]                          'extract all data

    PlotFlag = 1                                    'plot V magnitude
    CursorFlag = 0                                  'no cursor
    FileHeader$ = ""                                'blank out file info for variable star data
    CursorFlag.B = 0

    print #show.PlotIndex, "!enable"
    if FilterSystem$ = "1" then
        print #show.Plot, "V"
    else
        print #show.Plot, "r'"
    end if

    print #show.PlotIndex, "Index"

    print #show.MoveTimeLeft, "!disable"
    print #show.MoveTimeLeftFast, "!disable"
    print #show.MoveTimeRight, "!disable"
    print #show.MoveTimeRightFast, "!disable"
    print #show.EnterDate, "!disable"

    print #show.MoveMagUp, "!disable"
    print #show.MoveMagDown, "!disable"
    print #show.EnterMag, "!disable"

    print #show.PlotU, "!disable"
    print #show.PlotB, "!disable"
    print #show.PlotR, "!disable"
    print #show.PlotI, "!disable"

    print #show.PlotUB, "!disable"
    print #show.PlotBV, "!disable"
    print #show.PlotVR, "!disable"
    print #show.PlotVI, "!disable"

    print #show.TimeScale, "enable"
    print #show.Magnitude, "enable"

    print #show.StartDate, ""
    print #show.StartMag,  ""

    print #show.graphicbox1, "delsegment ";CursorValuesSegment.A
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.B
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.C
    print #show.graphicbox1, "delsegment ";MagScaleSegment
    print #show.graphicbox1, "delsegment ";TimeScaleSegment
    print #show.graphicbox1, "delsegment ";DrawDataSegment
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    print #show.graphicbox1, "delsegment ";CursorSegmentC
    print #show.graphicbox1, "delsegment ";CursorSegmentD
    print #show.graphicbox1, "delsegment ";CursorDiffSegment
    print #show.graphicbox1, "delsegment ";DrawTitle

    print #show.graphicbox1, "delsegment ";DrawUSegment
    print #show.graphicbox1, "delsegment ";DrawBSegment
    print #show.graphicbox1, "delsegment ";DrawRSegment
    print #show.graphicbox1, "delsegment ";DrawISegment

    print #show.graphicbox1, "delsegment ";DrawUBSegment
    print #show.graphicbox1, "delsegment ";DrawBVSegment
    print #show.graphicbox1, "delsegment ";DrawVRSegment
    print #show.graphicbox1, "delsegment ";DrawVISegment

    print #show.graphicbox1, "delsegment ";DrawParabolicSegment

    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next

    LabelCounter = 0
    CursorFlag.C = 0
    CursorFlag.B = 0
    CursorFlag.A = 0
    CursorTime.A$ = ""
    CursorTime.B$ = ""
    CursorTime.C$ = ""
    CursorTime.A = 0
    CursorTime.B = 0
    CursorTime.C = 0
    CursorID$ = "A"

    print #show.graphicbox1, "redraw"
Wait
'
[OpenFastFile]                                      'open fast data files
    filedialog "Open Data File", PathDataFastFile$, DataFile$

    FastIndex = 0
    for I = len(DataFile$) to 1 step -1             'remember path for opened folder and file
        if mid$(DataFile$,I,1) = "\" then
            ShortDataFile$ = mid$(DataFile$,I+1)
            PathDataFile$ = left$(DataFile$,I)+"*var"
            exit for
        end if
    next I

    if DataFile$ = "" then
        wait
    else
        open DataFile$ for input as #VarFile
        files "c:\", DataFile$, info$()
        if val(info$(0, 0)) = 0 then
            notice "cannot create new file"
        else
            gosub [Find_File_Name]

            open "IREX.txt" for output as #IREX
                print #IREX, "filename, output from [Find_File_Name] ";DataFileName$
                print #IREX, " "
            close #IREX

            VarIndex = 0
                while eof(#VarFile)=0               'read variable data to end of file
                    FastIndex = FastIndex + 1
                    input #VarFile, FastData$(FastIndex)
                wend
                FastIndexMax = FastIndex
            close #VarFile
            FileHeader$ = FastData$(2)
        end if
    end if
                                                    'find file name without type
    PlotFileName$ = upper$(left$(DataFileName$, (len(DataFileName$) - 4)))

    redim TimeScale$(4)
    TimeScale$(1)  = " 0.010s"
    TimeScale$(2)  = " 0.100s"
    TimeScale$(3)  = " 1.000s"
    TimeScale$(4)  = "10.000s"
    print #show.TimeScale, "reload"
    print #show.TimeScale, "select ";""

    redim MagScale$(5)
    MagScale$(1) = "   5"
    MagScale$(2) = "  10"
    MagScale$(3) = "  50"
    MagScale$(4) = " 100"
    MagScale$(5) = "1000"
    print #show.Magnitude, "reload"
    print #show.Magnitude, "select ";""

    gosub [ConvertFastFile]

    PlotFlag = 0                                'plot count
    CursorFlag = 0                              'no cursor
    CursorFlag.B = 0

    print #show.Plot, "C"
    print #show.PlotIndex, ""

    print #show.MoveTimeLeft, "!disable"
    print #show.MoveTimeLeftFast, "!disable"
    print #show.MoveTimeRight, "!disable"
    print #show.MoveTimeRightFast, "!disable"
    print #show.EnterDate, "!disable"
    print #show.PlotIndex, "!disable"

    print #show.MoveMagUp, "!disable"
    print #show.MoveMagDown, "!disable"
    print #show.EnterMag, "!disable"

    print #show.PlotU, "!disable"
    print #show.PlotB, "!disable"
    print #show.PlotR, "!disable"
    print #show.PlotI, "!disable"

    print #show.PlotUB, "!disable"
    print #show.PlotBV, "!disable"
    print #show.PlotVR, "!disable"
    print #show.PlotVI, "!disable"

    print #show.TimeScale, "enable"
    print #show.Magnitude, "enable"

    print #show.StartDate, ""
    print #show.StartMag,  ""
wait
'
[DataSave]                                      'save bitmap image to disk
    filedialog "Save As...", PathPlotFile$, PlotFile$
    for I = len(PlotFile$) to 1 step -1
        if mid$(PlotFile$,I,1) = "\" then
            ShortPlotFile$ = mid$(PlotFile$,I+1)
            PathPlotFile$ = left$(PlotFile$,I)+"*bmp"
            exit for
        end if
    next I

    if PlotFile$ <> "" then
        print #show.graphicbox1, "getbmp plot 0 0 993 573"
        if (right$(PlotFile$,4) = ".bmp") OR (right$(PlotFile$,4) = ".BMP") then
            bmpsave "plot", PlotFile$
        else
            PlotFile$ = PlotFile$+".bmp"
            bmpsave "plot", PlotFile$
        end if
    end if
wait
'
[FindPosition]                                  'find position from cursor mouse values
    if CursorFlag = 1 then
        gosub [DrawCursor]

        if PlotFlag = 1 OR PlotFlag = 2 then       'slow data file
            CursorTime = val(StartTime$) + ((MouseX - 40)/PixelTime)
            CursorTime$ = using("####.####",CursorTime)

            if PlotFlag = 1 then
                CursorMag = MagScaleArray(0) + (MouseY - 20)/PixelMag
                CursorMag$ = using("###.###",CursorMag)
            else
                CursorMag = VarColorMax - (MouseY - 20)/PixelMag
                CursorMag$ = using("###.###",CursorMag)
            end if
        else                                        'fast data file
            CursorTime = (MouseX - 40)/PixelTime + StartTime

                HR = int(CursorTime / 3600)
                MIN = int((CursorTime MOD 3600) / 60)
                SEC = CursorTime - 3600 * HR - 60 * MIN

                if HR >= 24 then
                    HR = HR - 24
                end if

                HR$ = using("##",HR)
                MIN$ = using("##",MIN)
                SEC$ = using("##.###",SEC)

            CursorTime$ = HR$+":"+MIN$+":"+SEC$

            CursorMag = CountMax - (MouseY - 20)/PixelMag
            CursorMag$ = using("####",CursorMag)
        end if

        Select Case CursorID$
            Case "A"
                CursorMag.A = CursorMag
                CursorMag.A$ = CursorMag$
                CursorTime.A = CursorTime
                CursorTime.A$ = CursorTime$
                gosub [DrawCursorValues.A]

                Select Case
                    case MagScale = 0.01 or MagScale = 0.02 or MagScale = 0.05
                        print #show.StartDate, CursorTime.A$
                        CursorMagMax.A$ = left$(CursorMag.A$,6)
                        print #show.StartMag, CursorMagMax.A$
                    case MagScale = 0.10 or MagScale = 0.20 or MagScale = 0.50
                        print #show.StartDate, CursorTime.A$
                        CursorMagMax.A$ = left$(CursorMag.A$,5)
                        print #show.StartMag, CursorMagMax.A$
                    case MagScale = 1.0
                        print #show.StartDate, CursorTime.A$
                        CursorMagMax.A$ = left$(CursorMag.A$,3)
                        print #show.StartMag, CursorMagMax.A$
                    case MagScale = 5 or MagScale = 10
                        print #show.StartDate, left$(CursorTime.A$,8)
                        CursorMagMax.A$ = str$(int((CursorMag.A+5)/10)*10)
                        print #show.StartMag, CursorMagMax.A$
                    case MagScale = 50 or MagScale = 100
                        print #show.StartDate, left$(CursorTime.A$,8)
                        CursorMagMax.A$ = str$(int((CursorMag.A+50)/100)*100)
                        print #show.StartMag, CursorMagMax.A$ 
                    case MagScale = 1000
                        print #show.StartDate, left$(CursorTime.A$,8)
                        CursorMagMax.A$ = str$(int((CursorMag.A+500)/1000)*1000)
                        print #show.StartMag, CursorMagMax.A$ 
                End Select
                CursorFlag.A = 1
            Case "B"
                CursorMag.B = CursorMag
                CursorMag.B$ = CursorMag$
                CursorTime.B = CursorTime
                CursorTime.B$ = CursorTime$ 
                gosub [DrawCursorValues.B]

                CursorFlag.B = 1
            Case "C"
                CursorTime.C = CursorTime
                CursorTime.C$ = CursorTime$
                gosub [DrawCursorValues.C]
        End Select

        CursorTimeDiff = CursorTime.B - CursorTime.A
        if CursorTimeDiff < 0 then
            Sign = 1
            CursorTimeDiff = abs(CursorTimeDiff)
        else
            Sign = 0
        end if

        CursorMagDiff = CursorMag.B - CursorMag.A

        if PlotFlag = 1 OR PlotFlag = 2 then
            CursorTimeDiff$ = using("###.####", CursorTimeDiff)
            CursorMagDiff$ = using("###.###",CursorMagDiff)
        end if

        if PlotFlag = 0 then
                HR = int(CursorTimeDiff / 3600)
                MIN = int((CursorTimeDiff MOD 3600) / 60)
                SEC = CursorTimeDiff - 3600 * HR - 60 * MIN

                if HR >= 24 then
                    HR = HR - 24
                end if

                HR$ = using("##",HR)
                MIN$ = using("##",MIN)
                SEC$ = using("##.###",SEC)

            CursorTimeDiff$ = HR$+":"+MIN$+":"+SEC$ 
            CursorMagDiff$ = using("#####",CursorMagDiff)
        end if

        if CursorFlag.B = 1 and CursorFlag.A = 1 then
            gosub [DrawCursorDiffValues]
        else
            CursorTimeDiff$ = ""
            CursorMagDiff$ = ""
            gosub [DrawCursorDiffValues]
        end if
    else
        notice "plot the data first"
    end if
wait
'
[EraseCursor]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    print #show.graphicbox1, "delsegment ";CursorSegmentC
    print #show.graphicbox1, "delsegment ";CursorSegmentD
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.A
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.B
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.C
    print #show.graphicbox1, "delsegment ";CursorDiffSegment
    print #show.graphicbox1, "redraw"
    CursorFlag.C = 0
    CursorFlag.B = 0
    CursorFlag.A = 0
    CursorTime.A$ = ""
    CursorTime.B$ = ""
    CursorTime.C$ = ""
wait
'
[PlotDots]
        ConnectDotFlag = 0
wait
'
[PlotLines]
        ConnectDotFlag = 1
wait
'
[PlotErrors]
    confirm "include error limits in data?"; ErrorAnswer$
    if ErrorAnswer$ = "yes" then
        PlotErrorFlag = 1
    else
        PlotErrorFlag = 0
    end if
wait
'
[SelectJohnson]
    print #show.PlotU, "U"
    print #show.PlotB, "B"
    print #show.Plot, "V"
    print #show.PlotR, "R"
    print #show.PlotI, "I"
    print #show.PlotBV, "B-V"
    print #show.PlotUB, "U-B"
    print #show.PlotVR, "V-R"
    print #show.PlotVI, "V-I"
    FilterSystem$ = "1"
wait
'
[SelectSloan]
    print #show.PlotU, "u'"
    print #show.PlotB, "g'"
    print #show.Plot, "r'"
    print #show.PlotR, "i'"
    print #show.PlotI, "z'"
    print #show.PlotBV, "g'-r'"
    print #show.PlotUB, "u'-g'"
    print #show.PlotVR, "r'-i'"
    print #show.PlotVI, "r'-z'"
    FilterSystem$ = "0"
wait
'
[EditTitle]
    TempFileName$ = PlotFileName$
    prompt "Enter new title"; TempFileName$
    if TempFileName$ <> "" then
        PlotFileName$ = TempFileName$ 
        gosub [DrawTitles]
    end if
wait
'
[EditFileInfo]
    TempFileName$ = FileHeader$
    prompt "Enter new file info";TempFileName$
    if TempFileName$ <> "" then
        FileHeader$ = TempFileName$
        gosub [DrawTitles]
    end if
wait
'
[AddLabel]
    if CursorFlag = 0 then
        notice "plot data first"
    else
        prompt "add label at cursor position"; Label$
        if Label$ <> "" then
            gosub [DrawLabel]
        end if
    end if
wait
'
[DeleteLabel]
    print #show.graphicbox1, "delsegment ";DrawLabel(LabelCounter)
    print #show.graphicbox1, "redraw"
    LabelCounter = LabelCounter - 1
wait
'
[CursorA]
    CursorID$ = "A"
wait
'
[CursorB]
    CursorID$ = "B"
wait
'
[CursorC]
    CursorID$ = "C"
wait
'
[About]
    notice "Plot Data - Johnson/Cousins/Sloan Differential Photometry"+chr$(13)+_
           " version "+VersionNumber$+chr$(13)+_
           " copyright 2015, Gerald Persha."+chr$(13)+_
           " www.sspdataq.com"
Wait
'
[Help]
    run "hh photometry2.chm"
Wait
'
[QuitShowData]                   'exit program
    confirm "do you wish to exit program?"; Answer$

    if Answer$ = "yes" then
        if AAVSOFlag = 1 then
            close #export
        end if
        if FindMinimumFlag = 1 then
            close #FindMinimum
        end if
        if FindPeriodFlag = 1 then
            close #FindPeriod
        end if
        if FindFourierFlag = 1 then
            close #FindFourier
        end if
        if PeriodSearchFlag = 1 then
            close #PeriodSearch
        end if
        if ETDFlag = 1 then
            close #exportETD
        end if
        if MEDUZAFlag = 1 then
            close #exportMEDUZA
        end if
        if BRNOFlag = 1 then
            close #exportBRNO
        end if
        if PARABOLICFlag = 1 then
            close #Parabolic
        end if
        close #show
        END
    else
        wait
    end if
'
'=====comboboxes input
'
[TimeScale]
    print #show.TimeScale, "selection? TimeScaleIndex$"
    Select Case TimeScaleIndex$
        Case " 0.002s"
            TimeScale = 0.002
        Case " 0.010s"
            TimeScale = 0.010
        Case " 0.100s"
            TimeScale = 0.100
        Case " 1.000s"
            TimeScale = 1
        Case "10.000s"
            TimeScale = 10
        Case " 1.000m"
            TimeScale = 60
        Case " 2.000m"
            TimeScale = 120
        Case " 5.000m"
            TimeScale = 300
        Case "10.000m"
            TimeScale = 600
        Case " 1.000h"
            TimeScale = 3600
        Case " 2.000h"
            TimeScale = 7200
        Case " 5.000h"
            TimeScale = 18000
        Case "10.000h"
            TimeScale = 36000
        Case " 1.000d"
            TimeScale = 86400
        Case " 2.000d"
            TimeScale = 172800
        Case " 5.000d"
            TimeScale = 432000
        Case "10.000d"
            TimeScale = 864000
        Case "20.000d"
            TimeScale = 1728000
    End Select

    open "IREX.txt" for append as #IREX
        print #IREX, "Time Scale Pick ";TimeScale
        print #IREX, " "
    close #IREX
wait
'
[MagScale]
    print #show.Magnitude, "selection? MagScaleIndex$"
    Select Case MagScaleIndex$
        Case " 0.01"
            MagScale = 0.01
       Case " 0.02"
            MagScale = 0.02
        Case " 0.05"
            MagScale = 0.05
        Case " 0.10"
            MagScale = 0.10
        Case " 0.20"
            MagScale = 0.20
        Case " 0.50"
            MagScale = 0.50
        Case " 1.00"
            MagScale = 1.00
        Case "   5"
            MagScale = 5
        Case "  10"
            MagScale = 10
        Case "  50"
            MagScale = 50
        Case " 100"
            MagScale = 100
         Case "1000"
            MagScale = 1000
    End Select

    CountsMax = MagScale * 10

    open "IREX.txt" for append as #IREX
        print #IREX, "Mag Scale Pick ";MagScale
        print #IREX, " "
    close #IREX
wait
'
'=====control buttons
'
[Plot]
    if PlotFlag = 2 then
        PlotFlag = 1
    end if

    print #show.graphicbox1, "delsegment ";DrawUBSegment
    print #show.graphicbox1, "delsegment ";DrawBVSegment
    print #show.graphicbox1, "delsegment ";DrawVRSegment
    print #show.graphicbox1, "delsegment ";DrawVISegment

    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.A
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.B
    print #show.graphicbox1, "delsegment ";CursorDiffSegment

    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0

    print #show.graphicbox1, "redraw"
    CursorFlag.B = 0
    CursorID$ = "A"

    if PlotFlag = 1 then
        print #show.StartDateText, "Enter Start Date"
        print #show.StartMagText, "Enter Max Mag"
        gosub [PlotV]
    end if
    if PlotFlag = 0 then
        print #show.StartDateText, "Enter Start Time"
        print #show.StartMagText, "Enter Max Count"
        gosub [PlotC]
    end if

    print #show.PlotUB, "!disable"
    print #show.PlotBV, "!disable"
    print #show.PlotVR, "!disable"
    print #show.PlotVI, "!disable"
wait
'
[PlotIndex]
    print #show.graphicbox1, "delsegment ";DrawUBSegment
    print #show.graphicbox1, "delsegment ";DrawBVSegment
    print #show.graphicbox1, "delsegment ";DrawVRSegment
    print #show.graphicbox1, "delsegment ";DrawVISegment

    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.A
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.B
    print #show.graphicbox1, "delsegment ";CursorDiffSegment

    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0

    print #show.graphicbox1, "redraw"
    CursorFlag.B = 0
    CursorID$ = "A"

    PlotFlag = 2                                            'plotting index values

    print #show.StartDateText, "Enter Start Date"
    print #show.StartMagText, "Enter Max Mag"

    gosub [PlotColorIndex]
wait
'
[PlotU]
    gosub [DrawU]
wait
'
[PlotB]
    gosub [DrawB]
wait
'
[PlotR]
    gosub [DrawR]
wait
'
[PlotI]
    gosub [DrawI]
wait
'
[PlotUB]
    gosub [DrawUBindex]
wait
'
[PlotBV]
    gosub [DrawBVindex]
wait
'
[PlotVR]
    gosub [DrawVRindex]
wait
'
[PlotVI]
    gosub [DrawVIindex]
wait
'
[MoveTimeLeft]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB

    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0
    print #show.graphicbox1, "redraw"

    select case PlotFlag
        case 0
            StartTime = StartTime - 10 * TimeScale
            gosub [FindStartTime]
            gosub [DrawData]
        case 1
            StartJ2000 = StartJ2000 - 10 * TimeScaleJ2000
            StartJ2000$ = using("####.####",StartJ2000)
            StartTime$ = StartJ2000$ 
            gosub [DrawUBRImags]
            gosub [DrawData]
            gosub [DrawUBRImags]
        case 2
            StartJ2000 = StartJ2000 - 10 * TimeScaleJ2000
            StartJ2000$ = using("####.####",StartJ2000)
            StartTime$ = StartJ2000$
            gosub [DrawColorIndicies]
        end select
        gosub [DrawTimeScale]
wait
'
[MoveTimeRight]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0
    print #show.graphicbox1, "redraw"

    select case PlotFlag
        case 0
            StartTime = StartTime + 10 * TimeScale
            gosub [FindStartTime]
            gosub [DrawData]
        case 1
            StartJ2000 = StartJ2000 + 10 * TimeScaleJ2000
            StartJ2000$ = using("####.####",StartJ2000)
            StartTime$ = StartJ2000$ 
            gosub [DrawUBRImags]
            gosub [DrawData]
            gosub [DrawUBRImags]
        case 2
            StartJ2000 = StartJ2000 + 10 * TimeScaleJ2000
            StartJ2000$ = using("####.####",StartJ2000)
            StartTime$ = StartJ2000$
            gosub [DrawColorIndicies]
        end select
        gosub [DrawTimeScale]
wait
'
[MoveTimeLeftFast]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0
    print #show.graphicbox1, "redraw"

    select case PlotFlag
        case 0
            StartTime = StartTime - 50 * TimeScale
            gosub [FindStartTime]
            gosub [DrawData]
        case 1
            StartJ2000 = StartJ2000 - 50 * TimeScaleJ2000
            StartJ2000$ = using("####.####",StartJ2000)
            StartTime$ = StartJ2000$ 
            gosub [DrawUBRImags]
            gosub [DrawData]
            gosub [DrawUBRImags]
        case 2
            StartJ2000 = StartJ2000 - 50 * TimeScaleJ2000
            StartJ2000$ = using("####.####",StartJ2000)
            StartTime$ = StartJ2000$
            gosub [DrawColorIndicies]
        end select
        gosub [DrawTimeScale]
wait
'
[MoveTimeRightFast]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0
    print #show.graphicbox1, "redraw"

    select case PlotFlag
        case 0
            StartTime = StartTime + 50 * TimeScale
            gosub [FindStartTime]
            gosub [DrawData]
        case 1
            StartJ2000 = StartJ2000 + 50 * TimeScaleJ2000
            StartJ2000$ = using("####.####",StartJ2000)
            StartTime$ = StartJ2000$ 
            gosub [DrawUBRImags]
            gosub [DrawData]
            gosub [DrawUBRImags]
        case 2
            StartJ2000 = StartJ2000 + 50 * TimeScaleJ2000
            StartJ2000$ = using("####.####",StartJ2000)
            StartTime$ = StartJ2000$
            gosub [DrawColorIndicies]
        end select
        gosub [DrawTimeScale]
wait
'
[EnterStartDate]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0
    print #show.graphicbox1, "redraw"

    print #show.StartDate, "!contents?"
    input #show.StartDate, NewDate$

        if NewDate$ = "" then
            notice "enter valid value"
            wait
        end if

    Select Case PlotFlag
        case 0
            For I = 1 to 5
                if mid$(NewDate$,I,1) = ":" then
                    C1 = I
                    exit for
                end if
            next
            HR$ = left$(NewDate$,(C1 - 1))

            if val(HR$) > 24 OR val(HR$) < 0 then
                notice "entire valid hour value"
                wait
            end if

            For I = 1 to 5
                if mid$(NewDate$,(C1 + 1 + I),1) = ":" then
                    C2 = C1 + 1 + I
                    exit for
                end if
            next
            MIN$ = mid$(NewDate$, (C1+1), I)

            if val(MIN$) > 60 OR val(MIN$) < 0 then
                notice "entire valid minute value"
                wait
            end if

            SEC$ = mid$(NewDate$, (C2+1))

            if val(SEC$) > 60 OR val(SEC$) < 0 then
                notice "entire valid second value"
                wait
            end if

            StartTime = val(HR$)*3600 + val(MIN$)*60 + val(SEC$)

            gosub [FindStartTime]
            gosub [DrawData]

            open "IREX.txt" for append as #IREX
                print #IREX, "Output from start time textbox"
                print #IREX, "NewDate$ = ";NewDate$;"  StartTime = ";StartTime;"  HR$ = ";HR$;"  MIN$ = ";MIN$;"  SEC$ = ";SEC$
                print #IREX, " "
            close #IREX
        case 1

            if val(NewDate$) < 1000 OR val(NewDate$) > 9999 then
                notice "enter valid date (1000 - 9999)"
                wait
            end if

            StartJ2000$ = using("####.####",val(NewDate$))
            StartJ2000 = val(StartJ2000$)
            StartTime$ = StartJ2000$ 

            gosub [DrawData]
            gosub [DrawUBRImags]
        case 2

            if val(NewDate$) < 1000 OR val(NewDate$) > 9999 then
                notice "enter valid date (1000 - 9999)"
                wait
            end if

            StartJ2000$ = using("####.####",val(NewDate$))
            StartTime$ = StartJ2000$ 
            gosub [DrawColorIndicies]
        end select

        gosub [DrawTimeScale]
wait
'
[MoveMagUp]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0
    print #show.graphicbox1, "redraw"

    Select Case PlotFlag
        case 0
            CountMax = CountMax + MagScale
            gosub [DrawData]
        case 1
            MagScaleArray(0) = MagScaleArray(0) - MagScale
            gosub [DrawData]
            gosub [DrawUBRImags]
        case 2
            VarColorMax = VarColorMax + MagScale
            MagScaleArray(0) = VarColorMax
            gosub [DrawColorIndicies]
        end select

    gosub [MakeMagArray]
    gosub [DrawMagScale]
wait
'
[MoveMagDown]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0
    print #show.graphicbox1, "redraw"

    Select Case PlotFlag
        case 0
            CountMax = CountMax - MagScale
            gosub [DrawData]
        case 1
            MagScaleArray(0) = MagScaleArray(0) + MagScale
            gosub [DrawData]
            gosub [DrawUBRImags]
        case 2
            VarColorMax = VarColorMax - MagScale
            MagScaleArray(0) = VarColorMax
            gosub [DrawColorIndicies]
        end select

    gosub [MakeMagArray]
    gosub [DrawMagScale]
wait
'
[EnterMag]
    print #show.graphicbox1, "delsegment ";CursorSegmentA
    print #show.graphicbox1, "delsegment ";CursorSegmentB
    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0
    print #show.graphicbox1, "redraw"

    print #show.StartMag, "!contents?"
    input #show.StartMag, TestContents$ 
        if TestContents$ = "" then
            notice "enter valid value"
            wait
        end if

    Select Case PlotFlag
        case 0
            print #show.StartMag, "!contents?"
            input #show.StartMag, CountMax$ 
            CountMax = val(CountMax$)
            gosub [DrawData]
        case 1
            print #show.StartMag, "!contents?"
            input #show.StartMag, VarMagMax$
            VarMagMax = val(VarMagMax$)
            MagScaleArray(0) = VarMagMax
            gosub [DrawData]
            gosub [DrawUBRImags]
        case 2
            print #show.StartMag, "!contents?"
            input #show.StartMag, VarColorMax$
            VarColorMax = val(VarColorMax$)
            MagScaleArray(0) = VarColorMax
            gosub [DrawColorIndicies]
        end select

    gosub [MakeMagArray]
    gosub [DrawMagScale]
wait
'
'=====subroutines
'
[ConvertVarFile]       'extract individual data items from each indexed data line

    open "IREX.txt" for append as #IREX
        print #IREX, "Variable star file data, output from [Convert_VarFile]"

    For VarIndex = 1 to VarIndexMax
        if len(VarData$(VarIndex)) < 99 then                       'delete any extra junk at end of file
            VarIndexMax = VarIndex-1
            exit for
        end if
        VarItem$(VarIndex,1)  = mid$(VarData$(VarIndex),1,2)        'UT day
        VarItem$(VarIndex,2)  = mid$(VarData$(VarIndex),4,2)        'UT month
        VarItem$(VarIndex,3)  = mid$(VarData$(VarIndex),7,4)        'UT year
        VarItem$(VarIndex,4)  = mid$(VarData$(VarIndex),13,2)       'UT hour
        VarItem$(VarIndex,5)  = mid$(VarData$(VarIndex),16,2)       'UT minute
        VarItem$(VarIndex,6)  = mid$(VarData$(VarIndex),19,2)       'UT second
        VarItem$(VarIndex,7)  = mid$(VarData$(VarIndex),22,9)       'Julian date
        VarItem$(VarIndex,8)  = mid$(VarData$(VarIndex),33,6)       'V magnitude
        VarItem$(VarIndex,9)  = mid$(VarData$(VarIndex),40,5)       'V standard error
        VarItem$(VarIndex,10) = mid$(VarData$(VarIndex),47,6)       'U-B
        VarItem$(VarIndex,11) = mid$(VarData$(VarIndex),54,5)       'U-B standard error
        VarItem$(VarIndex,12) = mid$(VarData$(VarIndex),61,6)       'B-V
        VarItem$(VarIndex,13) = mid$(VarData$(VarIndex),68,5)       'B-V standard error
        VarItem$(VarIndex,14) = mid$(VarData$(VarIndex),75,6)       'V-R
        VarItem$(VarIndex,15) = mid$(VarData$(VarIndex),82,5)       'V-R standard error
        VarItem$(VarIndex,16) = mid$(VarData$(VarIndex),89,6)       'V-I
        VarItem$(VarIndex,17) = mid$(VarData$(VarIndex),96,5)       'V-I standard error

        Print #IREX,using("###",VarIndex);"  ";_
            VarItem$(VarIndex,1);" ";_
            VarItem$(VarIndex,2);" ";_
            VarItem$(VarIndex,3);" ";_
            VarItem$(VarIndex,4);" ";_
            VarItem$(VarIndex,5);" ";_
            VarItem$(VarIndex,6);" ";_
            VarItem$(VarIndex,7);" ";_
            VarItem$(VarIndex,8);" ";_
            VarItem$(VarIndex,9);" ";_
            VarItem$(VarIndex,10);" ";_
            VarItem$(VarIndex,11);" ";_
            VarItem$(VarIndex,12);" ";_
            VarItem$(VarIndex,13);" ";_
            VarItem$(VarIndex,14);" ";_
            VarItem$(VarIndex,15);" ";_
            VarItem$(VarIndex,16);" ";_
            VarItem$(VarIndex,17)
    next

    StartJ2000$ = VarItem$(1,7)
    StartJ2000  = val(VarItem$(1,7))

    print #IREX, " "
    close #IREX

    For I = 0 to LabelCounter
        print #show.graphicbox1, "delsegment ";DrawLabel(I)
    next
    LabelCounter = 0

    print #show.graphicbox1, "redraw"

    CursorID$ = "A"
return
'
[ConvertFastFile]
    open "IREX.txt" for append as #IREX
    print #IREX, "Fast star file data, output from [ConvertFastFile]"

    FastDate$ = mid$(FastData$(2),1,10)
    FastHeader$ = mid$(FastData$(2),13)

    print #IREX,"  FastDate$:    ";FastDate$
    print #IREX,"  FastHeader$:  "; FastHeader$
    print #IREX,"  FastIndexMax: ";FastIndexMax
    print #IREX," "

    For FastIndex = 6 to FastIndexMax
        if len(FastData$(FastIndex)) < 20 then        'delete any extra junk at end of file
            FastIndexMax = FastIndex-1
            exit for
        end if
        FastItem$(FastIndex,1) = mid$(FastData$(FastIndex),1,4)         'count index
        FastItem$(FastIndex,2) = mid$(FastData$(FastIndex),7,2)         'hr
        FastItem$(FastIndex,3) = mid$(FastData$(FastIndex),10,2)        'minutes
        FastItem$(FastIndex,4) = mid$(FastData$(FastIndex),13,6)        'seconds
        FastItem$(FastIndex,5) = mid$(FastData$(FastIndex),22,4)        'count

        FastTime(FastIndex-5) = 3600 * Val(FastItem$(FastIndex,2))+_    'time in seconds for making the plot
                                60 * val(FastItem$(FastIndex,3))+_
                                val(FastItem$(FastIndex,4))
        FastCounts(FastIndex -5) = val(FastItem$(FastIndex,5))          'count

        FastIndex$ = using("####",FastIndex)
        print #IREX,FastIndex$;"   ";_
            FastItem$(FastIndex,1);"   ";_
            FastItem$(FastIndex,2);":";_
            FastItem$(FastIndex,3);":";_
            FastItem$(FastIndex,4);"  ";_
            FastItem$(FastIndex,5);"     ";_
            using("######.###",FastTime(FastIndex -5));"   ";_
            FastCounts(FastIndex -5)
    next
                                                                    'initial start time
        StartTimeInitial$ = FastItem$(6,2)+":"+FastItem$(6,3)+":"+FastItem$(6,4)
        StartTime$ = StartTimeInitial$
        StartTimeInitial = FastTime(1)
        StartTime = StartTimeInitial

    print #IREX, "  StartTime$:  ";StartTime$
    print #IREX, " "
    close #IREX
return
'
[PlotV]
    if DataFile$ = "" then
        notice "open a variable star data file first"
        wait
    end if

    #show.TimeScale "selectionindex? TimeScaleIndex"
    #show.Magnitude "selectionindex? MagScaleIndex"
    if TimeScaleIndex = 0 OR MagScaleIndex = 0 then
        notice "select the proper time and magnitude scale"
        wait
    end if

    gosub [TimeScaleSelect]

    StartTime$ = StartJ2000$
    gosub [DrawTimeScale]

    gosub [FindMagRange]

    gosub [DrawMagScale]

    gosub [DrawTitles]

    gosub [DrawData]

    print #show.MoveTimeLeft, "!enable"
    print #show.MoveTimeLeftFast, "!enable"
    print #show.MoveTimeRight, "!enable"
    print #show.MoveTimeRightFast, "!enable"
    print #show.EnterDate, "!enable"

    print #show.MoveMagUp, "!enable"
    print #show.MoveMagDown, "!enable"
    print #show.EnterMag, "!enable"

    UmagFlag = 0
    BmagFlag = 0
    RmagFlag = 0
    ImagFlag = 0

    For VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,10)) <> 0 then
            print #show.PlotU, "!enable"
            if FilterSystem$ = "1" then
                print #show.PlotU, "U"
            else
                print #show.PlotU, "u'"
            end if
            exit for
        end if
    Next

    For VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,12)) <> 0 then
            print #show.PlotB, "!enable"
            if FilterSystem$ = "1" then
                print #show.PlotB, "B"
            else
                print #show.PlotB, "g'"
            end if
            exit for
        end if
    Next

    For VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,14)) <> 0 then
            print #show.PlotR, "!enable"
            if FilterSystem$ = "1" then
                print #show.PlotR, "R"
            else
                print #show.PlotR, "i'"
            end if
            exit for
        end if
    Next

    For VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,16)) <> 0 then
            print #show.PlotI, "!enable"
            if FilterSystem$ = "1" then
                print #show.PlotI, "I"
            else
                print #show.PlotI, "z'"
            end if
            exit for
        end if
    Next

    CursorFlag = 1
return
'
[PlotC]
    if DataFile$ = "" then
        notice "open a fast star data file first"
        wait
    end if
    #show.TimeScale "selectionindex? TimeScaleIndex"
    #show.Magnitude "selectionindex? MagScaleIndex"
    if TimeScaleIndex = 0 OR MagScaleIndex = 0 then
        notice "select the proper time and count scale"
        wait
    end if

    gosub [TimeScaleSelect]

    gosub [DrawTimeScale]

    CountMax = MagScale * 20
    gosub [MakeMagArray]

    gosub [DrawMagScale]

    gosub [DrawTitles]

    gosub [DrawData]

    print #show.MoveTimeLeft, "!enable"
    print #show.MoveTimeLeftFast, "!enable"
    print #show.MoveTimeRight, "!enable"
    print #show.MoveTimeRightFast, "!enable"
    print #show.EnterDate, "!enable"

    print #show.MoveMagUp, "!enable"
    print #show.MoveMagDown, "!enable"
    print #show.EnterMag, "!enable"

    CursorFlag = 1
return
'
'
[PlotColorIndex]
    print #show.graphicbox1, "delsegment ";DrawDataSegment
    print #show.graphicbox1, "delsegment ";DrawUSegment
    print #show.graphicbox1, "delsegment ";DrawBSegment
    print #show.graphicbox1, "delsegment ";DrawRSegment
    print #show.graphicbox1, "delsegment ";DrawISegment

    if DataFile$ = "" then
        notice "open a variable star data file first"
        wait
    end if

    #show.TimeScale "selectionindex? TimeScaleIndex"
    #show.Magnitude "selectionindex? MagScaleIndex"
    if TimeScaleIndex = 0 OR MagScaleIndex = 0 then
        notice "select the proper time and magnitude scale"
        wait
    end if

    gosub [TimeScaleSelect]

    StartTime$ = StartJ2000$
    gosub [DrawTimeScale]

    gosub [FindMagRange]

    gosub [DrawMagScale]

    gosub [DrawTitles]

    print #show.MoveTimeLeft, "!enable"
    print #show.MoveTimeLeftFast, "!enable"
    print #show.MoveTimeRight, "!enable"
    print #show.MoveTimeRightFast, "!enable"
    print #show.EnterDate, "!enable"

    print #show.MoveMagUp, "!enable"
    print #show.MoveMagDown, "!enable"
    print #show.EnterMag, "!enable"

    print #show.PlotU, "!disable"
    print #show.PlotB, "!disable"
    print #show.PlotR, "!disable"
    print #show.PlotI, "!disable"

    BVindexFlag = 0
    UBindexFlag = 0
    VRindexFlag = 0
    VIindexFlag = 0

    For VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,10)) <> 0 then
            print #show.PlotUB, "!enable"
            if FilterSystem$ = "1" then
                print #show.PlotUB, "U-B"
            else
                print #show.PlotUB, "u'-g'"
            end if
            exit for
        end if
    Next

    For VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,12)) <> 0 then
            print #show.PlotBV, "!enable"
            if FilterSystem$ = "1" then
                print #show.PlotBV, "B-V"
            else
                print #show.PlotBV, "g'-r'"
            end if
            exit for
        end if
    Next

    For VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,14)) <> 0 then
            print #show.PlotVR, "!enable"
            if FilterSystem$ = "1" then
                print #show.PlotVR, "V-R"
            else
                print #show.PlotVR, "r'-i'"
            end if
            exit for
        end if
    Next

    For VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,16)) <> 0 then
            print #show.PlotVI, "!enable"
            if FilterSystem$ = "1" then
                print #show.PlotVI, "V-I"
            else
                print #show.PlotVI, "r'-z'"
            end if
            exit for
        end if
    Next

    CursorFlag = 1
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

    print #show.FileName, DataFileName$                 'display filename in "File" textbox
return
'
'
[TimeScaleSelect]       'establish the parameters for the time scale
    open "IREX.txt" for append as #IREX
        print #IREX, "Time Scale Array"
        print #IREX, " "

    Select Case
        Case TimeScale = 0.010
            TimeScaleArray(0) = TimeScaleStart
            For I = 0 to 9
                TimeScaleArray(I) =  100 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 10ms"
        Case TimeScale = 0.100
            TimeScaleArray(0) = TimeScaleStart
            For I = 0 to 9
                TimeScaleArray(I) =  1 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 0.1s"
        Case TimeScale = 1
            TimeScaleArray(0) = TimeScaleStart
            For I = 0 to 9
                TimeScaleArray(I) =  10 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 1 second"
        Case TimeScale = 10
            TimeScaleArray(0) = TimeScaleStart
            For I = 0 to 9
                TimeScaleArray(I) =  100 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 10 second"
            TimeScaleJ2000 = 0.00011574
        Case TimeScale = 60
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  10 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 1 minute"
            TimeScaleJ2000 = 0.00069444
        Case TimeScale = 120
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  20 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 2 minute"
            TimeScaleJ2000 = 0.00138888
        Case TimeScale = 300
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) = 50 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 5 minute"
            TimeScaleJ2000 = 0.0034722
        Case TimeScale = 600
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  100 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 10 minutes"
            TimeScaleJ2000 = 0.0069444
        Case TimeScale = 3600
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  10 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 1 hour"
            TimeScaleJ2000 = 0.0416667
        Case TimeScale = 7200
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  20 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 2 hour"
            TimeScaleJ2000 = 0.0833334
        Case TimeScale = 18000
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  50 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 5 hours"
            TimeScaleJ2000 = 0.2083335
        Case TimeScale = 36000
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  100 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 10 hours"
            TimeScaleJ2000 = 0.416667
        Case TimeScale = 86400
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  10 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 1 day"
            TimeScaleJ2000 = 1.00000
        Case TimeScale = 172800
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  20 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 2 day"
            TimeScaleJ2000 = 2.00000
        Case TimeScale = 432000
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  50 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 5 days"
            TimeScaleJ2000 = 5.00000
        Case TimeScale = 864000
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  100 * I
                TimeScaleArray$(I) = using("###", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 10 days"
            TimeScaleJ2000 = 10.00000
        Case TimeScale = 1728000
            TimeScaleArray(0) = 0
            For I = 0 to 9
                TimeScaleArray(I) =  200 * I
                TimeScaleArray$(I) = using("####", TimeScaleArray(I))
            Next
            TimeDiv$ = "1 div = 20 days"
            TimeScaleJ2000 = 20.00000
    End Select

    Print #IREX,TimeScaleArray$(0);" ";_
                TimeScaleArray$(1);" ";_
                TimeScaleArray$(2);" ";_
                TimeScaleArray$(3);" ";_
                TimeScaleArray$(4);" ";_
                TimeScaleArray$(5);" ";_
                TimeScaleArray$(6);" ";_
                TimeScaleArray$(7);" ";_
                TimeScaleArray$(8);" ";_
                TimeScaleArray$(9)

    print #IREX," "
    close #IREX
return
'
'
[FindMagRange]
    open "IREX.txt" for append as #IREX

    VarMagMax = val(VarItem$(1,8))              'find the brightest V magnitude
    For VarIndex = 2 to VarIndexMax
        if val(VarItem$(VarIndex,8)) < VarMagMax then
            VarMagMax = val(VarItem$(VarIndex,8))
        end if
    Next

    print #IREX, "VarMagMax ";VarMagMax
    print #IREX," "
    close #IREX

    Select Case MagScale
        Case 0.01
            MagScaleArray(0) = val(using("###.##",VarMagMax)) - 0.01
            VarColorMax = 0.05
        Case 0.02
            MagScaleArray(0) = val(using("###.##",VarMagMax)) - 0.02
            VarColorMax = 0.10
        Case 0.05
            VarMagMax = val(using("###.##",VarMagMax)) - 0.05
            MagScaleArray(0) = VarMagMax
            VarColorMax = 0.25
        Case 0.10
            VarMagMax = val(using("###.#",VarMagMax)) - 0.1
            MagScaleArray(0) = VarMagMax
            VarColorMax = 0.50
        Case 0.20
            VarMagMax = val(using("###.#",VarMagMax)) - 0.2
            MagScaleArray(0) = VarMagMax
            VarColorMax = 1.00
        Case 0.50
            VarMagMax = val(using("###.#",VarMagMax)) - 0.5
            MagScaleArray(0) = VarMagMax
            VarColorMax = 2.50
        Case 1.00
            VarMagMax = val(using("###",VarMagMax)) - 1.0
            MagScaleArray(0) = VarMagMax
            VarColorMax = 5.00
    End Select

    gosub [MakeMagArray]
return
'
[MakeMagArray]
    Select Case PlotFlag
        Case 0
            MagScaleArray(0) = CountMax
            For I = 1 to 20
                MagScaleArray(I) = MagScaleArray(0) - (MagScale * I)
                if MagScaleArray(I) < 0 then
                    MagScaleArray(I) = 0
                end if
            Next
        Case 1
            For I = 1 to 20
                MagScaleArray(I) = MagScaleArray(0) + (MagScale * I)
            Next
        Case 2
            MagScaleArray(0) = VarColorMax
            For I = 1 to 20
                MagScaleArray(I) = MagScaleArray(0) - (MagScale * I)
            Next
     end select

    open "IREX.txt" for append as #IREX
    print #IREX, "MagMagArray"
    print #IREX,MagScaleArray(0);" ";_
                MagScaleArray(1);" ";_
                MagScaleArray(2);" ";_
                MagScaleArray(3);" ";_
                MagScaleArray(4);" ";_
                MagScaleArray(5);" ";_
                MagScaleArray(6);" ";_
                MagScaleArray(7);" ";_
                MagScaleArray(8);" ";_
                MagScaleArray(9);" ";_
                MagScaleArray(10);" ";_
                MagScaleArray(11);" ";_
                MagScaleArray(12);" ";_
                MagScaleArray(13);" ";_
                MagScaleArray(14);" ";_
                MagScaleArray(15);" ";_
                MagScaleArray(16);" ";_
                MagScaleArray(17);" ";_
                MagScaleArray(18);" ";_
                MagScaleArray(19)

    print #IREX," "
    close #IREX
return
'
[DrawUBRImags]
    if UmagFlag = 1 then
        gosub [DrawU]
    end if

    if BmagFlag = 1 then
        gosub [DrawB]
    end if

    if RmagFlag = 1 then
        gosub [DrawR]
    end if

    if ImagFlag = 1 then
        gosub [DrawI]
    end if
return
'
[DrawColorIndicies]
    if BVindexFlag = 1 then
        gosub [DrawBVindex]
    end if
    if UBindexFlag = 1 then
        gosub [DrawUBindex]
    end if
    if VRindexFlag = 1 then
        gosub [DrawVRindex]
    end if
    if VIindexFlag = 1 then
        gosub [DrawVIindex]
    end if
return
'
'=====subroutines for calculations
'
[FindJ2000]    'convert UT time and date to Julian, epcoh J2000
                                'A = int(UTyear/100)
        A = int (UTyear/100)
        B = 2 - A + int(A/4)
                                'C = int(365.25 * UTyear)
        C = int(365.25 * UTyear)
                                'D = int(30.6001 *(UTmonth + 1))
        D = int(30.6001 * UTmonth + 1)
                                'JD = B + C + D - 730550.5 + UTday + (UThours + UTmin/60 + UTsec/3600)/24
        JD = B + C + D - 730550.5 + UTday + (UThours + UTmin/60 + UTsec/3600)/24
                                'Julian century
        JT = JD/36525
return
'
[FindStartTime]     'convert StartTime in seconds to time in 12:12:12.123 format

    HR = int(StartTime / 3600)
    MIN = int((StartTime MOD 3600) / 60)
    SEC = StartTime - 3600 * HR - 60 * MIN

    if HR >= 24 then
        HR = HR - 24
    end if

    HR$ = using("##",HR)
    MIN$ = using("##",MIN)
    SEC$ = using("##.###",SEC)
    StartTime$ = HR$+":"+MIN$+":"+SEC$

    open "IREX.txt" for append as #IREX
    print #IREX, "StartTime = ";StartTime;"  HR = ";HR;"  MIN = ";MIN;"  SEC = ";SEC
    print #IREX, ""
    close #IREX
return
'
'=====graphics routines
'
[Draw_Graph_Outline]
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    print #show.graphicbox1, "line 40 20 40 520"
    print #show.graphicbox1, "line 990 20 990 520"
    print #show.graphicbox1, "line 40 520 990 520"
    print #show.graphicbox1, "line 40 20 990 20"

    for I = 1 to 20
        yD =  25 * I - 5
        print #show.graphicbox1, "line 40 ";yD;" 44 ";yD
        print #show.graphicbox1, "line 990 ";yD;" 986 ";yD
    next
    for I = 1 to 94
        xD = 40 + 10 * I
        print #show.graphicbox1, "line ";xD;" 520 ";xD;" 516"
        print #show.graphicbox1, "line ";xD;" 20 ";xD;" 24"
    next
    for I = 0 to 19
        xD = 40 + 100 * I
        print #show.graphicbox1, "line ";xD;" 520 ";xD;" 510"
        print #show.graphicbox1, "line ";xD;" 20 ";xD;" 30"
    next
    for I = 0 to 19
        xD = 90 + 100 * I
        print #show.graphicbox1, "line ";xD;" 520 ";xD;" 513"
        print #show.graphicbox1, "line ";xD;" 20 ";xD;" 27"
    next
    print #show.graphicbox1, "flush"
return
'
[DrawCursor]

    if (MouseX < 40) OR (MouseX > 990) OR (MouseY < 20) OR (MouseY > 520) then
        notice "pointer out of plot area"
        wait
    end if

    Select Case CursorID$
        Case "A"
            print #show.graphicbox1, "delsegment ";CursorSegmentA
            print #show.graphicbox1, "redraw"
            print #show.graphicbox1, "color green"
            print #show.graphicbox1, "line 40 ";MouseY;" 990 ";MouseY
            print #show.graphicbox1, "line ";MouseX;" 20 ";MouseX;" 520"
            print #show.graphicbox1, "Segment CursorSegmentA"
        Case "B"
            print #show.graphicbox1, "delsegment ";CursorSegmentB
            print #show.graphicbox1, "redraw"
            print #show.graphicbox1, "color cyan"
            print #show.graphicbox1, "line 40 ";MouseY;" 990 ";MouseY
            print #show.graphicbox1, "line ";MouseX;" 20 ";MouseX;" 520"
            print #show.graphicbox1, "Segment CursorSegmentB"
        Case "C"
            print #show.graphicbox1, "delsegment ";CursorSegmentC
            print #show.graphicbox1, "redraw"
            print #show.graphicbox1, "color black"
            print #show.graphicbox1, "line ";MouseX;" 20 ";MouseX;" 520"
            print #show.graphicbox1, "Segment CursorSegmentC"
    End Select

    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
return
'
[DrawCursorValues.A]
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.A
    print #show.graphicbox1, "redraw"
    print #show.graphicbox1, "color darkgreen"
    print #show.graphicbox1, "font arial 7 14"

    if PlotFlag = 1 OR PlotFlag = 2 then
        print #show.graphicbox1, "place 170 11"
        print #show.graphicbox1, "\ Cursor A:"

        if JDFlag = 1 then
            print #show.graphicbox1, "place 230 11"
            print #show.graphicbox1, "\ JD"+CursorTime.A$
        else
            print #show.graphicbox1, "place 230 11"
            print #show.graphicbox1, "\ HJD"+CursorTime.A$
        end if

        print #show.graphicbox1, "place 330 11"
        print #show.graphicbox1, "\ Mag. "+CursorMag.A$
    else
        print #show.graphicbox1, "place 200 11"
        print #show.graphicbox1, "\ Cursor A:"

        print #show.graphicbox1, "place 260 11"
        print #show.graphicbox1, "\ UT"+CursorTime.A$

        print #show.graphicbox1, "place 365 11"
        print #show.graphicbox1, "\ Count "+CursorMag.A$
    end if

    print #show.graphicbox1, "Segment CursorValuesSegment.A"
    print #show.graphicbox1, "flush"
return
'
[DrawCursorValues.B]
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.B
    print #show.graphicbox1, "redraw"
    print #show.graphicbox1, "color darkcyan"
    print #show.graphicbox1, "font arial 7 14"

    if PlotFlag = 1 OR PlotFlag = 2 then
        print #show.graphicbox1, "place 440 11"
        print #show.graphicbox1, "\ Cursor B:"

        if JDFlag = 1 then
            print #show.graphicbox1, "place 500 11"
            print #show.graphicbox1, "\ JD"+CursorTime.B$
        else
            print #show.graphicbox1, "place 500 11"
            print #show.graphicbox1, "\ HJD"+CursorTime.B$ 
        end if

        print #show.graphicbox1, "place 600 11"
        print #show.graphicbox1, "\ Mag. "+CursorMag.B$
    else
        print #show.graphicbox1, "place 455 11"
        print #show.graphicbox1, "\ Cursor B:"

        print #show.graphicbox1, "place 515 11"
        print #show.graphicbox1, "\ UT"+CursorTime.B$

        print #show.graphicbox1, "place 620 11"
        print #show.graphicbox1, "\ Count "+CursorMag.B$
    end if

    print #show.graphicbox1, "Segment CursorValuesSegment.B"
    print #show.graphicbox1, "flush"
return
'
[DrawCursorValues.C]
    print #show.graphicbox1, "delsegment ";CursorValuesSegment.C
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"
    print #show.graphicbox1, "redraw"
    print #show.graphicbox1, "font arial 8 12"

    print #show.graphicbox1, "place ";MouseX-40;" ";547
    print #show.graphicbox1, "\ "+CursorTime$

    print #show.graphicbox1, "Segment CursorValuesSegment.C"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"
return
'
[DrawCursorDiffValues]
    print #show.graphicbox1, "delsegment ";CursorDiffSegment
    print #show.graphicbox1, "redraw"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "font arial 7 14"
    print #show.graphicbox1, "place 710 11"
    print #show.graphicbox1, "\ B-A: "

    if PlotFlag = 1 OR PlotFlag = 2 then
        print #show.graphicbox1, "place 740 11"
        if Sign = 1 then
            print #show.graphicbox1, "\ Days -"+CursorTimeDiff$
        else
            print #show.graphicbox1, "\ Days "+CursorTimeDiff$ 
        end if

        print #show.graphicbox1, "place 840 11"
        print #show.graphicbox1, "\ Mag. Diff. "+CursorMagDiff$ 
    else
        print #show.graphicbox1, "place 745 11"
        if Sign = 1 then
            print #show.graphicbox1, "\ Time -"+CursorTimeDiff$
        else
            print #show.graphicbox1, "\ Time "+CursorTimeDiff$
        end if

        print #show.graphicbox1, "place 850 11"
        print #show.graphicbox1, "\ Count Diff. "+CursorMagDiff$ 
    end if

    print #show.graphicbox1, "Segment CursorDiffSegment"
    print #show.graphicbox1, "flush"
return
'
[DrawTimeScale]
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    print #show.graphicbox1, "delsegment ";TimeScaleSegment
    print #show.graphicbox1, "redraw"
    print #show.graphicbox1, "font arial 6 12"

    For I = 0 to 9
        xD = 30 + 100 * I
        print #show.graphicbox1, "place ";xD;" ";535
        print #show.graphicbox1, "\ "+TimeScaleArray$(I)
    next

    if PlotFlag = 1 OR PlotFlag = 2 then
        print #show.graphicbox1, "place 10 545"
        if JDFlag = 1 then
            print #show.graphicbox1, "\ JD "+StartTime$
        else
            print #show.graphicbox1, "\ HJD "+StartTime$
        end if
        print #show.graphicbox1, "place 900 545"
        print #show.graphicbox1, "\ "+TimeDiv$
    else
        print #show.graphicbox1, "place 5 545"
        print #show.graphicbox1, "\ UT"+StartTime$
        print #show.graphicbox1, "place 900 545"
        print #show.graphicbox1, "\ "+TimeDiv$ 
    end if

    print #show.graphicbox1, "Segment TimeScaleSegment"
    print #show.graphicbox1, "flush"
return
'
[DrawMagScale]
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"
    print #show.graphicbox1, "delsegment ";MagScaleSegment
    print #show.graphicbox1, "redraw"
    print #show.graphicbox1, "font arial 6 12"

    for I = 0 to 20
        yD =  25 * I + 23

        if PlotFlag = 1 OR PlotFlag = 2 then
            print #show.graphicbox1, "place 5 ";yD
            MagScaleArray$(I) = using ("###.##", MagScaleArray(I))
        else
            print #show.graphicbox1, "place 7 ";yD
            MagScaleArray$(I) = using ("#####", MagScaleArray(I))
        end if
        print #show.graphicbox1, "\ "+MagScaleArray$(I)
    next

    Select Case PlotFlag
        case 0
            print #show.graphicbox1, "place 4 10"
            print #show.graphicbox1, "\ Counts"
        case 1
            print #show.graphicbox1, "place 2 10"
            print #show.graphicbox1, "\ Magnitude"
        case 2
            print #show.graphicbox1, "place 2 10"
            print #show.graphicbox1, "\ Color Index"
        end select

    print #show.graphicbox1, "Segment MagScaleSegment"
    print #show.graphicbox1, "flush"
return
'
[DrawTitles]
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    print #show.graphicbox1, "delsegment ";DrawTitle
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 10 12"
    print #show.graphicbox1, "place 460 560"
    print #show.graphicbox1, "\ "+PlotFileName$

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "place 5 560"
    print #show.graphicbox1, "\ File info: "+FileHeader$ 

    print #show.graphicbox1, "Segment DrawTitle"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"
return
'
[DrawLabel]
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 8 12"
    print #show.graphicbox1, "place ";MouseX;" ";MouseY
    print #show.graphicbox1, "\ "+Label$

    DrawLabel = DrawLabel(LabelCounter)
    print #show.graphicbox1, "Segment DrawLabel"
    LabelCounter = LabelCounter + 1
    DrawLabel(LabelCounter) = DrawLabel

    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"
return
'
[DrawData]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawData]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawDataSegment
    print #show.graphicbox1, "redraw"

    if PlotFlag = 1 then                'draw plot for variable star data
        print #show.graphicbox1, "color darkgreen"
        print #show.graphicbox1, "backcolor darkgreen"

        PixelTime = 10/TimeScaleJ2000
        PixelMag = 25/MagScale

        print #IREX,"PixelTime ";PixelTime
        print #IREX,"PixelMag  ";PixelMag
        print #IREX," "
        print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   ";"    VarError"

        for VarIndex = 1 to VarIndexMax

            If (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if

            VarMagDiff = val(VarItem$(VarIndex,8)) - MagScaleArray(0)
            yD = VarMagDiff * PixelMag + 20

            VarError = val(VarItem$(VarIndex,9))

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40

            If (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)+"  "+_
                         using("####.###",VarError)

            if xD >= 40  then
                print #show.graphicbox1, "place ";xD;" ";yD
                print #show.graphicbox1, "circlefilled 2"
            end if

            if PlotErrorFlag = 1 then
                VarErrorReduced = VarError * PixelMag * 0.5
                yEup = yD + VarErrorReduced
                yEdown = yD - VarErrorReduced
                print #show.graphicbox1, "line ";xD;" ";yEdown;" ";xD;" ";yEup
            end if
        next

    else                                'draw plot for fast star data
        print #show.graphicbox1, "color black"
        print #show.graphicbox1, "backcolor black"

        PixelTime = 10/TimeScale
        PixelMag = 25/MagScale

        print #IREX,"PixelTime ";PixelTime
        print #IREX,"PixelMag  ";PixelMag
        print #IREX," "
        print #IREX, "Index  ";"  CountDiff   ";"    yD     ";"CountTimeDiff ";"   xD   "

        For FastIndex = 1 to (FastIndexMax-5)

            If (ConnectDotFlag = 1) AND (FastIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if

            CountDiff = CountMax - FastCounts(FastIndex)
            yD = CountDiff * PixelMag + 20

            CountTimeDiff = FastTime(FastIndex) -  StartTime
            xD = CountTimeDiff * PixelTime + 40

            If (ConnectDotFlag = 1) AND (FastIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #IREX, using("###",FastIndex)+"     "+_
                         using("#####.##",CountDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",CountTimeDiff)+"  "+_
                         using("######.###",xD)

            if xD >= 40 then
                print #show.graphicbox1, "place ";xD;" ";yD
                print #show.graphicbox1, "circlefilled 2"
            end if

        next
    end if

    print #show.graphicbox1, "Segment DrawDataSegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    print #show.graphicbox1, "delsegment ";DrawUSegment
    print #show.graphicbox1, "delsegment ";DrawBSegment
    print #show.graphicbox1, "delsegment ";DrawRSegment
    print #show.graphicbox1, "delsegment ";DrawISegment
    print #show.graphicbox1, "redraw"

    print #IREX, " "
    close #IREX
return
'
[DrawU]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawB]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawUSegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color darkblue"
    print #show.graphicbox1, "backcolor darkblue"

    print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   "

    for VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,10)) <> 0 OR val(VarItem$(VarIndex,11)) <> 0 then
            If (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if
                                            'U = (U-B) + ((B-V) + V)
            VarMagDiff = val(VarItem$(VarIndex,10)) + (val(VarItem$(VarIndex,12)) +_
                         val(VarItem$(VarIndex,8))) - MagScaleArray(0)
            yD = VarMagDiff * PixelMag + 20

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40

            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)

            If (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #show.graphicbox1, "place ";xD;" ";yD
            print #show.graphicbox1, "circlefilled 2"
        end if
    next

    print #show.graphicbox1, "Segment DrawUSegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    UmagFlag = 1

    print #IREX, " "
    close #IREX
return
'
[DrawUBindex]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawUBindex]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawUBSegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color darkblue"
    print #show.graphicbox1, "backcolor darkblue"

    print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   ";"    VarError"

    PixelTime = 10/TimeScaleJ2000
    PixelMag = 25/MagScale

    for VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,10)) <> 0 OR val(VarItem$(VarIndex,11)) <> 0 then
            If (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if

            VarMagDiff = VarColorMax - val(VarItem$(VarIndex,10))
            yD = VarMagDiff * PixelMag + 20

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40

            VarError = val(VarItem$(VarIndex,11))

            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)+"  "+_
                         using("####.###",VarError)

            If (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #show.graphicbox1, "place ";xD;" ";yD
            print #show.graphicbox1, "circlefilled 2"

            if PlotErrorFlag = 1 then
                VarErrorReduced = VarError * PixelMag * 0.5
                yEup = yD + VarErrorReduced
                yEdown = yD - VarErrorReduced
                print #show.graphicbox1, "line ";xD;" ";yEdown;" ";xD;" ";yEup
            end if
        end if
    next

    print #show.graphicbox1, "Segment DrawUBSegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    UBindexFlag = 1

    print #IREX, " "
    close #IREX
return
'
[DrawB]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawB]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawBSegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color blue"
    print #show.graphicbox1, "backcolor blue"

    print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   "

    for VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,12)) <> 0 OR val(VarItem$(VarIndex,13)) <> 0 then
            If (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if
                                            'B = (B-V) + V
            VarMagDiff = val(VarItem$(VarIndex,12)) + val(VarItem$(VarIndex,8)) - MagScaleArray(0)
            yD = VarMagDiff * PixelMag + 20

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40


            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)

            If (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #show.graphicbox1, "place ";xD;" ";yD
            print #show.graphicbox1, "circlefilled 2"
        end if
    next

    print #show.graphicbox1, "Segment DrawBSegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    BmagFlag = 1

    print #IREX, " "
    close #IREX
return
'
[DrawBVindex]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawBVindex]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawBVSegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color blue"
    print #show.graphicbox1, "backcolor blue"

    print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   ";"    VarError"

    PixelTime = 10/TimeScaleJ2000
    PixelMag = 25/MagScale

    for VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,12)) <> 0 OR val(VarItem$(VarIndex,13)) <> 0 then
            If (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if

            VarMagDiff = VarColorMax - val(VarItem$(VarIndex,12))
            yD = VarMagDiff * PixelMag + 20

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40

            VarError = val(VarItem$(VarIndex,13))

            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)+"  "+_
                         using("####.###",VarError)

            If (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #show.graphicbox1, "place ";xD;" ";yD
            print #show.graphicbox1, "circlefilled 2"

            if PlotErrorFlag = 1 then
                VarErrorReduced = VarError * PixelMag * 0.5
                yEup = yD + VarErrorReduced
                yEdown = yD - VarErrorReduced
                print #show.graphicbox1, "line ";xD;" ";yEdown;" ";xD;" ";yEup
            end if
        end if
    next

    print #show.graphicbox1, "Segment DrawBVSegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    BVindexFlag = 1

    print #IREX, " "
    close #IREX
return
'
[DrawR]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawR]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawRSegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color red"
    print #show.graphicbox1, "backcolor red"

    print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   "

    for VarIndex = 1 to VarIndexMax
                                                        'skip data point of no data
        if val(VarItem$(VarIndex,14)) <> 0 OR val(VarItem$(VarIndex,15)) <> 0 then

            if (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if
                                            'R = V - (V-R)
            VarMagDiff = val(VarItem$(VarIndex,8)) - val(VarItem$(VarIndex,14)) - MagScaleArray(0)
            yD = VarMagDiff * PixelMag + 20

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40

            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)

            if (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #show.graphicbox1, "place ";xD;" ";yD
            print #show.graphicbox1, "circlefilled 2"
        end if
    next

    print #show.graphicbox1, "Segment DrawRSegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    RmagFlag = 1

    print #IREX, " "
    close #IREX
return
'
[DrawVRindex]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawVRindex]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawVRSegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color red"
    print #show.graphicbox1, "backcolor red"

    print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   ";"    VarError"

    PixelTime = 10/TimeScaleJ2000
    PixelMag = 25/MagScale

    for VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,14)) <> 0 OR val(VarItem$(VarIndex,15)) <> 0 then

            If (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if

            VarMagDiff = VarColorMax - val(VarItem$(VarIndex,14))
            yD = VarMagDiff * PixelMag + 20

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40

            VarError = val(VarItem$(VarIndex,15))

            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)+"  "+_
                         using("####.###",VarError)

            If (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #show.graphicbox1, "place ";xD;" ";yD
            print #show.graphicbox1, "circlefilled 2"

            if PlotErrorFlag = 1 then
                VarErrorReduced = VarError * PixelMag * 0.5
                yEup = yD + VarErrorReduced
                yEdown = yD - VarErrorReduced
                print #show.graphicbox1, "line ";xD;" ";yEdown;" ";xD;" ";yEup
            end if
        end if
    next

    print #show.graphicbox1, "Segment DrawVRSegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    VRindexFlag = 1

    print #IREX, " "
    close #IREX
return
'
[DrawI]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawI]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawISegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color darkred"
    print #show.graphicbox1, "backcolor darkred"

    print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   "

    for VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,16)) <> 0 OR val(VarItem$(VarIndex,17)) <> 0 then

            If (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if
                                            'I = V - (V-I)
            VarMagDiff = val(VarItem$(VarIndex,8)) - val(VarItem$(VarIndex,16)) - MagScaleArray(0)
            yD = VarMagDiff * PixelMag + 20

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40


            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)

            If (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #show.graphicbox1, "place ";xD;" ";yD
            print #show.graphicbox1, "circlefilled 2"
        end if
    next

    print #show.graphicbox1, "Segment DrawISegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    ImagFlag = 1

    print #IREX, " "
    close #IREX
return
'
[DrawVIindex]
    open "IREX.txt" for append as #IREX
    print #IREX, "output from [DrawVIindex]"
    print #IREX, " "

    print #show.graphicbox1, "delsegment ";DrawVISegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color darkred"
    print #show.graphicbox1, "backcolor darkred"

    print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   ";"    VarError"

    PixelTime = 10/TimeScaleJ2000
    PixelMag = 25/MagScale

    for VarIndex = 1 to VarIndexMax
        if val(VarItem$(VarIndex,16)) <> 0 OR val(VarItem$(VarIndex,17)) <> 0 then
            If (ConnectDotFlag = 1) AND (VarIndex > 1) then
                xDlast = xD
                yDlast = yD
            end if

            VarMagDiff = VarColorMax - val(VarItem$(VarIndex,16))
            yD = VarMagDiff * PixelMag + 20

            VarTimeDiff = val(VarItem$(VarIndex,7)) - val(StartJ2000$)
            xD = VarTimeDiff * PixelTime + 40

            VarError = val(VarItem$(VarIndex,17))

            print #IREX, using("###",VarIndex)+"     "+_
                         using("#####.##",VarMagDiff)+"      "+_
                         using("####.##",yD)+"  "+_
                         using("#####.####",VarTimeDiff)+"  "+_
                         using("######.###",xD)+"  "+_
                         using("####.###",VarError)

            If (ConnectDotFlag = 1) AND (VarIndex > 1) AND (xDlast >= 40) AND (xD >= 40) then
                print #show.graphicbox1,"line ";xDlast;" ";yDlast;" ";xD;" ";yD
            end if

            print #show.graphicbox1, "place ";xD;" ";yD
            print #show.graphicbox1, "circlefilled 2"

            if PlotErrorFlag = 1 then
                VarErrorReduced = VarError * PixelMag * 0.5
                yEup = yD + VarErrorReduced
                yEdown = yD - VarErrorReduced
                print #show.graphicbox1, "line ";xD;" ";yEdown;" ";xD;" ";yEup
            end if
        end if
    next

    print #show.graphicbox1, "Segment DrawVISegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    VIindexFlag = 1
    print #IREX, " "
    close #IREX
return
'
'=====sub routines
'
[SAVE_PPparms]
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
            print #PPparms, EpsilonFlag                      '1 if using epsilon and 0 if using epsilon R
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
'=================Make AAVSO data file
'
[AAVSO]
    NOMAINWIN
    WindowWidth = 350 : WindowHeight = 270
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #export, "File", "Quit", [QuitExport]

        statictext #export.varName, "variable name", 140,17,130,20
        textbox    #export.var, 10,15,120,22
        statictext #export.compName, "comparison name", 140,47,150,20
        textbox    #export.comp, 10,45,120,22
        statictext #export.obscodeName, "AAVSO observatory code", 140,77,180,20
        textbox    #export.obscode, 10,75,120,22
        statictext #export.chartName, "chart name", 140,107,130,20
        textbox    #export.chart, 10,105,120,22

        checkbox   #export.JD, "JD", [setJD], [resetJD], 10,135,35,25
        checkbox   #export.HJD, "HJD", [setHJD], [resetHJD], 80,135,45,25
        statictext #export.JDName, "Julian date type", 140,137,130,20

        button #export.save, "Make/Save AAVSO Data", [MakeAAVSOdata], UL, 85,170,180,30

    Open "Export data in AAVSO extended format" for Window as #export
        #export "trapclose [QuitExport]"
        #export "font ariel 10"

        if PlotFileName$ = ""  then
            notice "open a var data file "
        end if

        if VarStar$ = "" then
            print #export.var, PlotFileName$        'print default filename in text box
        else
            print #export.var, VarStar$             'print star names from file header
            print #export.comp, CompStar$
        end if

        print #export.chart, "na"                   'print default "na" in text box

        AAVSOFlag = 1

        if JDFlag = 1 then                          'check PPparms value of JDFlag
            print #export.JD, "set"
            print #export.HJD, "reset"
        else
            print #export.HJD, "set"
            print #export.JD, "reset"
            JDFlag = 0
        end if

        if JDFlag$ = "1" then                       'check filed header value for JDFlag
            print #export.JD, "set"
            print #export.HJD, "reset"
            JDFlag = 1
        end if
        if JDFlag$ = "0" then
            print #export.HJD, "set"
            print #export.JD, "reset"
            JDFlag = 0
        end if

        print #export.obscode, OBSCODE$
    wait

    [setJD]
        JDFlag = 1
        print #export.HJD, "reset"
    wait
    [setHJD]
        JDFlag = 0
        print #export.JD, "reset"
    wait
    [resetJD]
        JDFlag = 0
        print #export.HJD, "set"
    wait
    [resetHJD]
        JDFlag = 1
        print #export.JD, "set"
    wait

    [MakeAAVSOdata]

        print #export.var, "!contents? VAR$";
            VAR$ = upper$(VAR$)

        print #export.comp, "!contents? COMP$";
            COMP$ = upper$(COMP$)

        print #export.obscode, "!contents? OBSCODEnew$";
        OBSCODEnew$ = upper$(OBSCODEnew$)
        if OBSCODEnew$ <> OBSCODE$ then
            OBSCODE$ = OBSCODEnew$
            gosub [SAVE_PPparms]
        end if

        print #export.chart, "!contents? CHART$";

        AAVSO$(1) = "#TYPE=EXTENDED"
        AAVSO$(2) = "#OBSCODE="+OBSCODE$
        AAVSO$(3) = "#SOFTWARE=OPTEC SSPDATAQ, v"+VersionNumber$
        AAVSO$(4) = "#DELIM=,"
        if JDFlag = 1 then
            AAVSO$(5) = "#DATE=JD"
        else
            AAVSO$(5) = "#DATE=HJD"
        end if
        AAVSO$(6) = "#OBSTYPE=PEP"

        Group = 1
        AAVSOIndex = 1
        for VarIndex = 1 to VarIndexMax
            Uflag = 0 : Bflag = 0 : Vflag = 1 : Rflag = 0 : Iflag = 0
                                            'find how many colors for each data line used
            Colors = 1
            if val(VarItem$(VarIndex,10)) <> 0  then
                Colors  = Colors + 1
                Uflag = 1
            end if
            if val(VarItem$(VarIndex,12)) <> 0  then
                Colors  = Colors + 1
                Bflag = 1
            end if
            if val(VarItem$(VarIndex,14)) <> 0  then
                Colors  = Colors + 1
                Rflag = 1
            end if
            if val(VarItem$(VarIndex,16)) <> 0  then
                Colors  = Colors + 1
                Iflag = 1
            end if

            for J = 1 to Colors
                AAVSOitem$(AAVSOIndex, 1) = VAR$
                                            'calculate JDN from J2000 date
                AAVSOitem$(AAVSOIndex, 2) = using("#######.####", (val(VarItem$(VarIndex, 7)) + 2451545))
                                            'separate out colors from color index and find UBVRI magnitude
                if Uflag = 1 then
                    AAVSOitem$(AAVSOIndex, 3) = str$(val(VarItem$(VarIndex,10))+_
                                                     val(VarItem$(VarIndex,12))+_
                                                     val(VarItem$(VarIndex,8)))
                    if val(VarItem$(VarIndex,11)) = 0 then
                        AAVSOitem$(AAVSOIndex, 4) = "na"
                    else
                        AAVSOitem$(AAVSOIndex, 4) = VarItem$(VarIndex,11)
                    end if
                    if FilterSystem$ = "1" then
                        AAVSOitem$(AAVSOIndex, 5) = "U"
                    else
                        AAVSOitem$(AAVSOIndex, 5) = "SU"
                    end if
                    Uflag = 0
                    goto [EndColors]
                end if
                if Bflag = 1 then
                    AAVSOitem$(AAVSOIndex, 3) = str$(val(VarItem$(VarIndex,12)) + val(VarItem$(VarIndex,8)))
                    if val(VarItem$(VarIndex,13)) = 0 then
                        AAVSOitem$(AAVSOIndex, 4) = "na"
                    else
                        AAVSOitem$(AAVSOIndex, 4) = VarItem$(VarIndex,13)
                    end if
                    if FilterSystem$ = "1" then
                        AAVSOitem$(AAVSOIndex, 5) = "B"
                    else
                        AAVSOitem$(AAVSOIndex, 5) = "SG"
                    end if
                    Bflag = 0
                    goto [EndColors]
                end if
                if Vflag = 1 then
                    AAVSOitem$(AAVSOIndex, 3) = str$(val(VarItem$(VarIndex,8)))
                    if val(VarItem$(VarIndex,9)) = 0 then
                        AAVSOitem$(AAVSOIndex, 4) = "na"
                    else
                        AAVSOitem$(AAVSOIndex, 4) = VarItem$(VarIndex,9)
                    end if
                    if FilterSystem$ = "1" then
                        AAVSOitem$(AAVSOIndex, 5) = "V"
                    else
                        AAVSOitem$(AAVSOIndex, 5) = "SR"
                    end if
                    Vflag = 0
                    goto [EndColors]
                end if
                if Rflag = 1 then
                    AAVSOitem$(AAVSOIndex, 3) = str$(-1 * val(VarItem$(VarIndex,14)) + val(VarItem$(VarIndex,8)))
                    if val(VarItem$(VarIndex,15)) = 0 then
                        AAVSOitem$(AAVSOIndex, 4) = "na"
                    else
                        AAVSOitem$(AAVSOIndex, 4) = VarItem$(VarIndex,15)
                    end if
                    if FilterSystem$ = "1" then
                        AAVSOitem$(AAVSOIndex, 5) = "R"
                    else
                        AAVSOitem$(AAVSOIndex, 5) = "SI"
                    end if
                    Rflag = 0
                    goto [EndColors]
                end if
                if Iflag = 1 then
                    AAVSOitem$(AAVSOIndex, 3) = str$(-1 * val(VarItem$(VarIndex,16)) + val(VarItem$(VarIndex,8)))
                    if val(VarItem$(VarIndex,17)) = 0 then
                        AAVSOitem$(AAVSOIndex, 4) = "na"
                    else
                        AAVSOitem$(AAVSOIndex, 4) = VarItem$(VarIndex,17)
                    end if
                    if FilterSystem$ = "1" then
                        AAVSOitem$(AAVSOIndex, 5) = "I"
                    else
                        AAVSOitem$(AAVSOIndex, 5) = "SZ"
                    end if
                    Iflag = 0
                end if
                [EndColors]

                AAVSOitem$(AAVSOIndex, 6) = "YES"
                AAVSOitem$(AAVSOIndex, 7) = "STD"
                AAVSOitem$(AAVSOIndex, 8) = COMP$
                AAVSOitem$(AAVSOIndex, 9) = "na"
                AAVSOitem$(AAVSOIndex,10) = "na"
                AAVSOitem$(AAVSOIndex,11) = "na"
                AAVSOitem$(AAVSOIndex,12) = "na"
                AAVSOitem$(AAVSOIndex,13) = str$(Group)
                AAVSOitem$(AAVSOIndex,14) = CHART$
                AAVSOitem$(AAVSOIndex,15) = "na"

                AAVSOIndex = AAVSOIndex + 1
            next
            Group = Group + 1
        next
        AAVSOIndexMax = AAVSOIndex - 1

        gosub [SaveExportFile]
        goto [QuitExport]
    wait

    [SaveExportFile]
        AppendFlag = 0
        filedialog "Save AAVSO data", PathAAVSO$, AAVSOFile$

        for I = len(AAVSOFile$) to 1 step -1
            if mid$(AAVSOFile$,I,1) = "\" then
                ShortAAVSO$ = mid$(AAVSOFile$,I+1)
                PathAAVSO$ = left$(AAVSOFile$,I)+"*.txt"
                exit for
            end if
        next

        if AAVSOFile$ = "" then [QuitExport]

        files "c:\", AAVSOFile$, info$()
        if val(info$(0,0)) <> 0 then
           confirm "Append data?"; Answer$
               if Answer$ = "no" then [SaveExportFile]
               AppendFlag = 1
        end if

        if AppendFlag = 0 then
            if (right$(AAVSOFile$,4) = ".txt") OR (right$(AAVSOFile$,4) = ".TXT") then
                open AAVSOFile$ for Output as #AAVSOFile
            else
                AAVSOFile$ = AAVSOFile$+".txt"
                open AAVSOFile$ for Output as #AAVSOFile
            end if
            print #AAVSOFile, AAVSO$(1)     '"#TYPE=EXTENDED"
            print #AAVSOFile, AAVSO$(2)     '"#OBSCODE="+OBSCODE$
            print #AAVSOFile, AAVSO$(3)     '"#SOFTWARE=OPTEC SSPDATAQ"
            print #AAVSOFile, AAVSO$(4)     '"#DELIM=,"
            print #AAVSOFile, AAVSO$(5)     '"#DATE=JD"
            print #AAVSOFile, AAVSO$(6)     '"#OBSTYPE=PEP"
        else
            open AAVSOFile$ for Append as #AAVSOFile
        end if

        for AAVSOIndex = 1 to AAVSOIndexMax

            TempMagnitude = val(AAVSOitem$(AAVSOIndex,3))
            AAVSOitem$(AAVSOIndex,3) = using("##.###", TempMagnitude)
            TempStandardError = val(AAVSOitem$(AAVSOIndex,4))
            AAVSOitem$(AAVSOIndex,4) = using("#.###", TempStandardError)

            print #AAVSOFile, AAVSOitem$(AAVSOIndex,1);",";_    'VAR$, variable star name
                              AAVSOitem$(AAVSOIndex,2);",";_    'Julian Day
                              AAVSOitem$(AAVSOIndex,3);",";_    'magnitude
                              AAVSOitem$(AAVSOIndex,4);",";_    'magnitude standard error
                              AAVSOitem$(AAVSOIndex,5);",";_    'filter: UBVRI
                              AAVSOitem$(AAVSOIndex,6);",";_    '"YES", use transformation coefficients
                              AAVSOitem$(AAVSOIndex,7);",";_    '"STD", magnitude type is standard
                              AAVSOitem$(AAVSOIndex,8);",";_    'COMP$, comparison star name
                              AAVSOitem$(AAVSOIndex,9);",";_    '"na", instrument magnitude of comp
                              AAVSOitem$(AAVSOIndex,10);",";_   '"na", name of check star
                              AAVSOitem$(AAVSOIndex,11);",";_   '"na", instrument magnitude of check star
                              AAVSOitem$(AAVSOIndex,12);",";_   '"na", airmass
                              AAVSOitem$(AAVSOIndex,13);",";_   '"Group$, grouping identifier
                              AAVSOitem$(AAVSOIndex,14);",";_   'CHART$, chart name
                              AAVSOitem$(AAVSOIndex,15)         '"na", notes to data line

        next
        close #AAVSOFile
    return

    [QuitExport]
        AAVSOFlag = 0          'AAVSO export window is closed
    close #export
wait
'
'==============Export MEDUZA Format File
'
[MEDUZA]
    NOMAINWIN
    WindowWidth = 350 : WindowHeight = 270
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #exportMEDUZA, "File", "Quit", [QuitExportMEDUZA]

        statictext #exportMEDUZA.varName, "variable name", 140,17,130,20
        textbox    #exportMEDUZA.var, 10,15,120,22
        statictext #exportMEDUZA.compName, "comparison name", 140,47,150,20
        textbox    #exportMEDUZA.comp, 10,45,120,22
        statictext #exportMEDUZA.obscodeName, "MEDUZA observatory code", 140,77,180,20
        textbox    #exportMEDUZA.obscode, 10,75,120,22
        statictext #exportMEDUZA.JD, "Julian date protocol", 140,107,180,20
        textbox    #exportMEDUZA.jd, 10,105,120,22

        button #exportMEDUZA.save, "Make/Save MEDUZA Data", [MakeMEDUZAdata], UL, 85,170,180,30

    Open "Export data in MEDUZA format" for Window as #exportMEDUZA
        #exportMEDUZA "trapclose [QuitExportMEDUZA]"
        #exportMEDUZA "font ariel 10"

        MEDUZAFlag = 1
        if PlotFileName$ = ""  then
            notice "open a var data file "
            goto [QuitExportMEDUZA]
        end if

        VAR$ = VarStar$
        gosub [VAR_ABVR]

        if VarStar$ = "" then
            print #exportMEDUZA.var, PlotFileName$        'print default filename in text box
        else
            print #exportMEDUZA.var, VAR$                 'print star names from file header
            print #exportMEDUZA.comp, CompStar$
        end if

        print #exportMEDUZA.obscode, MEDUSAOBSCODE$

        for VarIndex = 1 to VarIndexMax
            VarItemJD$(VarIndex) = VarItem$(VarIndex,7)
        next

        if JDFlag <> 1 then                          'check PPparms value of JDFlag
            confirm "MEDUZA requires geocentric JD"+ chr$(13)+_
                    "do you wish to convert dates to JD";HJDtoJD$
            if HJDtoJD$ = "yes" then
                for VarIndex = 1 to VarIndexMax
                    UTday = val(VarItem$(VarIndex,1))
                    UTmonth = val(VarItem$(VarIndex,2))
                    UTyear = val(VarItem$(VarIndex,3))
                    UThour = val(VarItem$(VarIndex,4))
                    UTminute = val(VarItem$(VarIndex,5))
                    UTsec = val(VarItem$(VarIndex,6))
                    gosub [Calender_to_Julian]
                    VarItemJD$(VarIndex) = using("#####.#####",JD)
                next
                print #exportMEDUZA.jd, "GEOCENTRIC"
            else
                print #exportMEDUZA.jd, "HELIOCENTRIC"
            end if
        else
            print #exportMEDUZA.jd, "GEOCENTRIC"
        end if
    wait

    [MakeMEDUZAdata]
        print #exportMEDUZA.var, "!contents? VAR$";
             VAR$ = trim$(VAR$)

        print #exportMEDUZA.comp, "!contents? COMP$";
             COMP$ = trim$(COMP$)

        print #exportMEDUZA.obscode, "!contents? OBSCODEnew$";
        OBSCODEnew$ = upper$(OBSCODEnew$)
        if OBSCODEnew$ <> MEDUSAOBSCODE$ then
            MEDUSAOBSCODE$ = OBSCODEnew$
            gosub [SAVE_PPparms]
        end if

        MEDUZAIndex = 1
        for VarIndex = 1 to VarIndexMax
            Uflag = 0 : Bflag = 0 : Vflag = 1 : Rflag = 0 : Iflag = 0
                                            'find how many colors for each data line used
            Colors = 1
            if val(VarItem$(VarIndex,10)) <> 0  then
                Colors  = Colors + 1
                Uflag = 1
            end if
            if val(VarItem$(VarIndex,12)) <> 0  then
                Colors  = Colors + 1
                Bflag = 1
            end if
            if val(VarItem$(VarIndex,14)) <> 0  then
                Colors  = Colors + 1
                Rflag = 1
            end if
            if val(VarItem$(VarIndex,16)) <> 0  then
                Colors  = Colors + 1
                Iflag = 1
            end if

            for J = 1 to Colors
                MEDUZAitem$(MEDUZAIndex, 1) = VAR$
                                              'calculate JDN from J2000 date
                MEDUZAitem$(MEDUZAIndex, 2) = using("#######.####", (val(VarItemJD$(VarIndex)) + 2451545))

                MEDUZAitem$(MEDUZAIndex, 7) = COMP$

                MEDUZAitem$(MEDUZAIndex, 5) = OBSCODE$

                MEDUZAitem$(MEDUZAIndex, 4) = VarItem$(VarIndex,3)+"-"+_
                                              right$("0"+trim$(VarItem$(VarIndex,2)),2)+"-"+_
                                              right$("00"+trim$(using("##.####",VAL(VarItem$(VarIndex,1))+_
                                              val(VarItem$(VarIndex,4))/24 +_
                                              val(VarItem$(VarIndex,5))/1440 +_
                                              val(VarItem$(VarIndex,6))/86400)),7)

                                              'separate out colors from color index and find UBVRI magnitude
                if Uflag = 1 then
                    MEDUZAitem$(MEDUZAIndex, 3) = str$(val(VarItem$(VarIndex,10))+_
                                                  val(VarItem$(VarIndex,12))+_
                                                  val(VarItem$(VarIndex,8)))

                    MEDUZAitem$(MEDUZAIndex, 6) = VarItem$(VarIndex,11)

                    if FilterSystem$ = "1" then
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+U"
                    else
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+SU"
                    end if
                    Uflag = 0
                    goto [MEDUZAEndColors]
                end if
                if Bflag = 1 then
                    MEDUZAitem$(MEDUZAIndex, 3) = str$(val(VarItem$(VarIndex,12)) + val(VarItem$(VarIndex,8)))

                    MEDUZAitem$(MEDUZAIndex, 6) = VarItem$(VarIndex,13)

                    if FilterSystem$ = "1" then
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+B"
                    else
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+SG"
                    end if
                    Bflag = 0
                    goto [MEDUZAEndColors]
                end if
                if Vflag = 1 then
                    MEDUZAitem$(MEDUZAIndex, 3) = str$(val(VarItem$(VarIndex,8)))

                    MEDUZAitem$(MEDUZAIndex, 6) = VarItem$(VarIndex,9)

                    if FilterSystem$ = "1" then
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+V"
                    else
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+SR"
                    end if
                    Vflag = 0
                    goto [MEDUZAEndColors]
                end if
                if Rflag = 1 then
                    MEDUZAitem$(MEDUZAIndex, 3) = str$(-1 * val(VarItem$(VarIndex,14)) + val(VarItem$(VarIndex,8)))

                    MEDUZAitem$(MEDUZAIndex, 6) = VarItem$(VarIndex,15)

                    if FilterSystem$ = "1" then
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+R"
                    else
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+SI"
                    end if
                    Rflag = 0
                    goto [MEDUZAEndColors]
                end if
                if Iflag = 1 then
                    MEDUZAitem$(MEDUZAIndex, 3) = str$(-1 * val(VarItem$(VarIndex,16)) + val(VarItem$(VarIndex,8)))

                    MEDUZAitem$(MEDUZAIndex, 6) = VarItem$(VarIndex,17)

                    if FilterSystem$ = "1" then
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+I"
                    else
                        MEDUZAitem$(MEDUZAIndex, 8) = "PEP+SZ"
                    end if
                    Iflag = 0
                end if
                [MEDUZAEndColors]

                MEDUZAIndex = MEDUZAIndex + 1
            next
        next
        MEDUZAIndexMax = MEDUZAIndex - 1

        gosub [SaveExportMEDUZAFile]
    wait

    [QuitExportMEDUZA]
        MEDUZAFlag = 0
    close #exportMEDUZA
wait
'
'==============Export BRNO Format File
'
[BRNO]
    NOMAINWIN
    WindowWidth = 350 : WindowHeight = 550
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

        Menu       #exportBRNO, "File", "Quit", [QuitExportBRNO]

        statictext #exportBRNO.Var,      "Variable Name", 140,27,130,20
        textbox    #exportBRNO.var,      10,25,120,22
        statictext #exportBRNO.Comp,     "Comparison Name", 140,57,130,20
        textbox    #exportBRNO.comp,     10,55,120,22
        statictext #exportBRNO.Filter,   "Filter", 140,87,130,20
        textbox    #exportBRNO.filter,   10,85,120,22
        statictext #exportBRNO.JD,       "Date Protocol", 140,117,130,20
        textbox    #exportBRNO.jd,       10,115,120,22
        textbox    #exportBRNO.comment,  10,145,315,22

        listbox    #exportBRNO.data, TimeSeriesData$(), [BRNOData], 10,175,315,100

        groupbox   #exportBRNO.standarderror, "Linear Anaylis", 10,290,320,55
        statictext #exportBRNO.Error, "error (mag.)", 15,317,80,20
        textbox    #exportBRNO.error, 125,315,100,20
        button     #exportBRNO.finderror, "update", [UpdateBRNO_SE], UL, 245,313,70,25

        groupbox   #exportBRNO.standarderror.parabolic, "Parabolic Anaylsis", 10,355,320,85
        statictext #exportBRNO.Min.parabolic, "minimum HJD", 15,380,110,20
        textbox    #exportBRNO.mim.parabolic, 125,378,100,20
        statictext #exportBRNO.Error.parabolic, "error (mag.)", 15,412,80,20
        textbox    #exportBRNO.error.parabolic, 125,410,100,20
        button     #exportBRNO.finderror.parabolic, "update", [UpdateBRNO_SE_parabolic], UL, 245,408,70,25

        button     #exportBRNO.save, "Make/Save BRNO Data", [SaveBRNOdata], UL, 85,454,180,30

        Open "Export data in BRNO format" for Window as #exportBRNO
        #exportBRNO "trapclose [QuitExportBRNO]"
        #exportBRNO "font ariel 10"
        BRNOFlag = 1

        if PlotFileName$ = ""  then
            notice "open a var data file "
            goto [QuitExportBRNO]
        end if

        if FilterSystem$ = "1" then
            print #exportBRNO.filter, "V"
        else
            print #exportBRNO.filter, "r'"
        end if

        print #exportBRNO.comment, "PEP data in V"

        VAR$ = VarStar$
        gosub [VAR_ABVR]

        if VarStar$ = "" then
            print #exportBRNO.var, PlotFileName$        'print default filename in text box
        else
            print #exportBRNO.var, VAR$                 'print star names from file header
            print #exportBRNO.comp, CompStar$
        end if

        for VarIndex = 1 to VarIndexMax
            VarItemJD$(VarIndex) = VarItem$(VarIndex,7)
        next

        if JDFlag <> 1 then                          'check PPparms value of JDFlag
            confirm "BRNO requires geocentric JD"+ chr$(13)+_
                    "do you wish to convert dates to JD";HJDtoJD$
            if HJDtoJD$ = "yes" then
                for VarIndex = 1 to VarIndexMax
                    UTday = val(VarItem$(VarIndex,1))
                    UTmonth = val(VarItem$(VarIndex,2))
                    UTyear = val(VarItem$(VarIndex,3))
                    UThour = val(VarItem$(VarIndex,4))
                    UTminute = val(VarItem$(VarIndex,5))
                    UTsec = val(VarItem$(VarIndex,6))
                    gosub [Calender_to_Julian]
                    VarItemJD$(VarIndex) = using("#####.#####",JD)
                next
                print #exportBRNO.jd, "GEOCENTRIC"
            else
                print #exportBRNO.jd, "HELIOCENTRIC"
            end if
        else
            print #exportBRNO.jd, "GEOCENTRIC"
        end if

        gosub [DisplayTimeSeriesData]

        print #exportBRNO.data, "reload"

    wait

    [SaveBRNOdata]
        print #exportBRNO.var,      "!contents? var$"
        print #exportBRNO.comp,     "!contents? comp$"
        print #exportBRNO.jd,       "!contents? DateType$"
        print #exportBRNO.filter,   "!contents? Filter$"
        print #exportBRNO.comment,  "!contents? Comment$"

        if Comment$ = "add comment" then
            Comment$ = ""
        end if

        Header$ = "JD   V/r'"
        gosub [SaveTimeStringData]
    wait

    [BRNOData]
    wait

    [UpdateBRNO_SE]
        redim X(200)
        redim Y(200)
        open "IREX.txt" for append as #IREX
        print #IREX, " "
        print #IREX, "-I-    X(time)     Y(Mag)"
        Imax = 0
        for TimeIndex = 1 to VarIndexMax
            if val(VarItem$(TimeIndex,7)) >= CursorTime.A AND val(VarItem$(TimeIndex,7)) <= CursorTime.B then
                Imax = Imax + 1
                X(Imax) =  val(VarItem$(TimeIndex,7))
                Y(Imax) =  val(VarItem$(TimeIndex,8))
                print #IREX, using("###", Imax)+"  "+using("####.#####",X(Imax))+"   "+using("###.###",Y(Imax))
            end if
        next

        if Imax < 8 then
            notice "set cursors A & B to enclose at least 8 data points"
            goto [QuitUpdateBRNO_SE]
        end if

            'linear least squares routine from Nielson
            'pulled from appendix I.4 of Astronomical Photometry, written by Hendon 1973
            'inputs     X() air mass array
            '           m() instrument magnitude array
            'outputs   Slope and Intercept,   Y = aX + b
            'number of elements in array = RegIndexMax
    a2 = 0
    a3 = 0
    c1 = 0
    c2 = 0
    a1 = Imax
    for I = 1 to Imax
        a2 = a2 + X(I)
        a3 = a3 + X(I) * X(I)
        c1 = c1 + Y(I)
        c2 = c2 + Y(I) * X(I)
    next
    det = 1/(a1 * a3 - a2 * a2)
    Intercept = -1 * (a2 * c2 - c1 * a3) * det
    Slope = (a1 * c2 - c1 * a2) * det

            'compute standard error using eq. 3.21
    if Imax > 2 then
        y.deviation.squared.sum = 0
        for N = 1 to Imax
            y.fit = Slope * X(N) + Intercept
            y.deviation = Y(N) - y.fit
            y.deviation.squared.sum =  y.deviation.squared.sum + y.deviation^2
        next
        std.error = sqr((1/(N-2)) * y.deviation.squared.sum)
    else
        std.error = 0
    end if
    std.error$ = using("##.####", std.error)
    print #exportBRNO.error, std.error$

    ETDerror$ = std.error$ 
    gosub [DisplayTimeSeriesData]
    print #exportBRNO.data, "reload"

    [QuitUpdateBRNO_SE]
    close #IREX
    wait

    [QuitExportBRNO]
        close #exportBRNO
        BRNOFlag = 0
wait
'
    [UpdateBRNO_SE_parabolic]
        redim X(200)
        redim Y(200)
        open "IREX.txt" for append as #IREX
        print #IREX, " "
        print #IREX, "-I-    X(time)     Y(Mag)"
        Imax = 0
        for TimeIndex = 1 to VarIndexMax
            if val(VarItem$(TimeIndex,7)) >= CursorTime.A AND val(VarItem$(TimeIndex,7)) <= CursorTime.B then
                Imax = Imax + 1
                X(Imax) =  val(VarItem$(TimeIndex,7)) - CursorTime.C
                Y(Imax) =  val(VarItem$(TimeIndex,8))
                print #IREX, using("###", Imax)+"  "+using("####.#####",X(Imax))+"   "+using("###.###",Y(Imax))
            end if
        next

        if Imax < 8 then
            notice "set cursors A & B to enclose at least 8 data points"
            goto [QuitUpdateBRNO_SE_parabolic]
        end if

'****************************************************
'*  Parabolic Least Squares                         *
'* ------------------------------------------------ *
'* Reference: BASIC Scientific Subroutines, Vol. II *
'*   By F.R. Ruckdeschel, BYTE/McGRAWW-HILL, 1981   *
'*   [BIBLI 01].                                    *
'* ------------------------------------------------ *
'number of elements in array = RegIndexMax
    a0 = 1
    a1 = 0
    a2 = 0
    a3 = 0
    a4 = 0
    b0 = 0
    b1 = 0
    b2 = 0

    for I = 1 to Imax
        a1 = a1 + X(I)
        a2 = a2 + X(I) * X(I)
        a3 = a3 + X(I) * X(I) * X(I)
        a4 = a4 + X(I) * X(I) * X(I) *X(I)
        b0 = b0 + Y(I)
        b1 = b1 + Y(I) * X(I)
        b2 = b2 + Y(I) * X(I) * X(I)
    next I

    a1 = a1/Imax
    a2 = a2/Imax
    a3 = a3/Imax
    a4 = a4/Imax
    b0 = b0/Imax
    b1 = b1/Imax
    b2 = b2/Imax

    d = a0 * (a2 * a4 - a3 * a3) - a1 * (a1 * a4 - a2 * a3) + a2 * (a1 * a3 - a2 * a2)
    a = b0 * (a2 * a4 - a3 * a3) + b1 * (a2 * a3 - a1 * a4) + b2 * (a1 * a3 - a2 * a2)
    a = a / d
    b = b0 * (a2 * a3 - a1 * a4) + b1 * (a0 * a4 - a2 * a2) + b2 * (a1 * a2 - a0 * a3)
    b = b / d
    c = b0 * (a1 * a3 - a2 * a2) + b1 * (a2 * a1 - a0 * a3) + b2 * (a0 * a2 - a1 * a1)
    c = c / d

    'Evaluation of standard deviation d
    d = 0
    for I = 1 to Imax
        d1 = Y(I) - a - b * X(I) - c * X(I) * X(I)
        d  = d + d1 * d1
    next I

    std.error.parabolic = sqr(d/(Imax - 3))

    print #IREX, " "
    print #IREX, "Coefficients Y = a + bX + cX^2 and standard error"
    print #IREX, "       a           b            c         std.error.parabolic"
    print #IREX, using("####.#####",a)+"   "+using("####.#####",b)+"   "+using("####.#####",c)+"       "+using("####.#####",std.error.parabolic)

    std.error.parabolic$ = using("##.####", std.error.parabolic)
    print #exportBRNO.error.parabolic, std.error.parabolic$

    min.parabolic =  CursorTime.C - b/(2*c)
    min.parabolic$ = using("#####.#####", min.parabolic)
    print #exportBRNO.mim.parabolic, min.parabolic$
    print #IREX, " "
    print #IREX, "min.parabolic HJD = "+min.parabolic$

    ETDerror$ = std.error.parabolic$ 
    gosub [DisplayTimeSeriesData]
    print #exportBRNO.data, "reload"

    [QuitUpdateBRNO_SE_parabolic]
        close #IREX
        wait

    [QuitExportBRNO_parabolic]
        close #exportBRNO
        BRNOFlag = 0
wait
'
'==============Export ETD Format File
'
[ETD]
    NOMAINWIN
    WindowWidth = 350 : WindowHeight = 450
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

        Menu       #exportETD, "File", "Quit", [QuitExportETD]

        statictext #exportETD.Var,     "Variable Name", 140,27,130,20
        textbox    #exportETD.var,      10,25,120,22
        statictext #exportETD.Comp,     "Comparison Name",140,57,130,20
        textbox    #exportETD.comp,     10,55,120,22
        statictext #exportETD.Filter,   "Filter", 140,87,130,20
        textbox    #exportETD.filter,   10,85,120,22
        statictext #exportETD.JD,       "Date Protocol", 140,117,130,20
        textbox    #exportETD.jd,       10,115,120,22
        textbox    #exportETD.comment,  10,145,315,22

        listbox    #exportETD.data, TimeSeriesData$(), [ETDData], 10,175,315,100

        groupbox   #exportETD.standarderror, "Corrected Sample Standard Deviation", 10,285,320,55
        textbox    #exportETD.error, 25,310, 115,20
        button     #exportETD.finderror, "update", [UpdateSE], UL, 200,308,70,25

        button     #exportETD.save, "Make/Save ETD Data", [SaveETAdata], UL, 85,354,180,30

        Open "Export data in ETD format" for Window as #exportETD
        #exportETD "trapclose [QuitExportETD]"
        #exportETD "font ariel 10"
        ETDFlag = 1
'
'-------check for go conditions
'
        if PlotFileName$ = ""  then
            notice "open a .var data file "
            goto [QuitExportETD]
        end if
'
'-------------fill in texboxes with results
'
        if VarStar$ = "" then
            print #exportETD.var, PlotFileName$        'print default filename in text box
        else
            print #exportETD.var, VarStar$             'print star names from file header
            print #exportETD.comp, CompStar$
        end if

        if FilterSystem$ = "1" then
            print #exportETD.filter, "V"
        else
            print #exportETD.filter, "r'"
        end if

        if JDFlag = 1 then
            print #exportETD.jd, "geocentric"
        end if
        if JDFlag = 0 then
            print #exportETD.jd, "heliocentric"
        end if

        print #exportETD.comment, "PEP observations -edit comment-"

        for VarIndex = 1 to VarIndexMax
            VarItemJD$(VarIndex) = VarItem$(VarIndex,7)
        next
        gosub [DisplayTimeSeriesData]

        print #exportETD.data, "reload"

        [ETDData]
            'do nothing if text is selected in listbox
        wait

        [SaveETAdata]
        print #exportETD.var,      "!contents? var$"
        print #exportETD.comp,     "!contents? comp$"
        print #exportETD.jd,       "!contents? DateType$"
        print #exportETD.filter,   "!contents? Filter$"
        print #exportETD.comment,  "!contents? Comment$"

        if Comment$ = "PEP observations -edit comment-" then
            Comment$ = "PEP observations"
        end if
        if JDFlag = 1 then
            Header$ = "JD   V/r'  Error"
        else
            Header$ = "HJD  V/r'  Error"
        end if

        gosub [SaveTimeStringData]

        wait
'
'----------Find Standard Error
'
    [UpdateSE]
        open "IREX.txt" for append as #IREX
        print #IREX, " "
        print #IREX, "-I-    ErrorMag     JD date"
        Imax = 0
        for TimeIndex = 1 to VarIndexMax
            if val(VarItem$(TimeIndex,7)) >= CursorTime.A AND val(VarItem$(TimeIndex,7)) <= CursorTime.B then
                Imax = Imax + 1
                ErrorMag(Imax) = val(VarItem$(TimeIndex,8))
                print #IREX, using("###", Imax)+"  "+using("####.#####",ErrorMag(Imax))+"   "+VarItem$(TimeIndex,7)
            end if
        next

        if Imax < 8 then
            notice "set cursors A & B to enclose at least 8 data points"
            goto [QuitUpdateSE]
        end if

        ErrorMagAvg = 0
        for J = 1 to Imax
            ErrorMagAvg = ErrorMag(J) + ErrorMagAvg
        next
        ErrorMagAvg = ErrorMagAvg / Imax

        print #IREX, "ErrorMagAvg : "+str$(ErrorMagAvg)

        print #IREX, " "
        print #IREX, "-J-    deviation"
        deviation = 0
        for J = 1 to Imax
            deviation = (ErrorMag(J) - ErrorMagAvg)^2 + deviation
            print #IREX, using("###", J)+"    "+using("###.#####", deviation)
        next
        ETDerror$ = using("##.####",(sqr((deviation/(Imax-1)))))
        print #IREX, "ETDerror : "+ETDerror$
        print #exportETD.error, ETDerror$+"      N="+str$(Imax)
        gosub [DisplayTimeSeriesData]
        print #exportETD.data, "reload"

        [QuitUpdateSE]
        close #IREX
    wait
'
'---------End ETD Routine
'
    [QuitExportETD]
        ETDFlag = 0
    close #exportETD
wait
'
'==============common subroutines for MEDUZA, BRNO & ETD
'
    [DisplayTimeSeriesData]
        if BRNOFlag = 1 or ETDFlag = 1 then
            JulianConvert = 2451545
        else
            JulianConvert = 0
        end if
        for TimeIndex = 1 to VarIndexMax
            TimeSeriesdate = val(VarItemJD$(TimeIndex)) + JulianConvert
            TimeSeriesdate$ = using("#######.####",TimeSeriesdate)
            TimeSeriesData$(TimeIndex) = TimeSeriesdate$+"   "+VarItem$(TimeIndex,8)+"   "+ETDerror$
        next
    return


    [Calender_to_Julian]
          '  enter these values
          '  UTyear
          '  UTmonth
          '  UTday
          '  UThour
          '  UTminute
          '  UTsec

            If (UTmonth = 1) or (UTmonth = 2) then
                UTmonth = UTmonth + 12
                UTyear = UTyear - 1
            end if
                                'A = int(UTyear/100)
            A = int(UTyear/100)
            B = 2 - A + int(A/4)
                                'C = int(365.25 * UTyear)
            C = int(365.25 * UTyear)
                                'D = int(30.6001 *(UTmonth + 1))
            D = int(30.6001 * (UTmonth + 1))
                                'JD = B + C + D - 730550.5 + UTday + (UThours + UTmin/60 + UTsec/3600)/24
            JD = B + C + D - 730550.5 + UTday + (UThour + UTminute/60 + UTsec/3600)/24
    return


    [SaveExportMEDUZAFile]
        AppendFlag = 0
        filedialog "Save MEDUZA data", PathMEDUZA$, MEDUZAFile$

        for I = len(MEDUZAFile$) to 1 step -1
            if mid$(MEDUZAFile$,I,1) = "\" then
                ShortMEDUZA$ = mid$(MEDUZAFile$,I+1)
                PathMEDUZA$ = left$(MEDUZAFile$,I)+"*.txt"
                exit for
            end if
        next

        if MEDUZAFile$ = "" then [QuitExportMEDUZA]

        files "c:\", MEDUZAFile$, info$()
        if val(info$(0,0)) <> 0 then
           confirm "Append data?"; Answer$
               if Answer$ = "no" then [SaveExportMEDUZAFile]
               AppendFlag = 1
        end if

        if AppendFlag = 0 then
            if (right$(MEDUZAFile$,4) = ".txt") OR (right$(MEDUZAFile$,4) = ".TXT") then
                open MEDUZAFile$ for Output as #MEDUZAFile
            else
                MEDUZAFile$ = MEDUZAFile$+".txt"
                open MEDUZAFile$ for Output as #MEDUZAFile
            end if

        else
            open MEDUZAFile$ for Append as #MEDUZAFile
        end if

        for MEDUZAIndex = 1 to MEDUZAIndexMax

            TempMagnitude = val(MEDUZAitem$(MEDUZAIndex,3))
            MEDUZAitem$(MEDUZAIndex,3) = using("##.###", TempMagnitude)
            TempStandardError = val(MEDUZAitem$(MEDUZAIndex,6))
            MEDUZAitem$(MEDUZAIndex,6) = using("#.###", TempStandardError)

            print #MEDUZAFile, MEDUZAitem$(MEDUZAIndex,1);"  ";_           'VAR$, variable star name
                               MEDUZAitem$(MEDUZAIndex,2);"  ";_           'Julian Day
                               MEDUZAitem$(MEDUZAIndex,3);" ";_            'magnitude
                               MEDUZAitem$(MEDUZAIndex,4);"   ";_          'calendar date
                               MEDUZAitem$(MEDUZAIndex,5);"  ";_           'observer's code
                               trim$(MEDUZAitem$(MEDUZAIndex,6));"  ";_    'error
                               trim$(MEDUZAitem$(MEDUZAIndex,7));"   ";_   'COMP$, comparison star name
                               MEDUZAitem$(MEDUZAIndex,8)                  'PEP+Filter
        next
        close #MEDUZAFile
    return


    [SaveTimeStringData]                       'make data file with .txt type as default

    filedialog "Save Time String data", PathTimeString$, TimeStringFile$
         for I = len(TimeStringFile$) to 1 step -1
             if mid$(TimeStringFile$,I,1) = "\" then
                 ShortTimeString$ = mid$(TimeStringFile$,I+1)
                 PathTimeString$ = left$(TimeStringFile$,I)+"*.txt"
                 exit for
             end if
         next

         if TimeStringFile$ <> "" then
            files "c:\", TimeStringFile$, info$()
            if val(info$(0,0)) <> 0 then
                confirm "Write over existing file?"; Answer$
                if Answer$ = "no" then [SaveTimeStringData]
            end if

            if (right$(TimeStringFile$,4) = ".txt") OR (right$(TimeStringFile$,4) = ".TXT") then
                open TimeStringFile$ for Output as #TimeStringFile
            else
                TimeStringFile$ = TimeStringFile$+".txt"
                open TimeStringFile$ for Output as #TimeStringFile
            end if


            print #TimeStringFile, Header$ 
            print #TimeStringFile, "Variable: "; var$;"  Comparison: "; comp$;"  Filter: ";Filter$;"  Date Protocol: ";DateType$
            print #TimeStringFile, "Comment: "; Comment$

            for TimeIndex = 1 to VarIndexMax
                print #TimeStringFile, TimeSeriesData$(TimeIndex)
            next

            close  #TimeStringFile
        end if
    return


    [VAR_ABVR]
        VARName$ = ""
        Constellation$ = ""
        VAR$ = trim$(VAR$)
        Jmax = LEN(VAR$)
        for J = 1 to Jmax
            Check$ = mid$(VAR$,J,1)
            if Check$ = " " then
                VARName$ = left$(VAR$,J-1)
                Constellation$ = right$(VAR$,3)
                exit for
            end if
        next

        SELECT CASE Constellation$
            CASE "AND"
                Constellation$ = "And"
            CASE "ANT"
                Constellation$ = "Ant"
            CASE "APS"
                Constellation$ = "Aps"
            CASE "AQR"
                Constellation$ = "Aqr"
            CASE "AQL"
                Constellation$ = "Aql"
            CASE "ARA"
                Constellation$ = "Ara"
            CASE "ARI"
                Constellation$ = "Ari"
            CASE "AUR"
                Constellation$ = "Aur"
            CASE "BOO"
                Constellation$ = "Boo"
            CASE "CAE"
                Constellation$ = "Cae"
            CASE "CAM"
                Constellation$ = "Cam"
            CASE "CNC"
                Constellation$ = "Cnc"
            CASE "CVN"
                Constellation$ = "CVn"
            CASE "CMA"
                Constellation$ = "CMa"
            CASE "CMI"
                Constellation$ = "CMi"
            CASE "CAP"
                Constellation$ = "Cap"
            CASE "CAR"
                Constellation$ = "Car"
            CASE "CAS"
                Constellation$ = "Cas"
            CASE "CEN"
                Constellation$ = "Cen"
            CASE "CEP"
                Constellation$ = "Cep"
            CASE "CET"
                Constellation$ = "Cet"
            CASE "CHA"
                Constellation$ = "Cha"
            CASE "CIR"
                Constellation$ = "Cir"
            CASE "COL"
                Constellation$ = "Col"
            CASE "COM"
                Constellation$ = "Com"
            CASE "CRA"
                Constellation$ = "CrA"
            CASE "CRB"
                Constellation$ = "CrB"
            CASE "CRV"
                Constellation$ = "Crv"
            CASE "CRT"
                Constellation$ = "Crt"
            CASE "CYG"
                Constellation$ = "Cyg"
            CASE "DEL"
                Constellation$ = "Del"
            CASE "DOR"
                Constellation$ = "Dor"
            CASE "DRA"
                Constellation$ = "Dra"
            CASE "EQU"
                Constellation$ = "Equ"
            CASE "ERI"
                Constellation$ = "Eri"
            CASE "FOR"
                Constellation$ = "For"
            CASE "GEM"
                Constellation$ = "Gem"
            CASE "GRU"
                Constellation$ = "Gru"
            CASE "HER"
                Constellation$ = "Her"
            CASE "HOR"
                Constellation$ = "Hor"
            CASE "HYA"
                Constellation$ = "Hya"
            CASE "HYI"
                Constellation$ = "Hyi"
            CASE "IND"
                Constellation$ = "Ind"
            CASE "LAC"
                Constellation$ = "Lac"
            CASE "LEO"
                Constellation$ = "Leo"
            CASE "LMI"
                Constellation$ = "LMi"
            CASE "LEP"
                Constellation$ = "Lep"
            CASE "LIB"
                Constellation$ = "Lib"
            CASE "LUP"
                Constellation$ = "Lup"
            CASE "LYN"
                Constellation$ = "Lyn"
            CASE "LYR"
                Constellation$ = "Lyr"
            CASE "MEN"
                Constellation$ = "Men"
            CASE "MIC"
                Constellation$ = "Mic"
            CASE "MON"
                Constellation$ = "Mon"
            CASE "MUS"
                Constellation$ = "Mus"
            CASE "NOR"
                Constellation$ = "Nor"
            CASE "OCT"
                Constellation$ = "Oct"
            CASE "OPH"
                Constellation$ = "Oph"
            CASE "ORI"
                Constellation$ = "Ori"
            CASE "PAV"
                Constellation$ = "Pav"
            CASE "PEG"
                Constellation$ = "Peg"
            CASE "PER"
                Constellation$ = "Per"
            CASE "PHE"
                Constellation$ = "Phe"
            CASE "PIC"
                Constellation$ = "Pic"
            CASE "PSC"
                Constellation$ = "Psc"
            CASE "PSA"
                Constellation$ = "PsA"
            CASE "PUP"
                Constellation$ = "Pup"
            CASE "PYX"
                Constellation$ = "Pyx"
            CASE "RET"
                Constellation$ = "Ret"
            CASE "SQE"
                Constellation$ = "Sqe"
            CASE "SGR"
                Constellation$ = "Sgr"
            CASE "SCO"
                Constellation$ = "Sco"
            CASE "SCL"
                Constellation$ = "Scl"
            CASE "SCT"
                Constellation$ = "Sct"
            CASE "SER"
                Constellation$ = "Ser"
            CASE "SEX"
                Constellation$ = "Sex"
            CASE "TAU"
                Constellation$ = "Tau"
            CASE "TEL"
                Constellation$ = "Tel"
            CASE "TRI"
                Constellation$ = "Tri"
            CASE "TRA"
                Constellation$ = "TrA"
            CASE "TUC"
                Constellation$ = "Tuc"
            CASE "UMA"
                Constellation$ = "UMa"
            CASE "UMI"
                Constellation$ = "UMi"
            CASE "VEL"
                Constellation$ = "Vel"
            CASE "VIR"
                Constellation$ = "Vir"
            CASE "VOL"
                Constellation$ = "Vol"
            CASE "VUL"
                Constellation$ = "Vul"
            CASE ELSE
                return
        END SELECT
        VAR$ = VARName$+" "+Constellation$
    return
'
'============== Eclipse Binary Analysis
'
[FindMin]

    NOMAINWIN
    WindowWidth = 328 : WindowHeight = 610
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

    Menu        #FindMinimum, " File ",   "Submit Minima Parameters", [SubmitMinima],_
                                          "Exit", [Quit_FindMinimum]
    Menu        #FindMinimum, " Config ", "JD2000 Epoch", [Set_JD2000],_
                                          "JD4713BC Epoch", [Set_JD4713BC]

    groupbox   #FindMinimum.Minimum, "Find Time of Minimum  HJD2000", 9, 9, 300, 310
    statictext #FindMinimum.text1, "start time (cursor A)", 120,35,180,20
    textbox    #FindMinimum.start, 20, 30, 90, 25

    statictext #FindMinimum.text2, "end time (cursor B)", 120,65,180,20
    textbox    #FindMinimum.end, 20, 60, 90, 25

    statictext #FindMinimum.text3, "trial min. (cursor C)", 120,95,180,20
    textbox    #FindMinimum.trial, 20, 90, 90, 25

    statictext #FindMinimum.text4, "intervals", 120,125,180,20
    textbox    #FindMinimum.intervals, 80, 120, 30,25

    statictext #FindMinimum.text5, chr$(68)+"T", 120,155,100,20
    textbox    #FindMinimum.deltaT, 20, 150, 90, 25

    statictext #FindMinimum.text6, "T", 120,185,10,20
    statictext #FindMinimum.text9, "min", 133,190,30,20
    textbox    #FindMinimum.minimum, 20, 180, 90, 25

    statictext #FindMinimum.text25, "Yo =", 120,215,40,20
    statictext #FindMinimum.text7, "S", 160, 214,10,20
    statictext #FindMinimum.text8, "|Diff|"+chr$(178), 173,215,80,20
    textbox    #FindMinimum.diff, 20, 210, 90, 25

    statictext #FindMinimum.text24, "Error (SD 1 sigma)", 120,244,200,20
    textbox    #FindMinimum.error, 20,240,90,25

    button     #FindMinimum.update, "Update", [UpdateFindMinimum], UL, 120, 280, 75, 30

    groupbox   #FindMinimum.OC, "Find O-C  HJD4713BC", 9, 330, 300, 215

    statictext #FindMinimum.text10, "24 ", 20,354,20,20
    textbox    #FindMinimum.epoch, 42, 350, 100, 25
    statictext #FindMinimum.text11, "Enter Epoch", 152, 355, 120, 20

    textbox    #FindMinimum.period, 42, 380, 100, 25
    statictext #FindMinimum.text13, "Enter Period", 152, 385, 130, 20

    statictext #FindMinimum.text14, "24 ", 20,424,20,20
    textbox    #FindMinimum.Tcalc,  42, 420, 100, 25
    statictext #FindMinimum.text15, "T", 152, 425, 10, 20
    statictext #FindMinimum.text16, "min", 165, 430, 25, 20
    statictext #FindMinimum.text17, "calculated", 190, 425, 100, 20

    statictext #FindMinimum.text18, "24 ", 20,454,20,20
    textbox    #FindMinimum.Tobs,   42, 450, 100, 25
    statictext #FindMinimum.text19, "T", 152, 455, 10, 20
    statictext #FindMinimum.text20, "min", 165, 460, 25, 20
    statictext #FindMinimum.text21, "observed", 190, 455, 100, 20

    textbox    #FindMinimum.cycles, 42, 480, 100, 25
    statictext #FindMinimum.text23, "Cycles", 152, 485, 100, 20

    textbox    #FindMinimum.OminusC, 42, 510, 100,25
    statictext #FindMinimum.text22, "O-C", 152,515,40,20

    Open "Eclipsing Binary Analysis" for Window as #FindMinimum
    #FindMinimum "trapclose [Quit_FindMinimum]"
    #FindMinimum "font courier_new 8 16"

    print #FindMinimum.text5,  "!font symbol 10 14"
    print #FindMinimum.text6,  "!font symbol 10 14"
    print #FindMinimum.text7,  "!font symbol 13 17"
    print #FindMinimum.text8,  "!font courier 8 16"
    print #FindMinimum.text9,  "!font courier_new 8"
    print #FindMinimum.text15, "!font symbol 10 14"
    print #FindMinimum.text25, "!font courier 8 16"
    print #FindMinimum.text16, "!font courier_new 8"
    print #FindMinimum.text19, "!font symbol 10 14"
    print #FindMinimum.text20, "!font courier_new 8"

    FindMinimumFlag = 1

    DateEpoch$ = "JD4713BC"
    if CursorTime.A$ = "" or CursorTime.B$ = "" or CursorTime.C$ = "" then
        notice "set cursors"
        goto [Quit_FindMinimum]
    end if
    print #FindMinimum.start, CursorTime.A$ 
    print #FindMinimum.end, CursorTime.B$ 
    print #FindMinimum.trial, CursorTime.C$

    gosub [FindIntervals]
    print #FindMinimum.intervals, Intervals$ 

    wait

    [Set_JD2000]
        DateEpoch$ = "JD2000"
        print #FindMinimum.text10, "!hide"
        print #FindMinimum.text14, "!hide"
        print #FindMinimum.text18, "!hide"
    wait
    [Set_JD4713BC]
        DateEpoch$ = "JD4713BC"
        print #FindMinimum.text10, "!show"
        print #FindMinimum.text14, "!show"
        print #FindMinimum.text18, "!show"
    wait

    [UpdateFindMinimum]
        if CursorTime.A$ = "" or CursorTime.B$ = "" or CursorTime.C$ = "" then
            notice "set cursors"
            goto [Quit_FindMinimum]
        end if
        print #FindMinimum.start, CursorTime.A$
        print #FindMinimum.end, CursorTime.B$
        print #FindMinimum.trial, CursorTime.C$

        print #FindMinimum.intervals, "!contents? Temporary$";
        if int(val(Temporary$)) <> Intervals then
            Intervals = int(val(Temporary$))
            if Intervals > 99 or Intervals <= 5 then
                notice "Intervals must be between 5 and 99"
                wait
            end if
            Intervals$ = using("##", Intervals)
        end if
        print #FindMinimum.intervals, Intervals$


        gosub [FindDeltaT]
        print #FindMinimum.deltaT, DeltaT$

        open "IREX.txt" for append as #IREX
        print #IREX, "output from [FindMin]"
        print #IREX, " "
        print #IREX, "CursorTime.A$  CursorTime.B$  CursorTime.C$  Intervals   DeltaT"
        print #IREX, CursorTime.A$+"      "+CursorTime.B$+"      "+CursorTime.C$+"         "+_
                 Intervals$+"      "+DeltaT$ 
                                                    'find Yzero
        TimeZero = CursorTime.C
        gosub [FindMinimum]

        print #IREX, " "
        print #IREX, "I   DateDecending  DateAscending  MagDecending  MagAscending  MagDiff"
        for I = Intervals to 2 step -1
            print #IREX, using("##",I)+"    "+_
                         using("####.####",DateDecending(I))+"      "+_
                         using("####.####",DateAscending(I))+"     "+_
                         using("###.###",MagDecending(I))+"       "+_
                         using("###.###",MagAscending(I))+"       "+_
                         using("##.###",MagDiff(I))
        next
        Yzero = MagDiff
        print #IREX, "Yzero = "+using("##.######", Yzero)
        print #IREX, " "
                                                    'find Yminus
        TimeZero = CursorTime.C - DeltaT
        gosub [FindMinimum]

        print #IREX, " "
        print #IREX, "I   DateDecending  DateAscending  MagDecending  MagAscending  MagDiff"
        for I = Intervals to 2 step -1
            print #IREX, using("##",I)+"    "+_
                         using("####.####",DateDecending(I))+"      "+_
                         using("####.####",DateAscending(I))+"     "+_
                         using("###.###",MagDecending(I))+"       "+_
                         using("###.###",MagAscending(I))+"       "+_
                         using("##.###",MagDiff(I))
        next
        Yminus = MagDiff
        print #IREX, "Yminus = "+using("##.######", Yminus)
        print #IREX, " "
                                                    'find Yplus
        TimeZero = CursorTime.C + DeltaT
        gosub [FindMinimum]

        print #IREX, " "
        print #IREX, "I   DateDecending  DateAscending  MagDecending  MagAscending  MagDiff"
        for I = Intervals to 2 step -1
            print #IREX, using("##",I)+"    "+_
                         using("####.####",DateDecending(I))+"      "+_
                         using("####.####",DateAscending(I))+"     "+_
                         using("###.###",MagDecending(I))+"       "+_
                         using("###.###",MagAscending(I))+"       "+_
                         using("##.###",MagDiff(I))
        next
        Yplus = MagDiff
        print #IREX, "Yplus = "+using("##.######", Yplus)
        print #IREX, " "
                                                    'find Tminimum
        ReducedMinimum = CursorTime.C + 0.5*((Yminus - Yplus)/(Yminus - 2*Yzero + Yplus))*DeltaT
        ReducedMinimum$ = using("####.####", ReducedMinimum)
        Yzero$ = using("##.######",Yzero)
        print #FindMinimum.minimum, ReducedMinimum$
        print #FindMinimum.diff, Yzero$
                                                    'find probable error
        TimeZero = ReducedMinimum
        gosub [FindMinimum]
        print #IREX, " "
        print #IREX, "I   DateDecending  DateAscending  MagDecending  MagAscending  MagDiff"
        for I = Intervals to 2 step -1
            print #IREX, using("##",I)+"    "+_
                         using("####.####",DateDecending(I))+"      "+_
                         using("####.####",DateAscending(I))+"     "+_
                         using("###.###",MagDecending(I))+"       "+_
                         using("###.###",MagAscending(I))+"       "+_
                         using("##.###",MagDiff(I))
        next
        Yminimum = MagDiff
        print #IREX, "Yminimum = "+using("##.######", Yminimum)

        'equation from Louis Winkler page 229
        ProbableError = (sqr((Intervals/2)*MagSD/(abs((Yplus - Yminimum)) * 2))) * DeltaT
        print #FindMinimum.error, using("##.####", ProbableError)

        print #IREX, "MagSD  ="+using("##.######", MagSD)
        print #IREX, "MagAvg ="+using("##.######", MagAvg)
        print #IREX, "DeltaT ="+using("##.######", DeltaT)
        print #IREX, "Yplus  ="+using("##.######", Yplus)
        print #IREX, "Ymin   ="+using("##.######", Yminimum)
        print #IREX, "Error  ="+using("##.######", ProbableError)
        print #IREX, " "
        close #IREX
                                                   'draw Tminimum on graph
        Xmin = (ReducedMinimum - val(StartJ2000$))* PixelTime + 40
        print #show.graphicbox1, "delsegment ";CursorSegmentD
        print #show.graphicbox1, "redraw"
        print #show.graphicbox1, "color lightgray"
        print #show.graphicbox1, "line ";Xmin;" 20 ";Xmin;" 520"
        print #show.graphicbox1, "Segment CursorSegmentD"
        print #show.graphicbox1, "flush"
        print #show.graphicbox1, "color black"

        print #FindMinimum.epoch,  "!contents? epoch$";
        print #FindMinimum.period, "!contents? period$";
        epoch = val(epoch$)
        period = val(period$)
        if DateEpoch$ = "JD4713BC" then
            Tobserved = ReducedMinimum + 51545
            Tobserved$ = using("#####.####",Tobserved)
            print #FindMinimum.Tobs, Tobserved$
        else
            Tobserved  = ReducedMinimum
            Tobserved$ = ReducedMinimum$ 
            print #FindMinimum.Tobs, Tobserved$ 
        end if
        if epoch <> 0 and period <> 0 then
            gosub [FindOC]
        end if
    wait

    [SubmitMinima]
            run "hh Enter_Minima.chm"
     wait

    [Quit_FindMinimum]
        close #FindMinimum
        FindMinimumFlag = 0
wait
'
'============== Eclipse Binary Analysis subroutines
'
[FindIntervals]
    Intervals = 0
    for I = 1 to VarIndexMax
        if val(VarItem$(I,7)) >= CursorTime.A AND val(VarItem$(I,7)) <= CursorTime.B then
            Intervals = Intervals + 1
        end if
    next
    Intervals$ = str$(Intervals)
    if Intervals <= 5 then
        notice "Intervals must be equal to or greater than 5"
        goto [Quit_FindMinimum]
    end if
return
'
[FindDeltaT]
    DeltaT = (CursorTime.B - CursorTime.A)/(Intervals * 2)
    DeltaT$ = using("##.#####",DeltaT)
return
'
[FindMinimum]
    For I =  Intervals to 1 step -1
        DeltaTsum = I * DeltaT
        DateDecending(I) = TimeZero - DeltaTsum
        DateAscending(I) = TimeZero + DeltaTsum
    Next

    For I = Intervals to 2 step -1
        X = DateDecending(I)
        For VarIndex = 1 to VarIndexMax
            if  val(VarItem$(VarIndex,7)) <= X AND val(VarItem$(VarIndex+1,7)) > X then
                X1 = val(VarItem$(VarIndex,7))
                X2 = val(VarItem$(VarIndex + 1,7))
                Y1 = val(VarItem$(VarIndex,8))
                Y2 = val(VarItem$(VarIndex + 1,8))
                Y  = Y1 + ((Y2 - Y1)/(X2 - X1))*(X - X1)
                MagDecending(I) = Y
                exit for
            end if
        next
    next

    For I = Intervals to 2 step -1
        X = DateAscending(I)
        For VarIndex = 1 to VarIndexMax
            if  val(VarItem$(VarIndex,7)) <= X AND val(VarItem$(VarIndex+1,7)) > X then
                X1 = val(VarItem$(VarIndex,7))
                X2 = val(VarItem$(VarIndex + 1,7))
                Y1 = val(VarItem$(VarIndex,8))
                Y2 = val(VarItem$(VarIndex + 1,8))
                Y  = Y1 + ((Y2 - Y1)/(X2 - X1))*(X - X1)
                MagAscending(I) = Y
                exit for
            end if
        next
    next

    MagAvg = 0
    MagDiff = 0
    For I = Intervals to 2 step -1
        MagDiff(I) = MagAscending(I) - MagDecending(I)
        MagAvg = MagAvg + MagAscending(I) - MagDecending(I)
        MagDiff = MagDiff + (abs(MagDiff(I)))^2
    next
    MagAvg = MagAvg/(Intervals - 1)

    MagVariance = 0
    For I = Intervals to 2 step -1
        MagVariance = MagVariance + (MagDiff(I) - MagAvg)^2
    next
    MagSD = MagVariance/(Intervals - 1)
return
'
[FindOC]
    cycles = (Tobserved - epoch)/period
    cyclesRemainder = cycles MOD 1
    cyclesInterger = int(cycles + 0.5)
    cyclesInterger$ = using("#######",cyclesInterger)
    print #FindMinimum.cycles, cyclesInterger$

    Tcalculated = cyclesInterger * period + epoch
    Tcalculated$ = using("#####.####", Tcalculated)
    print #FindMinimum.Tcalc, Tcalculated$

    OC = Tobserved - Tcalculated
    OC$ = using("###.#####", OC)
    print #FindMinimum.OminusC, OC$
return
'
'====================Phase Plot Analysis
'
[FindPeriod]

    NOMAINWIN
    WindowWidth = 320 : WindowHeight = 220
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #FindPeriod, " File " ,  "Exit", [Quit_FindPeriod]

    statictext  #FindPeriod.text1, "start date", 120,25,110,20
    textbox     #FindPeriod.start, 20, 20, 90, 25

    groupbox    #FindPeriod.enter, "enter period", 10,55,292,55
    radiobutton #FindPeriod.day, "day", [setDay], [resetDay], 130,80,40,20
    radiobutton #FindPeriod.hour, "hour", [setHour], [resetHour], 190,80,50,20
    radiobutton #FindPeriod.min,   "min", [setMin], [resetMin], 250,80,50,20
    textbox     #FindPeriod.period, 20, 75, 90, 25

    button      #FindPeriod, "Update", [UpdateFindPeriod], UL 110, 125,80,30

    Open "Phase Plot Analysis" for Window as #FindPeriod
        #FindPeriod "trapclose [Quit_FindPeriod]"
        #FindPeriod "font courier_new 8 16"
        print #FindPeriod.day, "set"
        DayHourMin = 1
        FindPeriodFlag = 1

        print #FindPeriod.start, StartJ2000$ 
    wait
                                                'set units for period, all calculations done in days
    [setDay]
        DayHourMin = 1
    wait

    [setHour]
        DayHourMin = 24
    wait

    [setMin]
        DayHourMin = 1440
    wait

    [resetDay]
    [resetHour]
    [resetMin]
    wait

    [UpdateFindPeriod]
        print #FindPeriod.start, StartJ2000$ 
        print #FindPeriod.start, "!contents? StartTime$"
        print #FindPeriod.period, "!contents? EnterPeriod$"

        StartTime = val(StartTime$)
        EnterPeriod = val(EnterPeriod$)

        if EnterPeriod = 0 then
            notice "enter valid period"
            wait
        end if

        EnterPeriod = EnterPeriod/DayHourMin

        gosub [DrawDataPeriod]
    wait

    [Quit_FindPeriod]
        close #FindPeriod
        FindPeriodFlag = 0
wait
'
'====================Phase Plot Analysis subroutines
'
    [DrawDataPeriod]
        open "IREX.txt" for append as #IREX
        print #IREX, "output from [DrawDataPeriod]"
        print #IREX, " "

        print #show.graphicbox1, "delsegment ";DrawDataSegment
        print #show.graphicbox1, "redraw"
        print #show.graphicbox1, "color darkgreen"
        print #show.graphicbox1, "backcolor darkgreen"

        if PlotFlag = 1 then                'draw plot for variable star data

            PixelTime = 10/TimeScaleJ2000
            PixelMag = 25/MagScale

            print #IREX,"PixelTime ";PixelTime
            print #IREX,"PixelMag  ";PixelMag
            print #IREX," "
            print #IREX, "VarIndex  ";"VarMagDiff  ";"   yD     ";"VarTimeDiff ";"   xD   ";"    VarError"

            for VarIndex = 1 to VarIndexMax

                VarMagDiff = val(VarItem$(VarIndex,8)) - VarMagMax
                yD = VarMagDiff * PixelMag + 20

                VarError = val(VarItem$(VarIndex,9))

                VarTimeDiff = val(VarItem$(VarIndex,7)) - StartTime

                VarTimePhase = (VarTimeDiff/EnterPeriod) MOD 1

                xD = VarTimePhase * EnterPeriod * PixelTime + 40

                print #IREX, using("###",VarIndex)+"     "+_
                             using("#####.##",VarMagDiff)+"      "+_
                             using("####.##",yD)+"  "+_
                             using("#####.####",VarTimeDiff)+"  "+_
                             using("######.###",xD)+"  "+_
                             using("####.###",VarError)

                if xD >= 40  then
                    print #show.graphicbox1, "place ";xD;" ";yD
                    print #show.graphicbox1, "circlefilled 2"
                end if

                if PlotErrorFlag = 1 then
                    VarErrorReduced = VarError * PixelMag * 0.5
                    yEup = yD + VarErrorReduced
                    yEdown = yD - VarErrorReduced
                    print #show.graphicbox1, "line ";xD;" ";yEdown;" ";xD;" ";yEup
                end if
            next
                                                'print vertical line showing end of period
            Xmin = EnterPeriod * PixelTime + 40
            print #show.graphicbox1, "line ";Xmin;" 20 ";Xmin;" 520"

            print #show.graphicbox1, "line 40 490 ";Xmin;" 490"

            for I = 1 to 10
                X = int(EnterPeriod * PixelTime/10) * I + 40
                print #show.graphicbox1, "line ";X;" 490 ";X;" 480"
            next
            X = int(EnterPeriod * PixelTime/10) * 5 + 40
            print #show.graphicbox1, "line ";X;" 490 ";X;" 470"

            print #show.graphicbox1, "color black"
            print #show.graphicbox1, "backcolor white"
            print #show.graphicbox1, "font arial 8 12"

            X = int(EnterPeriod * PixelTime/10) * 5 + 25
            print #show.graphicbox1, "place ";X;" 505"
            print #show.graphicbox1, "\ 0.5"

            X = int(EnterPeriod * PixelTime/10) * 10 + 20
            print #show.graphicbox1, "place ";X;" 505"
            print #show.graphicbox1, "\1.0"

            print #show.graphicbox1, "Segment DrawDataSegment"
            print #show.graphicbox1, "flush"
            print #show.graphicbox1, "redraw"

            print #IREX, " "
            close #IREX
        else
            notice "only slow data can be plotted"
        end if
    return
'
'=================Fourier Analysis with PERIOD04
'
[FindFourier]
    NOMAINWIN
    WindowWidth = 320 : WindowHeight = 220
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #FindFourier, " File " ,  "Exit", [Quit_FindFourier]

    groupbox    #FindFourier.file, "create time-string file", 10,15,292,100
    radiobutton #FindFourier.U, "U", [setU], [resetU], 30,40,30,20
    radiobutton #FindFourier.B, "B", [setB], [resetB], 85,40,30,20
    radiobutton #FindFourier.V, "V", [setV], [resetV], 140,40,30,20
    radiobutton #FindFourier.R, "R", [setR], [resetR], 195,40,30,20
    radiobutton #FindFourier.I, "I", [setI], [resetI], 250,40,30,20
    button      #FindFourier.file, "Make File", [MakePeriod04File], UL 80,75,160,30

    button      #FindFourier.run, "Run Period04", [RunPeriod04], UL 80, 125,160,30

    Open "Fourier Analysis" for Window as #FindFourier
        #FindFourier "trapclose [Quit_FindFourier]"
        #FindFourier "font courier_new 8 16"
        print #FindFourier.V, "set"
        FourierColor$ = "V"

        FindFourierFlag = 1
    wait

    [setU]
        FourierColor$ = "U"
    wait

    [setB]
        FourierColor$ = "B"
    wait

    [setV]
        FourierColor$ = "V"
    wait

    [setR]
        FourierColor$ = "R"
    wait

    [setI]
        FourierColor$ = "I"
    wait

    [resetU]
    [resetB]
    [resetV]
    [resetR]
    [resetI]
    wait

    [RunPeriod04]
        run "period04.exe"
    wait

    [MakePeriod04File]
                                            'find which colors are available
        Uflag = 0 : Bflag = 0 : Vflag = 0 : Rflag = 0 : Iflag = 0
        if val(VarItem$(1,8)) <> 0  then
            Vflag = 1
        end if
        if val(VarItem$(1,10)) <> 0  and val(VarItem$(1,12)) <> 0 and Vflag = 1 then
            Uflag = 1
        end if
        if val(VarItem$(1,12)) <> 0 and Vflag = 1 then
            Bflag = 1
        end if
        if val(VarItem$(1,14)) <> 0 and Vflag = 1 then
            Rflag = 1
        end if
        if val(VarItem$(1,16)) <> 0 and Vflag = 1 then
            Iflag = 1
        end if
                                            'select UBVRI color for making datafile
        select case
            case (Vflag = 1) and (FourierColor$ = "V")
                FourierColorIndex = 8
            case (Uflag = 1) and (FourierColor$ = "U")
                FourierColorIndex = 10
            case (Bflag = 1) and (FourierColor$ = "B")
                FourierColorIndex = 12
            case (Rflag = 1) and (FourierColor$ = "R")
                FourierColorIndex = 14
            case (Iflag = 1) and (FourierColor$ = "I")
                FourierColorIndex = 16
            case else
                notice "error - no magnitudes"
                wait
        end select
                                            'make time string array for writing to data file
        for TimeIndex = 1 to VarIndexMax
            TimeString$(TimeIndex,1) = VarItem$(TimeIndex,7)
            select case FourierColorIndex
                case 8
                    TimeString$(TimeIndex,2) = VarItem$(TimeIndex,8)
                case 10
                    TimeString$(TimeIndex,2) = str$(val(VarItem$(TimeIndex,10)) - val(VarItem$(TimeIndex,12)))
                case 12
                    TimeString$(TimeIndex,2) = str$(val(VarItem$(TimeIndex,12)) + val(VarItem$(TimeIndex,8)))
                case 14
                    TimeString$(TimeIndex,2) = str$(val(VarItem$(TimeIndex,8)) - val(VarItem$(TimeIndex,14)))
                case 16
                    TimeString$(TimeIndex,2) = str$(val(VarItem$(TimeIndex,8)) - val(VarItem$(TimeIndex,16)))
            end select
        next

        [TimeString]                        'make data file with .txt type as default
        filedialog "Save Time String data", PathTimeString$, TimeStringFile$

         for I = len(TimeStringFile$) to 1 step -1
             if mid$(TimeStringFile$,I,1) = "\" then
                 ShortTimeString$ = mid$(TimeStringFile$,I+1)
                 PathTimeString$ = left$(TimeStringFile$,I)+"*.txt"
                 exit for
             end if
         next

         if TimeStringFile$ <> "" then

            files "c:\", TimeStringFile$, info$()
            if val(info$(0,0)) <> 0 then
                confirm "Write over existing file?"; Answer$
                if Answer$ = "no" then [TimeString]
            end if

            if (right$(TimeStringFile$,4) = ".txt") OR (right$(TimeStringFile$,4) = ".TXT") then
                open TimeStringFile$ for Output as #TimeStringFile
            else
                TimeStringFile$ = TimeStringFile$+".txt"
                open TimeStringFile$ for Output as #TimeStringFile
            end if

            for TimeIndex = 1 to VarIndexMax
                print #TimeStringFile, TimeString$(TimeIndex,1);"  ";TimeString$(TimeIndex,2)
            next
            close  #TimeStringFile
        else
            wait
        end if

    [Quit_FindFourier]
        close #FindFourier
        FindFourierFlag = 0
wait
'
'=============Period Search with Bob Nelson's Minima
'
[PeriodSearch]
    NOMAINWIN
    WindowWidth = 320 : WindowHeight = 220
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #PeriodSearch, " File " ,  "Exit", [QuitPeriodSearch]

    groupbox    #PeriodSearch.file, "create time-string file", 10,15,292,100
    radiobutton #PeriodSearch.U, "U", [setUU], [resetUU], 30,40,30,20
    radiobutton #PeriodSearch.B, "B", [setBB], [resetBB], 85,40,30,20
    radiobutton #PeriodSearch.V, "V", [setVV], [resetVV], 140,40,30,20
    radiobutton #PeriodSearch.R, "R", [setRR], [resetRR], 195,40,30,20
    radiobutton #PeriodSearch.I, "I", [setII], [resetII], 250,40,30,20
    button      #PeriodSearch.file, "Make File", [MakePeriodSearchFile], UL 80,75,160,30

    button      #PeriodSearch.run, "Run Period Search", [RunPeriodSearch], UL 80, 125,160,30

    Open "Period Search" for Window as #PeriodSearch
        #PeriodSearch "trapclose [QuitPeriodSearch]"
        #PeriodSearch "font courier_new 8 16"
        print #PeriodSearch.V, "set"
        PeriodSearchColor$ = "V"
        PeriodSearchFlag = 1
    wait

    [setUU]
        PeriodSearchColor$ = "U"
    wait

    [setBB]
        PeriodSearchColor$ = "B"
    wait

    [setVV]
        PeriodSearchColor$ = "V"
    wait

    [setRR]
        PeriodSearchColor$ = "R"
    wait

    [setII]
        PeriodSearchColor$ = "I"
    wait

    [resetUU]
    [resetBB]
    [resetVV]
    [resetRR]
    [resetII]
    wait

    [RunPeriodSearch]
        run "P_search15f.exe"
    wait

    [MakePeriodSearchFile]
                                            'find which colors are available
        Uflag = 0 : Bflag = 0 : Vflag = 0 : Rflag = 0 : Iflag = 0
        if val(VarItem$(1,8)) <> 0  then
            Vflag = 1
        end if
        if val(VarItem$(1,10)) <> 0  and val(VarItem$(1,12)) <> 0 and Vflag = 1 then
            Uflag = 1
        end if
        if val(VarItem$(1,12)) <> 0 and Vflag = 1 then
            Bflag = 1
        end if
        if val(VarItem$(1,14)) <> 0 and Vflag = 1 then
            Rflag = 1
        end if
        if val(VarItem$(1,16)) <> 0 and Vflag = 1 then
            Iflag = 1
        end if
                                            'select UBVRI color for making datafile
        select case
            case (Vflag = 1) and (PeriodSearchColor$ = "V")
                PeriodSearchColorIndex = 8
            case (Uflag = 1) and (PeriodSearchColor$ = "U")
                PeriodSearchColorIndex = 10
            case (Bflag = 1) and (PeriodSearchColor$ = "B")
                PeriodSearchColorIndex = 12
            case (Rflag = 1) and (PeriodSearchColor$ = "R")
                PeriodSearchColorIndex = 14
            case (Iflag = 1) and (PeriodSearchColor$ = "I")
                PeriodSearchColorIndex = 16
            case else
                notice "error - no magnitudes"
                wait
        end select
                                            'make time string array for writing to data file
        for TimeIndex = 1 to VarIndexMax
            TimeString$(TimeIndex,1) = VarItem$(TimeIndex,7)
            select case PeriodSearchColorIndex
                case 8
                    TimeString$(TimeIndex,2) = VarItem$(TimeIndex,8)
                case 10
                    TimeString$(TimeIndex,2) = str$(val(VarItem$(TimeIndex,10)) - val(VarItem$(TimeIndex,12)))
                case 12
                    TimeString$(TimeIndex,2) = str$(val(VarItem$(TimeIndex,12)) + val(VarItem$(TimeIndex,8)))
                case 14
                    TimeString$(TimeIndex,2) = str$(val(VarItem$(TimeIndex,8)) - val(VarItem$(TimeIndex,14)))
                case 16
                    TimeString$(TimeIndex,2) = str$(val(VarItem$(TimeIndex,8)) - val(VarItem$(TimeIndex,16)))
            end select
        next

        [PeriodSearchTimeString]                        'make data file with .txt type as default
        filedialog "Save Time String data", PathTimeStringCSV$, TimeStringFile$

         for I = len(TimeStringFile$) to 1 step -1
             if mid$(TimeStringFile$,I,1) = "\" then
                 ShortTimeString$ = mid$(TimeStringFile$,I+1)
                 PathTimeStringCSV$ = left$(TimeStringFile$,I)+"*.csv"
                 exit for
             end if
         next

         if TimeStringFile$ <> "" then

            files "c:\", TimeStringFile$, info$()
            if val(info$(0,0)) <> 0 then
                confirm "Write over existing file?"; Answer$
                if Answer$ = "no" then [PeriodSearchTimeString]
            end if

            if (right$(TimeStringFile$,4) = ".csv") OR (right$(TimeStringFile$,4) = ".CSV") then
                open TimeStringFile$ for Output as #PeriodSearchFile
            else
                TimeStringFile$ = TimeStringFile$+".csv"
                open TimeStringFile$ for Output as #PeriodSearchFile
            end if

            for TimeIndex = 1 to VarIndexMax
                print #PeriodSearchFile, TimeString$(TimeIndex,1);",";TimeString$(TimeIndex,2)
            next
            close  #PeriodSearchFile
        else
            wait
        end if

    [QuitPeriodSearch]
        close #PeriodSearch
        PeriodSearchFlag = 0
wait
'
'=================================Parabolic Curve Fitting to Eclipsing Binary
'
    [FindParabolic]
    PARABOLICFlag = 1
    NOMAINWIN
    WindowWidth = 350 : WindowHeight = 550
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

        Menu       #Parabolic, "File", "Quit", [Quitparabolic]

        statictext #Parabolic.Var,      "Variable Name", 140,27,130,20
        textbox    #Parabolic.var,      10,25,120,22
        statictext #Parabolic.Comp,     "Comparison Name", 140,57,130,20
        textbox    #Parabolic.comp,     10,55,120,22
        statictext #Parabolic.Filter,   "Filter", 140,87,130,20
        textbox    #Parabolic.filter,   10,85,120,22
        statictext #Parabolic.JD,       "Date Protocol", 140,117,130,20
        textbox    #Parabolic.jd,       10,115,120,22

        listbox    #Parabolic.data, TimeSeriesData$(), [ParabolicData], 10,165,315,175

        groupbox   #Parabolic.standarderror.parabolic, "Parabolic Anaylsis", 10,355,320,85
        statictext #Parabolic.Min.parabolic, " ", 15,380,110,20
        textbox    #Parabolic.mim.parabolic, 125,378,100,20
        statictext #Parabolic.Error.parabolic, "error (mag.)", 15,412,80,20
        textbox    #Parabolic.error.parabolic, 125,410,100,20
        button     #Parabolic.finderror.parabolic, "update", [UpdateParabolic], UL, 245,408,70,25


        Open "Parabolic Curve Fit" for Window as #Parabolic
        #Parabolic "trapclose [QuitParabolic]"
        #Parabolic "font ariel 10"

        if PlotFileName$ = ""  then
            notice "open a var data file "
            goto [QuitParabolic]
        end if

        if FilterSystem$ = "1" then
            print #Parabolic.filter, "V"
        else
            print #Parabolic.filter, "r'"
        end if

        VAR$ = VarStar$
        gosub [VAR_ABVR]

        if VarStar$ = "" then
            print #Parabolic.var, PlotFileName$        'print default filename in text box
        else
            print #Parabolic.var, VAR$                 'print star names from file header
            print #Parabolic.comp, CompStar$
        end if

        for VarIndex = 1 to VarIndexMax
            VarItemJD$(VarIndex) = VarItem$(VarIndex,7)
        next

        if JDFlag <> 1 then
            print #Parabolic.jd, "HELIOCENTRIC"
            print #Parabolic.Min.parabolic, "minimum HJD"
        else
            print #Parabolic.jd, "GEOCENTRIC"
            print #Parabolic.Min.parabolic, "minimum  JD"
        end if

        gosub [DisplayTimeSeriesData]

        print #Parabolic.data, "reload"

        wait

        [ParabolicData]
        wait

    [UpdateParabolic]

        open "IREX.txt" for append as #IREX

        redim X(200)
        redim Y(200)

        print #IREX, " "
        print #IREX, "-I-    X(time)     Y(Mag)"
        Imax = 0
        for TimeIndex = 1 to VarIndexMax
            if val(VarItem$(TimeIndex,7)) >= CursorTime.A AND val(VarItem$(TimeIndex,7)) <= CursorTime.B then
                Imax = Imax + 1
                X(Imax) =  val(VarItem$(TimeIndex,7)) - CursorTime.C
                Y(Imax) =  val(VarItem$(TimeIndex,8))
                print #IREX, using("###", Imax)+"  "+using("####.#####",X(Imax))+"   "+using("###.###",Y(Imax))
            end if
        next

        if Imax < 8 then
            notice "set cursors A & B to enclose at least 8 data points"
            goto [QuitUpdateParabolic]
        end if

'****************************************************
'*  Parabolic Least Squares                         *
'* ------------------------------------------------ *
'* Reference: BASIC Scientific Subroutines, Vol. II *
'*   By F.R. Ruckdeschel, BYTE/McGRAWW-HILL, 1981   *
'*   [BIBLI 01].                                    *
'* ------------------------------------------------ *
'number of elements in array = RegIndexMax
    a0 = 1
    a1 = 0
    a2 = 0
    a3 = 0
    a4 = 0
    b0 = 0
    b1 = 0
    b2 = 0

    for I = 1 to Imax
        a1 = a1 + X(I)
        a2 = a2 + X(I) * X(I)
        a3 = a3 + X(I) * X(I) * X(I)
        a4 = a4 + X(I) * X(I) * X(I) *X(I)
        b0 = b0 + Y(I)
        b1 = b1 + Y(I) * X(I)
        b2 = b2 + Y(I) * X(I) * X(I)
    next I

    a1 = a1/Imax
    a2 = a2/Imax
    a3 = a3/Imax
    a4 = a4/Imax
    b0 = b0/Imax
    b1 = b1/Imax
    b2 = b2/Imax

    d = a0 * (a2 * a4 - a3 * a3) - a1 * (a1 * a4 - a2 * a3) + a2 * (a1 * a3 - a2 * a2)
    a = b0 * (a2 * a4 - a3 * a3) + b1 * (a2 * a3 - a1 * a4) + b2 * (a1 * a3 - a2 * a2)
    a = a / d
    b = b0 * (a2 * a3 - a1 * a4) + b1 * (a0 * a4 - a2 * a2) + b2 * (a1 * a2 - a0 * a3)
    b = b / d
    c = b0 * (a1 * a3 - a2 * a2) + b1 * (a2 * a1 - a0 * a3) + b2 * (a0 * a2 - a1 * a1)
    c = c / d

    'Evaluation of standard deviation d
    d = 0
    for I = 1 to Imax
        d1 = Y(I) - a - b * X(I) - c * X(I) * X(I)
        d  = d + d1 * d1
    next I

    std.error.parabolic = sqr(d/(Imax - 3))

    print #IREX, " "
    print #IREX, "Coefficients Y = a + bX + cX^2 and standard error"
    print #IREX, "       a           b            c         std.error.parabolic"
    print #IREX, using("####.#####",a)+"   "+using("####.#####",b)+"   "+using("####.#####",c)+"       "+using("####.#####",std.error.parabolic)

    std.error.parabolic$ = using("##.####", std.error.parabolic)
    print #Parabolic.error.parabolic, std.error.parabolic$

    min.parabolic =  CursorTime.C - b/(2*c)
    min.parabolic$ = using("#####.#####", min.parabolic)
    print #Parabolic.mim.parabolic, min.parabolic$
    print #IREX, " "
    print #IREX, "min.parabolic HJD = "+min.parabolic$

    ETDerror$ = ""
    gosub [DisplayTimeSeriesData]
    print #Parabolic.data, "reload"

    ParabolicTimeDif = CursorTime.B - CursorTime.A
    DeltaTime = ParabolicTimeDif/200

    print #show.graphicbox1, "delsegment ";DrawParabolicSegment
    print #show.graphicbox1, "redraw"

    print #show.graphicbox1, "font arial 6 12"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor black"

    For I = 0 to 200
        X = (CursorTime.A + I * DeltaTime) - min.parabolic
        yD = ((a + b * X + c * X^2) - MagScaleArray(0)) * PixelMag + 20
        xD = (X + min.parabolic - val(StartJ2000$)) * PixelTime + 40

        print #show.graphicbox1, "place ";xD;" ";yD
        print #show.graphicbox1, "circlefilled 1"
    next I

    print #show.graphicbox1, "Segment DrawParabolicSegment"
    print #show.graphicbox1, "flush"
    print #show.graphicbox1, "color black"
    print #show.graphicbox1, "backcolor white"

    [QuitUpdateParabolic]
        close #IREX
    wait

    [QuitParabolic]
        close #Parabolic
        PARABOLICFlag = 0
    wait
END


