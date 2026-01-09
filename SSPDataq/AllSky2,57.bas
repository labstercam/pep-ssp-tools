  '                         Calibration Module - All Sky Photometry
'                                      Gerald Persha
'
'======version history

'   compiles with Liberty Basic 4.50
'V2.57 September 2016
'   fixed graph line for end point
'
'V2.56
'
'
'=====dimension statements and initial conditions
'
    DIM info$(10,10)
    files "c:\", info$()

' display listbox arrays
    DIM TransData$(100)                 'data lines for listbox table, #trans.Table, index var = TransIndex
        TransData$(1) = "   "           'cannot use listbox unless something is put in before creation

    DIM TransStar$(100)                 'FOE star names in raw file, index var = TransIndex

    DIM Trans.V(100)                    'V, index var = TransIndex
    DIM Trans.Vv(100)                   'V-vo, index var = TransIndex

    DIM TransStdColor(100)              'B - V standard color index, index var = TransIndex
    DIM TransColor(100)                 '(b - v) instrument colorindex, index var = TransIndex
    DIM TransColor2(100)                '(V-v) - eps(B-V), index var = TransIndex
    DIM TransColor3(100)                '(B-V) - mu(b-v), index var = TransIndex

    DIM RA(100)                         'RA in decimal degrees for each trans star, index var = TransIndex
    DIM DEC(100)                        'DEC in decimal derees for each trans star, index var = TransIndex

' working arrays for computing values in TransData$ listbox table for each filter
' array(TransIndex,Filter)              TransIndex: 1 to 100 for each transformation star

    DIM X(100,2)                        'air mass for each star reading and for each filter
    DIM AvgX(100)                       'average of X in b and v, Index: TransIndex
    DIM m(100,2)                        'instrument magnitude for each filter, b, v, u, r, i

' calibration data file array
    DIM TDitem$(2000,13)                'data items from Transformation Data file, index var = DataIndex
                                        'TDitem$(x,1)  = star name, 8 bytes long
                                        'TDitem$(x,2)  = spectral type, not really needed
                                        'TDitem$(x,3)  = RA hour
                                        'TDitem$(x,4)  = RA minute
                                        'TDitem$(x,5)  = RA second
                                        'TDitem$(x,6)  = DEC degree
                                        'TDitem$(x,7)  = DEC minute
                                        'TDitem$(x,8)  = DEC second
                                        'TDitem$(x,9)  = V magnitude
                                        'TDitem$(x,10) = B-V magnitude
                                        'TDitem$(x,11) = not used
                                        'TDitem$(x,12) = not used
                                        'TDitem$(x,13) = not used

' raw data file arrays
    DIM RawData$(1000)                  'data lines from raw file of observations, index var = RawIndex
    DIM RDitem$(1000,15)                'data items from raw file of observations, index var = RawIndex
                                        'RDitem$(x,1)  = UT month
                                        'RDitem$(x,2)  = UT day
                                        'RDitem$(x,3)  = UT year
                                        'RDitem$(x,4)  = UT hour
                                        'RDitem$(x,5)  = UT minute
                                        'RDitem$(x,6)  = UT second
                                        'RDitem$(x,7)  = catalog, "F" for Calibration star
                                        'RDitem$(x,8)  = object, star name, SKY, SKYNEXT or SKYLAST
                                        'RDitem$(x,9)  = filter, B, V
                                        'RDitem$(x,10) = count 1
                                        'RDitem$(x,11) = count 2
                                        'RDitem$(x,12) = count 3
                                        'RDitem$(x,13) = count 4
                                        'RDitem$(x,14) = integration time, 1 or 10 seconds
                                        'RDitem$(x,15) = scale, 1 10 or 100

    DIM CountFinal(1000)                'average count including integration and scale, index var = RawIndex
    DIM JD(1000)                        'Julean date from 2000 for each RawIndex, index var = RawIndex
    DIM JT(1000)                        'Julean century fromm 2000 for each RawIndex, index var = RawIndex

' other arrays
    DIM Xaxis(100)                      'Xaxis() X airmass
    DIM Yaxis(100)                      'Yaxis() (V-v)-eps(B-V) or (B-V)-mu(b-v)
'
'=====initialize and start up values
'
VersionNumber$ = "2.57"
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
    input #PPparms, ZPgr                'zero-point constant for g'-r'
    input #PPparms, Ev                  'standard error for v
    input #PPparms, Er                  'standard error for r'
    input #PPparms, Ebv                 'standard error for b-v
    input #PPparms, Egr                 'standard error for g'-r'
close #PPparms

gosub [Find_Lat_Long]

            open "IREX.txt" for output as #IREX
                print #IREX, "All Sky Calibration, Veraion "; VersionNumber$
                print #IREX, "PPparms"
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
                print #IREX, "  Egr           "; Egr
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
    Menu        #trans, "File",_
                        "Open File", [Open_File],_
                        "Save Plot Graphic", [Data_Save],_
                        "Quit", [Quit_Extinction]
    Menu        #trans, "Constants",_
                        "Load Saved Constants", [Load_Previous_Coeff],_
                        "Transfer Computed Constants to Results", [Use_Current_Coefficients],_
                        "Save Constants in Results to PPparms", [Save_Coefficients],_
                        "Clear Result Boxes", [Clear_Coefficients]
    Menu        #trans, "Help",_
                        "About", [About],_
                        "Help", [Help]

    graphicbox  #trans.graphicbox1,   515, 40, 490, 265

    groupbox    #trans.groupbox1, "All Sky Stars File", 11, 310, 245, 85
    groupbox    #trans.groupbox2, "Results", 263, 310, 430, 85
    statictext  #trans.statictext52,  "Johnson/Cousins FOE - zero points", 275,327,400,18

    groupbox    #trans.groupbox3, "Least-Squares Analysis", 700, 310, 305, 85

    statictext  #trans.statictext1,  "Star",   30, 20, 40, 14
    statictext  #trans.statictext2,  "X",      147, 20, 10, 14

    statictext  #trans.statictext3,  "V",      197, 20, 29, 14

    statictext  #trans.statictext5,  "(B-V)",  237, 20, 60, 14

    statictext  #trans.statictext8,  "v",      315, 20, 10, 14

    statictext  #trans.statictext11, "(V-",    350, 5, 30, 14
    statictext  #trans.statictext12, "(B-V)",  360, 20, 44, 14
    statictext  #trans.statictext13, "e",      350, 20, 10, 14
    statictext  #trans.statictext50, "v",      379, 5, 10, 14
    statictext  #trans.statictext51, ")-",      389, 5, 20, 14

    statictext  #trans.statictext14, "(B-V)-", 427,  5, 60, 14
    statictext  #trans.statictext15, "(b-v)", 437, 20, 44, 14
    statictext  #trans.statictext16, "m",      427, 20, 10, 14

    statictext  #trans.statictext30,"slope",    787, 337, 50, 14
    statictext  #trans.statictext31,"intercept", 752, 352, 90, 14
    statictext  #trans.statictext32,"standard error", 710, 367, 132, 14
                                                'greek letters for results labels
    statictext  #trans.statictext33,"K'",   295, 341, 20, 16    'K'v
    statictext  #trans.statictext36,"v",    305, 345, 12, 16    '
    statictext  #trans.statictext34,"Z",    365, 341, 10, 16    'ZPv
    statictext  #trans.statictext37,"v",    375, 345, 12, 16
    statictext  #trans.statictext41,"s",    435, 341, 12, 18    'standard error for v
    statictext  #trans.statictext42,"v",    446, 345, 12, 16
    statictext  #trans.statictext35,"K'",   500, 341, 20, 16    'K'bv
    statictext  #trans.statictext38,"bv",   510, 345, 20, 16
    statictext  #trans.statictext39,"Z",    570, 341, 20, 16    'ZPbv
    statictext  #trans.statictext40,"bv",   580, 345, 20, 16
    statictext  #trans.statictext43,"s",    640, 341, 12, 18    'standard error for b-v
    statictext  #trans.statictext44,"bv",   651, 345, 20, 16
                                                'buttons for calculating constants
    button      #trans.ShowKv, "extinction plot for v",[Show_Kv.click],UL, 515, 10, 225, 25
    button      #trans.ShowKbv, "extinction plot for b-v",[Show_Kbv.click],UL, 780, 10, 225, 25

    button      #trans.Print, "print",[DataPrint.click], UL, 940, 360, 57, 25

    textbox     #trans.Kv, 270, 363, 65, 25
    textbox     #trans.ZPv, 340,363,65,25
    textbox     #trans.Ev, 410,363,65,25
    textbox     #trans.Kbv, 480, 363, 65, 25
    textbox     #trans.ZPbv, 550,363,65,25
    textbox     #trans.Ebv, 620,363,65,25

    textbox     #trans.Analysis, 844, 335, 88, 50

    textbox     #trans.FileName, 19, 345, 230, 25

    listbox     #trans.Table, TransData$(),[Transformation_Table.click], 10, 40, 500, 265

    Open "All Sky Calibration - Johnson/Cousins/Sloan Photometry" for Window as #trans
    #trans "trapclose [Quit_Extinction]"
    #trans.graphicbox1 "down; fill White; flush"
    #trans.graphicbox1 "setfocus; when mouseMove [MouseChange1]"
    #trans.Table "selectindex 1"
    #trans "font courier_new 10 14"
                                                    'select greek letters for results box
    print #trans.statictext13, "!font symbol 10 14"
    print #trans.statictext16, "!font symbol 10 14"
    print #trans.statictext41, "!font symbol 10 16"
    print #trans.statictext43, "!font symbol 10 16"

    print #trans.FileName, "open raw data file"

    print #trans.ShowKv, "!Disable"
    print #trans.ShowKbv, "!Disable"
    print #trans.Print, "!Disable"

    FilterSystem$ = "1"             'default filter system
Wait                                'finised setting up, wait here for new command
'
'======menu controls
'
[Open_File]
'
'                                   'clear the graphics screen and turn off buttons
    print #trans.ShowKv, "!Disable"
    print #trans.ShowKbv, "!Disable"
    print #trans.Print, "!Disable"
    print #trans.graphicbox1, "down; fill White; flush"

    filedialog "Open Data File", PathDataFile$, DataFile$

    for I = len(DataFile$) to 1 step -1             'remember path for opened folder and file
        if mid$(DataFile$,I,1) = "\" then
            ShortDataFile$ = mid$(DataFile$,I+1)
            PathDataFile$ = left$(DataFile$,I)+"*raw"
            exit for
        end if
    next I

    if DataFile$ = "" then
        print #trans.FileName, "open raw data file"
    else
        files "c:\", DataFile$, info$()
        if val(info$(0, 0)) = 0 then
            notice "cannot create new file"
        else
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

            print #trans.Kv, ""                     'clear the result boxes
            print #trans.Kbv, ""
            print #trans.ZPv, ""
            print #trans.ZPbv, ""
            print #trans.Ev, ""
            print #trans.Ebv, ""

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Find_File_Name]"
                print #IREX, "filename"
                gosub [Find_File_Name]
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Convert_RawFile]"
                print #IREX, "raw file data"
                gosub [Convert_RawFile]
                print #IREX, " "
            close #IREX

            gosub [Write_Window_Labels]

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Open_Star_Data]"
                if FilterSystem$ = "1" then
                    print #IREX, "star         type  RA         DEC      V     B-V"
                else
                    print #IREX, "star         type  RA         DEC      r     g-r"
                end if
                gosub [Open_Star_Data]
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Total_Count_RawFile]"
                print #IREX, "RawIndex   CountFinal"
                gosub [Total_Count_RawFile]

                print #IREX, " "
            close #IREX

            gosub [Julian_Day_RawFile]

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [IREX_RawFile]"
                print #IREX, "star           Julean date  final count   filter"

                if FilterSystem$ = "1" then
                    Filter$ = "B"
                    gosub [IREX_RawFile]
                    Filter$ = "V"
                    gosub [IREX_RawFile]
                else
                    Filter$ = "g"
                    gosub [IREX_RawFile]
                    Filter$ = "r"
                end if

                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Find_Trans_Stars]"
                print #IREX, "star       TransIndex"
                gosub [Find_Trans_Stars]
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Get_Trans_Star_Data]"
                if FilterSystem$ = "1" then
                    print #IREX, "star              RA        DEC       V      B-V"
                else
                    print #IREX, "star              RA        DEC       r      g-r"
                end if
                gosub [Get_Trans_Star_Data]
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Create_Transformation_Table]"
                print #IREX, "star          LMST       AirMass  CntFinal  InstMag  Filter"
                gosub [Create_Transformation_Table]
                print #IREX, " "
            close #IREX
                                                    'turn on buttons of there is data for each filter

            print #trans.ShowKv, "!Enable"
            print #trans.ShowKbv, "!Enable"

        end if
    end if
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
        print #trans.graphicbox1, "getbmp plot -2 -2 492 267"
        if (right$(PlotFile$,4) = ".bmp") OR (right$(PlotFile$,4) = ".BMP") then
            bmpsave "plot", PlotFile$
        else
            PlotFile$ = PlotFile$+".bmp"
            bmpsave "plot", PlotFile$
        end if
    end if
wait
'
[Load_Previous_Coeff]
    if FilterSystem$ = "1" then
        print #trans.Kv,   using("##.###",KV)
        KBV = KB-KV
        print #trans.Kbv,  using("##.###",KBV)
        print #trans.ZPv,  using("##.###",ZPv)
        print #trans.ZPbv, using("##.###",ZPbv)
        print #trans.Ev,   using("##.###",Ev)
        print #trans.Ebv,  using("##.###",Ebv)
    else
        print #trans.Kv,   using("##.###",Kr)
        Kgr = Kg-Kr
        print #trans.Kbv,  using("##.###",Kgr)
        print #trans.ZPv,  using("##.###",ZPr)
        print #trans.ZPbv, using("##.###",ZPgr)
        print #trans.Er,   using("##.###",Er)
        print #trans.Egr,  using("##.###",Egr)
    end if
Wait
'
[Save_Coefficients]
    print #trans.Kv,   "!contents? KvTemp"
    print #trans.Kbv,  "!contents? KbvTemp"
    print #trans.ZPv,  "!contents? ZPvTemp"
    print #trans.ZPbv, "!contents? ZPbvTemp"
    print #trans.Ev,   "!contents? EvTemp"
    print #trans.Ebv,  "!contents? EbvTemp"

    if KvTemp = 0 AND KbvTemp = 0 AND ZPvTemp = 0 AND ZPbvTemp = 0 then
        notice "nothing to save"
        Wait
    end if

    confirm "This will save all non-zero contents"+chr$(13)_
            +"Type a zero in box to keep previous saved constants"+chr$(13)+chr$(13)_
            +"Do you wish to save values?"; Answer$
    if Answer$ = "yes" then
        if FilterSystem$ = "1" then
            if KvTemp <> 0 then
                KV = KvTemp
            end if
            if KbvTemp <> 0 then
                Kbv = KbvTemp
                KB = Kbv + KV
            end if
            if ZPvTemp <> 0 then
                ZPv = ZPvTemp
            end if
            if ZPbvTemp <> 0 then
                ZPbv = ZPbvTemp
            end if
            if EvTemp <> 0 then
                Ev = EvTemp
            end if
            if EbvTemp <> 0 then
                Ebv = EbvTemp
            end if
        else
            if KvTemp <> 0 then
                Kr = KvTemp
            end if
            if KbvTemp <> 0 then
                Kgr = KbvTemp
                Kg = Kgr + Kr
            end if
            if ZPrTemp <> 0 then
                ZPr = ZPvTemp
            end if
            if ZPgrTemp <> 0 then
                ZPgr = ZPbvTemp
            end if
            if EvTemp <> 0 then
                Er = EvTemp
            end if
            if EbvTemp <> 0 then
                Egr = EbvTemp
            end if
        end if
        gosub [Write_PPparms]
    end if
Wait
'
[Use_Current_Coefficients]
    print #trans.Kv,   using("##.###",Kvtemporary)
    print #trans.Kbv,  using("##.###",Kbvtemporary)
    print #trans.ZPv,  using("##.###",ZPvtemporary)
    print #trans.ZPbv, using("##.###",ZPbvtemporary)
    print #trans.Ev,   using("##.###",Evtemporary)
    print #trans.Ebv,  using("##.###",Ebvtemporary)
Wait
'
[Clear_Coefficients]
    print #trans.Kv, ""
    print #trans.Kbv, ""
    print #trans.ZPv, ""
    print #trans.ZPbv, ""
    print #trans.Ev, ""
    print #trans.Ebv, ""
Wait
'
[About]
    notice "All Sky Calibration - Johnson/Cousins/Sloan Photometry"+chr$(13)+_
           " version "+VersionNumber$+chr$(13)+_
           " copyright 2015, Gerald Persha."+chr$(13)+_
           " www.sspdataq.com"
Wait

[Help]
    run "hh photometry2.chm"
Wait

[MouseChange1]
    'MouseX and MouseY contain mouse coordinates
wait

[Quit_Extinction]                   'exit program
    confirm "do you wish to exit program?"; Answer$

    if Answer$ = "yes" then
        close #trans
        END
    else
        wait
    end if
'
'=====control buttons and control boxes
'
[Show_Kv.click]
    print #trans.Print, "!Enable"
    Kvtemporary = 0
    Graph$ = "eps"
    print #trans.graphicbox1, "cls"
    print #trans.graphicbox1, "color black"

    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "place 7 125"
        print #trans.graphicbox1, "font arial 8 12"
        print #trans.graphicbox1, "\(V-v) -"
        print #trans.graphicbox1, "place 15 145"
        print #trans.graphicbox1, "\(B-V)"
        print #trans.graphicbox1, "place 5 145"
        print #trans.graphicbox1, "font symbol 10 16"
        print #trans.graphicbox1, "\e"
    else
        print #trans.graphicbox1, "place 7 125"
        print #trans.graphicbox1, "font arial 8 12"
        print #trans.graphicbox1, "\(r-"
        print #trans.graphicbox1, "place 30 125"
        print #trans.graphicbox1, "\) -"
        print #trans.graphicbox1, "place 22 125"
        print #trans.graphicbox1, "font arial 8 12 italic"
        print #trans.graphicbox1, "\r"
        print #trans.graphicbox1, "font arial 8 12"
        print #trans.graphicbox1, "place 15 145"
        print #trans.graphicbox1, "\(g-r)"
        print #trans.graphicbox1, "place 6 145"
        print #trans.graphicbox1, "font symbol 10 16"
        print #trans.graphicbox1, "\e"
    end if
    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "place 255 250"
    print #trans.graphicbox1, "\X"

    gosub [Draw_Graph_Outline]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "Coefficient = Kv"
        print #IREX, "star             Xaxis      Yaxis"
        gosub [Create_Regression_Array]
        print #IREX, " "
    close #IREX

    gosub [Solve_Regression_Matrix]
                                                'output to Analysis textbox the results
    print #trans.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                           using("####.###", Intercept) + chr$(13) + chr$(10) +_
                           using("####.###", std.error)

    PointColor$ = "blue"
    print #trans.graphicbox1, "color darkgreen"
    gosub [Draw_Best_Line]

    gosub [Draw_Description]
    print #trans.graphicbox1, "flush"

    Kvtemporary = -1*Slope
    ZPvtemporary = Intercept
    Evtemporary = std.error
wait
'
'
[Show_Kbv.click]
    print #trans.Print, "!Enable"
    Kbvtemporary = 0
    Graph$ = "mu"
    print #trans.graphicbox1, "cls"
    print #trans.graphicbox1, "color black"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "place 7 125"
        print #trans.graphicbox1, "font arial 8 12"
        print #trans.graphicbox1, "\(B-V) -"
        print #trans.graphicbox1, "place 17 145"
        print #trans.graphicbox1, "\(b-v)"
        print #trans.graphicbox1, "place 5 145"
        print #trans.graphicbox1, "font symbol 10 16"
        print #trans.graphicbox1, "\m"
    else
        print #trans.graphicbox1, "place 7 125"
        print #trans.graphicbox1, "font arial 8 12"
        print #trans.graphicbox1, "\(g-r) -"
        print #trans.graphicbox1, "place 6 145"
        print #trans.graphicbox1, "font symbol 10 14"
        print #trans.graphicbox1, "\m"
        print #trans.graphicbox1, "place 16 145"
        print #trans.graphicbox1, "\("
        print #trans.graphicbox1, "place 23 145"
        print #trans.graphicbox1, "font arial 8 12 italic"
        print #trans.graphicbox1, "\g-r"
        print #trans.graphicbox1, "font arial 8 12"
        print #trans.graphicbox1, "place 44 145"
        print #trans.graphicbox1, "\)"
    end if

    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "place 255 250"
    print #trans.graphicbox1, "\X"

    gosub [Draw_Graph_Outline]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "Coefficient = Kbv"
        print #IREX, "star             Xaxis      Yaxis"
        gosub [Create_Regression_Array]
        print #IREX, " "
    close #IREX

    gosub [Solve_Regression_Matrix]
                                                'output to Analysis textbox the results
    print #trans.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                           using("####.###", Intercept) + chr$(13) + chr$(10) +_
                           using("####.###", std.error)

    print #trans.graphicbox1, "color blue"
    gosub [Draw_Best_Line]

    gosub [Draw_Description]
    print #trans.graphicbox1, "flush"
'
    if Kvtemporary = 0 then
        notice "must compute Kv first"
        wait
    end if

    Kbvtemporary = -1*Slope
    ZPbvtemporary = Intercept
    Ebvtemporary = std.error
wait
'
'
[DataPrint.click]

    printerdialog
    if PrinterName$ <> "" then
        print #trans.graphicbox1, "Print VGA"
        dump
    end if
wait
'
[Extinction_Table.click]
    #trans.Table "selection? selected$"
wait
'
'=====subroutines for extracting data from opened raw file
'
[Open_Star_Data]
    if FilterSystem$ = "1" then
        open "FOE Data Version 2.txt" for input as #TransData
    else
        open "FOE Data Version 2 Sloan.txt" for input as #TransData
    end if
    DataIndex = 0
    while eof(#TransData) = 0
        DataIndex = DataIndex + 1
        input #TransData,TDitem$(DataIndex,1),_      'star name
                         TDitem$(DataIndex,2),_      'spectral type
                         TDitem$(DataIndex,3),_      'RA hour
                         TDitem$(DataIndex,4),_      'RA minute
                         TDitem$(DataIndex,5),_      'RA second
                         TDitem$(DataIndex,6),_      'DEC degree
                         TDitem$(DataIndex,7),_      'DEC minute
                         TDitem$(DataIndex,8),_      'DEC second
                         TDitem$(DataIndex,9),_      'V/r magnitude, ##.##
                         TDitem$(DataIndex,10),_     'B-V/g-r index, ##.##
                         TDitem$(DataIndex,11),_
                         TDitem$(DataIndex,12),_
                         TDitem$(DataIndex,13)

        print #IREX,     left$(TDitem$(DataIndex,1)+"        ",12);"  ";_
                         TDitem$(DataIndex,2);"  ";_
                         right$("00"+TDitem$(DataIndex,3),2);":";_
                         right$("00"+TDitem$(DataIndex,4),2);":";_
                         right$("00"+TDitem$(DataIndex,5),2);"  ";_
                         using("###",val(TDitem$(DataIndex,6)));":";_
                         right$("00"+TDitem$(DataIndex,7),2);":";_
                         right$("00"+TDitem$(DataIndex,8),2);"  ";_
                         TDitem$(DataIndex,9);"  ";_
                         TDitem$(DataIndex,10)
    wend
    DataIndexMax = DataIndex
close #TransData
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
        RDitem$(RawIndex,7)  = mid$(RawData$(RawIndex),21,1)       'catalog: T
        RDitem$(RawIndex,8)  = mid$(RawData$(RawIndex),26,12)      'star name
        RDitem$(RawIndex,9)  = mid$(RawData$(RawIndex),41,1)       'filter: B, V
        RDitem$(RawIndex,10) = mid$(RawData$(RawIndex),44,5)       'Count 1
        RDitem$(RawIndex,11) = mid$(RawData$(RawIndex),51,5)       'Count 2
        RDitem$(RawIndex,12) = mid$(RawData$(RawIndex),58,5)       'Count 3
        RDitem$(RawIndex,13) = mid$(RawData$(RawIndex),65,5)       'Count 4
        RDitem$(RawIndex,14) = mid$(RawData$(RawIndex),72,2)       'integration time in seconds: 1 or 10
        RDitem$(RawIndex,15) = mid$(RawData$(RawIndex),75,3)       'scale: 1, 10 or 10

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

    if RDitem$(5,9) = "g" OR RDitem$(5,9) = "r" then
        FilterSystem$ = "0"
    else
        FilterSystem$ = "1"
    end if
return
'
[Write_Window_Labels]
    if FilterSystem$= "1" then
        print  #trans.statictext1,  "Star"
        print  #trans.statictext2,  "X"

        print  #trans.statictext3,  "V"

        print  #trans.statictext5,  "(B-V)"

        print  #trans.statictext8,  "v"

        print  #trans.statictext11, "(V-"
        print  #trans.statictext12, "(B-V)"
        print  #trans.statictext13, "e"
        print  #trans.statictext50, "v)-"

        print  #trans.statictext14, "(B-V)-"
        print  #trans.statictext15, "(b-v)-"
        print  #trans.statictext16, "m"

        print  #trans.ShowKv,       "extinction plot for v"
        print  #trans.ShowKbv,      "extinction plot for b-v"
        print  #trans.statictext52, "Johnson/Cousins FOE - zero points"
    else
        print  #trans.statictext1,  "Star"
        print  #trans.statictext2,  "X"

        print  #trans.statictext3,  "r"

        print  #trans.statictext5,  "(g-r)"

        print  #trans.statictext8, "!font courier_new 10 16 italic"
        print  #trans.statictext8,  "r"

        print  #trans.statictext11, "(r-"
        print  #trans.statictext50, "!font courier_new 10 16 italic"
        print  #trans.statictext50, "r)"

        print  #trans.statictext12, "(g-r)"

        print  #trans.statictext14, "(g-r)-"

        print  #trans.statictext15, "!font courier_new 10 16 italic"
        print  #trans.statictext15, "(g-r)"

        print #trans.ShowKv,        "extinction plot for r"
        print #trans.ShowKbv,       "extinction plot for g-r"
        print #trans.statictext52,  "Sloan FOE - zero points"
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

        print #IREX, using("####", RawIndex)+"       "+using("#######",CountFinal(RawIndex))
    next
return
'
[Julian_Day_RawFile]    'convert UT time and date to Julian, epcoh J2000
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
[Find_Trans_Stars]
                                        'make list of unique transformation stars contained in the raw file
    TransIndexMax = 0                   'reset transformation array index to 0, this will result in 1 being
                                        'the first array item
    for RawIndex = 5 to RawIndexMax
                                        'go through raw file and pick out only the transformation stars with
                                        'the selected filter B or V
        if (RDitem$(RawIndex,7) = "F") then
            TransFlag = 0
                                        'see if the FOE Star is new to the list
            for TransIndex = 1 to TransIndexMax
                if TransStar$(TransIndex) = RDitem$(RawIndex,8) then
                    TransFlag = 1
                end if
            next
            if TransFlag = 0 then       'add the new FOE Star to the list
                TransIndexMax = TransIndexMax + 1
                TransStar$(TransIndexMax) = RDitem$(RawIndex,8)
            end if
        end if
    next
    for TransIndex = 1 to TransIndexMax
        print #IREX, TransStar$(TransIndex);"   ";_     'unique trans star name
                     TransIndex                         'index for star
    next
return
'
[IREX_RawFile]      'subtract skies from transformation star data
    for RawIndex = 5 to RawIndexMax
                    'go through raw file and pick out only the transformation stars with the selected filter
        if (RDitem$(RawIndex,7) = "F")  AND (RDitem$(RawIndex,9) = Filter$) then
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
                    'subtract sky from Trans star count depending on SKY, SKYNEXT or SKYLAST protocol and change
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

            print #IREX,    RDitem$(RawIndex,8);"  ";_                              'star name
                            using("#####.#####",JD(RawIndex));"   ";_               'Julean Date
                            using("#######", CountFinal(RawIndex));"        ";_     'final average count
                            Filter$                                                 'filter
        end if
    next
return
'
'=====subroutines for creating estinction table
'
[Get_Trans_Star_Data]
    redim RA(100)                       'RA in decimal degrees for each trans star, index var = TransIndex
    redim DEC(100)                      'DEC in decimal derees for each trans star, index var = TransIndex
    redim Trans.V(100)                  'V standard magnitude, index var = TransIndex
    redim TransStdColor(100)            'B - V standard color index, index var = TransIndex

                                                    'get RA and DEC info of comp star from Star Data file
    for TransIndex = 1 to TransIndexMax             'go through trans stars contained in raw file
        for DataIndex = 1 to DataIndexMax           'then go through transformation data file

            if TransStar$(TransIndex) = left$(TDitem$(DataIndex,1)+"           ",12) then
                                                    'get RA and convert to decimal
                RA(TransIndex) =            val(TDitem$(DataIndex,3)) +_
                                            val(TDitem$(DataIndex,4))/60 +_
                                            val(TDitem$(DataIndex,5))/3600
                                                    'convert RA to degrees
                RA(TransIndex) = (RA(TransIndex)/24) * 360
                                                    'get and convert DEC to decimal
                DEC(TransIndex) =           abs(val(right$(TDitem$(DataIndex,6),2))) +_
                                            val(TDitem$(DataIndex,7))/60 +_
                                            val(TDitem$(DataIndex,8))/3600
                                                    'see if there is a minus sign in DECd then make DEC negative
                if left$(TDitem$(DataIndex,6),1) = "-"  then
                    DEC(TransIndex) = DEC(TransIndex) * -1
                end if
                                                    'get V magnitude
                Trans.V(TransIndex) =     val(TDitem$(DataIndex,9))
                                                    'get B-V color index
                TransStdColor(TransIndex) = val(TDitem$(DataIndex,10))

            end if
        next
        if (RA(TransIndex) = 0) AND (DEC(TransIndex) = 0) then
            notice "could not find selected Comp Star in Star Data file"
            wait
        end if
        print #IREX, TransStar$(TransIndex);"   ";_
                     using("###.####",RA(TransIndex));"  ";_
                     using("###.####",DEC(TransIndex));"  ";_
                     using("###.##",Trans.V(TransIndex));"  ";_
                     using("###.##",TransStdColor(TransIndex))
    next
return
'
                                'create ExtData() for display in listbox
[Create_Transformation_Table]
    redim TransData$(100)
    redim X(100,2)                          'air mass for each star reading and for each filter
    redim m(100,2)                          'instrument mag. for each filter, b, v

    for TransIndex = 1 to TransIndexMax
        for RawIndex = 5 to RawIndexMax
            if TransStar$(TransIndex) = RDitem$(RawIndex,8) then
                gosub [Siderial_Time]
                gosub [Find_Air_Mass]
                InstrumentMag = -1.0857*log(CountFinal(RawIndex))                   'ln(x) = 2.3026 * log(x)
                FilterID$ =  RDitem$(RawIndex,9)
                select case
                    case (FilterID$ = "B") OR (FilterID$ = "g")
                        m(TransIndex,1) = InstrumentMag                             'b
                        X(TransIndex,1) = AirMass
                    case (FilterID$ = "V") OR (FilterID$ = "r")
                        m(TransIndex,2) = InstrumentMag                             'v
                        X(TransIndex,2) = AirMass
                end select

                print #IREX, TransStar$(TransIndex);"  ";_                          'star
                             using("###.####",LMST);"  ";_                          'local mean sideral time
                             using("##.####",AirMass);"   ";_                       'air mass, X
                             using("#######",CountFinal(RawIndex));"   ";_          'reduced average count
                             using("###.##",InstrumentMag);"    ";_                 'instrument mag, u, b, v, r, i
                             RDitem$(RawIndex,9)                                    'filter, B, V
            end if
        next
    next
    for TransIndex = 1 to TransIndexMax

        Trans.Vv(TransIndex) = Trans.V(TransIndex) - m(TransIndex,2)                    'V - v

        AvgX(TransIndex) = (X(TransIndex,1) + X(TransIndex,2))/2                        'average X for b and v

        TransColor(TransIndex) = (m(TransIndex,1) - m(TransIndex,2))                    'b - v

        'compute (V-v) - eps(B - V), equation G.10
        TransColor2(TransIndex) = Trans.Vv(TransIndex) - Eps*TransStdColor(TransIndex)  'V- v - eps(B-V)

        'compute (B-V) - mu(b-v), equation G.11
        TransColor3(TransIndex) = TransStdColor(TransIndex) - Mu*TransColor(TransIndex)

        TransData$(TransIndex) = TransStar$(TransIndex)+" "+_                           'star name
                                 using("#.##",AvgX(TransIndex))+" "+_                   'air mass for v
                                 using("##.##",Trans.V(TransIndex))+" "+_               'V
                                 using("##.##",TransStdColor(TransIndex))+" "+_         'B-V
                                 using("###.##",m(TransIndex,2))+" "+_                  'v
                                 using("###.##",TransColor2(TransIndex))+" "+_          '(V-v) - eps(B-V)
                                 using("###.##",TransColor3(TransIndex))                '(B-V) - mu(b-v)

    next
    print #trans.Table, "reload"
return
'
[Create_Regression_Array]
    for TransIndex = 1 to TransIndexMax
        select case Graph$
            case "eps"
                Xaxis(TransIndex) = AvgX(TransIndex)
                Yaxis(TransIndex) = TransColor2(TransIndex)
            case "mu"
                Xaxis(TransIndex) = AvgX(TransIndex)
                Yaxis(TransIndex) = TransColor3(TransIndex)

        end select
        print #IREX, TransStar$(TransIndex);"  ";_
                     using("####.###",Xaxis(TransIndex));"   ";_
                     using("####.###",Yaxis(TransIndex))
    next
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

    print #trans.FileName, DataFileName$                 'display filename in "File" textbox
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
[Find_Air_Mass]                              'compute air mass
    HA = LMST - RA(TransIndex)               'find hour angle in degrees
    if HA < 0 then
        HA = HA + 360
    end if

    HAradians = HA * 3.1416/180             'convert to radians
    DECradians = DEC(TransIndex) * 3.1416/180
    LATradians = LAT * 3.1416/180

                        'compute secant of zenith angle - distance from zenith in radians
    secZ = 1/(sin(LATradians) * sin(DECradians) + cos(LATradians) * cos(DECradians) * cos(HAradians))
                        'compute air mass using Hardie equation
                        'X = sec Z - 0.0018167(sec Z - 1) - 0.002875(sec Z - 1)^2 - 0.0008083(sec Z - 1)^3
    AirMass = secZ - 0.0018167 * (secZ - 1) - 0.002875 * (secZ - 1)^2 - 0.0008083 * (secZ - 1)^3
return
'
[Solve_Regression_Matrix]
            'linear least squares routine from Nielson
            'pulled from appendix I.4 of Astronomical Photometry, written by Hendon 1973
            'inputs     Xaxis() X average airmass
            '           Yaxis() TransColor2 and TransColor3
            'outputs   Slope and Intercept,   Y = aX + b
            'number of elements in array = TransIndexMax
    a2 = 0
    a3 = 0
    c1 = 0
    c2 = 0
    a1 = TransIndexMax
    for I = 1 to TransIndexMax
        a2 = a2 + Xaxis(I)
        a3 = a3 + Xaxis(I) * Xaxis(I)
        c1 = c1 + Yaxis(I)
        c2 = c2 + Yaxis(I) * Xaxis(I)
    next
    det = 1/(a1 * a3 - a2 * a2)
    Intercept = -1 * (a2 * c2 - c1 * a3) * det
    Slope = (a1 * c2 - c1 * a2) * det

            'compute standard error using eq. 3.21
    if TransIndexMax > 2 then
        y.deviation.squared.sum = 0
        for N = 1 to TransIndexMax
            y.fit = Slope * Xaxis(N) + Intercept
            y.deviation = Yaxis(N) - y.fit
            y.deviation.squared.sum =  y.deviation.squared.sum + y.deviation^2
        next
        std.error = sqr((1/(N-2)) * y.deviation.squared.sum)
    else
        std.error = 0
    end if

    open "IREX.txt" for append as #IREX
        print #IREX, "output from [Solve_Regression_Matrix]"
        print #IREX, "Intercept    Slope    std.error"
        print #IREX, using("###.###",Intercept)+"   "+_
                     using("###.###",Slope)+"   "+_
                     using("###.###",std.error)
        print #IREX, " "
   close #IREX
return
'
'=====graphics routines
'
[Draw_Graph_Outline]
    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "font arial 6 12"
    print #trans.graphicbox1, "place 50 235"
    print #trans.graphicbox1, "\ 1.0"
    print #trans.graphicbox1, "place 175 235"
    print #trans.graphicbox1, "\ 1.5"
    print #trans.graphicbox1, "place 300 235"
    print #trans.graphicbox1, "\ 2.0"
    print #trans.graphicbox1, "place 425 235"
    print #trans.graphicbox1, "\ 2.5"

    print #trans.graphicbox1, "line 60 20 60 220"
    print #trans.graphicbox1, "line 60 220 460 220"
    print #trans.graphicbox1, "font arial 6 12"

    for I = 1 to 10
        xD =  20 * I
        print #trans.graphicbox1, "line 60 ";xD;" 65 ";xD
    next
    for I = 1 to 15
        yD = 60 + 25 * I
        print #trans.graphicbox1, "line ";yD;" 220 ";yD;" 215"
    next
    for I = 1 to 3
        yD = 60 + 125 * I
        print #trans.graphicbox1, "line ";yD;" 220 ";yD;" 210"
    next
return
'
[Draw_Best_Line]
    ScaleTop = (int((Slope+Intercept) * 10) + 5)/10
    ScaleBot = ScaleTop - 1

    StartLine = 1.0 * Slope + Intercept                         'start of best fit line at index = 1.0
    EndLine   = 2.5 * Slope + Intercept                         'end of best fit line at index = 2.5
    YaxisTop = ScaleTop * 200                                   'value for top of Y axis
                                                                '
    StartLine = YaxisTop - StartLine * 200 + 20
    EndLine = YaxisTop - EndLine * 200 + 20
    print #trans.graphicbox1, "line 60 ";StartLine;" 435 ";EndLine

                                                                'plot data points
    for TransIndex = 1 to TransIndexMax
        select case Graph$
            case "eps"
                Ypoint = YaxisTop - int(TransColor2(TransIndex) * 200) + 20
                Xpoint = int(AvgX(TransIndex) * 250) - 190
            case "mu"
                Ypoint = YaxisTop - int(TransColor3(TransIndex) * 200) + 20
                Xpoint = int(AvgX(TransIndex) * 250) - 190
        end select
        print #trans.graphicbox1, "place ";Xpoint;" ";Ypoint
        print #trans.graphicbox1, "circle 3"
    next
'
                                                    'draw y scale values
    print #trans.graphicbox1, "color black"
    print #trans.graphicbox1, "font arial 6 12"
    print #trans.graphicbox1, "place 25 25"
    ScaleTop$ = "\"+using("###.#", ScaleTop)
    print #trans.graphicbox1, ScaleTop$
    print #trans.graphicbox1, "place 25 220"
    ScaleBot$ = "\"+using("###.#", ScaleBot)
    print #trans.graphicbox1, ScaleBot$

return
'
[Draw_Description]
                                                    'print file name
    print #trans.graphicbox1, "place 60 300"
    print #trans.graphicbox1, "\FILE NAME :"
    print #trans.graphicbox1, "place 160 300"
    GraphicFileName$ = "\"+ShortDataFile$
    print #trans.graphicbox1, GraphicFileName$ 
                                                    'print start Julian Date
    print #trans.graphicbox1, "place 60 325"
    print #trans.graphicbox1, "\START J2000:"
    print #trans.graphicbox1, "place 160 325"
    GraphicStartJD$ = "\"+Using("####.####", JD(5))
    print #trans.graphicbox1, GraphicStartJD$ 
                                                    'print end Julian Date
    print #trans.graphicbox1, "place 60 350"
    print #trans.graphicbox1, "\END J2000:"
    print #trans.graphicbox1, "place 160 350"
    GraphicEndJD$ = "\"+Using("####.####", JD(RawIndexMax))
    print #trans.graphicbox1, GraphicEndJD$ 
                                                    'print slope
    print #trans.graphicbox1, "place 60 375"
    print #trans.graphicbox1, "\SLOPE:"
    print #trans.graphicbox1, "place 160 375"
    GraphicSlope$ = "\"+Using("####.###", Slope)
    print #trans.graphicbox1, GraphicSlope$ 
                                                    'printer intercept
    print #trans.graphicbox1, "place 60 400"
    print #trans.graphicbox1, "\INTERCEPT:"
    print #trans.graphicbox1, "place 160 400"
    GraphicIntercept$ = "\"+Using("####.###", Intercept)
    print #trans.graphicbox1, GraphicIntercept$ 
                                                    'print standard error
    print #trans.graphicbox1, "place 60 425"
    print #trans.graphicbox1, "\STD. ERROR:"
    print #trans.graphicbox1, "place 160 425"
    GraphicStd.error$ = "\"+Using("####.###", std.error)
    print #trans.graphicbox1, GraphicStd.error$ 
                                                    'print stars
    print #trans.graphicbox1, "place 60 450"
    print #trans.graphicbox1, "\STARS :"
    For TransIndex = 1 to TransIndexMax
        GraphicStar$ = "\"+TransStar$(TransIndex)
        place$ = "place 160 "+str$(435 + (15*TransIndex))
        print #trans.graphicbox1, place$
        print #trans.graphicbox1, GraphicStar$
    Next

return
'
end

