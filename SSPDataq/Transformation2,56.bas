'                        Transformation Module - Differential Photometry
'                                      Optec, Inc.
'
'======version history
'
'V2.56, November 2015
'   added PPparms3
'
'V2.53, September 2015
'   added save plot graphic
'
'V2.52, September 2015
'   compiled with LB 4.50
'   increased DIM
'
'V2.50, October 2014
'   added Sloan filters
'
'V2.42, September 9, 2014
'   corrected enable/disable buttons
'   added "Clear Result Boxes"
'
'V2.41, September 29, 2013
'   small changes
'   expanded IREX logging
'   corrected KI and KR error
'
'V2.40, September, 2013
'   added heliocentric JD to PPparms file and reduction module
'
'V2.32, August, 2013
'   cleared graphics screen when opening new file
'
'V2.31, August, 2013
'   fixed I label
'
'V2.30, March, 2013
'   fixed error in computing DEC
'
'V2.20, Jamuary, 2010
'   added improved file handling - remembers previously opened folder
'   changed help file to chm type
'   added graphicbox printing
'   compiled with Liberty Basic 4.03
'
'V2.00, October, 2007
'   added U, R and I filters
'
'
'V1.01, November 1, 2005
'   compiles with Liberty Basic 4.02
'
'V1.00
'
'
'=====dimension statements and initial conditions
'
    DIM info$(10,10)
    files "c:\", info$()

' display listbox arrays
    DIM TransData$(100)                 'data lines for listbox table, #trans.Table, index var = TransIndex
        TransData$(1) = "   "           'cannot use listbox unless something is put in before creation

    DIM TransStar$(100)                 'transformation star names in raw file, index var = TransIndex

    DIM Trans.V(100)                    'V, index var = TransIndex
    DIM Trans.Vv(100)                   'V-vo, index var = TransIndex

    DIM TransStdColor(100)              'B - V standard color index, index var = TransIndex
    DIM TransColor(100)                 '(b - v)o instrument colorindex corrected for K', index var = TransIndex
    DIM TransColor2(100)                '(B - V) - (b - v)o, index var = TransIndex

    DIM TransStdColorU(100)             'U - B standard color index, index var = TransIndex
    DIM TransColorU(100)                '(u - b)o instrument colorindex corrected for K', index var = TransIndex
    DIM TransColor2U(100)               '(U - B) - (u - b)o, index var = TransIndex

    DIM TransStdColorR(100)             'V - R standard color index, index var = TransIndex
    DIM TransColorR(100)                '(v - r)o instrument colorindex corrected for K', index var = TransIndex
    DIM TransColor2R(100)               '(V - R) - (v - r)o, index var = TransIndex

    DIM TransStdColorI(100)             'V - I standard color index, index var = TransIndex
    DIM TransColorI(100)                '(v - i)o instrument colorindex corrected for K', index var = TransIndex
    DIM TransColor2I(100)               '(V - I) - (v - i)o, index var = TransIndex

    DIM RA(100)                         'RA in decimal degrees for each trans star, index var = TransIndex
    DIM DEC(100)                        'DEC in decimal derees for each trans star, index var = TransIndex

' working arrays for computing values in TransData$ listbox table for each filter
' array(TransIndex,Filter)             TransIndex: 1 to 50 for each transformation star
'                                       Filter: 1 for B, 2 for V, 3 for U, 4 for R and 5 for I

    DIM X(100,5)                        'air mass for each star reading and for each filter
    DIM mo(100,5)                       'instrument magnitude for each filter reduced for K', bo, vo, uo, ro, io
    DIM m(100,5)                        'instrument magnitude for each filter, b, v, u, r, i
    DIM FilterFlag(100,5)               'flag to determine if column entry should be 0

' transformation data file array
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
                                        'TDitem$(x,11) = U-B magnitude
                                        'TDitem$(x,12) = V-R magnitude
                                        'TDitem$(x,13) = V-I magnitude


' raw data file arrays
    DIM RawData$(1000)                  'data lines from raw file of observations, index var = RawIndex
    DIM RDitem$(1000,15)                'data items from raw file of observations, index var = RawIndex
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

    DIM CountFinal(1000)                'average count including integration and scale, index var = RawIndex
    DIM JD(1000)                        'Julean date from 2000 for each RawIndex, index var = RawIndex
    DIM JT(1000)                        'Julean century fromm 2000 for each RawIndex, index var = RawIndex

' other arrays
    DIM Xaxis(100)                      'Xaxis() transformation star standard color index B-V
    DIM Yaxis(100)                      'Yaxis() V-vo to solve for eps, or (B-V)-(b-v)o to solve for mu
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
    input #PPparms, ZPgr                'zero-point constant for g'-r'
    input #PPparms, Ev                  'standard error for v
    input #PPparms, Er                  'standard error for r'
    input #PPparms, Ebv                 'standard error for b-v
    input #PPparms, Egr                 'standard error for g'-r'
close #PPparms

gosub [Find_Lat_Long]

            open "IREX.txt" for output as #IREX
                print #IREX, "Transformation Module 2, Veraion "; VersionNumber$
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
    Menu        #trans, "Coefficients",_
                        "Load Saved Transformation Coefficients", [Load_Previous_Coeff],_
                        "Transfer Computed Coefficients to Results", [Use_Current_Coefficients],_
                        "Save Coefficients in Results to PPparms", [Save_Coefficients],_
                        "Clear Result Boxes", [Clear_Coefficients]
    Menu        #trans, "Help",_
                        "About", [About],_
                        "Help", [Help]

    graphicbox  #trans.graphicbox1,   515, 40, 490, 265

    groupbox    #trans.groupbox1, "Transformation Stars File", 11, 310, 250, 85
    groupbox    #trans.groupbox2, "Results", 275, 310, 410, 85
    groupbox    #trans.groupbox3, "Least-Squares Analysis", 700, 310, 305, 85

    statictext  #trans.statictext1,  "Star",    30, 20, 40, 14
    statictext  #trans.statictext2,  "X",      145, 20, 10, 14

    statictext  #trans.statictext3,  "V-v",    190, 20, 29, 14
    statictext  #trans.statictext4,  "o",      218, 23, 10, 14

    statictext  #trans.statictext5,  "(B-V)-", 247,  5, 60, 14
    statictext  #trans.statictext6,  "(b-v)",  247, 20, 44, 14
    statictext  #trans.statictext7,  "o",      290, 23, 10, 14

    statictext  #trans.statictext8,  "(U-B)-", 310,  5, 60, 14
    statictext  #trans.statictext9,  "(u-b)-", 310, 20, 44, 14
    statictext  #trans.statictext10, "o",      353, 23, 10, 14

    statictext  #trans.statictext11, "(V-R)-", 372,  5, 60, 14
    statictext  #trans.statictext12, "(v-r)-", 372, 20, 44, 14
    statictext  #trans.statictext13, "o",      415, 23, 10, 14

    statictext  #trans.statictext14, "(V-I)-", 437,  5, 60, 14
    statictext  #trans.statictext15, "(v-i)-", 437, 20, 44, 14
    statictext  #trans.statictext16, "o",      480, 23, 10, 14

    statictext  #trans.statictext30,"slope", 787, 337, 50, 14
    statictext  #trans.statictext31,"intercept", 752, 352, 90, 14
    statictext  #trans.statictext32,"standard error", 710, 367, 132, 14
                                                'greek letters for results labels
    statictext  #trans.statictext33,"e", 310, 336, 12, 16       'epsilon
    statictext  #trans.statictext34,"e", 366, 336, 12, 16       'epsilon R
    statictext  #trans.statictext35,"m", 440, 336, 12, 16       'mu
    statictext  #trans.statictext36,"y", 504, 336, 14, 16       'psi
    statictext  #trans.statictext37,"t", 571, 336, 16, 14       'tau
    statictext  #trans.statictext38,"h", 636, 336, 12, 16       'eta
    statictext  #trans.statictext39,"r", 379, 343, 12, 16       'r

    statictext  #trans.statictext40,"j", 323,343,15,16
    statictext  #trans.statictext41,"j", 389,343,15,16
    statictext  #trans.statictext42,"j", 453,343,15,16
    statictext  #trans.statictext43,"j", 520,343,15,16
    statictext  #trans.statictext44,"c", 585,343,15,16
    statictext  #trans.statictext45,"c", 652,343,15,16

    statictext #trans.statictext46, "", 400,320,270, 16

                                                'buttons for calculating coefficients
    button      #trans.Showeps, "eps",[Show_eps.click],UL, 515, 10, 95, 25
    button      #trans.ShowepsR, "epsR",[Show_epsR.click],UL, 617, 10, 95, 25
    button      #trans.Showmu, "mu",[Show_mu.click],UL, 719, 10, 65, 25
    button      #trans.Showpsi, "psi",[Show_psi.click],UL, 791, 10, 65, 25
    button      #trans.Showtau, "tau",[Show_tau.click],UL, 863, 10, 65, 25
    button      #trans.Showeta, "eta",[Show_eta.click],UL, 935, 10, 65, 25

    button      #trans.Print, "print",[DataPrint.click], UL, 940, 360, 57, 25

    textbox     #trans.eps, 285, 360, 63, 25
    textbox     #trans.epsR, 351, 360, 63, 25
    textbox     #trans.mu, 417, 360, 63, 25
    textbox     #trans.psi, 483, 360, 63, 25
    textbox     #trans.tau, 549, 360, 63, 25
    textbox     #trans.eta, 615, 360, 63, 25

    textbox     #trans.Analysis, 844, 335, 88, 50

    textbox     #trans.FileName, 19, 345, 235, 25

    listbox     #trans.Table, TransData$(),[Transformation_Table.click], 10, 40, 500, 265

    Open "Transformation Coefficients - Johnson/Cousins/Sloan Photometry" for Window as #trans
    #trans "trapclose [Quit_Extinction]"
    #trans.graphicbox1 "down; fill White; flush"
    #trans.graphicbox1 "setfocus; when mouseMove [MouseChange1]"
    #trans.Table "selectindex 1"
    #trans "font courier_new 10 14"
                                                    'select greek letters for results box
    print #trans.statictext33, "!font symbol 13 17"
    print #trans.statictext34, "!font symbol 13 17"
    print #trans.statictext35, "!font symbol 13 17"
    print #trans.statictext36, "!font symbol 13 17"
    print #trans.statictext37, "!font symbol 16 18"
    print #trans.statictext38, "!font symbol 13 17"

    print #trans.FileName, "open raw data file"

    print #trans.Showeps, "!Disable"
    print #trans.ShowepsR, "!Disable"
    print #trans.Showmu, "!Disable"
    print #trans.Showpsi, "!Disable"
    print #trans.Showtau, "!Disable"
    print #trans.Showeta, "!Disable"
    print #trans.Print, "!Disable"

[loop]

Wait                                'finised setting up, wait here for new command
'
'======menu controls
'
[Open_File]
'
'                                   'clear the graphics screen and turn off buttons
    print #trans.Showeps, "!Disable"
    print #trans.ShowepsR, "!Disable"
    print #trans.Showmu, "!Disable"
    print #trans.Showpsi, "!Disable"
    print #trans.Showtau, "!Disable"
    print #trans.Showeta, "!Disable"
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

            print #trans.mu, ""                     'clear the result boxes
            print #trans.eps, ""
            print #trans.epsR, ""
            print #trans.psi, ""
            print #trans.tau, ""
            print #trans.eta, ""

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

            gosub [Open_Star_Data]

            gosub [Total_Count_RawFile]
            gosub [Julian_Day_RawFile]

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [IREX_RawFile]"
                print #IREX, "star           Julean date  final count   filter"

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
                    print #IREX, "star              RA        DEC       V      B-V     U-B     V-R     V-I"
                else
                    print #IREX, "star              RA        DEC       r      g-r     u-g     r-i     r-z"
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
            for TransIndex = 1 to TransIndexMax
                If FilterFlag(TransIndex,1) = 1 then
                    print #trans.Showmu, "!Enable"
                    print #trans.Showeps, "!Enable"
                end if
                If FilterFlag(TransIndex,3) = 1 then
                    print #trans.Showpsi, "!Enable"
                end if
                If FilterFlag(TransIndex,4) = 1 then
                    print #trans.Showtau, "!Enable"
                    print #trans.ShowepsR, "!Enable"
                end if
                If FilterFlag(TransIndex,5) = 1 then
                    print #trans.Showeta, "!Enable"
                end if
            next

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
        print #trans.mu, using("##.###",Mu)
        print #trans.eps, using("##.###",Eps)
        print #trans.epsR, using("##.###",EpsR)
        print #trans.psi, using("##.###",Psi)
        print #trans.tau, using("##.###",Tau)
        print #trans.eta, using("##.###",Eta)
    else
        print #trans.mu, using("##.###",SMu)
        print #trans.eps, using("##.###",SEps)
        print #trans.epsR, using("##.###",SEpsR)
        print #trans.psi, using("##.###",SPsi)
        print #trans.tau, using("##.###",STau)
        print #trans.eta, using("##.###",SEta)
    end if
Wait
'
[Save_Coefficients]
    print #trans.mu, "!contents? MuTemp"
    print #trans.eps, "!contents? EpsTemp"
    print #trans.epsR, "!contents? EpsRTemp"
    print #trans.psi, "!contents? PsiTemp"
    print #trans.tau, "!contents? TauTemp"
    print #trans.eta, "!contents? EtaTemp"

    if MuTemp = 0 AND EpsTemp = 0 AND EpsRTemp = 0 AND PsiTemp = 0 AND TauTemp = 0 AND EtaTemp = 0 then
        notice "nothing to save"
        Wait
    end if

    confirm "This will save all non-zero contents"+chr$(13)_
            +"Type a zero in box to keep previous saved coefficient"+chr$(13)+chr$(13)_
            +"Do you wish to save values?"; Answer$
    if Answer$ = "yes" then
        if FilterSystem$ = "1" then
            if MuTemp <> 0 then
                Mu = MuTemp
            end if
            if EpsTemp <> 0 then
                Eps = EpsTemp
            end if
            if EpsRTemp <> 0 then
                EpsR = EpsRTemp
            end if
            if PsiTemp <> 0 then
                Psi = PsiTemp
            end if
            if TauTemp <> 0 then
                Tau = TauTemp
            end if
            if EtaTemp <> 0 then
                Eta = EtaTemp
            end if
        else
            if MuTemp <> 0 then
                SMu = MuTemp
            end if
            if EpsTemp <> 0 then
                SEps = EpsTemp
            end if
            if EpsRTemp <> 0 then
                SEpsR = EpsRTemp
            end if
            if PsiTemp <> 0 then
                SPsi = PsiTemp
            end if
            if TauTemp <> 0 then
                STau = TauTemp
            end if
            if EtaTemp <> 0 then
                SEta = EtaTemp
            end if
        end if
        gosub [Write_PPparms]
    end if
Wait
'
[Use_Current_Coefficients]
    print #trans.mu, using("##.###",Mutemporary)
    print #trans.eps, using("##.###",Epstemporary)
    print #trans.epsR, using("##.###",EpsRtemporary)
    print #trans.psi, using("##.###",Psitemporary)
    print #trans.tau, using("##.###",Tautemporary)
    print #trans.eta, using("##.###",Etatemporary)
Wait
'
[Clear_Coefficients]
    print #trans.mu, ""
    print #trans.eps, ""
    print #trans.epsR, ""
    print #trans.psi, ""
    print #trans.tau, ""
    print #trans.eta, ""
Wait
'
[About]
    notice "Transformation Coefficients - Johnson/Cousins/Sloan Photometry"+chr$(13)+_
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
[Show_eps.click]
    print#trans.Print, "!Enable"
    Epstemporary = 0
    Graph$ = "eps"
    print #trans.graphicbox1, "cls"
    print #trans.graphicbox1, "color black"
    print #trans.graphicbox1, "place 10 125"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "font arial 6 12"
        print #trans.graphicbox1, "\V-v"
    else
        print #trans.graphicbox1, "font arial 8 12"
        print #trans.graphicbox1, "\ r-r"
    end if
    print #trans.graphicbox1, "place 28 130"
    print #trans.graphicbox1, "font arial 6 12"
    print #trans.graphicbox1, "\o"
    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "place 225 250"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "\B - V"
    else
        print #trans.graphicbox1, "\g - r"
    end if

    gosub [Draw_Graph_Outline]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "Coefficient = eps"
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

    Epstemporary = Slope
wait
'
[Show_epsR.click]
    print#trans.Print, "!Enable"
    EpsRtemporary = 0
    Graph$ = "epsR"
    print #trans.graphicbox1, "cls"
    print #trans.graphicbox1, "color black"
    print #trans.graphicbox1, "place 10 125"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "font arial 6 12"
        print #trans.graphicbox1, "\V-v"
    else
        print #trans.graphicbox1, "font arial 8 12"
        print #trans.graphicbox1, "\ r-r"
    end if
    print #trans.graphicbox1, "place 28 130"
    print #trans.graphicbox1, "font arial 6 12"
    print #trans.graphicbox1, "\o"
    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "place 225 250"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "\V - R"
    else
        print #trans.graphicbox1, "\r - i"
    end if

    gosub [Draw_Graph_Outline]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "Coefficient = epsR"
        print #IREX, "star             Xaxis      Yaxis"
        gosub [Create_Regression_Array]
        print #IREX, " "
    close #IREX

    gosub [Solve_Regression_Matrix]
                                                'output to Analysis textbox the results
    print #trans.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                           using("####.###", Intercept) + chr$(13) + chr$(10) +_
                           using("####.###", std.error)

    print #trans.graphicbox1, "color darkgreen"
    gosub [Draw_Best_Line]

    gosub [Draw_Description]
    print #trans.graphicbox1, "flush"

    EpsRtemporary = Slope
wait
'
[Show_mu.click]
    print#trans.Print, "!Enable"
    Mutemporary = 0
    Graph$ = "mu"
    print #trans.graphicbox1, "cls"
    print #trans.graphicbox1, "color black"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "font arial 6 12"
        print #trans.graphicbox1, "place 2 125"
        print #trans.graphicbox1, "\(B-V)-"
        print #trans.graphicbox1, "place 5 140"
        print #trans.graphicbox1, "\(b-v)"
    else
        print #trans.graphicbox1, "font arial 7 12"
        print #trans.graphicbox1, "place 2 125"
        print #trans.graphicbox1, "\(g-r) -"
        print #trans.graphicbox1, "place 4 140"
        print #trans.graphicbox1, "\(g-r)"
    end if
    print #trans.graphicbox1, "place 30 145"
    print #trans.graphicbox1, "\o"
    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "place 225 250"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "\B - V"
    else
        print #trans.graphicbox1, "\g - r"
    end if
    gosub [Draw_Graph_Outline]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "Coefficient = mu"
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
'               Slope = 1 - 1/mu from page 332
'               mu = 1/(1 - Slope)
    Mutemporary = 1/(1 - Slope)
wait
'
[Show_tau.click]
    print#trans.Print, "!Enable"
    Tautemporary = 0
    Graph$ = "tau"
    print #trans.graphicbox1, "cls"
    print #trans.graphicbox1, "color black"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "font arial 6 12"
        print #trans.graphicbox1, "place 2 125"
        print #trans.graphicbox1, "\(V-R)-"
        print #trans.graphicbox1, "place 6 140"
        print #trans.graphicbox1, "\(v-r)"
    else
        print #trans.graphicbox1, "font arial 7 12"
        print #trans.graphicbox1, "place 2 125"
        print #trans.graphicbox1, "\(r-i) -"
        print #trans.graphicbox1, "place 6 140"
        print #trans.graphicbox1, "\(r-i)"
    end if
    print #trans.graphicbox1, "place 29 145"
    print #trans.graphicbox1, "\o"
    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "place 225 250"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "\V - R"
    else
        print #trans.graphicbox1, "\r - i"
    end if
    gosub [Draw_Graph_Outline]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "Coefficient = tau"
        print #IREX, "star             Xaxis      Yaxis"
        gosub [Create_Regression_Array]
        print #IREX, " "
    close #IREX

    gosub [Solve_Regression_Matrix]
                                                'output to Analysis textbox the results
    print #trans.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                           using("####.###", Intercept) + chr$(13) + chr$(10) +_
                           using("####.###", std.error)

    print #trans.graphicbox1, "color red"
    gosub [Draw_Best_Line]

    gosub [Draw_Description]
    print #trans.graphicbox1, "flush"
'
'               Slope = 1 - 1/psi from page 332
'               psi = 1/(1 - Slope)
    Tautemporary = 1/(1 - Slope)
wait
'
[Show_psi.click]
    print#trans.Print, "!Enable"
    Psitemporary = 0
    Graph$ = "psi"
    print #trans.graphicbox1, "cls"
    print #trans.graphicbox1, "color black"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "font arial 6 12"
        print #trans.graphicbox1, "place 2 125"
        print #trans.graphicbox1, "\(U-B)-"
        print #trans.graphicbox1, "place 5 140"
        print #trans.graphicbox1, "\(u-b)"
    else
        print #trans.graphicbox1, "font arial 7 12"
        print #trans.graphicbox1, "place 2 125"
        print #trans.graphicbox1, "\(u-g) -"
        print #trans.graphicbox1, "place 4 140"
        print #trans.graphicbox1, "\(u-g)"
    end if
    print #trans.graphicbox1, "place 30 145"
    print #trans.graphicbox1, "\o"
    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "place 225 250"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "\U - B"
    else
        print #trans.graphicbox1, "\u - g"
    end if
    gosub [Draw_Graph_Outline]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "Coefficient = psi"
        print #IREX, "star             Xaxis      Yaxis"
        gosub [Create_Regression_Array]
        print #IREX, " "
    close #IREX

    gosub [Solve_Regression_Matrix]
                                                'output to Analysis textbox the results
    print #trans.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                           using("####.###", Intercept) + chr$(13) + chr$(10) +_
                           using("####.###", std.error)

    print #trans.graphicbox1, "color darkpink"
    gosub [Draw_Best_Line]

    gosub [Draw_Description]
    print #trans.graphicbox1, "flush"
'
'               Slope = 1 - 1/eta from page 332
'               eta = 1/(1 - Slope)
    Psitemporary = 1/(1 - Slope)
'
wait
'
[Show_eta.click]
    print#trans.Print, "!Enable"
    Etatemporary = 0
    Graph$ = "eta"
    print #trans.graphicbox1, "cls"
    print #trans.graphicbox1, "color black"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "font arial 6 12"
        print #trans.graphicbox1, "place 2 125"
        print #trans.graphicbox1, "\(V-I)-"
        print #trans.graphicbox1, "place 6 140"
        print #trans.graphicbox1, "\(v-i)"
    else
        print #trans.graphicbox1, "font arial 7 12"
        print #trans.graphicbox1, "place 2 125"
        print #trans.graphicbox1, "\(r-z) -"
        print #trans.graphicbox1, "place 4 140"
        print #trans.graphicbox1, "\(r-z)"
    end if
    print #trans.graphicbox1, "place 29 145"
    print #trans.graphicbox1, "\o"
    print #trans.graphicbox1, "font arial 8 16"
    print #trans.graphicbox1, "place 225 250"
    if FilterSystem$ = "1" then
        print #trans.graphicbox1, "\V - I"
    else
        print #trans.graphicbox1, "\r - z"
    end if
    gosub [Draw_Graph_Outline]

    open "IREX.txt" for append as #IREX         'save to IREX file for diagnostics
        print #IREX, "output from [Create_Regression_Array]"
        print #IREX, "Coefficient = eta"
        print #IREX, "star             Xaxis      Yaxis"
        gosub [Create_Regression_Array]
        print #IREX, " "
    close #IREX

    gosub [Solve_Regression_Matrix]
                                                'output to Analysis textbox the results
    print #trans.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                           using("####.###", Intercept) + chr$(13) + chr$(10) +_
                           using("####.###", std.error)

    print #trans.graphicbox1, "color darkgray"
    gosub [Draw_Best_Line]

    gosub [Draw_Description]
    print #trans.graphicbox1, "flush"
'
'               Slope = 1 - 1/mu from page 332
'               mu = 1/(1 - Slope)
    Etatemporary = 1/(1 - Slope)
'
wait
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
        open "Transformation Data Version 2.txt" for input as #TransData
    else
        open "Transformation Data Version 2 Sloan.txt" for input as #TransData
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
                         TDitem$(DataIndex,9),_      'V magnitude, ##.##
                         TDitem$(DataIndex,10),_     'B-V index, ##.##
                         TDitem$(DataIndex,11),_     'U-B index, ##.##
                         TDitem$(DataIndex,12),_     'V-R index, ##.##
                         TDitem$(DataIndex,13)       'V-I index, ##.##
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
        RDitem$(RawIndex,9)  = mid$(RawData$(RawIndex),41,1)       'filter: U, B, V, R or I
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

    if RDitem$(5,9) = "u" OR RDitem$(5,9) = "g" OR RDitem$(5,9) = "r" OR RDitem$(5,9) = "i" OR RDitem$(5,9) = "z" then
        FilterSystem$ = "0"
    else
        FilterSystem$ = "1"
    end if
return
'
[Write_Window_Labels]
    if FilterSystem$= "1" then
        print #trans.statictext3,  "V-v"
        print #trans.statictext4,  "o"

        print #trans.statictext5,  "(B-V)-"
        print #trans.statictext6,  "(b-v)"
        print #trans.statictext7,  "o"

        print #trans.statictext8,  "(U-B)-"
        print #trans.statictext9,  "(u-b)-"
        print #trans.statictext10, "o"

        print #trans.statictext11, "(V-R)-"
        print #trans.statictext12, "(v-r)-"
        print #trans.statictext13, "o"

        print #trans.statictext14, "(V-I)-"
        print #trans.statictext15, "(v-i)-"
        print #trans.statictext16, "o"

        print #trans.statictext40,"j"
        print #trans.statictext41,"j"
        print #trans.statictext42,"j"
        print #trans.statictext43,"j"
        print #trans.statictext44,"c"
        print #trans.statictext45,"c"

        print #trans.statictext46, "Johnson/Cousins Coefficients"

    else
        print #trans.statictext3,  "r-r"
        print #trans.statictext4,  "o"

        print #trans.statictext5,  "(g-r)-"
        print #trans.statictext6,  "(g-r)"
        print #trans.statictext7,  "o"

        print #trans.statictext8,  "(u-g)-"
        print #trans.statictext9,  "(u-g)-"
        print #trans.statictext10, "o"

        print #trans.statictext11, "(r-i)-"
        print #trans.statictext12, "(r-i)-"
        print #trans.statictext13, "o"

        print #trans.statictext14, "(r-z)-"
        print #trans.statictext15, "(r-z)-"
        print #trans.statictext16, "o"

        print #trans.statictext40,"s"
        print #trans.statictext41,"s"
        print #trans.statictext42,"s"
        print #trans.statictext43,"s"
        print #trans.statictext44,"s"
        print #trans.statictext45,"s"

        print #trans.statictext46, "Sloan Coefficients"

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
        if (RDitem$(RawIndex,7) = "T") then
            TransFlag = 0
                                        'see if the Trans Star is new to the list
            for TransIndex = 1 to TransIndexMax
                if TransStar$(TransIndex) = RDitem$(RawIndex,8) then
                    TransFlag = 1
                end if
            next
            if TransFlag = 0 then       'add the new Trans Star to the list
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
        if (RDitem$(RawIndex,7) = "T")  AND (RDitem$(RawIndex,9) = Filter$) then
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
                            using("######", CountFinal(RawIndex));"         ";_     'final average count
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
    redim TransStdColorU(100)           'U - B standard color index, index var = TransIndex
    redim TransStdColorR(100)           'V - R standard color index, index var = TransIndex
    redim TransStdColorI(100)           'V - I standard color index, index var = TransIndex

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
                                                    'get U-B color index
                TransStdColorU(TransIndex) = val(TDitem$(DataIndex,11))
                                                    'get V-R color index
                TransStdColorR(TransIndex) = val(TDitem$(DataIndex,12))
                                                    'get V-I color index
                TransStdColorI(TransIndex) = val(TDitem$(DataIndex,13))
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
                     using("###.##",TransStdColor(TransIndex));"  ";_
                     using("###.##",TransStdColorU(TransIndex));"  ";_
                     using("###.##",TransStdColorR(TransIndex));"  ";_
                     using("###.##",TransStdColorI(TransIndex))
    next
return
'
                                'create ExtData() for display in listbox
[Create_Transformation_Table]
    redim TransData$(100)

    redim FilterFlag(100,5)
    redim X(100,5)                          'air mass for each star reading and for each filter
    redim mo(100,5)                         'instrument mag. for each filter reduced for K', bo, vo, uo, ro, io
    redim m(100,5)                          'instrument mag. for each filter, b, v, u, r, i

    for TransIndex = 1 to TransIndexMax
        for RawIndex = 5 to RawIndexMax
            if TransStar$(TransIndex) = RDitem$(RawIndex,8) then
                gosub [Siderial_Time]
                gosub [Find_Air_Mass]
                InstrumentMag = -1.0857*log(CountFinal(RawIndex))                   'ln(x) = 2.3026 * log(x)
                FilterID$ =  RDitem$(RawIndex,9)
                select case
                    case (FilterID$ = "B") OR (FilterID$ = "g")
                        FilterFlag(TransIndex,1) = 1
                        m(TransIndex,1) = InstrumentMag                             'b
                        mo(TransIndex,1) = InstrumentMag - KB * AirMass             'bo
                        X(TransIndex,1) = AirMass
                    case (FilterID$ = "V") OR (FilterID$ = "r")
                        FilterFlag(TransIndex,2) = 1
                        m(TransIndex,2) = InstrumentMag                             'v
                        mo(TransIndex,2) = InstrumentMag - KV * AirMass             'vo
                        X(TransIndex,2) = AirMass
                    case (FilterID$ = "U") OR (FilterID$ = "u")
                        FilterFlag(TransIndex,3) = 1
                        m(TransIndex,3) = InstrumentMag                             'u
                        mo(TransIndex,3) = InstrumentMag - KU * AirMass             'uo
                        X(TransIndex,3) = AirMass
                    case (FilterID$ = "R") OR (FilterID$ = "i")
                        FilterFlag(TransIndex,4) = 1
                        m(TransIndex,4) = InstrumentMag                             'r
                        mo(TransIndex,4) = InstrumentMag - KR * AirMass             'ro
                        X(TransIndex,4) = AirMass
                    case (FilterID$ = "I") OR (FilterID$ = "z")
                        FilterFlag(TransIndex,5) = 1
                        m(TransIndex,5) = InstrumentMag                             'i
                        mo(TransIndex,5) = InstrumentMag - KI * AirMass             'io
                        X(TransIndex,5) = AirMass
                end select

                print #IREX, TransStar$(TransIndex);"  ";_                          'star
                             using("###.####",LMST);"  ";_                          'local mean sideral time
                             using("##.####",AirMass);"   ";_                       'air mass, X
                             using("######",CountFinal(RawIndex));"    ";_          'reduced average count
                             using("###.##",InstrumentMag);"    ";_                 'instrument mag, u, b, v, r, i
                             RDitem$(RawIndex,9)                                    'filter, U, B, V, R, I
            end if
        next
    next
    for TransIndex = 1 to TransIndexMax

        Trans.Vv(TransIndex) = Trans.V(TransIndex) - mo(TransIndex,2)                       'V - vo

        If FilterFlag(TransIndex,1) = 1 then
            'compute (b - v)o = (b - v) * (1 - K"bv * X) - K'bv * X, equation 2.7
            AvgAirMass = (X(TransIndex,1) + X(TransIndex,2))/2                              'average X for b and v
            TransColor(TransIndex) = (m(TransIndex,1) - m(TransIndex,2)) *_                 'b - v
                                    (1 - KKbv * AvgAirMass) -_                              '1 - K"bv * X
                                    (KB - KV) * AvgAirMass                                  'K'bv * X
            TransColor2(TransIndex) = TransStdColor(TransIndex) - TransColor(TransIndex)    '(B-V) - (b-v)o
        else
            TransColor2(TransIndex) = 0
        end if

        if FilterFlag(TransIndex,3) = 1 then
            'compute (u - b)o = (u - b) - K'ub * X, equation 2.8
            AvgAirMass = (X(TransIndex,3) + X(TransIndex,1))/2                              'average X for u and b
            TransColorU(TransIndex) = (m(TransIndex,3) - m(TransIndex,1)) -_                'u - b
                                      (KU - KB) * AvgAirMass                                'K'ub * X
            TransColor2U(TransIndex) = TransStdColorU(TransIndex) - TransColorU(TransIndex) '(U-B) - (u-b)o
        else
            TransColor2U(TransIndex) = 0
        end if

        if FilterFlag(TransIndex,4) = 1 then
            'compute (v - r)o = (v - r) - K'vr * X
            AvgAirMass = (X(TransIndex,2) + X(TransIndex,4))/2                              'average X for v and r
            TransColorR(TransIndex) = (m(TransIndex,2) - m(TransIndex,4)) -_                'v - r
                                      (KV - KR) * AvgAirMass                                'K'vr * X
            TransColor2R(TransIndex) = TransStdColorR(TransIndex) - TransColorR(TransIndex) '(V-R) - (v-r)o
        else
            TransColorR(TransIndex) = 0
        end if

        if FilterFlag(TransIndex,5) = 1 then
            'compute (v - i)o = (v - i) - K'vi * X
            AvgAirMass = (X(TransIndex,2) + X(TransIndex,5))/2                              'average X for v and i
            TransColorI(TransIndex) = (m(TransIndex,2) - m(TransIndex,5)) -_                'v - i
                                      (KV - KI) * AvgAirMass                                'K'vi * X
            TransColor2I(TransIndex) = TransStdColorI(TransIndex) - TransColorI(TransIndex) '(V-I) - (v-i)o
        else
            TransColor2I(TransIndex) = 0
        end if


        TransData$(TransIndex) = TransStar$(TransIndex)+" "+_                               'star name
                                 using("#.##",X(TransIndex,2))+" "+_                        'air mass for v
                                 using("###.##",Trans.Vv(TransIndex))+"  "+_                'V-vo
                                 using("##.##",TransColor2(TransIndex))+"  "+_              '(B-V) - (b-v)o
                                 using("##.##",TransColor2U(TransIndex))+"  "+_             '(U-B) - (u-b)o
                                 using("##.##",TransColor2R(TransIndex))+"  "+_             '(V-R) - (v-r)o
                                 using("##.##",TransColor2I(TransIndex))                    '(V-I) - (v-i)o

    next
    print #trans.Table, "reload"
return
'
[Create_Regression_Array]
    for TransIndex = 1 to TransIndexMax
        select case Graph$
            case "eps"
                Xaxis(TransIndex) = TransStdColor(TransIndex)
                Yaxis(TransIndex) = Trans.Vv(TransIndex)
            case "mu"
                Xaxis(TransIndex) = TransStdColor(TransIndex)
                Yaxis(TransIndex) = TransColor2(TransIndex)
            case "epsR"
                Xaxis(TransIndex) = TransStdColorR(TransIndex)
                Yaxis(TransIndex) = Trans.Vv(TransIndex)
            case "psi"
                Xaxis(TransIndex) = TransStdColorU(TransIndex)
                Yaxis(TransIndex) = TransColor2U(TransIndex)
            case "tau"
                Xaxis(TransIndex) = TransStdColorR(TransIndex)
                Yaxis(TransIndex) = TransColor2R(TransIndex)
            case "eta"
                Xaxis(TransIndex) = TransStdColorI(TransIndex)
                Yaxis(TransIndex) = TransColor2I(TransIndex)
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
            'inputs     Xaxis() V-vo to solve for eps, or (B-V)-(b-v)o to solve for mu
            '           Yaxis() transformation star standard color index B-V
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
    print #trans.graphicbox1, "place 60 235"
    print #trans.graphicbox1, "\ -1.0"
    print #trans.graphicbox1, "place 110 235"
    print #trans.graphicbox1, "\ -0.5"
    print #trans.graphicbox1, "place 160 235"
    print #trans.graphicbox1, "\ 0.0"
    print #trans.graphicbox1, "place 210 235"
    print #trans.graphicbox1, "\ 0.5"
    print #trans.graphicbox1, "place 260 235"
    print #trans.graphicbox1, "\ 1.0"
    print #trans.graphicbox1, "place 310 235"
    print #trans.graphicbox1, "\ 1.5"
    print #trans.graphicbox1, "place 360 235"
    print #trans.graphicbox1, "\ 2.0"
    print #trans.graphicbox1, "place 410 235"
    print #trans.graphicbox1, "\ 2.5"
    print #trans.graphicbox1, "place 460 235"
    print #trans.graphicbox1, "\ 3.0"

    print #trans.graphicbox1, "line 40 20 40 220"
    print #trans.graphicbox1, "line 40 220 480 220"
    print #trans.graphicbox1, "font arial 6 12"

    for I = 1 to 10
        xD =  20 * I
        print #trans.graphicbox1, "line 40 ";xD;" 45 ";xD
    next
    for I = 1 to 42
        yD = 40 + 10 * I
        print #trans.graphicbox1, "line ";yD;" 220 ";yD;" 215"
    next
    for I = 0 to 8
        yD = 70 + 50 * I
        print #trans.graphicbox1, "line ";yD;" 220 ";yD;" 210"
    next
return
'
[Draw_Best_Line]
    ScaleTop = (int(Intercept * 10) + 5)/10
    ScaleBot = ScaleTop - 1

    StartLine = -1.3 * Slope + Intercept                        'start of best fit line at index = -1.3
    EndLine   = 3.0 * Slope + Intercept                         'end of best fit line at index = 3.0
    YaxisTop = ScaleTop * 200                                   'value for top of Y axis
                                                                '
    StartLine = YaxisTop - StartLine * 200 + 20
    EndLine = YaxisTop - EndLine * 200 + 20
    print #trans.graphicbox1, "line 40 ";StartLine;" 470 ";EndLine

                                                                'plot data points
    for TransIndex = 1 to TransIndexMax
        select case Graph$
            case "eps"
                Ypoint = YaxisTop - int(Trans.Vv(TransIndex) * 200) + 20
                Xpoint = int(TransStdColor(TransIndex) * 100) + 170
            case "mu"
                Ypoint = YaxisTop - int(TransColor2(TransIndex) * 200) + 20
                Xpoint = int(TransStdColor(TransIndex) * 100) + 170
            case "epsR"
                Ypoint = YaxisTop - int(Trans.Vv(TransIndex) * 200) + 20
                Xpoint = int(TransStdColorR(TransIndex) * 100) + 170
            case "psi"
                Ypoint = YaxisTop - int(TransColor2U(TransIndex) * 200) + 20
                Xpoint = int(TransStdColorU(TransIndex) * 100) + 170
            case "tau"
                Ypoint = YaxisTop - int(TransColor2R(TransIndex) * 200) + 20
                Xpoint = int(TransStdColorR(TransIndex) * 100) + 170
            case "eta"
                Ypoint = YaxisTop - int(TransColor2I(TransIndex) * 200) + 20
                Xpoint = int(TransStdColorI(TransIndex) * 100) + 170
        end select
        print #trans.graphicbox1, "place ";Xpoint;" ";Ypoint
        print #trans.graphicbox1, "circle 3"
    next
'
                                                    'draw y scale values
    print #trans.graphicbox1, "color black"
    print #trans.graphicbox1, "font arial 6 12"
    print #trans.graphicbox1, "place 10 25"
    ScaleTop$ = "\"+using("###.#", ScaleTop)
    print #trans.graphicbox1, ScaleTop$
    print #trans.graphicbox1, "place 10 220"
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
