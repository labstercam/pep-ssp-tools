'                        Reduction Module - U, B, V, R, & I Photometry
'                                              Optec, Inc.
'
'======version history
'
'V2.61, November 2018
'    fixed Sloan errors
'
'V2.59, May 2018
'    corrrected processing error when doing different COMP stars with different mixes of magnitudes and epsilons
'    added error trapping
'
'V2.58, November 2016
'    fixed missing OBSCODE
'
'V2.57, September 2016
'    added only V filter option for continuous readings
'
'V2.56, All Sky for B and V
'    PPParms3
'
'V2.54, November 2015
'    corrected error in calender date reporting Helio instead of Geocentic
'
'V2.53, September, 2015
'    fixed display of version number
'
'V2.52, September 2015
'    compiled with LB 4.50
'    increased DIM
'
'V2.51, April, 2015
'    fixed bug in save imtermediate data
'
'V2.50, October, 2014
'    added sloan magnitudes
'
'V2.44, January 20, 2014
'     changed size of listbox in View VAR/COMP/CHECK window
'
'V2.43, January, 2014
'     fixed reduction in [Reduction_Table_Step3VI] - change CompVR to CompVI
'
'V2.42, October, 2013
'    added check star
'    added comp\var\check star database window
'
'V2.41, September 29, 2013
'    expanded IREX logging
'
'V2.40, September, 2013
'    added heliocentric JD
'
'V2.33, August, 2013
'    fixed problem in V-I reduction module
'
'V2.32, July 2013
'    fixed clearing of old file data when new opening a new file
'
'V2.31, May 2013
'    improved save data file routines
'    fixed standard error calculation
'
'V2.30, March 2013
'    fixed error in computing DEC
'
'V2.21, April, 2010
'   changed save data so that indicies are on the same line as V magnitude
'   fixed major errors in v-r and u-b calculations
'
'V2.20, January, 2010
'   added improved file handling - remembers previously opened folder
'   changed help file to chm type
'   added graphicbox printing
'   compiled with Liberty Basic 4.03
'
'V2.00, October, 2007
'   added U,R and I filters
'
'V1.03, July 1, 2006 - Reduction_18.bas
'   fixed problem with date-to-Julian conversion with January and February
'   compiles with Liberty Basic 4.02
'
'V1.02, November 1, 2005 - Reduction_17.bas
'   compiled with Liberty Basic 4.02
'
'V1.01, October 30, 2005
'   fixed variable name error in [Reduction_Table_Step3]
'   compiled with Liberty Basic 4.01, the token file is used as a patch for SSPDATAQ version 1.11
'
'V1.00
'
'=====dimension statements and initial conditions
'
    DIM info$(10,10)
    files "c:\", info$()

    DIM ReducData$(2000)                 'reduction data lines for list box table, index = ReducIndex
        ReducData$(1) = "open raw data file first and select comp and variable star"

    DIM ReducStar$(2000)                 'comp or variable star name
    DIM ReducType$(2000)                 'C or V
    DIM ReducJD(2000)                    'Julean date of observation, epoch 2000
    DIM ReducCount(2000)                 'net count, average of (star - sky)

    DIM ReducDelta.u(2000)               'differential u instrument magnitude
    DIM ReducDelta.b(2000)               'differential b instrument magnitude
    DIM ReducDelta.v(2000)               'differential v instrument magnitude
    DIM ReducDelta.r(2000)               'differential r instrument magnitude
    DIM ReducDelta.i(2000)               'differential i instrument magnitude

    DIM ReducDelta.uo(2000)              'differential uo instrument magnitude
    DIM ReducDelta.bo(2000)              'differential bo instrument magnitude
    DIM ReducDelta.vo(2000)              'differential vo instrument magnitude
    DIM ReducDelta.ro(2000)              'differential ro instrument magnitude
    DIM ReducDelta.io(2000)              'differential io instrument magnitude

    DIM ReducDelta.V(2000)               'differential V standard magnitude, equation 2.48
    DIM ReducDelta.UB(2000)              'differential U-B standard magnitude, equation 2.50
    DIM ReducDelta.BV(2000)              'differential B-V standard magnitude, equation 2.49
    DIM ReducDelta.VR(2000)              'differential V-R standard magnitude
    DIM ReducDelta.VI(2000)              'differential V-I standard magnitude

    DIM ReducV(2000)                     'standard V magnitude, equation 2.51
    DIM ReducUB(2000)                    'standard U-B index, equation 2.53
    DIM ReducBV(2000)                    'standard B-V index, equation 2.52
    DIM ReducVR(2000)                    'standard V-R index
    DIM ReducVI(2000)                    'standard V-I index

    DIM ReducX(2000)                     'air mass for comp or variable
    DIM ReducFilter$(2000)               'filter, U, B, V, R or I

    DIM CompStar$(400)                   'list of comparison C stars, index = CompIndex
        CompStar$(1) = "   "
    DIM VarStar$(400)                    'list of variable V stars, index - VarIndex
        VarStar$(1) = "   "

    DIM StarData$(400)                   'Comp/Variable/Check star data
        StarData$(1) = "open RAW data file first"

'======arrays used in Star Data file reduction

    DIM SDitem$(2000,13)                'individual data items from Star Data file
                                        'SDitem$(DataIndex,1)  = comp or variable star name
                                        'SDitem$(DataIndex,2)  = type, either C or V
                                        'SDitem$(DataIndex,3)  = RA hour
                                        'SDitem$(DataIndex,4)  = RA minute
                                        'SDitem$(DataIndex,5)  = RA second
                                        'SDitem$(DataIndex,6)  = DEC degree
                                        'SDitem$(DataIndex,7)  = DEC minute
                                        'SDitem$(DataIndex,8)  = DEC second
                                        'SDitem$(DataIndex,9)  = V magnitude
                                        'SDitem$(DataIndex,10) = B-V color index
                                        'SDitem$(DataIndex,11) = U-B color index
                                        'SDitem$(DataIndex,12) = V-R color index
                                        'SDitem$(DataIndex,13) = V-I color index

'=======arrays used in raw file reduction

    DIM RawData$(2000)                  'data from raw file of observations

    DIM RDitem$(2000,15)                'individual data items from raw file of observations
                                        'RDitem$(RawIndex,1)  = UT month
                                        'RDitem$(RawIndex,2)  = UT day
                                        'RDitem$(RawIndex,3)  = UT year
                                        'RDitem$(RawIndex,4)  = UT hour
                                        'RDitem$(RawIndex,5)  = UT minute
                                        'RDitem$(RawIndex,6)  = UT second
                                        'RDitem$(RawIndex,7)  = catalog type, C, V, SKY, SKYLAST or SKYNEXT
                                        'RDitem$(RawIndex,8)  = star name, 8 bytes
                                        'RDitem$(RawIndex,9)  = filter, U, B, V, R or I
                                        'RDitem$(RawIndex,10) = count 1
                                        'RDitem$(RawIndex,11) = count 2
                                        'RDitem$(RawIndex,12) = count 3
                                        'RDitem$(RawIndex,13) = count 4
                                        'RDitem$(RawIndex,14) = integration time, 1 or 10 seconds
                                        'RDitem$(RawIndex,15) = scale factor, 1, 10 or 100

    DIM CountFinal(2000)                'average count including integration and scale, index var = RawIndex
    DIM JD(2000)                        'Julean date from 2000, index var = RawIndex
    DIM JT(2000)                        'Julean century from 2000, index var = RawIndex
    DIM X(2000)                         'air mass, index var = RawIndex
'
'=====initialize and start up values
'
VersionNumber$ = "2.61  "
PathDataFile$ = "*.raw"                             'default path for data files
PathSaveData$ = "*.var"                             'default path for var saved data file
ChoiceFlag = 0                                      'default value to indicate that choice window is closed
SaveDataFlag = 0                                    'default value to indicate that SaveData window is closed
BdataFlag = 0                                       'flag to determine if there is B data so that eps or epsR
                                                    '    error messages are accurate, 0 no B data
FilterSystem$ = "1"                                 'default filter system Johnson/Cousins
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

gosub [Find_Lat_Long]

            open "IREX.txt" for output as #IREX
                print #IREX, "Reduction Module, Version "; VersionNumber$
                print #IREX, "PPparms3"
                print #IREX, "  Location      "; Location$
                print #IREX, "  KU            "; KU
                print #IREX, "  KB            "; KB
                print #IREX, "  KV            "; KV
                print #IREX, "  KR            "; KR
                print #IREX, "  KI            "; KI
                print #IREX, "  KKbv          "; KKbv
                print #IREX, "  Eps           "; Eps
                print #IREX, "  Psi           "; Psi
                print #IREX, "  Mu            "; Mu
                print #IREX, "  Tau           "; Tau
                print #IREX, "  Eta           "; Eta
                print #IREX, "  EpsR          "; EpsR
                print #IREX, "  EpsilonFlag   "; EpsilonFlag
                print #IREX, "  JDFlag        "; JDFlag
                print #IREX, "  OBSCODE       "; OBSCODE$
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
                print #IREX, " "
            close #IREX
'
'=====set up main GUI control window
'
[WindowSetup]
    NOMAINWIN
    WindowWidth = 1024 : WindowHeight = 465
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

[ControlSetup]
    Menu        #reduc, "File", "Open File", [Open_File],_
                                "Save Data to Variable Star File", [Save_Data],_
                                "Quit", [Quit_Reduc]
    Menu        #reduc, "Information", "View Extinction and Transformation Coefficients", [View_Coefficients],_
                                       "Comp/Variable/Check Star Database", [View_StarDatabase]
    Menu        #reduc, "Help", "About", [About], "Help", [Help]

    groupbox    #reduc.groupbox1, "Raw Data File", 11, 310, 200, 90
    groupbox    #reduc.groupbox2, "Comparison  -   Variable/Check", 215, 310, 290, 90
    groupbox    #reduc.groupbox4, "Process", 510, 310, 75, 90
    groupbox    #reduc.groupbox3, "Mean Standard Magnitude and Date", 590, 310, 415, 90

    statictext  #reduc.statictext1,  "star", 30, 20, 40, 14
    statictext  #reduc.statictext2, "type", 130, 20, 40, 14
    statictext  #reduc.statictext3, "JD", 210, 7, 30, 14
    statictext  #reduc.statictext4,  "J2000.0", 186, 20, 170, 14
    statictext  #reduc.statictext5,  "net", 285, 7, 30, 14
    statictext  #reduc.statictext6, "count", 275, 20, 60, 14
    statictext  #reduc.statictext7, "F", 340, 20, 10, 14
    statictext  #reduc.statictext8,  chr$(68), 380, 20, 10, 14
    statictext  #reduc.statictext9,  "u", 390, 20, 10, 14
    statictext  #reduc.statictext10,  chr$(68), 444, 20, 10, 14
    statictext  #reduc.statictext11,  "b", 454, 20, 10, 14
    statictext  #reduc.statictext12,  chr$(68), 507, 20, 10, 14
    statictext  #reduc.statictext13,  "v", 517, 20, 10, 14
    statictext  #reduc.statictext14, chr$(68), 575, 20, 10, 14
    statictext  #reduc.statictext15, "r", 585, 20, 10, 14
    statictext  #reduc.statictext16, chr$(68), 635, 20, 10, 14
    statictext  #reduc.statictext17, "i", 645, 20, 10, 14
    statictext  #reduc.statictext18, "V", 700, 20, 70, 14
    statictext  #reduc.statictext19, "B-V", 755, 20, 70, 14
    statictext  #reduc.statictext20, "U-B", 817, 20, 70, 14
    statictext  #reduc.statictext21, "V-R", 879, 20, 70, 14
    statictext  #reduc.statictext22, "V-I", 941, 20, 70, 14

    statictext  #reduc.statictext30, " V", 633, 342, 20, 14
    statictext  #reduc.statictext31, "  B-V", 607, 357, 50, 14
    statictext  #reduc.statictext32, "J2000", 607, 372, 50, 14
    statictext  #reduc.statictext33, "  U-B", 807, 342, 50, 14
    statictext  #reduc.statictext34, "  V-R", 807, 357, 50, 14
    statictext  #reduc.statictext35, "  V-I", 807, 372, 50, 14

    button      #reduc.Start, "Start", [Start_Reduction],UL,523,350

    textbox     #reduc.Analysis, 660, 338, 135, 50
    textbox     #reduc.Analysis2, 860, 338, 135, 50

    textbox     #reduc.FileName, 15, 350, 190, 25

    listbox     #reduc.Table, ReducData$(),[Reduction_Table.click], 10, 40, 995, 265

    combobox    #reduc.Comp,CompStar$(),[Select_Comp.click], 220, 350, 135, 300
    combobox    #reduc.Variable,VarStar$(),[Select_Var.click],360, 350, 140, 300

    Open "Data Reduction -  Johnson/Cousins/Sloan Photometry" for Window as #reduc
    #reduc "trapclose [Quit_Reduc]"
    #reduc.Table "selectindex 1"
    #reduc.Comp "selectindex 1"
    #reduc "font courier_new 10 14"

    print #reduc.statictext8,  "!font symbol 10 14"
    print #reduc.statictext10, "!font symbol 10 14"
    print #reduc.statictext12, "!font symbol 10 14"
    print #reduc.statictext14, "!font symbol 10 14"
    print #reduc.statictext16, "!font symbol 10 14"

    print #reduc.FileName, "open raw data file"

    StartVar.Flag = 0               'turn off START button until data and stars are loaded
    StartComp.Flag = 0
    print #reduc.Start, "!Disable"

Wait                                'finished setting up, wait here for new command
'
[errorHandler]
    print #IREX, " "
    print #IREX, "error code = "; Err
    print #IREX, " "
    close #IREX
    SELECT CASE Err
        CASE 11
            NOTICE "divide by zero error"
            print #reduc.Start, "Start"
        CASE else
            NOTICE "Error Code = "+Err$
    END SELECT
Wait
'
'======menu controls
'
[Open_File]
    UdataFlag = 0                                   'no U data yet
    BdataFlag = 0                                   'no B data yet
    RdataFlag = 0                                   'no R data yet
    IdataFlag = 0                                   'no I data yet
    CompFlag = 0                                    'no Comp star yet
    VarFlag = 0                                     'no Var star yet

    filedialog "Open Data File", PathDataFile$, DataFile$

    for I = len(DataFile$) to 1 step -1             'remember path for opened folder and file
        if mid$(DataFile$,I,1) = "\" then
            ShortDataFile$ = mid$(DataFile$,I+1)
            PathDataFile$ = left$(DataFile$,I)+"*raw"
            exit for
        end if
    next I

    if DataFile$ = "" then
        print #reduc.FileName, "open raw data file"
    else
        files "c:\", DataFile$, info$()
        if val(info$(0, 0)) = 0 then
            notice "cannot create new file"
        else
                                                    'clear the contents of the comparison & variable comboboxes & previous reduction data
            redim CompStar$(400)                    'list of comparison C stars, index = CompIndex
                  CompStar$(1) = "   "
            redim VarStar$(400)                     'list of variable V stars, index - VarIndex
                  VarStar$(1) = "   "
            redim ReducV(2000)                      'standard V magnitude
            redim ReducUB(2000)                     'standard U-B index
            redim ReducBV(2000)                     'standard B-V index
            redim ReducVR(2000)                     'standard V-R index
            redim ReducVI(2000)                     'standard V-I index
            ReducV.average = 0
            ReducUB.average = 0
            ReducBV.average = 0
            ReducVR.average = 0
            ReducVI.average = 0
            ReducV.std.deviation = 0
            ReducUB.std.deviation = 0
            ReducBV.std.deviation = 0
            ReducVR.std.deviation = 0
            ReducVI.std.deviation = 0
                                                    'clear reduction table
            redim ReducData$(2000)
            ReducData$(1) = "select comp and variable star"
            print #reduc.Table, "reload"
                                                    'clear the Comp & Var input boxes
            print #reduc.Comp, "reload"
            print #reduc.Comp, "selectindex 1"
            print #reduc.Variable, "reload"
            print #reduc.Variable, "selectindex 1"
                                                    'clear analysis results boxes
            print #reduc.Analysis, ""
            print #reduc.Analysis2, ""

            StartVar.Flag = 0                       'turn off START button until data and stars are loaded
            StartComp.Flag = 0
            print #reduc.Start, "!Disable"
                                                    'input the contents of the file
            open DataFile$ for input as #RawFile
            for RawIndex = 1 to 4                   'read first 4 descriptive lines with line input to capture commas
                line input #RawFile, RawData$(RawIndex)
            next RawIndex
            RawIndex = 4
            while eof(#RawFile)=0                   'read rest of the data to end of file
                RawIndex = RawIndex + 1
                input #RawFile, RawData$(RawIndex)
            wend
            RawIndexMax = RawIndex
            close #RawFile

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Find_File_Name]"
                gosub [Find_File_Name]
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Convert_RawFile]"
                print #IREX, "M - D - Year  H - M - S  CAT Object        F"+_
                             "    C1     C2     C3     C4    S   I"
                gosub [Convert_RawFile]
                print #IREX, " "
            close #IREX

            gosub [Open_Star_Data]

            gosub [Write_Window_Labels]

            gosub [Total_Count_RawFile]
            gosub [Julian_Day_RawFile]

            CompIndexMax = 1                     'reset array index to 1 for Comp Star list
            VarIndexMax = 1                      'reset array index to 1 for Variable Star list

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [IREX_RawFile]"
                print #IREX, "star         Julean date   net count  filter SkyPast   Sky Future,"

                if FilterSystem$ = "1" then
                    Filter$ = "U"
                    gosub [IREX_RawFile]
                    Filter$ = "B"
                    gosub [IREX_RawFile]
                    Filter$ = "V"
                    gosub [IREX_RawFile]
                    Filter$ = "R"
                    gosub [IREX_RawFile]
                    Filter$ = "I"
                    gosub [IREX_RawFile]
                    print #IREX, " "
                else
                    Filter$ = "u"
                    gosub [IREX_RawFile]
                    Filter$ = "g"
                    gosub [IREX_RawFile]
                    Filter$ = "r"
                    gosub [IREX_RawFile]
                    Filter$ = "i"
                    gosub [IREX_RawFile]
                    Filter$ = "z"
                    gosub [IREX_RawFile]
                    print #IREX, " "
                end if
            close #IREX
            print #reduc.Variable, "reload"
            print #reduc.Comp, "reload"

            gosub [Make_CompVarCheck_List]

        end if
    end if
Wait

[Save_Data]
'--------------open file dialog for saving *.var reduced data file
 '   if (ReducV.average = 0) AND (ReducBV.average = 0) then
  '      notice "nothing to save"
 '       wait
 '   end if
    filedialog "Open Variable Data File", PathSaveData$, SaveData$

    for I = len(SaveData$) to 1 step -1             'remember path for opened folder and file
        if mid$(SaveData$,I,1) = "\" then
            ShortSaveData$ = mid$(SaveData$,I+1)
            PathSaveData$ = left$(SaveData$,I)+"*.var"
            exit for
        end if
    next I

    files "c:\", SaveData$, info$()
    if SaveData$ <> "" then
        if val(info$(0,0)) = 0  then
            confirm "Create new data file?"; Answer$
            if Answer$ = "yes" then
                if (right$(SaveData$,4) = ".var") OR (right$(SaveData$,4) = ".VAR") then
                    open SaveData$ for output as #SaveData
                else
                    SaveData$ = SaveData$+".var"
                    open SaveData$ for output as #SaveData
                end if
                                                    'print header to var file
                                                    'FileHeaderFlag = "#"
                                                    'FilterSystem$  0 = Sloan, 1 = Johnson/Cousins
                                                    'JDFlag         0 = HJD,   1 = JD
                                                    'Comp star name
                                                    'variable star name
                print #SaveData$, "#,"+FilterSystem$+","+str$(JDFlag)+","+trim$(selectedComp$)+","+trim$(selectedVar$)

            else
                Wait
            end if
        else
            confirm "Append data to "+ShortSaveData$+"?"; Answer$
            if Answer$ = "yes" then
                open SaveData$ for append as #SaveData
            else
                Wait
            end if
        end if

        SaveDataFlag = 1                            'save date file window is opened

'-------------open window to select saving mean or itermediate results
        NOMAINWIN
        WindowWidth = 220 : WindowHeight = 150
        UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
        UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

        radiobutton #choice.mean, "save mean magnitude values", [setMean], [resetMean], 10,10,170,20
        radiobutton #choice.intermediate, "save intermediate values", [setInt], [resetIng], 10,35,170,20
        button #choice.continue, "continue", [ContinueSave], UL, 80,85,55,25
        button #choice.cancel, "cancel", [QuitChoice], UL, 150,85,55,25

        open "Save Options" for window as #choice
        #choice "trapclose [QuitChoice]"
        ChoiceFlag = 1

        if ReducV.average <> 0 then
            print #choice.mean, "set"
            Choice$ = "mean"
        else
            print #choice.intermediate, "set"
            Choice$ = "intermediate"
        end if
        wait

        [setMean]
            Choice$ = "mean"
        wait

        [setInt]
            Choice$ = "intermediate"
        wait

        [resetMean]
        [resetInt]
        wait
'--------------save reduced data to *.var file
        [ContinueSave]
        Select Case Choice$
        Case "mean"              'save mean magnitude index and J2000 date
            print #SaveData,JDtoCAL$(GeocentricJD.Mean)+" "+_
                            using("####.####",J2000.Mean)+" "+_
                            using("###.###",ReducV.average)+" "+using("#.###",ReducV.std.deviation)+" "+_
                            using("###.###",ReducUB.average)+" "+using("#.###",ReducUB.std.deviation)+" "+_
                            using("###.###",ReducBV.average)+" "+using("#.###",ReducBV.std.deviation)+" "+_
                            using("###.###",ReducVR.average)+" "+using("#.###",ReducVR.std.deviation)+" "+_
                            using("###.###",ReducVI.average)+" "+using("#.###",ReducVI.std.deviation)

        Case "intermediate"      'save individual V and index values with dates
            PrintFlag = 0
            SaveUB = 0
            SaveBV = 0
            SaveVR = 0
            SaveVI = 0
            for ReducIndex = 1 to ReducIndexMax
                if ReducType$(ReducIndex) = "V" then
                    PrintFlag = 1
                    Select Case ReducFilter$(ReducIndex)
                        Case "V","r"
                            SaveV = ReducV(ReducIndex)
                            SaveDateCAL$ = JDtoCAL$(ReducJD(ReducIndex))
                            SaveDateJD = ReducJD(ReducIndex)
                        Case "U"
                            SaveUB = ReducUB(ReducIndex)
                                                     'check to see of value is zero and change to +/-0.001 if it is
                            TestValue = SaveUB
                            gosub [TestZero]
                            SaveUB = TestValue
                        Case "B"
                            SaveBV = ReducBV(ReducIndex)
                                                     'check to see of value is zero and change to +/-0.001 if it is
                            TestValue = SaveBV
                            gosub [TestZero]
                            SaveBV = TestValue
                        Case "R"
                            SaveVR = ReducVR(ReducIndex)
                                                     'check to see of value is zero and change to +/-0.001 if it is
                            TestValue = SaveVR
                            gosub [TestZero]
                            SaveVR = TestValue
                        Case "I"
                            SaveVI = ReducVI(ReducIndex)
                                                     'check to see of value is zero and change to +/-0.001 if it is
                            TestValue = SaveVI
                            gosub [TestZero]
                            SaveVI = TestValue
                    End Select
                else
                    if PrintFlag = 1 then
                                                    'convert Juliean Date to HJD if JDFlag = 0
                        if JDFlag = 0 then
                            JDtemporary = SaveDateJD
                            gosub [JDtoHJD]
                            SaveDateJD = JDtemporary
                        end if

                        print #SaveData,SaveDateCAL$+" "+_
                            using("####.####",SaveDateJD)+" "+_
                            using("###.###",SaveV)+" "+using("#.###",0)+" "+_
                            using("###.###",SaveUB)+" "+using("#.###",0)+" "+_
                            using("###.###",SaveBV)+" "+using("#.###",0)+" "+_
                            using("###.###",SaveVR)+" "+using("#.###",0)+" "+_
                            using("###.###",SaveVI)+" "+using("#.###",0)
                        PrintFlag = 0
                    end if
                end if
            next
        End Select
    end if

    [QuitChoice]
    if ChoiceFlag = 1 then
        close #choice
        ChoiceFlag = 0
    end if
    if SaveDataFlag = 1 then
        close #SaveData
        SaveDataFlag = 0
    end if
Wait
'
'=====Information Windows beginning
'
[View_Coefficients]
    if CoeffFlag = 1 then
        notice "View Coefficients Window already opened"
        wait
    end if

    FilterSystemTemp$ = FilterSystem$

    NOMAINWIN
    WindowWidth = 495 : WindowHeight = 520

    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

    Menu        #coeff, "File", "Use but do not save coefficients", [Use_Coefficients],_
                        "Save and use coefficients", [Save_Coefficients],_
                        "Quit", [Quit_Coefficients]
    Menu        #coeff, "System", "Johnson/Cousins", [Select_JohnsonCousins],_
                        "Sloan", [Select_Sloan]

    statictext  #coeff.static1,  "K'",  40,  42, 15, 20
    statictext  #coeff.static2,  "u",   55,  47, 10, 20
    statictext  #coeff.static3,  "K'",  40,  77, 15, 20
    statictext  #coeff.static4,  "b",   55,  82, 10, 20
    statictext  #coeff.static5,  "K'",  40, 112, 15, 20
    statictext  #coeff.static6,  "v",   55, 117, 10, 20
    statictext  #coeff.static7,  "K'",  40, 147, 15, 20
    statictext  #coeff.static8,  "r",   55, 152, 10, 20
    statictext  #coeff.static9,  "K'",  40, 182, 15, 20
    statictext  #coeff.static10, "i",   55, 187, 10, 20
    statictext  #coeff.static11, "K''", 40, 217, 22, 20
    statictext  #coeff.static12, "bv",  61, 222, 20, 20
    statictext  #coeff.static13, "e",   45, 247, 13, 20
    statictext  #coeff.static14, "e",   45, 282, 13, 20
    statictext  #coeff.static15, "r",   58, 293, 10, 20
    statictext  #coeff.static16, "m",   45, 317, 15, 20
    statictext  #coeff.static17, "y",   45, 352, 15, 20
    statictext  #coeff.static18, "t",   45, 387, 14, 19
    statictext  #coeff.static19, "h",   45, 422, 14, 20
    statictext  #coeff.static24, "j",   57, 258, 10, 20
    statictext  #coeff.static25, "j",   66, 293, 10, 20
    statictext  #coeff.static26, "j",   60, 328, 10, 20
    statictext  #coeff.static27, "j",   62, 363, 10, 20
    statictext  #coeff.static28, "c",   57, 398, 10, 20
    statictext  #coeff.static29, "c",   58, 433, 10, 20

    groupbox    #coeff.groupbox1, "Select date protocol", 200, 35, 265, 80
    checkbox    #coeff.JD, "JD, Julian Date",       [setJD], [resetJD], 220, 60, 150, 25
    checkbox    #coeff.HJD, "HJD, Heliocentric JD", [setHJD], [resetHJD], 220, 80, 150, 25

    groupbox    #coeff.groupbox2, "Select epsilon for V magnitude", 200, 130, 265, 80
    checkbox    #coeff.epsilonBV, "Epsilon from",   [setEpsilonBV], [resetEpsilonBV], 220, 155, 90, 25
    checkbox    #coeff.epsilonVR, "Epsilon from",   [setEpsilonVR], [resetEpsilonVR], 220, 175, 90, 25
    statictext  #coeff.static30,  "B-V", 315, 159, 50, 25
    statictext  #coeff.static31,  "V-R", 315, 179, 50, 25

    groupbox    #coeff.groupbox3, "Zero point constants (All Sky)", 200,225,265,140
    statictext  #coeff.static34, "Z",  210, 255, 10, 20
    statictext  #coeff.static37, "v",  220, 260, 10, 20
    statictext  #coeff.static35, "Z",  210, 325, 10, 20
    statictext  #coeff.static38, "bv", 220, 330, 20, 20
    textbox     #coeff.Zv,       245, 250, 75, 25
    textbox     #coeff.Zbv,      245, 320, 75, 25
    statictext  #coeff.static40, "s", 345, 250, 10, 16
    statictext  #coeff.static41, "v", 356, 258, 10, 16
    statictext  #coeff.static42, "s", 345, 320, 10, 16
    statictext  #coeff.static43, "bv", 356, 328, 20, 16
    textbox     #coeff.Ev,       380, 250, 75, 25
    textbox     #coeff.Ebv,      380, 320, 75, 25

    textbox     #coeff.KU,        90,  40, 75, 25
    textbox     #coeff.KB,        90,  75, 75, 25
    textbox     #coeff.KV,        90, 110, 75, 25
    textbox     #coeff.KR,        90, 145, 75, 25
    textbox     #coeff.KI,        90, 180, 75, 25
    textbox     #coeff.KKBV,      90, 215, 75, 25
    textbox     #coeff.epsilon,   90, 250, 75, 25
    textbox     #coeff.epsilonR,  90, 285, 75, 25
    textbox     #coeff.mu,        90, 320, 75, 25
    textbox     #coeff.psi,       90, 355, 75, 25
    textbox     #coeff.tau,       90, 390, 75, 25
    textbox     #coeff.eta,       90, 425, 75, 25

    Open "PPparms3 coefficients" for Window as #coeff
        #coeff "trapclose [Quit_Coefficients]"
        #coeff "font ms_sans_serif 10"
        print #coeff.static13, "!font symbol 14"             'font for printing epsilon
        print #coeff.static14, "!font symbol 14"             'font for printing epsilon
        print #coeff.static16, "!font symbol 14"             'font for printing mu
        print #coeff.static17, "!font symbol 14"             'font for printing psi
        print #coeff.static18, "!font symbol 14"             'font for printing tau
        print #coeff.static19, "!font symbol 14"             'font for printing eta
        print #coeff.static40, "!font symbol 12"
        print #coeff.static42, "!font symbol 12"

        print #coeff.static1,  "!font ms_sans_serif 10 bold"
        print #coeff.static3,  "!font ms_sans_serif 10 bold"
        print #coeff.static5,  "!font ms_sans_serif 10 bold"
        print #coeff.static7,  "!font ms_sans_serif 10 bold"
        print #coeff.static9,  "!font ms_sans_serif 10 bold"
        print #coeff.static11, "!font ms_sans_serif 10 bold"
        print #coeff.static34, "!font ms_sans_serif 10 bold"
        print #coeff.static35, "!font ms_sans_serif 10 bold"

    [Print_Coefficients]
                    'print PPparms coefficients into textboxes
        if FilterSystem$ = "1" then
            print #coeff.KU, using("###.###",KU)            'first order extinction for u: K'u
            print #coeff.KB, using("###.###",KB)            'first order extinction for b: K'b
            print #coeff.KV, using("###.###",KV)            'first order extinction for v: K'v
            print #coeff.KR, using("###.###",KR)            'first order extinction for r: K'r
            print #coeff.KI, using("###.###",KI)            'first order extinction for i: K'i
            print #coeff.KKBV, using("###.###",KKbv)        'second order extinction for b-v: K"bv
            print #coeff.epsilon, using("###.###",Eps)      'transformation coefficient for v: epsilon
            print #coeff.epsilonR, using("###.###",EpsR)    'transformtion coefficient for v: epsilon R
            print #coeff.mu, using("###.###",Mu)            'transformtion coefficient for b-v: mu
            print #coeff.psi, using("###.###",Psi)          'transformtion coefficient for u-b: psi
            print #coeff.tau, using("###.###",Tau)          'transformtion coefficient for v-r: tau
            print #coeff.eta, using("###.###",Eta)          'transformtion coefficient for v-i: eta
            print #coeff.Zv, using("###.###",ZPv)           'zero point constant for v
            print #coeff.Zbv, using("###.###",ZPbv)         'zero point constant for b-v
            print #coeff.Ev, using("###.###",Ev)            'standard error for zero point constant for v
            print #coeff.Ebv, using("###.###",Ebv)          'standard error for zero point constant for b-v

            print #coeff.static4,  "b"
            print #coeff.static6,  "v"
            print #coeff.static8,  "r"
            print #coeff.static10, "i"
            print #coeff.static12, "bv"
            print #coeff.static24, "j"
            print #coeff.static25, "j"
            print #coeff.static26, "j"
            print #coeff.static27, "j"
            print #coeff.static28, "c"
            print #coeff.static29, "c"
            print #coeff.static30, "B-V"
            print #coeff.static31, "V-R"
            print #coeff.static37, "v"
            print #coeff.static38, "bv"
            print #coeff.static41, "v"
            print #coeff.static43, "bv"
        else
            print #coeff.KU, using("###.###",Ku)            'first order extinction for u: K'u
            print #coeff.KB, using("###.###",Kg)            'first order extinction for b: K'b
            print #coeff.KV, using("###.###",Kr)            'first order extinction for v: K'v
            print #coeff.KR, using("###.###",Ki)            'first order extinction for r: K'r
            print #coeff.KI, using("###.###",Kz)            'first order extinction for i: K'i
            print #coeff.KKBV, using("###.###",KKgr)        'second order extinction for b-v: K"bv
            print #coeff.epsilon, using("###.###",SEps)     'transformation coefficient for v: epsilon
            print #coeff.epsilonR, using("###.###",SEpsR)   'transformtion coefficient for v: epsilon R
            print #coeff.mu, using("###.###",SMu)           'transformtion coefficient for b-v: mu
            print #coeff.psi, using("###.###",SPsi)         'transformtion coefficient for u-b: psi
            print #coeff.tau, using("###.###",STau)         'transformtion coefficient for v-r: tau
            print #coeff.eta, using("###.###",SEta)         'transformtion coefficient for v-i: eta
            print #coeff.Zv, using("###.###",ZPr)           'zero point constant for r
            print #coeff.Zbv, using("###.###",ZPgr)         'zero point constant for g-r
            print #coeff.Ev, using("###.###",Er)            'standard error for zero point constant for r
            print #coeff.Ebv, using("###.###",Egr)          'standard error for zero point constant for g-r

            print #coeff.static4,   "g"
            print #coeff.static6,   "r"
            print #coeff.static8,   "i"
            print #coeff.static10,  "z"
            print #coeff.static12,  "gr"
            print #coeff.static24,  "s"
            print #coeff.static25,  "s"
            print #coeff.static26,  "s"
            print #coeff.static27,  "s"
            print #coeff.static28,  "s"
            print #coeff.static29,  "s"
            print  #coeff.static30, "g'-r'"
            print #coeff.static31,  "r'-i'"
            print #coeff.static37,  "r"
            print #coeff.static38,  "gr"
            print #coeff.static41,  "r"
            print #coeff.static43,  "gr"
        end if

        CoeffFlag = 1

        if EpsilonFlag = 1 then
            print #coeff.epsilonBV, "set"
        else
            print #coeff.epsilonVR, "set"
        end if

        if JDFlag = 1 then
            print #coeff.JD, "set"
        else
            print #coeff.HJD, "set"
        end if
Wait

    [setEpsilonBV]
        EpsilonFlag = 1                                     'use epsilon from B-V to compute V
        print #coeff.epsilonVR, "reset"
    wait
    [setEpsilonVR]
        EpsilonFlag = 0                                     'use epsilon from V-R to compute V
        print #coeff.epsilonBV, "reset"
    wait
    [resetEpsilonBV]
        EpsilonFlag = 0                                     'use epsilon from V-R to compute V
        print #coeff.epsilonVR, "set"
    wait
    [resetEpsilonVR]
        EpsilonFlag = 1                                     'use epsilon from B-V to compute V
        print #coeff.epsilonBV, "set"
    wait

    [setJD]
        JDFlag = 1
        print #coeff.HJD, "reset"
    wait
    [setHJD]
        JDFlag = 0
        print #coeff.JD, "reset"
    wait
    [resetJD]
        JDFlag = 0
        print #coeff.HJD, "set"
    wait
    [resetHJD]
        JDFlag = 1
        print #coeff.JD, "set"
    wait

    [Use_Coefficients]
        temporary$ = ""
        if FilterSystem$ = "1" then
            print #coeff.KU, "!contents? temporary$";
            KU = val(temporary$)
            print #coeff.KB, "!contents? temporary$";
            KB = val(temporary$)
            print #coeff.KV, "!contents? temporary$";
            KV = val(temporary$)
            print #coeff.KR, "!contents? temporary$";
            KR = val(temporary$)
            print #coeff.KI, "!contents? temporary$";
            KI = val(temporary$)
            print #coeff.KKBV, "!contents? temporary$";
            KKbv = val(temporary$)
            print #coeff.epsilon, "!contents? temporary$";
            Eps = val(temporary$)
            print #coeff.epsilonR, "!contents? temporary$";
            EpsR = val(temporary$)
            print #coeff.psi, "!contents? temporary$";
            Psi = val(temporary$)
            print #coeff.mu, "!contents? temporary$";
            Mu = val(temporary$)
            print #coeff.tau, "!contents? temporary$";
            Tau = val(temporary$)
            print #coeff.eta, "!contents? temporary$";
            Eta = val(temporary$)
            print #coeff.Zv, "!contents? temporary$";
            ZPv = val(temporary$)
            print #coeff.Zbv, "!contents? temporary$";
            ZPbv = val(temporary$)
            print #coeff.Ev, "!contents? temporary$";
            Ev = val(temporary$)
            print #coeff.Ebv, "!contents? temporary$";
            Ebv = val(temporary$)
        else
            print #coeff.KU, "!contents? temporary$";
            Ku = val(temporary$)
            print #coeff.KB, "!contents? temporary$";
            Kg = val(temporary$)
            print #coeff.KV, "!contents? temporary$";
            Kr = val(temporary$)
            print #coeff.KR, "!contents? temporary$";
            Ki = val(temporary$)
            print #coeff.KI, "!contents? temporary$";
            Kz = val(temporary$)
            print #coeff.KKBV, "!contents? temporary$";
            KKgr = val(temporary$)
            print #coeff.epsilon, "!contents? temporary$";
            SEps = val(temporary$)
            print #coeff.epsilonR, "!contents? temporary$";
            SEpsR = val(temporary$)
            print #coeff.psi, "!contents? temporary$";
            SPsi = val(temporary$)
            print #coeff.mu, "!contents? temporary$";
            SMu = val(temporary$)
            print #coeff.tau, "!contents? temporary$";
            STau = val(temporary$)
            print #coeff.eta, "!contents? temporary$";
            SEta = val(temporary$)
            print #coeff.Zv, "!contents? temporary$";
            ZPr = val(temporary$)
            print #coeff.Zbv, "!contents? temporary$";
            ZPgr = val(temporary$)
            print #coeff.Ev, "!contents? temporary$";
            Er = val(temporary$)
            print #coeff.Ebv, "!contents? temporary$";
            Egr = val(temporary$)
        end if
Wait

    [Save_Coefficients]
        temporary$ = ""
        if FilterSystem$ = "1" then
            print #coeff.KU, "!contents? temporary$";
            KU = val(temporary$)
            print #coeff.KB, "!contents? temporary$";
            KB = val(temporary$)
            print #coeff.KV, "!contents? temporary$";
            KV = val(temporary$)
            print #coeff.KR, "!contents? temporary$";
            KR = val(temporary$)
            print #coeff.KI, "!contents? temporary$";
            KI = val(temporary$)
            print #coeff.KKBV, "!contents? temporary$";
            KKbv = val(temporary$)
            print #coeff.epsilon, "!contents? temporary$";
            Eps = val(temporary$)
            print #coeff.epsilonR, "!contents? temporary$";
            EpsR = val(temporary$)
            print #coeff.psi, "!contents? temporary$";
            Psi = val(temporary$)
            print #coeff.mu, "!contents? temporary$";
            Mu = val(temporary$)
            print #coeff.tau, "!contents? temporary$";
            Tau = val(temporary$)
            print #coeff.eta, "!contents? temporary$";
            Eta = val(temporary$)
            print #coeff.Zv, "!contents? temporary$";
            ZPv = val(temporary$)
            print #coeff.Zbv, "!contents? temporary$";
            ZPbv = val(temporary$)
            print #coeff.Ev, "!contents? temporary$";
            Ev = val(temporary$)
            print #coeff.Ebv, "!contents? temporary$";
            Ebv = val(temporary$)
        else
            print #coeff.KU, "!contents? temporary$";
            Ku = val(temporary$)
            print #coeff.KB, "!contents? temporary$";
            Kg = val(temporary$)
            print #coeff.KV, "!contents? temporary$";
            Kr = val(temporary$)
            print #coeff.KR, "!contents? temporary$";
            Ki = val(temporary$)
            print #coeff.KI, "!contents? temporary$";
            Kz = val(temporary$)
            print #coeff.KKBV, "!contents? temporary$";
            KKgr = val(temporary$)
            print #coeff.epsilon, "!contents? temporary$";
            SEps = val(temporary$)
            print #coeff.epsilonR, "!contents? temporary$";
            SEpsR = val(temporary$)
            print #coeff.psi, "!contents? temporary$";
            SPsi = val(temporary$)
            print #coeff.mu, "!contents? temporary$";
            SMu = val(temporary$)
            print #coeff.tau, "!contents? temporary$";
            STau = val(temporary$)
            print #coeff.eta, "!contents? temporary$";
            SEta = val(temporary$)
            print #coeff.Zv, "!contents? temporary$";
            ZPr = val(temporary$)
            print #coeff.Zbv, "!contents? temporary$";
            ZPgr = val(temporary$)
            print #coeff.Ev, "!contents? temporary$";
            Er = val(temporary$)
            print #coeff.Ebv, "!contents? temporary$";
            Egr = val(temporary$)
        end if

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
            print #PPparms, using("##.###",ZPgr)             'zero-point constant for g'-r
            print #PPparms, using("##.###",Ev)               'standard error for v
            print #PPparms, using("##.###",Er)               'standard error for r'
            print #PPparms, using("##.###",Ebv)              'standard error for b-v
            print #PPparms, using("##.###",Egr)              'standard error for g'-r'
        close #PPparms
Wait

    [Select_JohnsonCousins]
        FilterSystem$ = "1"
        goto [Print_Coefficients]

    [Select_Sloan]
        FilterSystem$ = "0"
        goto [Print_Coefficients]


    [Quit_Coefficients]
        CoeffFlag = 0
        FilterSystem$ = FilterSystemTemp$
        close #coeff
Wait
'
'
[View_StarDatabase]
        if ViewStarDataFlag = 1 then
            notice "Comp/Variable/Check Star Database already opened"
            wait
        end if

        NOMAINWIN
        WindowWidth = 660 : WindowHeight = 290
        UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
        UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

        Menu        #ViewStarData, "File", "Quit", [QuitViewStarData]

        listbox #ViewStarData.Table, StarData$(),[ViewStarData.click], 10, 40, 630, 180

        statictext  #ViewStarData.RA,  "---RA---",  175,  5, 80, 15
        statictext  #ViewStarData.DEC,  "---DEC---",  265,  5, 90, 15
        statictext  #ViewStarData.name,  "Star Name",  20,  20, 90, 15
        statictext  #ViewStarData.type,  "Type",  130,  20, 40, 15
        statictext  #ViewStarData.RAhour,  "H",  180,  20, 10, 15
        statictext  #ViewStarData.RAmin,  "M",  210,  20, 10, 15
        statictext  #ViewStarData.RAsec,  "S",  235,  20, 10, 15
        statictext  #ViewStarData.DECdeg,  "D",  270,  20, 10, 15
        statictext  #ViewStarData.DECmin,  "M",  300,  20, 10, 15
        statictext  #ViewStarData.DECsec,  "S",  325,  20, 10, 15
        statictext  #ViewStarData.V,       " V",  365,  20, 20, 15
        statictext  #ViewStarData.BV,     " B-V",  405,  20, 50, 15
        statictext  #ViewStarData.UB,     " U-B",  460,  20, 50, 15
        statictext  #ViewStarData.VR,     " V-R",  515,  20, 50, 15
        statictext  #ViewStarData.VI,     " V-I",  570,  20, 50, 15

        open "Comp/Variable/Check Star Database" for window as #ViewStarData
        #ViewStarData "trapclose [QuitViewStarData]"

        if FilterSystem$ = "1" then
            print #ViewStarData.V, "V"
            print #ViewStarData.BV, "B-V"
            print #ViewStarData.UB, "U-B"
            print #ViewStarData.VR, "V-R"
            print #ViewStarData.VI, "V-I"
        else
            print #ViewStarData.V, "r'"
            print #ViewStarData.BV, "g'-r'"
            print #ViewStarData.UB, "u'-g'"
            print #ViewStarData.VR, "r'-i'"
            print #ViewStarData.VI, "r'-z'"
        end if

        ViewStarDataFlag = 1
        #ViewStarData "font courier_new 10 14"
        print #ViewStarData.Table, "reload"

    [ViewStarData.click]

Wait
    [QuitViewStarData]
        ViewStarDataFlag = 0
        close #ViewStarData
Wait
'
'==========end of Information Windows
'
[About]
    notice "Data Reduction - Johnson/Cousins/Sloan Photometry"+chr$(13)+_
           " Version " +VersionNumber$+chr$(13)+_
           " copyright 2015, Gerald Persha"+chr$(13)+_
           " www.sspdataq.com"
Wait
'
[Help]
    run "hh photometry2.chm"
Wait
'
[Quit_Reduc]                                'exit program
    confirm "do you wish to exit program?"; Answer$

    if Answer$ = "yes" then
        if CoeffFlag = 1 then
            close #coeff
            CoeffFlag = 0
        end if
        if ChoiceFlag = 1 then
            close #choice
            ChoiceFlag = 0
        end if
        if SaveDataFlag = 1 then
            close #SaveData
            SaveDataFlag = 0
        end if
        close #reduc
        if ViewStarDataFlag = 1 then
            close #ViewStarData
            ViewStarDataFlag = 0
        end if
    else
        wait
    end if
END
'
'=====control buttons and control boxes
'
[Reduction_Table.click]
    #reduc.Table "selection? selected$"
wait

[Select_Comp.click]
    print #reduc.Comp, "selection? selectedComp$"

    RAComp = 0
    DECComp = 0
                                            'get RA and DEC info of comp star from Star Data file
    for DataIndex = 1 to DataIndexMax
        if selectedComp$ = left$(SDitem$(DataIndex,1)+"           ",12) then
                                            'convert RA and DEC to decimal
            RAComp =  val(SDitem$(DataIndex,3)) + val(SDitem$(DataIndex,4))/60 + val(SDitem$(DataIndex,5))/3600
            RAComp = (RAComp/24) * 360      'convert RA to degrees
            DECComp = abs(val(right$(SDitem$(DataIndex,6),2))) +_
                      val(SDitem$(DataIndex,7))/60 + val(SDitem$(DataIndex,8))/3600
                                            'see if there are any minus signs in DECd and make DECComp negative if so
            if left$(SDitem$(DataIndex,6),1) = "-" then
                DECComp = DECComp * -1
            end if
                                            'get standard V mag, B-V,U-B,V-R & V-I index for selected comparison star
            CompV  = val(SDitem$(DataIndex,9))
            CompBV = val(SDitem$(DataIndex,10))
            CompUB = val(SDitem$(DataIndex,11))
            CompVR = val(SDitem$(DataIndex,12))
            CompVI = val(SDitem$(DataIndex,13))
            exit for
        end if
    next
    if (RAComp = 0) AND (DECComp = 0) then
        notice "could not find selected Comp Star in Star Data file"
        wait
    end if
    StartComp.Flag = 1
    if StartComp.Flag = 1 and StartVar.Flag = 1 then
        print #reduc.Start, "!Enable"
    end if

    open "IREX.txt" for append as #IREX
    print #IREX, "RAComp     DECComp    CompV     CompBV    CompUB    CompVR    CompVI"
    print #IREX, using("###.####", RAComp);"  ";_
                 using("###.####", DECComp);"  ";_
                 using("###.###", CompV);"   ";_
                 using("###.###", CompBV);"   ";_
                 using("###.###", CompUB);"   ";_
                 using("###.###", CompVR);"   ";_
                 using("###.###", CompVI)
    print #IREX, " "
    close #IREX

wait

[Select_Var.click]
    print #reduc.Variable, "selection? selectedVar$"

    RAVar = 0
    DECVar = 0
                                           'get RA and DEC info of variable star from Star Data file
    for DataIndex = 1 to DataIndexMax
        if selectedVar$ = left$(SDitem$(DataIndex,1)+"           ",12) then
                                           'convert RA and DEC to decimal
            RAVar =  val(SDitem$(DataIndex,3)) + val(SDitem$(DataIndex,4))/60 + val(SDitem$(DataIndex,5))/3600
            RAVar = (RAVar/24) * 360       'convert RA to degrees
            DECVar = abs(val(SDitem$(DataIndex,6)) + val(SDitem$(DataIndex,7))/60 + val(SDitem$(DataIndex,8))/3600)

                                            'see if there are any minus signs in DECd and make DECVar negative if so
            if mid$(SDitem$(DataIndex,6),1,1) = "-" OR_
               mid$(SDitem$(DataIndex,6),2,1) = "-" OR_
               mid$(SDitem$(DataIndex,6),3,1) = "-" then
                DECVar = DECVar * -1
            end if
            exit for
        end if
    next
    if (RAVar = 0) AND (DECVar = 0) then
        notice "could not find selected Variable Star in Star Data file"
        wait
    end if
    StartVar.Flag = 1
    if StartComp.Flag = 1 and StartVar.Flag = 1 then
        print #reduc.Start, "!Enable"
    end if
    if CompFlag = 0 and StartVar.Flag = 1 then
        print #reduc.Start, "!Enable"
    end if
wait

[Start_Reduction]
    open "IREX.txt" for append as #IREX
        print #reduc.Start, "wait"
        gosub [Create_Reduction_Table]
        print #reduc.Start, "Start"
        print #IREX, " "
    close #IREX
wait
'
'=====subroutines for extracting data from opened raw file
'
[Open_Star_Data]
    if FilterSystem$ = "1" then
        open "Star Data Version 2.txt" for input as #StarData
    else
        open "Star Data Version 2 Sloan.txt" for input as #StarData
    end if
        DataIndex = 0
        while eof(#StarData) = 0
        DataIndex = DataIndex + 1
        input #StarData,SDitem$(DataIndex,1),_      'comp or var star name
                        SDitem$(DataIndex,2),_      'type, either C or V
                        SDitem$(DataIndex,3),_      'RA hour
                        SDitem$(DataIndex,4),_      'RA minute
                        SDitem$(DataIndex,5),_      'RA second
                        SDitem$(DataIndex,6),_      'DEC degree
                        SDitem$(DataIndex,7),_      'DEC minute
                        SDitem$(DataIndex,8),_      'DEC second
                        SDitem$(DataIndex,9),_      'V/r' magnitude, ##.##
                        SDitem$(DataIndex,10),_     'B-V/g'-r' index, ##.##
                        SDitem$(DataIndex,11),_     'U-B/u'-r' index, ##.##
                        SDitem$(DataIndex,12),_     'V-R/r'-i' index, ##.##
                        SDitem$(DataIndex,13)       'V-I/r'-z' index, ##.##

        wend
        DataIndexMax = DataIndex
    close #StarData
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
        RDitem$(RawIndex,7)  = mid$(RawData$(RawIndex),21,1)       'catalog: C, V, SKY, SKYNEXT or SKYLAST
        RDitem$(RawIndex,8)  = mid$(RawData$(RawIndex),26,12)      'star name
        RDitem$(RawIndex,9)  = mid$(RawData$(RawIndex),41,1)       'filter: U, B, V, R or I
        RDitem$(RawIndex,10) = mid$(RawData$(RawIndex),44,5)       'Count 1
        RDitem$(RawIndex,11) = mid$(RawData$(RawIndex),51,5)       'Count 2
        RDitem$(RawIndex,12) = mid$(RawData$(RawIndex),58,5)       'Count 3
        RDitem$(RawIndex,13) = mid$(RawData$(RawIndex),65,5)       'Count 4
        RDitem$(RawIndex,14) = mid$(RawData$(RawIndex),72,2)       'integration time in seconds: 1 or 10
        RDitem$(RawIndex,15) = mid$(RawData$(RawIndex),75,3)       'scale: 1, 10 or 100

        print #IREX, RDitem$(RawIndex,1);"  ";_
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
        print #reduc.statictext9,  "u"
        print #reduc.statictext11, "b"
        print #reduc.statictext13, "v"
        print #reduc.statictext15, "r"
        print #reduc.statictext17, "i"
        print #reduc.statictext18, "V"
        print #reduc.statictext19, "B-V"
        print #reduc.statictext20, "U-B"
        print #reduc.statictext21, "V-R"
        print #reduc.statictext22, "V-I"

        print #reduc.statictext30, " V"
        print #reduc.statictext31, "  B-V"
        print #reduc.statictext33, "  U-B"
        print #reduc.statictext34, "  V-R"
        print #reduc.statictext35, "  V-I"
    else
        print #reduc.statictext9,  "u"
        print #reduc.statictext11, "g"
        print #reduc.statictext13, "r"
        print #reduc.statictext15, "i"
        print #reduc.statictext17, "z"
        print #reduc.statictext18, "r'"
        print #reduc.statictext19, "g'-r'"
        print #reduc.statictext20, "u'-g'"
        print #reduc.statictext21, "r'-i'"
        print #reduc.statictext22, "r'-z'"

        print #reduc.statictext30, "r'"
        print #reduc.statictext31, "g'-r'"
        print #reduc.statictext33, "u'-g'"
        print #reduc.statictext34, "r'-i'"
        print #reduc.statictext35, "r'-z'"
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
            ' do something to prevent division by 0
        end if
        Integration = val(RDitem$(RawIndex,14))                     'find integration time :1 or 10 seconds
        Scale = val(RDitem$(RawIndex,15))                           'find scale factor: 1, 10 or 100
        CountFinal(RawIndex) = int((CountSum/Divider) * (1000/(Integration * Scale)))
    next
return
'
[Julian_Day_RawFile]    'convert UT time and date to Julian, epcoh J2000
    For RawIndex = 5 to RawIndexMax

        UTyear =  val(RDitem$(RawIndex,3))
        UTmonth = val(RDitem$(RawIndex,1))

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
        JD(RawIndex) = B + C + D - 730550.5 + val(RDitem$(RawIndex,2)) +_
                       (val(RDitem$(RawIndex,4)) + val(RDitem$(RawIndex,5))/60 + val(RDitem$(RawIndex,6))/3600)/24

                                'Julian century
        JT(RawIndex) = JD(RawIndex)/36525
    next
return
'
[IREX_RawFile]      'subtract skies from comp star data
    for RawIndex = 5 to RawIndexMax
                    'go through raw file and pick out stars with the selected filters
        if ((RDitem$(RawIndex,7) = "C") OR (RDitem$(RawIndex,7) = "V") OR (RDitem$(RawIndex,7) = "Q"))_
            AND (RDitem$(RawIndex,9) = Filter$) then

            if (RDitem$(RawIndex,7) = "C") then
                    'make list of  comparison stars for COMP combobox
                CompFlag = 0
                for CompIndex = 1 to CompIndexMax          'see if the Comp Star is new to the list
                    if CompStar$(CompIndex) = RDitem$(RawIndex,8) then
                        CompFlag = 1
                    end if
                next
                if CompFlag = 0 then                      'add the new Comp Star to the list
                    CompIndexMax = CompIndexMax + 1
                    CompStar$(CompIndex) = RDitem$(RawIndex,8)
                end if
            else
                    'make list of variable and check stars for Variable combobox
                VarFlag = 0
                for VarIndex = 1 to VarIndexMax
                    if VarStar$(VarIndex) = RDitem$(RawIndex,8) then
                        VarFlag = 1
                    end if
                next
                if VarFlag = 0 then
                    VarIndexMax = VarIndexMax + 1
                    VarStar$(VarIndex) = RDitem$(RawIndex,8)
                end if
            end if

                    'find the past sky count to apply
            SkyPastCount = 0
            PastTime = 0
            for I = RawIndex to 5 step -1
                if (RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = Filter$) OR_
                   (RDitem$(I,8) = "SKYNEXT     ") AND (RDitem$(I,9) = Filter$) then
                    SkyPastCount = CountFinal(I)
                    PastTime = JD(I)
                    exit for
                end if
            next
                    'find the future sky count to apply
            SkyFutureCount = 0
            FutureTime = 0
            for I = RawIndex to RawIndexMax step 1
                if (RDitem$(I,8) = "SKY         ") AND (RDitem$(I,9) = Filter$) OR_
                   (RDitem$(I,8) = "SKYLAST     ") AND (RDitem$(I,9) = Filter$) then
                    SkyFutureCount = CountFinal(I)
                    FutureTime = JD(I)
                    exit for
                end if
            next
                    'subtract sky from star count depending on SKY, SKYNEXT or SKYLAST protocol and change
                    'CountFinal value accordingly
            select case
                case (SkyPastCount = 0) AND (SkyFutureCount = 0)
                    notice "no SKY counts for  star at line# "; RawIndex
                    wait
                case (SkyPastCount > 0) AND (SkyFutureCount = 0)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyPastCount
                case (SkyPastCount = 0) AND (SkyFutureCount > 0)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyFutureCount
                case else
                        '                           y2 - y1
                        'interpolation:   y = y1 + --------- * (x - x1)
                        '                           x2 - x1
                    SkyCurrentCount = SkyPastCount + ((SkyFutureCount - SkyPastCount)/(FutureTime - PastTime))*_
                                      (JD(RawIndex) - PastTime)
                    CountFinal(RawIndex) = CountFinal(RawIndex) - SkyCurrentCount
            end select

            print #IREX, RDitem$(RawIndex,8);" ";_
                         using("#####.#####",JD(RawIndex));"  ";_
                         using("#######", CountFinal(RawIndex));"       ";_
                         Filter$;"   ";_
                         using("#######", SkyPastCount);"   ";_
                         using("#######",SkyFutureCount)
        end if
    next
return
'
[Make_CompVarCheck_List]
    StarDataIndex = 0
    For CompIndex = 1 to CompIndexMax
        For DataIndex = 1 to DataIndexMax
            if CompStar$(CompIndex) = left$(SDitem$(DataIndex,1)+"           ",12) then
                StarDataIndex = 1 + StarDataIndex
                StarData$(StarDataIndex) = left$(SDitem$(DataIndex,1)+"           ",12)+"  "+_
                                           SDitem$(DataIndex,2)+"   "+_
                                           using("##",val(SDitem$(DataIndex,3)))+" "+_
                                           using("##",val(SDitem$(DataIndex,4)))+" "+_
                                           using("##",val(SDitem$(DataIndex,5)))+" "+_
                                           using("###",val(SDitem$(DataIndex,6)))+" "+_
                                           using("##",val(SDitem$(DataIndex,7)))+" "+_
                                           using("##",val(SDitem$(DataIndex,8)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,9)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,10)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,11)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,12)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,13)))
            end if
        next
    next
    For VarIndex = 1 to VarIndexMax
        For DataIndex = 1 to DataIndexMax
            if VarStar$(VarIndex) = left$(SDitem$(DataIndex,1)+"           ",12) then
                StarDataIndex = 1 + StarDataIndex
                StarData$(StarDataIndex) = left$(SDitem$(DataIndex,1)+"           ",12)+"  "+_
                                           SDitem$(DataIndex,2)+"   "+_
                                           using("##",val(SDitem$(DataIndex,3)))+" "+_
                                           using("##",val(SDitem$(DataIndex,4)))+" "+_
                                           using("##",val(SDitem$(DataIndex,5)))+" "+_
                                           using("###",val(SDitem$(DataIndex,6)))+" "+_
                                           using("##",val(SDitem$(DataIndex,7)))+" "+_
                                           using("##",val(SDitem$(DataIndex,8)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,9)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,10)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,11)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,12)))+" "+_
                                           using("##.##",val(SDitem$(DataIndex,13)))
            end if
        next
    next
    StarDataIndexMax = StarDataIndex
return
'
'=====subroutines for creating reduction table
'
                                           'create ReducData$() for display in listbox
[Create_Reduction_Table]
    redim ReducData$(2000)                 'string data lines for reduction table in list box

    redim ReducStar$(2000)                 'comp or variable star name
    redim ReducType$(2000)                 'C or V
    redim ReducJD(2000)                    'Julean date of observation, epoch 2000
    redim ReducCount(2000)                 'net count, average of (star - sky)

    redim ReducDelta.u(2000)               'differential u instrument magnitude
    redim ReducDelta.b(2000)               'differential b instrument magnitude
    redim ReducDelta.v(2000)               'differential v instrument magnitude
    redim ReducDelta.r(2000)               'differential r instrument magnitude
    redim ReducDelta.i(2000)               'differential i instrument magnitude

    redim ReducDelta.uo(2000)              'differential uo instrument magnitude
    redim ReducDelta.bo(2000)              'differential bo instrument magnitude
    redim ReducDelta.vo(2000)              'differential vo instrument magnitude
    redim ReducDelta.ro(2000)              'differential ro instrument magnitude
    redim ReducDelta.io(2000)              'differential io instrument magnitude

    redim ReducDelta.V(2000)               'differential V standard magnitude, equation 2.48
    redim ReducDelta.BV(2000)              'differential B-V standard magnitude, equation 2.49
    redim ReducDelta.UB(2000)              'differential U-B standard magnitude, equation 2.50
    redim ReducDelta.VR(2000)              'differential V-R standard magnitude
    redim ReducDelta.VI(2000)              'differential V-I standard magnitude

    redim ReducV(2000)                     'standard V magnitude, equation 2.51
    redim ReducBV(2000)                    'standard B-V index, equation 2.52
    redim ReducUB(2000)                    'standard U-B index, equation 2.53
    redim ReducVR(2000)                    'standard V-R index
    redim ReducVI(2000)                    'standard V-I index, equation 2.52

    redim ReducX(2000)                     'air mass for comp or variable
    redim ReducFilter$(2000)               'filter, U, B, V, R or I

    FilterFlagU = 0                        'reset all filter flags to 0 or false
    FilterFlagB = 0
    FilterFlagV = 0
    FilterFlagR = 0
    FilterFlagI = 0

    ReducBV.average = 0
    ReducBV.std.deviation = 0
    ReducVR.average = 0
    ReducVR.std.deviation = 0
    ReducVI.average = 0
    ReducVI.std.deviation = 0
    ReducUB.average = 0
    ReducUB.std.deviation = 0

    BdataFlag = 0
    RdataFlag = 0

    gosub [Reduction_Table_Step1]                   'get star names, net count, date, RA, DEC and airmass

    if FilterFlagU >= 3 then
        gosub [Reduction_Table_Step2U]
    end if
    if FilterFlagB >= 3 and CompFlag = 1 then
        print #reduc.statictext10,  chr$(68)
        gosub [Reduction_Table_Step2B]
    end if
    if FilterFlagB >= 3 and CompFlag = 0 then
        print #reduc.statictext10,  ""
        gosub [Reduction_Table_AllSky_Step2B]
    end if
    if FilterFlagV >= 3 and CompFlag = 1 then
        print #reduc.statictext12,  chr$(68)
        gosub [Reduction_Table_Step2V]
    end if
    if FilterFlagV >= 3 and CompFlag = 0 then
        print #reduc.statictext12,  ""
        gosub [Reduction_Table_AllSky_Step2V]
    end if
    if FilterFlagR >= 3 then
        gosub [Reduction_Table_Step2R]
    end if
    if FilterFlagI >= 3 then
        gosub [Reduction_Table_Step2I]
    end if
    if FilterFlagB >= 3 AND FilterFlagV >= 3 AND CompFlag = 1 then
        gosub [Reduction_Table_Step3BV]             'associate the bo and vo mags with each other and calculate results
    end if
    if FilterFlagB >= 3 AND FilterFlagV >= 3 AND CompFlag = 0 then
        gosub [Reduction_Table_AllSky_Step3BV]
    end if
    if FilterFlagR >= 3 AND FilterFlagV >= 3 then
        gosub [Reduction_Table_Step3VR]             'associate the bo and vo mags with each other and calculate results
    end if
    if FilterFlagI >= 3 AND FilterFlagV >= 3 then
        gosub [Reduction_Table_Step3VI]             'associate the bo and vo mags with each other and calculate results
    end if
    if FilterFlagU >= 3 AND FilterFlagB >= 3 then
        gosub [Reduction_Table_Step3UB]             'associate the bo and vo mags with each other and calculate results
    end if
    if FilterFlagV >= 3 AND CompFlag = 1 AND FilterFlagU = 0 AND FilterFlagB = 0 AND FilterFlagR = 0 AND FilterFlagI = 0 then
        gosub [Reduction_Table_Step3V]              'for doing continuous reading with V/r' filter only

    else
        gosub [Report_Results]                 'send average magnitudes and error to Avg. Standard Magnitude textbox
        gosub [Report_Results2]                'send average magnitudes and error to Avg. Standard Magnitude textbox
    end if

    for ReducIndex = 1 to ReducIndexMax          'write data items to the data string array and display
        ReducData$(ReducIndex) = ReducStar$(ReducIndex)+"  "+_
                                 ReducType$(ReducIndex)+"  "+_
                                 using("####.####",ReducJD(ReducIndex))+" "+_
                                 using("#######",ReducCount(ReducIndex))+"  "+_
                                 ReducFilter$(ReducIndex)+" "

                                 if ReducDelta.u(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducDelta.u(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$

                                 if ReducDelta.b(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducDelta.b(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$

                                 if ReducDelta.v(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducDelta.v(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$ 

                                 if ReducDelta.r(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducDelta.r(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$ 

                                 if ReducDelta.i(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducDelta.i(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$

                                 if ReducV(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducV(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$

                                 if ReducBV(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducBV(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$

                                 if ReducUB(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducUB(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$

                                 if ReducVR(ReducIndex) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ReducVR(ReducIndex))+" "
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$

                                 if ReducVI(ReducIndex) = 0 then
                                    Temp$ = " . . ."
                                 else
                                    Temp$ = using("###.##",ReducVI(ReducIndex))
                                 end if
                                 ReducData$(ReducIndex) = ReducData$(ReducIndex)+Temp$

    next
    print #reduc.Table, "reload"
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step1]             'get stars, type, date and counts - compute airmass

    print #IREX, "output from [Reduction_Table_Step1]"
    print #IREX, "ReducIndex  star          type    J2000      net count     X      filter"

    ReducIndex = 0
    for RawIndex = 5 to RawIndexMax
        if (selectedComp$ = RDitem$(RawIndex,8)) OR (selectedVar$ = RDitem$(RawIndex,8)) then
            ReducIndex = ReducIndex + 1
            ReducStar$(ReducIndex) = RDitem$(RawIndex,8)        'star name
            ReducType$(ReducIndex) = RDitem$(RawIndex,7)        'type, C or V
            ReducJD(ReducIndex)    = JD(RawIndex)               'Julean date for observation
            ReducCount(ReducIndex) = CountFinal(RawIndex)       'net count for observation

            if ReducType$(ReducIndex) = "C" then                'get the RA and DEC for comp or var
                RA = RAComp
                DEC = DECComp
            else
                RA = RAVar
                DEC = DECVar
            end if
            gosub [Siderial_Time]
            gosub [Find_Air_Mass]                               'compute airmass X
            ReducX(ReducIndex) = AirMass                        'airmass for comp or var

            ReducFilter$(ReducIndex) = RDitem$(RawIndex,9)      'filter, U, B, V, R or I

            if RDitem$(RawIndex,9) = "U" OR RDitem$(RawIndex,9) = "u" then     'see what filters are used in data set and
                FilterFlagU = 1 + FilterFlagU                   'set flag to true.
            end if                                              'would need 3 readings minimum for data to be good
            if RDitem$(RawIndex,9) = "B" OR RDitem$(RawIndex,9) = "g" then
                FilterFlagB = 1 + FilterFlagB
            end if
            if RDitem$(RawIndex,9) = "V" OR RDitem$(RawIndex,9) = "r" then
                FilterFlagV = 1 +  FilterFlagV
            end if
            if RDitem$(RawIndex,9) = "R" OR RDitem$(RawIndex,9) = "i" then
                FilterFlagR = 1 + FilterFlagR
            end if
            if RDitem$(RawIndex,9) = "I" OR RDitem$(RawIndex,9) = "z" then
                FilterFlagI = 1 + FilterFlagI
            end if

            print #IREX, using("####",ReducIndex);"        ";_       'send intermediate results to IREX file for diagnostic
                         ReducStar$(ReducIndex);"   ";_
                         ReducType$(ReducIndex);"    ";_
                         using("####.####",ReducJD(ReducIndex));"     ";_
                         using("#######",ReducCount(ReducIndex));"   ";_
                         using("##.###",ReducX(ReducIndex));"     ";_
                         ReducFilter$(ReducIndex)
        end if
    next
    ReducIndexMax = ReducIndex
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step2U]                        'calculate u and uo

    print #IREX, "Start of [Reduction_Table_Step2U]"
    print #IREX, "ReducIndex  AirMassBack   AirMassForward   ReducDelta.u   ReducDelta.uo    CompCountAvg"

    for ReducIndex = 1 to ReducIndexMax
                                                'find the variable star with filter = U
        if ((ReducType$(ReducIndex)) = "V" OR (ReducType$(ReducIndex)) = "Q") AND ((ReducFilter$(ReducIndex)) = "U" OR (ReducFilter$(ReducIndex)) = "u") then
                                                'get the back and forward comp star counts and air masses
            for I = ReducIndex to 1 step -1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "U") OR (ReducFilter$(I) = "u")) then
                    CompCountBack = ReducCount(I)
                    AirMassBack = ReducX(I)
                    exit for
                end if
            next
            for I = ReducIndex to ReducIndexMax step 1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "U") OR (ReducFilter$(I) = "u")) then
                    CompCountForward = ReducCount(I)
                    AirMassForward = ReducX(I)
                    exit for
                end if
            next
            CompCountAvg = (CompCountBack + CompCountForward)/2
            AirMassAvg = (AirMassBack + AirMassForward)/2
                                                'calculate delta u using equation 2.35
            ReducDelta.u(ReducIndex) = -1.0857 * log(ReducCount(ReducIndex)/CompCountAvg)
                                                'calculate delta uo using equation 2.43
            if FilterSystyem$ = "1" then
                ReducDelta.uo(ReducIndex) = ReducDelta.u(ReducIndex) - KU * (ReducX(ReducIndex) - AirMassAvg)
            else
                ReducDelta.uo(ReducIndex) = ReducDelta.u(ReducIndex) - Ku * (ReducX(ReducIndex) - AirMassAvg)
            end if
            print #IREX, using("####",ReducIndex);"        ";_
                         using("###.###",AirMassBack);"         ";_
                         using("###.###",AirMassForward);"       ";_
                         using("####.###",ReducDelta.u(ReducIndex));"       ";_
                         using("####.###",ReducDelta.uo(ReducIndex));"          ";_
                         using("########",CompCountAvg)
        end if
    next
    print #IREX, " "
    UdataFlag = 1
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step2B]                        'calculate b and bo

    print #IREX, "Start of [Reduction_Table_Step2B]"
    print #IREX, "ReducIndex  AirMassBack   AirMassForward   ReducDelta.b   ReducDelta.bo    CompCountAvg"

    for ReducIndex = 1 to ReducIndexMax
                                                'find the variable star with filter = B
        if (ReducType$(ReducIndex)) = "V" OR (ReducType$(ReducIndex)) = "Q" AND ((ReducFilter$(ReducIndex)) = "B" OR (ReducFilter$(ReducIndex)) = "g") then
                                                'get the back and forward comp star counts and air masses
            for I = ReducIndex to 1 step -1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "B") OR (ReducFilter$(I) = "g")) then
                    CompCountBack = ReducCount(I)
                    AirMassBack = ReducX(I)
                    exit for
                end if
            next
            for I = ReducIndex to ReducIndexMax step 1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "B") OR (ReducFilter$(I) = "g")) then
                    CompCountForward = ReducCount(I)
                    AirMassForward = ReducX(I)
                    exit for
                end if
            next
            CompCountAvg = (CompCountBack + CompCountForward)/2
            AirMassAvg = (AirMassBack + AirMassForward)/2
                                                'calculate delta b using equation 2.35
            ReducDelta.b(ReducIndex) = -1.0857 * log(ReducCount(ReducIndex)/CompCountAvg)
                                                'calculate delta bo using equation 2.43
            if FilterSystem$ = "1" then
                ReducDelta.bo(ReducIndex) = ReducDelta.b(ReducIndex) - KB * (ReducX(ReducIndex) - AirMassAvg)
            else
                ReducDelta.bo(ReducIndex) = ReducDelta.b(ReducIndex) - Kg * (ReducX(ReducIndex) - AirMassAvg)
            end if

            print #IREX, using("####",ReducIndex);"        ";_
                         using("###.###",AirMassBack);"         ";_
                         using("###.###",AirMassForward);"       ";_
                         using("####.###",ReducDelta.b(ReducIndex));"       ";_
                         using("####.###",ReducDelta.bo(ReducIndex));"          ";_
                         using("########",CompCountAvg)
        end if
    next
        print #IREX, " "
    BdataFlag = 1
    ON ERROR goto [errorHandler]
                             'there is B data
return
'
[Reduction_Table_AllSky_Step2B]
    print #IREX, "Start of [Reduction_Table_AllSky_Step2B"
    print #IREX, "ReducIndex  ReducX      Reduc.b      Reduc.bo"

    for ReducIndex = 1 to ReducIndexMax
        if (ReducType$(ReducIndex)) = "V" OR (ReducType$(ReducIndex)) = "Q" AND ((ReducFilter$(ReducIndex)) = "B" OR (ReducFilter$(ReducIndex)) = "g") then
            ReducDelta.b(ReducIndex) = -1.0857 * log(ReducCount(ReducIndex))
            if FilterSystem$ = "1" then
                ReducDelta.bo(ReducIndex) = ReducDelta.b(ReducIndex) - KB * ReducX(ReducIndex)
            else
                ReducDelta.bo(ReducIndex) = ReducDelta.b(ReducIndex) - Kg * ReducX(ReducIndex)
            end if
            print #IREX, using("####",ReducIndex);"      ";_
                         using("###.###",ReducX(ReducIndex));"      ";_
                         using("####.###",ReducDelta.b(ReducIndex));"     ";_
                         using("####.###",ReducDelta.bo(ReducIndex))
        end if
    next
    print #IREX, " "
    BdataFlag = 1                               'there is B data
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step2V]                        'calculate mean julian date, v and  vo
    J2000.Total = 0
    J2000.Divider = 0
    print #IREX, "Start of [Reduction_Table_Step2V]"
    print #IREX, "ReducIndex  AirMassBack   AirMassForward   ReducDelta.v   ReducDelta.vo    CompCountAvg"
    for ReducIndex = 1 to ReducIndexMax
                                                'find the variable star with filter = V
        if (ReducType$(ReducIndex)) = "V" OR (ReducType$(ReducIndex)) = "Q" AND ((ReducFilter$(ReducIndex)) = "V" OR (ReducFilter$(ReducIndex)) = "r") then
                                                'sum the J2000 dates for v magnitude time to calculate mean J2000 date
            J2000.Total = J2000.Total + ReducJD(ReducIndex)
            J2000.Divider = J2000.Divider + 1
                                                'get the back and forward comp star counts and air masses
            for I = ReducIndex to 1 step -1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "V") OR (ReducFilter$(I) = "r")) then
                    CompCountBack = ReducCount(I)
                    AirMassBack = ReducX(I)
                    exit for
                end if
            next
            for I = ReducIndex to ReducIndexMax step 1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "V") OR (ReducFilter$(I) = "r")) then
                    CompCountForward = ReducCount(I)
                    AirMassForward = ReducX(I)
                    exit for
                end if
            next
            CompCountAvg = (CompCountBack + CompCountForward)/2
            AirMassAvg = (AirMassBack + AirMassForward)/2
                                                'calculate delta v using equation 2.35
            ReducDelta.v(ReducIndex) = -1.0857 * log(ReducCount(ReducIndex)/CompCountAvg)
                                                'calculate delta vo using equation 2.43
            if FilterSystem$ = "1" then
                ReducDelta.vo(ReducIndex) = ReducDelta.v(ReducIndex) - KV * (ReducX(ReducIndex) - AirMassAvg)
            else
                ReducDelta.vo(ReducIndex) = ReducDelta.v(ReducIndex) - Kr * (ReducX(ReducIndex) - AirMassAvg)
            end if

            print #IREX, using("####",ReducIndex);"        ";_
                         using("###.###",AirMassBack);"         ";_
                         using("###.###",AirMassForward);"       ";_
                         using("####.###",ReducDelta.v(ReducIndex));"       ";_
                         using("####.###",ReducDelta.vo(ReducIndex));"          ";_
                         using("########",CompCountAvg)
        end if
    next
    J2000.Mean = J2000.Total/J2000.Divider      'mean J2000 date for v magnitude measurements
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_AllSky_Step2V]
    J2000.Total = 0
    J2000.Divider = 0
    print #IREX, "Start of [Reduction_Table_AllSky_Step2V]"
    print #IREX, "ReducIndex  ReducX      Reduc.v     Reduc.vo "
    for ReducIndex = 1 to ReducIndexMax
                                                'find the variable star with filter = V
        if (ReducType$(ReducIndex)) = "V" OR (ReducType$(ReducIndex)) = "Q" AND ((ReducFilter$(ReducIndex)) = "V" OR (ReducFilter$(ReducIndex)) = "r") then
                                                'sum the J2000 dates for v magnitude time to calculate mean J2000 date
            J2000.Total = J2000.Total + ReducJD(ReducIndex)
            J2000.Divider = J2000.Divider + 1

                                                'calculate delta v using equation 2.35
            ReducDelta.v(ReducIndex) = -1.0857 * log(ReducCount(ReducIndex))
                                                'calculate delta vo using equation 2.43
            if FilterSystem$ = "1" then
                ReducDelta.vo(ReducIndex) = ReducDelta.v(ReducIndex) - KV * (ReducX(ReducIndex))
            else
                ReducDelta.vo(ReducIndex) = ReducDelta.v(ReducIndex) - Kr * (ReducX(ReducIndex))
            end if

            print #IREX, using("####",ReducIndex);"      ";_
                         using("###.###",ReducX(ReducIndex));"      ";_
                         using("####.###",ReducDelta.v(ReducIndex));"     ";_
                         using("####.###",ReducDelta.vo(ReducIndex))
        end if
    next
    J2000.Mean = J2000.Total/J2000.Divider      'mean J2000 date for v magnitude measurements
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step2R]                        'calculate r and ro

    print #IREX, "Start of [Reduction_Table_Step2R]"
    print #IREX, "ReducIndex  AirMassBack   AirMassForward   ReducDelta.r   ReducDelta.ro    CompCountAvg"

    for ReducIndex = 1 to ReducIndexMax
                                                'find the variable star with filter = R
        if (ReducType$(ReducIndex)) = "V" OR (ReducType$(ReducIndex)) = "Q" AND ((ReducFilter$(ReducIndex)) = "R" OR (ReducFilter$(ReducIndex)) = "i") then
                                                'get the back and forward comp star counts and air masses
            for I = ReducIndex to 1 step -1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "R") OR (ReducFilter$(I) = "i")) then
                    CompCountBack = ReducCount(I)
                    AirMassBack = ReducX(I)
                    exit for
                end if
            next
            for I = ReducIndex to ReducIndexMax step 1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "R") OR (ReducFilter$(I) = "i")) then
                    CompCountForward = ReducCount(I)
                    AirMassForward = ReducX(I)
                    exit for
                end if
            next
            CompCountAvg = (CompCountBack + CompCountForward)/2
            AirMassAvg = (AirMassBack + AirMassForward)/2
                                                'calculate delta r using equation 2.35
            ReducDelta.r(ReducIndex) = -1.0857 * log(ReducCount(ReducIndex)/CompCountAvg)
                                                'calculate delta ro using equation 2.43
            if FilterSystem$ = "1" then
                ReducDelta.ro(ReducIndex) = ReducDelta.r(ReducIndex) - KR * (ReducX(ReducIndex) - AirMassAvg)
            else
                ReducDelta.ro(ReducIndex) = ReducDelta.r(ReducIndex) - Ki * (ReducX(ReducIndex) - AirMassAvg)
            end if

            print #IREX, using("####",ReducIndex);"        ";_
                         using("###.###",AirMassBack);"         ";_
                         using("###.###",AirMassForward);"       ";_
                         using("####.###",ReducDelta.r(ReducIndex));"       ";_
                         using("####.###",ReducDelta.ro(ReducIndex));"          ";_
                         using("########",CompCountAvg)
        end if
    next
    print #IREX, " "
    RdataFlag = 1                               'there is R data
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step2I]                        'calculate i and io

    print #IREX, "Start of [Reduction_Table_Step2I]"
    print #IREX, "ReducIndex  AirMassBack   AirMassForward   ReducDelta.i   ReducDelta.io    CompCountAvg"

    for ReducIndex = 1 to ReducIndexMax
                                                'find the variable star with filter = I
        if (ReducType$(ReducIndex)) = "V" OR (ReducType$(ReducIndex)) = "Q" AND ((ReducFilter$(ReducIndex)) = "I" OR (ReducFilter$(ReducIndex)) = "z") then
                                                'get the back and forward comp star counts and air masses
            for I = ReducIndex to 1 step -1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "I") OR (ReducFilter$(I) = "z")) then
                    CompCountBack = ReducCount(I)
                    AirMassBack = ReducX(I)
                    exit for
                end if
            next
            for I = ReducIndex to ReducIndexMax step 1
                if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "I") OR (ReducFilter$(I) = "z")) then
                    CompCountForward = ReducCount(I)
                    AirMassForward = ReducX(I)
                    exit for
                end if
            next
            CompCountAvg = (CompCountBack + CompCountForward)/2
            AirMassAvg = (AirMassBack + AirMassForward)/2
                                                'calculate delta i using equation 2.35
            ReducDelta.i(ReducIndex) = -1.0857 * log(ReducCount(ReducIndex)/CompCountAvg)
                                                'calculate delta io using equation 2.43
            if FilterSystem$ = "1" then
                ReducDelta.io(ReducIndex) = ReducDelta.i(ReducIndex) - KI * (ReducX(ReducIndex) - AirMassAvg)
            else
                ReducDelta.io(ReducIndex) = ReducDelta.i(ReducIndex) - Kz * (ReducX(ReducIndex) - AirMassAvg)
            end if

            print #IREX, using("####",ReducIndex);"        ";_
                         using("###.###",AirMassBack);"         ";_
                         using("###.###",AirMassForward);"       ";_
                         using("####.###",ReducDelta.i(ReducIndex));"       ";_
                         using("####.###",ReducDelta.io(ReducIndex));"          ";_
                         using("########",CompCountAvg)
        end if
    next
    print #IREX, " "
    IdataFlag = 1
    ON ERROR goto [errorHandler]
return
'
'
[Reduction_Table_Step3BV]                        'reduction for v and b-v

    print #IREX, "Start of [Reduction_Table_Step3BV]"
    print #IREX, "ReducIndex  AirMassAverage.Comp   delta.bv   delta.bovo   ReducDelta.BV    ReducDelta.V"

    if RdataFlag = 0 and EpsilonFlag = 0 then    'if no R data and using epsR, display error notice
        notice  "ERROR"+chr$(13)+"there must be R (i') data if using epsR"+chr$(13)+_
                "suggest change to epsilon for B-V (g'-r')"
        print #reduc.Start, "Start"
'        print #reduc.Start, "!Disable"
        close #IREX
        wait
    end if

    direction = 1
    for ReducIndex = 1 to ReducIndexMax
                                                'associate the delta b and v to each other
        if (ReducDelta.b(ReducIndex) <> 0) AND (direction = 1) then
            select case
                case ReducDelta.v(ReducIndex + 1) <> 0
                    direction = 1
                    delta.bv = ReducDelta.b(ReducIndex) - ReducDelta.v(ReducIndex + 1)
                    delta.vo = ReducDelta.vo(ReducIndex + 1)
                    delta.vo.index = ReducIndex + 1
                case ReducDelta.v(ReducIndex - 1) <> 0
                    direction = 0
                case else
                    notice "cannot associate delta v to a delta b"
                    wait
            end select
        end if
        if (ReducDelta.b(ReducIndex) <> 0) AND (direction = 0) then
            select case
                case ReducDelta.v(ReducIndex - 1) <> 0
                    direction = 0
                    delta.bv = ReducDelta.b(ReducIndex) - ReducDelta.v(ReducIndex - 1)
                    delta.vo = ReducDelta.vo(ReducIndex - 1)
                    delta.vo.index = ReducIndex - 1
                case ReducDelta.v(ReducIndex + 1) <> 0
                    direction = 1
                case else
                    notice "cannot associate delta v to a delta b"
                    wait
            end select
        end if
                                                    'get the back and forward comp air masses
        for I = ReducIndex to 1 step -1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "V") OR (ReducFilter$(I) = "r")) then
                AirMassBack.V = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to ReducIndexMax step 1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "V") OR (ReducFilter$(I) = "r")) then
                AirMassForward.V = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to 1 step -1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "B") OR (ReducFilter$(I) = "g"))then
                AirMassBack.B = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to ReducIndexMax step 1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "B") OR (ReducFilter$(I) = "g")) then
                AirMassForward.B = ReducX(I)
                exit for
            end if
        next

        if (ReducDelta.b(ReducIndex) <> 0) then
            AirMassAverage.Comp = (AirMassBack.V + AirMassForward.V + AirMassBack.B + AirMassForward.B)/4
                                                'instrument delta(b-v)o using equation 2.46
            if FilterSystem$ = "1" then
                delta.bovo = delta.bv - (KB - KV) * (ReducX(ReducIndex) - AirMassAverage.Comp) -_
                         KKbv * delta.bv * ((ReducX(ReducIndex) + AirMassAverage.Comp)/2)
                                                'standard delta(B-V) using equation 2.49
                ReducDelta.BV(ReducIndex) = Mu * delta.bovo
            else
                delta.bovo = delta.bv - (Kg - Kr) * (ReducX(ReducIndex) - AirMassAverage.Comp) -_
                         KKgr * delta.bv * ((ReducX(ReducIndex) + AirMassAverage.Comp)/2)
                                                'standard delta(B-V) using equation 2.49
                ReducDelta.BV(ReducIndex) = SMu * delta.bovo
            end if

            if EpsilonFlag = 1 then             'caculate standard V if using epsilon from B-V
                                                'standard delta V using equation 2.48
                if FilterSystem$ = "1" then
                    ReducDelta.V(delta.vo.index) = delta.vo + Eps * ReducDelta.BV(ReducIndex)
                else
                    ReducDelta.V(delta.vo.index) = delta.vo + SEps * ReducDelta.BV(ReducIndex)
                end if
                                                'standard V magnitude using equation 2.51
                ReducV(delta.vo.index) = CompV + ReducDelta.V(delta.vo.index)
            end if
                                                'standard B-V index using equation 2.52
            ReducBV(ReducIndex) = CompBV + ReducDelta.BV(ReducIndex)

                        print #IREX, using("####",ReducIndex);"         ";_
                         using("###.###",AirMassAverage.Comp);"             ";_
                         using("###.###",delta.bv);"     ";_
                         using("####.###",delta.bovo);"     ";_
                         using("####.###",ReducDelta.BV(ReducIndex));"       ";_
                         using("####.###",ReducDelta.V(delta.vo.index))
        end if

    next
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step3V]
    print #IREX, "Start of [Reduction_Table_Step3V]"
    print #IREX, "ReducIndex   ReducV"

    for ReducIndex = 1 to ReducIndexMax step 1
        ReducV(ReducIndex) = CompV + ReducDelta.vo(ReducIndex)
        if ReducV(ReducIndex) = CompV then
            ReducV(ReducIndex) = 0
        end if
        print #IREX, using("####",ReducIndex);"      ";using("####.###",ReducV(ReducIndex))

    next
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_AllSky_Step3BV]
    if EpsilonFlag = 0 then    'if epsilon set for V-R
        notice  "ERROR"+chr$(13)+"All Sky reduction only works for epsilon set for B-V or g-r"
        print #reduc.Start, "Start"
        print #reduc.Start, "!Disable"
        close #IREX
        wait
    end if

    print #IREX, "Start of [Reduction_Table_AllSky_Step3BV]"
    print #IREX, "ReducIndex  ReducX   delta.bv   delta.bovo   Reduc.BV    Reduc.V"

    direction = 1
    for ReducIndex = 1 to ReducIndexMax
                                                'associate the delta b and v to each other
        if (ReducDelta.b(ReducIndex) <> 0) AND (direction = 1) then
            select case
                case ReducDelta.v(ReducIndex + 1) <> 0
                    direction = 1
                    delta.bv = ReducDelta.b(ReducIndex) - ReducDelta.v(ReducIndex + 1)
                    delta.vo = ReducDelta.vo(ReducIndex + 1)
                    delta.vo.index = ReducIndex + 1
                case ReducDelta.v(ReducIndex - 1) <> 0
                    direction = 0
                case else
                    notice "cannot associate delta v to a delta b"
                    wait
            end select
        end if
        if (ReducDelta.b(ReducIndex) <> 0) AND (direction = 0) then
            select case
                case ReducDelta.v(ReducIndex - 1) <> 0
                    direction = 0
                    delta.bv = ReducDelta.b(ReducIndex) - ReducDelta.v(ReducIndex - 1)
                    delta.vo = ReducDelta.vo(ReducIndex - 1)
                    delta.vo.index = ReducIndex - 1
                case ReducDelta.v(ReducIndex + 1) <> 0
                    direction = 1
                case else
                    notice "cannot associate delta v to a delta b"
                    wait
            end select
        end if

        if (ReducDelta.b(ReducIndex) <> 0) then

            if FilterSystem$ = "1" then             'calculate B-V using equation 2.10
                delta.bovo = delta.bv - (KB - KV) * (ReducX(ReducIndex)) -_
                         KKbv * delta.bv * (ReducX(ReducIndex))
                ReducBV(ReducIndex) = Mu * delta.bovo + ZPbv
            else                                    'calculate g'-r' using equation 2.10
                delta.bovo = delta.bv - (Kg - Kr) * (ReducX(ReducIndex)) -_
                         KKgr * delta.bv * (ReducX(ReducIndex))
                ReducBV(ReducIndex) = SMu * delta.bovo + ZPgr
            end if

            if EpsilonFlag = 1 then             'caculate standard V if using epsilon from B-V
                                                'standard delta V using equation 2.9
                if FilterSystem$ = "1" then
                    ReducV(delta.vo.index) = delta.vo + Eps * ReducBV(ReducIndex) + ZPv
                else
                    ReducV(delta.vo.index) = delta.vo + SEps * ReducBV(ReducIndex) +ZPr
                end if
            end if
                        print #IREX, using("####",ReducIndex);"      ";_
                         using("###.###",ReducX(ReducIndex));"    ";_
                         using("###.###",delta.bv);"    ";_
                         using("####.###",delta.bovo);"   ";_
                         using("####.###",ReducBV(ReducIndex));"    ";_
                         using("####.###",ReducV(delta.vo.index))
        end if
    next
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step3VR]                       'reduction for v and v-r

    print #IREX, "Start of [Reduction_Table_Step3VR]"
    print #IREX, "ReducIndex  AirMassAverage.Comp   delta.vr   delta.voro   ReducDelta.VR    ReducDelta.V"

    if BdataFlag = 0 and EpsilonFlag =1 then    'if no B data and using eps, display error notice
        notice  "ERROR"+chr$(13)+"there must be B (g') data if using epsilon"+chr$(13)+_
                "suggest change to epsilon for V-R (r'-i')"
        print #reduc.Start, "Start"
'         print #reduc.Start, "!Disable"
        close #IREX
        wait
    end if

    direction = 1
    for ReducIndex = 1 to ReducIndexMax
                                                'associate the delta r and v to each other
        if (ReducDelta.r(ReducIndex) <> 0) AND (direction = 1) then
            select case
                case ReducDelta.v(ReducIndex + 1) <> 0
                    direction = 1
                    delta.vr = ReducDelta.v(ReducIndex + 1) - ReducDelta.r(ReducIndex)
                    delta.vo = ReducDelta.vo(ReducIndex + 1)
                    delta.vo.index = ReducIndex + 1
                case ReducDelta.v(ReducIndex - 1) <> 0
                    direction = 0
                case else
                    notice "cannot associate delta v to a delta r"
                    wait
            end select
        end if
        if (ReducDelta.r(ReducIndex) <> 0) AND (direction = 0) then
            select case
                case ReducDelta.v(ReducIndex - 1) <> 0
                    direction = 0
                    delta.vr = ReducDelta.v(ReducIndex - 1) - ReducDelta.r(ReducIndex)
                    delta.vo = ReducDelta.vo(ReducIndex - 1)
                    delta.vo.index = ReducIndex - 1
                case ReducDelta.v(ReducIndex + 1) <> 0
                    direction = 1
                case else
                    notice "cannot associate delta v to a delta r"
                    wait
            end select
        end if

                                                    'get the back and forward comp air masses
        for I = ReducIndex to 1 step -1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "V") OR (ReducFilter$(I) = "r")) then
                AirMassBack.V = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to ReducIndexMax step 1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "V") OR (ReducFilter$(I) = "r")) then
                AirMassForward.V = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to 1 step -1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "R") OR (ReducFilter$(I) = "i")) then
                AirMassBack.R = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to ReducIndexMax step 1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "R") OR (ReducFilter$(I) = "i")) then
                AirMassForward.R = ReducX(I)
                exit for
            end if
        next

        if (ReducDelta.r(ReducIndex) <> 0) then
            AirMassAverage.Comp = (AirMassBack.V + AirMassForward.V + AirMassBack.R + AirMassForward.R)/4
                                                'instrument delta(v-r)o using equation 2.
            if FilterSystem$ = "1" then
                delta.voro = delta.vr - (KV - KR) * (ReducX(ReducIndex) - AirMassAverage.Comp)
                                                'standard delta(V-R) using equation 2.49
                ReducDelta.VR(ReducIndex) = Tau * delta.voro
            else
                delta.voro = delta.vr - (Kr - Ki) * (ReducX(ReducIndex) - AirMassAverage.Comp)
                                                'standard delta(V-R) using equation 2.49
                ReducDelta.VR(ReducIndex) = STau * delta.voro
            end if

            if EpsilonFlag = 0 then             'compute standard V if using epsilon R
                                                'standard delta V using equation 2.48
                if FilterSystem$ = "1" then
                    ReducDelta.V(delta.vo.index) = delta.vo + EpsR * ReducDelta.VR(ReducIndex)
                else
                    ReducDelta.V(delta.vo.index) = delta.vo + SEpsR * ReducDelta.VR(ReducIndex)
                end if
                                                'standard V magnitude using equation 2.51
                ReducV(delta.vo.index) = CompV + ReducDelta.V(delta.vo.index)
            end if
                                                'standard V-R index using equation 2.52
            ReducVR(ReducIndex) = CompVR + ReducDelta.VR(ReducIndex)

                        print #IREX, using("####",ReducIndex);"         ";_
                         using("###.###",AirMassAverage.Comp);"             ";_
                         using("###.###",delta.vr);"     ";_
                         using("####.###",delta.voro);"     ";_
                         using("####.###",ReducDelta.VR(ReducIndex));"       ";_
                         using("####.###",ReducDelta.V(delta.vo.index))
        end if

    next
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step3VI]                       'reduction for v and v-i

    print #IREX, "Start of [Reduction_Table_Step3VI]"
    print #IREX, "ReducIndex  AirMassAverage.Comp   delta.vi   delta.voio   ReducDelta.VI    ReducDelta.V"

    for ReducIndex = 1 to ReducIndexMax
                                                'associate the delta i and v to each other
                                                'there should always be a VRI reading so, go
                                                'back 2 to get v
        if (ReducDelta.i(ReducIndex) <> 0) then
            select case
                case ReducDelta.v(ReducIndex - 2) <> 0
                    direction = 0
                    delta.vi = ReducDelta.v(ReducIndex - 2) - ReducDelta.i(ReducIndex)
                    delta.vo = ReducDelta.vo(ReducIndex - 2)
                    delta.vo.index = ReducIndex -2
                case else
                    notice "cannot 1 associate delta v to a delta i"+chr$(13)+_
                           "there should always be a VRI reading to get I"
                    wait
            end select
        end if
                                   'get the back and forward comp air masses
        for I = ReducIndex to 1 step -1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "V") OR (ReducFilter$(I) = "r")) then
                AirMassBack.V = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to ReducIndexMax step 1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "V") OR (ReducFilter$(I) = "r")) then
                AirMassForward.V = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to 1 step -1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "I") OR (ReducFilter$(I) = "z")) then
                AirMassBack.I = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to ReducIndexMax step 1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "I") OR (ReducFilter$(I) = "z")) then
                AirMassForward.I = ReducX(I)
                exit for
            end if
        next

        if (ReducDelta.i(ReducIndex) <> 0) then
            AirMassAverage.Comp = (AirMassBack.V + AirMassForward.V + AirMassBack.I + AirMassForward.I)/4
                                                'instrument delta(v-r)o using equation 2.
            if FilterSystem$ = "1" then
                delta.voio = delta.vi - (KV - KI) * (ReducX(ReducIndex) - AirMassAverage.Comp)
                                                'standard delta(V-I) using equation 2.49
                ReducDelta.VI(ReducIndex) = Eta * delta.voio
            else
                delta.voio = delta.vi - (Kr - Kz) * (ReducX(ReducIndex) - AirMassAverage.Comp)
                                                'standard delta(V-I) using equation 2.49
                ReducDelta.VI(ReducIndex) = SEta * delta.voio
            end if
                                                'standard V-I index using equation 2.52
            ReducVI(ReducIndex) = CompVI + ReducDelta.VI(ReducIndex)

                        print #IREX, using("####",ReducIndex);"         ";_
                         using("###.###",AirMassAverage.Comp);"             ";_
                         using("###.###",delta.vi);"     ";_
                         using("####.###",delta.voio);"     ";_
                         using("####.###",ReducDelta.VI(ReducIndex));"       ";_
                         using("####.###",ReducDelta.V(delta.vo.index))
        end if
    next
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Reduction_Table_Step3UB]                       'reduction for u and u-b

    print #IREX, "Start of [Reduction_Table_Step3UB]"
    print #IREX, "ReducIndex  AirMassAverage.Comp   delta.ub   delta.uobo   ReducDelta.UB    CompUB"

    direction = 1
    for ReducIndex = 1 to ReducIndexMax
                                                'associate the delta u and b to each other
        if (ReducDelta.u(ReducIndex) <> 0) AND (direction = 1) then
            select case
                case ReducDelta.b(ReducIndex + 1) <> 0
                    direction = 1
                    delta.ub = ReducDelta.u(ReducIndex) - ReducDelta.b(ReducIndex + 1)
                    delta.bo = ReducDelta.bo(ReducIndex + 1)
                    delta.bo.index = ReducIndex + 1
                case ReducDelta.b(ReducIndex - 1) <> 0
                    direction = 0
                case else
                    notice "cannot associate delta u to a delta b Dir =1"
                    wait
            end select
        end if
        if (ReducDelta.u(ReducIndex) <> 0) AND (direction = 0) then
            select case
                case ReducDelta.b(ReducIndex - 1) <> 0
                    direction = 0
                    delta.ub = ReducDelta.u(ReducIndex) - ReducDelta.b(ReducIndex - 1)
                    delta.bo = ReducDelta.bo(ReducIndex - 1)
                    delta.bo.index = ReducIndex - 1
                case ReducDelta.b(ReducIndex + 1) <> 0
                    direction = 1
                case else
                    notice "cannot associate delta u to a delta b"
                    wait
            end select
        end if

                                                    'get the back and forward comp air masses
        for I = ReducIndex to 1 step -1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "U") OR (ReducFilter$(I) = "u")) then
                AirMassBack.U = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to ReducIndexMax step 1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "U") OR (ReducFilter$(I) = "u")) then
                AirMassForward.U = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to 1 step -1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "B") OR (ReducFilter$(I) = "g")) then
                AirMassBack.B = ReducX(I)
                exit for
            end if
        next
        for I = ReducIndex to ReducIndexMax step 1
            if (ReducType$(I) = "C") AND ((ReducFilter$(I) = "B") OR (ReducFilter$(I) = "g")) then
                AirMassForward.B = ReducX(I)
                exit for
            end if
        next

        if (ReducDelta.u(ReducIndex) <> 0) then
            AirMassAverage.Comp = (AirMassBack.B + AirMassForward.B + AirMassBack.U + AirMassForward.U)/4
                                                'instrument delta(v-r)o using equation 2.
            if FilterSystem$ = "1" then
                delta.uobo = delta.ub - (KU - KB) * (ReducX(ReducIndex) - AirMassAverage.Comp)
                                                'standard delta(V-R) using equation 2.49
                ReducDelta.UB(ReducIndex) = Psi * delta.uobo
            else
                delta.uobo = delta.ub - (Ku - Kg) * (ReducX(ReducIndex) - AirMassAverage.Comp)
                                                'standard delta(V-R) using equation 2.49
                ReducDelta.UB(ReducIndex) = SPsi * delta.uobo
            end if
                                                'standard U-B index using equation 2.52
            ReducUB(ReducIndex) = CompUB + ReducDelta.UB(ReducIndex)

                        print #IREX, using("####",ReducIndex);"         ";_
                         using("###.###",AirMassAverage.Comp);"             ";_
                         using("###.###",delta.ub);"     ";_
                         using("####.###",delta.uobo);"     ";_
                         using("####.###",ReducDelta.UB(ReducIndex));"       ";_
                         using("####.###",CompUB)
        end if
    next
    print #IREX, " "
    ON ERROR goto [errorHandler]
return
'
[Report_Results]
                                            'compute mean V magnitude with standard deviation
    I = 0
    ReducV.total = 0
    for ReducIndex = 1 to ReducIndexMax
        if ReducV(ReducIndex) <> 0 then
            I = I + 1
            ReducV.total = ReducV.total + ReducV(ReducIndex)
        end if
    next
    ReducV.average = ReducV.total/I

    print #IREX, " "
    print #IREX, "start of [Report_Results]"
    print #IREX, "ReducV.average = "+using("##.####", ReducV.average)
    print #IREX, " "

    N = 0
    ReducV.deviation = 0

    print #IREX, "ReducIndex   ReducV     ReducV.deviation"
    for ReducIndex = 1 to ReducIndexMax
        if ReducV(ReducIndex) <> 0 then
            N = N + 1
            ReducV.deviation = (ReducV(ReducIndex) - ReducV.average)^2 + ReducV.deviation

            print #IREX, using("####",ReducIndex)+"       "+using("###.####",ReducV(ReducIndex))+_
                         "   "+using("###.######",ReducV.deviation)
        end if

    next

    if N > 2 then
                                            'standard deviation of all V magnitudes using equation 3.9
        ReducV.std.deviation = sqr(ReducV.deviation/(N-1))

        if CompFlag = 0 then                'add in standard error from zero points
            ReducV.std.deviation = sqr(ReducV.std.deviation^2 + Ev^2)
        end if
                                            'check to see of value is zero and change to +/-0.001 if it is
        TestValue = ReducV.std.deviation
        gosub [TestZero]
        ReducV.std.deviation = TestValue
    else
        ReducV.std.deviation = 0
    end if

    print #IREX, " "
    print #IREX, "ReducV.std.deviation  "; using("###.####",ReducV.std.deviation)
                                            'compute standard B-V if there is filter data
    if FilterFlagB >= 3 then
        I = 0
        ReducBV.total = 0
        for ReducIndex = 1 to ReducIndexMax
            if ReducBV(ReducIndex) <> 0 then
                I = I + 1
                ReducBV.total = ReducBV.total + ReducBV(ReducIndex)
            end if
        next
        ReducBV.average = ReducBV.total/I
                                            'check to see of value is zero and change to +/-0.001 if it is
        TestValue = ReducBV.average
        gosub [TestZero]
        ReducBV.average = TestValue

        N = 0
        ReducBV.deviation = 0
        for ReducIndex = 1 to ReducIndexMax
            if ReducBV(ReducIndex) <> 0 then
                N = N + 1
                ReducBV.deviation = (ReducBV(ReducIndex) - ReducBV.average)^2 + ReducBV.deviation
            end if
        next
        if N > 2 then
                                            'standard deviation of all B-V indexes using equation 3.6
            ReducBV.std.deviation = sqr(ReducBV.deviation/(N-1))

            if CompFlag = 0 then                'add in standard error from zero points
                ReducBV.std.deviation = sqr(ReducBV.std.deviation^2 + Ebv^2)
            end if
                                            'check to see of value is zero and change to +/-0.001 if it is
            TestValue = ReducBV.std.deviation
            gosub [TestZero]
            ReducBV.std.deviation = TestValue

        else
            ReducBV.std.deviation = 0
        end if
    end if

    print #IREX, " "
    print #IREX, "ReducBV.average       "; using("###.####",ReducBV.average)
    print #IREX, "ReducBV.std.deviation "; using("###.####",ReducBV.std.deviation)

                                            'print results in Analysis textbox with errors
    Temp$ = using("####.###",ReducV.average)+chr$(177)+_
            using("#.###",ReducV.std.deviation)+chr$(13)+chr$(10)

            if FilterFlagB >= 3 then
                Temp$ = Temp$ + using("####.###",ReducBV.average)+chr$(177)+_
                                using("#.###",ReducBV.std.deviation)+chr$(13)+chr$(10)
            else
                Temp$ = Temp$ + " - - - - - - - "+chr$(13)+chr$(10)
            end if

            JDlabel$ = "  JD "
            GeocentricJD.Mean = J2000.Mean
            if JDFlag = 0 then
                JDtemporary = J2000.Mean
                gosub [JDtoHJD]
                J2000.Mean = JDtemporary
                JDlabel$ = " HJD "
            end if

            Temp$ = Temp$ + JDlabel$ + using("####.####",J2000.Mean)

    print #reduc.Analysis, Temp$

return

[Report_Results2]

    if FilterFlagR >= 3 then                'compute standard V-R index if R filter is used
        I = 0
        ReducVR.total = 0
        for ReducIndex = 1 to ReducIndexMax
            if ReducVR(ReducIndex) <> 0 then
                I = I + 1
                ReducVR.total = ReducVR.total + ReducVR(ReducIndex)
            end if
        next
        ReducVR.average = ReducVR.total/I
                                            'check to see of value is zero and change to +/-0.001 if it is
        TestValue = ReducVR.average
        gosub [TestZero]
        ReducVR.average = TestValue

        N = 0
        ReducVR.deviation = 0
        for ReducIndex = 1 to ReducIndexMax
            if ReducVR(ReducIndex) <> 0 then
                N = N + 1
                ReducVR.deviation = (ReducVR(ReducIndex) - ReducVR.average)^2 + ReducVR.deviation
            end if
        next
        if N > 2 then
                                            'standard deviation of all V-R indexes using equation 3.6
            ReducVR.std.deviation = sqr(ReducVR.deviation/(N-1))

                                            'check to see of value is zero and change to +/-0.001 if it is
            TestValue = ReducVR.std.deviation
            gosub [TestZero]
            ReducVR.std.deviation = TestValue

        else
            ReducVR.std.deviation = 0
        end if
    end if

    print #IREX, " "
    print #IREX, "start of [Report_Results2]"
    print #IREX, "ReducVR.average       "; using("###.####",ReducVR.average)
    print #IREX, "ReducVR.std.deviation "; using("###.####",ReducVR.std.deviation)

    if FilterFlagI >= 3 then                'comput standard V-I index if I filter is used
        I = 0
        ReducVI.total = 0
        for ReducIndex = 1 to ReducIndexMax
            if ReducVI(ReducIndex) <> 0 then
                I = I + 1
                ReducVI.total = ReducVI.total + ReducVI(ReducIndex)
            end if
        next
        ReducVI.average = ReducVI.total/I
                                            'check to see of value is zero and change to +/-0.001 if it is
        TestValue = ReducVI.average
        gosub [TestZero]
        ReducVI.average = TestValue

        N = 0
        ReducVI.deviation = 0
        for ReducIndex = 1 to ReducIndexMax
            if ReducVI(ReducIndex) <> 0 then
                N = N + 1
                ReducVI.deviation = (ReducVI(ReducIndex) - ReducVI.average)^2 + ReducVI.deviation
            end if
        next
        if N > 2 then
                                            'standard deviation of all V-I indexes using equation 3.6
            ReducVI.std.deviation = sqr(ReducVI.deviation/(N-1))

                                            'check to see of value is zero and change to +/-0.001 if it is
            TestValue = ReducVI.std.deviation
            gosub [TestZero]
            ReducVI.std.deviation = TestValue

        else
            ReducVI.std.deviation = 0
        end if
    end if

    print #IREX, " "
    print #IREX, "ReducVI.average       "; using("###.####",ReducVI.average)
    print #IREX, "ReducVI.std.deviation "; using("###.####",ReducVI.std.deviation)

    if FilterFlagU >= 3 then                'comput standard U-B index if U filter is used
        I = 0
        ReducUB.total = 0
        for ReducIndex = 1 to ReducIndexMax
            if ReducUB(ReducIndex) <> 0 then
                I = I + 1
                ReducUB.total = ReducUB.total + ReducUB(ReducIndex)
            end if
        next
        ReducUB.average = ReducUB.total/I
                                            'check to see of value is zero and change to +/-0.001 if it is
        TestValue = ReducUB.average
        gosub [TestZero]
        ReducUB.average = TestValue

        N = 0
        ReducUB.deviation = 0
        for ReducIndex = 1 to ReducIndexMax
            if ReducUB(ReducIndex) <> 0 then
                N = N + 1
                ReducUB.deviation = (ReducUB(ReducIndex) - ReducUB.average)^2 + ReducUB.deviation
            end if
        next
        if N > 2 then
                                            'standard deviation of all U-B indexes using equation 3.6
            ReducUB.std.deviation = sqr(ReducUB.deviation/(N-1))

                                            'check to see of value is zero and change to +/-0.001 if it is
            TestValue = ReducUB.std.deviation
            gosub [TestZero]
            ReducUB.std.deviation = TestValue

        else
            ReducUB.std.deviation = 0
        end if
    end if

    print #IREX, " "
    print #IREX, "ReducUB.average       "; using("###.####",ReducUB.average)
    print #IREX, "ReducUB.std.deviation "; using("###.####",ReducUB.std.deviation)

                                            'print results in Analysis2 textbox with errors
    if FilterFlagU >= 3 then
        Temp$ =  using("####.###",ReducUB.average)+chr$(177)+_
                 using("#.###",ReducUB.std.deviation)+chr$(13)+chr$(10)
    else
        Temp$ = " - - - - - - - "+chr$(13)+chr$(10)
    end if
    if FilterFlagR >= 3 then
        Temp$ = Temp$ + using("####.###",ReducVR.average)+chr$(177)+_
                        using("#.###",ReducVR.std.deviation)+chr$(13)+chr$(10)
    else
        Temp$ = Temp$ + " - - - - - - - "+chr$(13)+chr$(10)
    end if
    if FilterFlagI >= 3 then
        Temp$ = Temp$ + using("####.###",ReducVI.average)+chr$(177)+_
                        using("#.###",ReducVI.std.deviation)+chr$(13)+chr$(10)
    else
        Temp$ = Temp$ + " - - - - - - - "+chr$(13)+chr$(10)
    end if
    print #reduc.Analysis2, Temp$

return
'
'
'====subroutines for file operations
'
'
[Find_File_Name]        'seperate out filename and extension from info() path/filename
    FileNameIndex = len(DataFile$)
    FileNameLength = len(DataFile$)
    while mid$(DataFile$, FileNameIndex,1)<>"\"               'look for the last backlash
        FileNameIndex = FileNameIndex - 1
    wend
    FileNamePath$ = left$(DataFile$, FileNameIndex)
    DataFileName$ = right$(DataFile$, FileNameLength-FileNameIndex)

    print #reduc.FileName, DataFileName$                      'display filename in "File" textbox

    print #IREX, DataFileName$

return
'
'=====subroutines for calculations
'
[TestZero]              'check to see if value is zero and change to +/-0.001 if necessary
    if abs(TestValue) < 0.0006 then
        if TestValue >= 0 then
            TestValue = 0.001
        else
            TestValue = -0.001
        end if
    end if
return
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
    MST = 280.46061837 + 360.98564736629 * JD(RawIndex) + 0.000387933 * JT(RawIndex) *_
          JT(RawIndex) - (JT(RawIndex) * JT(RawIndex) * JT(RawIndex))/38710000
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
[Find_Air_Mass]                       'compute air mass
    HA = LMST - RA                    'find hour angle in degrees
    if HA < 0 then
        HA = HA + 360
    end if

    HAradians = HA * 3.1416/180       'convert to radians
    DECradians = DEC * 3.1416/180
    LATradians = LAT * 3.1416/180

                    'compute secant of zenith angle - distance from zenith in radians
    secZ = 1/(sin(LATradians) * sin(DECradians) + cos(LATradians) * cos(DECradians) * cos(HAradians))
                    'compute air mass using Hardie equation
                    'X = sec Z - 0.0018167(sec Z - 1) - 0.002875(sec Z - 1)^2 - 0.0008083(sec Z - 1)^3
    AirMass = secZ - 0.0018167 * (secZ - 1) - 0.002875 * (secZ - 1)^2 - 0.0008083 * (secZ - 1)^3
return
'
function JDtoCAL$(JD)                   'J2000 day to calendar day and time
                                        'from web page at: www.tamuk.edu/math/scott/stars/jcal.htm
    JD = JD + 2451545.0                 'add J2000 days from start at 4713 BC
    z = int(JD + 0.5)
    f = JD + 0.5 - int(JD + 0.5)
    aa = int((z - 1867216.25) / 36524.25)
    a = z + 1 + aa - int(aa / 4)
    b = a + 1524
    c = int((b - 122.1) / 365.25)
    dd = int(365.25 * c)
    e = int((b - dd) / 30.6001)
    if e < 13.5 then
        mm = e - 1
    else
        mm = e - 13
    end if
    if mm > 2.5 then
        yy = c - 4716
    else
        yy = c - 4715
    end if
    dd = b - dd - int(30.6001 * e) + f
    hr = dd - int(dd)
    dd = dd - hr
    hr = hr * 24
    mn = hr - int(hr)
    hr = hr - mn
    mn = mn * 60
    ss = mn - int(mn)
    mn = mn - ss
    ss = ss * 60
    JDtoCAL$ = using("##", dd)+"/"+using("##", mm)+"/"+using("####", yy)+"  "+_
               using("##", hr)+":"+using("##", mn)+":"+using("##", ss)
end function
'
[JDtoHJD]
                                        'from section 5.3e of Astronomical Photometry, pages 113 - 116
    T = (JDtemporary - 36525)/36525

    SolLongitude = 279.696678 + 36000.76892 * T + 0.000303 * T^2_
                     - (1.39604 + 0.000308 * (T + 0.5)) * (T - 0.499998)

    SolAnomaly = 358.475833 + 35999.04975 * T - 0.00015 * T^2

    shit = cos(SolLongitude/57.2958)

    Xjd = 0.99986 * cos(SolLongitude/57.2958) - 0.025127 * cos((SolAnomaly - SolLongitude)/57.2958)_
          + 0.008374 * cos((SolAnomaly + SolLongitude)/57.2958)_
          + 0.000105 * cos((2*SolAnomaly + SolLongitude)/57.2958)_
          + 0.000063 * T * cos((SolAnomaly - SolLongitude)/57.2958)_
          + 0.000035 * cos((2 * SolAnomaly - SolLongitude)/57.2958)

    Yjd = 0.917308 * sin(SolLongitude/57.2958) + 0.023053 * sin((SolAnomaly - SolLongitude)/57.2958)_
          + 0.007683 * sin((SolAnomaly + SolLongitude)/57.2958)_
          + 0.000097 * sin((2 * SolAnomaly + SolLongitude)/57.2958)_
          - 0.000057 * T * sin((SolAnomaly - SolLongitude)/57.2958)_
          - 0.000032 * sin((2 * SolAnomaly - SolLongitude)/57.2958)

    DeltaT = -0.0057755 * ((cos(DECVar/57.2958) * cos(RAVar/57.2958)) * Xjd _
             + (tan(0.40928) * sin(DECVar/57.2958) + cos(DECVar/57.2958) * sin(RAVar/57.2958)) * Yjd)

   JDtemporary = JDtemporary + DeltaT
return
'
end


