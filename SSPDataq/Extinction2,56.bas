'                       Extinction Module - U,B,V,R and I Photometry
'                                                Optec, Inc.
'
'======version history
'V2.56, November, 2015
'    added PPparms3
'
'V2.53, September 2015
'    added SAVE PLOT
'
'V2.52, September 2015
'   compiled with LB 4.50
'   increased DIM
'
'V2.50, October, 2014
'    added sloan magnitudes
'
'V2.43, April, 2014
'   got rid of JDFlag in extinction table
'
'V2.42, October 28,2013
'   improved location edit window
'
'V2.41, September 29, 2013
'   changed results saving to be like transformation in saving non-zero values
'
'V2.40, September 2013
'   changed PParms file to include heliocentric JD in reduction module
'
'V2.30, March 2013
'   changed K" handling
'   added IREX print diagnostics
'   corrected error in computing DEC
'
'V2.21, April, 2010
'   added flush command for graphics
'
'V2.20, Jamuary, 2010
'   added improved file handling - remembers previously opened folder
'   changed help file to chm type
'   improved LOCATION entry
'   added graphicbox printing
'   compiled with Liberty Basic 4.03
'
'V2.00, September, 2007
'   added U,R and I filters
'   compiled with Liberty Basic 4.03
'
'V1.01, November 1, 2005
'   compiled with Liberty Basic 4.02
'
'V1.00
'
'
'=====dimension statements and initial conditions
'
    DIM info$(10,10)
    files "c:\", info$()

    DIM ExtData$(4000)                              'extinction data lines for list box table
        ExtData$(1) = "open raw data file and select comp star"
    DIM ExtData(4000,12)                            'extinction data items for list box table
    DIM CompStar$(400)                              'list of comparison C stars
        CompStar$(1) = "select"
    DIM RawData$(4000)                              'data from raw file of observations
    DIM SDitem$(4000,13)                            'individual data items from Star Data file
    DIM RDitem$(1000,20)                             'individual data items from raw file of observations
    DIM CountFinal(4000)                            'average count including integration and scale factors
    DIM JD(4000)                                    'Julean date from 2000 for each RawIndex
    DIM JT(4000)                                    'Julean century fromm 2000 for each RawIndex
    DIM X(400)                                      'air mass array for regression anaylsis
    DIM m(400)                                      'instrument magnitude array for regression anaylsis
'
'=====initialize and start up values
'
VersionNumber$ = "2.56"
PathDataFile$ = "*.raw"                             'default path for data files
PathPlotFile$ = "* .bmp"                            'default path for plot files
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
    input #PPparms, Psi                 'transformation coeff. psi for U-B
    input #PPparms, Mu                  'transformation coeff. mu for B-V
    input #PPparms, Tau                 'transformation coeff. tau for V-R
    input #PPparms, Eta                 'transformation coeff. eta for V-I
    input #PPparms, EpsR                'transformation coeff. epsilon for V using V-R
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
                print #IREX, "Extinction Module, Version "; VersionNumber$
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
    Menu        #extinction, "File",_
                             "Open File", [Open_File],_
                             "Save Plot Graphic", [Data_Save],_
                             "Quit", [Quit_Extinction]
    Menu        #extinction, "Coefficients",_
                             "Load Saved Extinction Coefficients", [Load_Previous_Coeff],_
                             "Send Computed Coefficients to Results", [Use_Current_Coefficients],_
                             "Save Coefficients in Results to PPparms", [Save_Coefficients],_
                             "Enter Second Order Extinction Coefficients",[Enter_SOE_Coefficients],_
                             "Clear Results", [Clear_Results]
    Menu        #extinction, "Setup", "Location", [Location]
    Menu        #extinction, "Help", "About", [About], "Help", [Help]

    graphicbox  #extinction.graphicbox1,   650, 40, 350, 265

    groupbox    #extinction.groupbox1, "Raw Data File", 11, 311, 250, 90
    groupbox    #extinction.groupbox2, "Results", 275, 310, 360, 90
    groupbox    #extinction.groupbox3, "Least-Squares Analysis", 650, 310, 350, 90

    statictext  #extinction.statictext2, "HA", 35, 20, 20, 14
    statictext  #extinction.statictext2, "X", 85, 20, 10, 14
    statictext  #extinction.statictext3, "---------Counts ---------", 126, 5, 250, 14
    statictext  #extinction.statictext4, "u", 136, 20, 10, 14
    statictext  #extinction.statictext5, "b ", 185, 20, 10, 14
    statictext  #extinction.statictext6, "v ", 234, 20, 10, 14
    statictext  #extinction.statictext7, "r ", 283, 20, 10, 14
    statictext  #extinction.statictext8, "i ", 332, 20, 10, 14

    statictext  #extinction.statictext10, "----Instrument Magnitude----", 365, 5, 270, 14
    statictext  #extinction.statictext11, "u", 380, 20, 10, 14
    statictext  #extinction.statictext12, "b", 429, 20, 10, 14
    statictext  #extinction.statictext13, "v", 476, 20, 10, 14
    statictext  #extinction.statictext14, "r", 526, 20, 10, 14
    statictext  #extinction.statictext15, "i", 576, 20, 10, 14

    statictext  #extinction.statictext20, "Comp Star", 20, 365, 90, 14

    statictext  #extinction.statictext33, "K'", 305, 335, 15, 14
    statictext  #extinction.statictext34, "u", 320, 340, 10, 14
    statictext  #extinction.statictext35, "K'", 375, 335, 15, 14
    statictext  #extinction.statictext36, "b", 390, 340, 10, 14
    statictext  #extinction.statictext37, "K'", 442, 335, 15, 14
    statictext  #extinction.statictext38, "v", 458, 340, 10, 14
    statictext  #extinction.statictext39, "K'", 512, 335, 15, 14
    statictext  #extinction.statictext40, "r", 528, 340, 10, 14
    statictext  #extinction.statictext41, "K'", 582, 335, 15, 14
    statictext  #extinction.statictext42, "i", 598, 340, 10, 14

    statictext  #extinction.statictext50, "slope", 750, 337, 50, 14
    statictext  #extinction.statictext51, "intercept", 715, 352, 90, 14
    statictext  #extinction.statictext52, "standard error", 670, 367, 140, 14

    button      #extinction.ShowU, "u ",[Show_U.click],UL, 650, 10, 67, 25
    button      #extinction.ShowB, "b ",[Show_B.click],UL, 720, 10, 67, 25
    button      #extinction.ShowV, "v ",[Show_V.click],UL, 790, 10, 67, 25
    button      #extinction.ShowR, "r ",[Show_R.click],UL, 860, 10, 67, 25
    button      #extinction.ShowI, "i ",[Show_I.click],UL, 930, 10, 67, 25

    button      #extinction.Print, "print",[DataPrint.click], UL, 930, 360, 57, 25

    textbox     #extinction.Ku, 281, 360, 67, 25
    textbox     #extinction.Kb, 351, 360, 67, 25
    textbox     #extinction.Kv, 421, 360, 67, 25
    textbox     #extinction.Kr, 491, 360, 67, 25
    textbox     #extinction.Ki, 561, 360, 67, 25

    textbox     #extinction.Analysis, 810, 335, 105, 50
    textbox     #extinction.FileName, 20, 330, 230, 25
    listbox     #extinction.Table, ExtData$(),[Extinction_Table.click], 10, 40, 625, 265

    combobox    #extinction.Comp,CompStar$(),[Select_Comp.click], 110, 362, 140, 300

    Open "K' Extinction - Johnson\Cousins\Sloan Photometry" for Window as #extinction
    #extinction "trapclose [Quit_Extinction]"
    #extinction.graphicbox1 "down; fill White; flush"
    #extinction.graphicbox1 "setfocus; when mouseMove [MouseChange1]"
    #extinction.Table "selectindex 1"
    #extinction.Comp "selectindex 1"
    #extinction "font courier_new 10 14"

    print #extinction.FileName, "open raw data file"

    gosub [Disable_Buttons]

[loop]

Wait                                                'finised setting up, wait here for new command
'
'======menu controls
'
[Open_File]
    print #extinction.graphicbox1, "cls"            'clear all tables and graphs for new data set
    redim ExtData$(4000)
    ExtData$(1) = "open raw data file and select comp star"
    #extinction.Table "reload"
    redim CompStar$(400)
    CompStar$(1) = "select"
    #extinction.Comp "selectindex 1"

    filedialog "Open Data File", PathDataFile$, DataFile$

    for I = len(DataFile$) to 1 step -1             'remember path for opened folder and file
        if mid$(DataFile$,I,1) = "\" then
            ShortDataFile$ = mid$(DataFile$,I+1)
            PathDataFile$ = left$(DataFile$,I)+"*raw"
            exit for
        end if
    next I

    if DataFile$ = "" then
        print #extinction.FileName, "open raw data file"
    else
        files "c:\", DataFile$, info$()
        if val(info$(0, 0)) = 0 then
            notice "cannot create new file"
        else

            gosub [Disable_Buttons]

            open DataFile$ for input as #RawFile
            for RawIndex = 1 to 4                   'read first 4 lines with line input to capture commas
                line input #RawFile, RawData$(RawIndex)
            next RawIndex
            RawIndex = 4
            while eof(#RawFile)=0                   'read rest of data to end of file
                RawIndex = RawIndex + 1
                input #RawFile, RawData$(RawIndex)
            wend
            RawIndexMax = RawIndex
            close #RawFile

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Find_File_Name]"
                gosub [Find_File_Name]
                print #IREX, DataFileName$
                print #IREX, " "
            close #IREX

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [Convert_RawFile]"
                gosub [Convert_RawFile]
                print #IREX, " "
            close #IREX

            gosub [Open_Star_Data]

            gosub [Write_Window_Labels]

            gosub [Total_Count_RawFile]
            gosub [Julian_Day_RawFile]
            CompIndexMax = 1                     'reset array index to 1 for Comp Star list

            open "IREX.txt" for append as #IREX
                print #IREX, "output from [IREX_RawFile]"
                print #IREX, "star       Julean date   final cnt  filter SkyPast   Sky Future,"

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

            print #extinction.Comp, "reload"
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
        print #extinction.graphicbox1, "getbmp plot -2 -2 352 267"
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
    print #extinction.Ku, using("##.###",KU)
    print #extinction.Kb, using("##.###",KB)
    print #extinction.Kv, using("##.###",KV)
    print #extinction.Kr, using("##.###",KR)
    print #extinction.Ki, using("##.###",KI)
Wait
'
[Save_Coefficients]
    print #extinction.Ku, "!contents? KUtemp$"
    print #extinction.Kb, "!contents? KBtemp$"
    print #extinction.Kv, "!contents? KVtemp$"
    print #extinction.Kr, "!contents? KRtemp$"
    print #extinction.Ki, "!contents? KItemp$"

    KUtemp = val(KUtemp$)
    KBtemp = val(KBtemp$)
    KVtemp = val(KVtemp$)
    KRtemp = val(KRtemp$)
    KItemp = val(KItemp$)

    if KUtemp = 0 AND KBtemp = 0 AND KVtemp = 0 AND KRtemp = 0 AND KItemp = 0 then
        notice "nothing to save"
        Wait
    end if

    confirm "This will save all non-zero contents"+chr$(13)_
            +"Type a zero in box to keep previous saved coefficient"+chr$(13)+chr$(13)_
            +"Do you wish to save values?"; Answer$
    if Answer$ = "yes" then
        if KUtemp <> 0 then
            if FilterSystem$ = "1" then
                KU = KUtemp
            else
                Ku = KUtemp
            end if
        end if
        if KBtemp <> 0 then
            if FilterSystem$ = "1" then
                KB = KBtemp
            else
                Kg = KBtemp
            end if
        end if
        if KVtemp <> 0 then
            if FilterSystem$ = "1" then
                KV = KVtemp
            else
                Kr = KVtemp
            end if
        end if
        if KRtemp <> 0 then
            if FilterSystem$ = "1" then
                KR = KRtemp
            else
                Ki = KRtemp
            end if
        end if
        if KItemp <> 0 then
            if FilterSystem$ = "1" then
                KI = KItemp
            else
                Kz = KItemp
            end if
        end if
        gosub [Write_PPparms]
    end if
Wait
'
[Use_Current_Coefficients]
    print #extinction.Ku, using("##.###",KUtemporary)
    print #extinction.Kb, using("##.###",KBtemporary)
    print #extinction.Kv, using("##.###",KVtemporary)
    print #extinction.Kr, using("##.###",KRtemporary)
    print #extinction.Ki, using("##.###",KItemporary)
Wait
'
[Enter_SOE_Coefficients]
    confirm "The default value of K'' is 0. Use the SOE K''"+chr$(13)+_
            "Coefficient module to calculate K'' from Blue-Red "+chr$(13)+_
            "star observations and save results to PPparms. Continue"+chr$(13)+_
            "if you wish to enter a value"+chr$(13)+chr$(13)+_
            "Continue anyway?"; answerSOE$
            if answerSOE$ = "no" then [loop]
    prompt "SOE Coefficient"+chr$(13)+_
           "Enter new value, current value = "+using("###.###", KKbv); KKbv$
            if KKbv$ <> "" then
                KKbv = val(KKbv$)
                gosub [Write_PPparms]
            end if
wait
'
[Clear_Results]
    print #extinction.Ku, ""
    print #extinction.Kb, ""
    print #extinction.Kv, ""
    print #extinction.Kr, ""
    print #extinction.Ki, ""
wait
'
[Location]

    NOMAINWIN
    WindowWidth = 227 : WindowHeight = 240
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #location, "&File" , "E&xit", [Quit_location], "Save", [Save_location]

    statictext  #location.text1, "use decimal format", 35,20,150,18

    groupbox    #location.longitude, "Longitude", 10, 50, 200, 60
    radiobutton #location.E, "E", [setE], [resetE], 25,80,30,16
    radiobutton #location.W, "W", [setW], [resetW], 70,80,30,16
    textbox     #location.long, 115, 75, 70, 25

    groupbox    #location.latitude, "Latitude", 10, 120, 200, 60
    radiobutton #location.N, "N", [setN], [resetN], 25,150,30,16
    radiobutton #location.S, "S", [setS], [resetS], 70,150,30,16
    textbox     #location.lat,  115, 145, 70, 25

    Open "Edit Location" for Window as #location
        #location "trapclose [Quit_location]"
        #location "font courier_new 8 16"

    LocationFlag = 1

    LATdec$  = mid$(Location$,2,4)
    LATns$   = left$(Location$,1)
    LONGdec$ = mid$(Location$,8,5)
    LONGew$  = mid$(Location$,7,1)

    SELECT CASE LATns$
        CASE "N"
            print #location.N, "set"
        CASE "S"
            print #location.S, "set"
        CASE ELSE
            notice "error in reading N or S latitude"
            wait
    END SELECT
    SELECT CASE LONGew$
        CASE "E"
            print #location.E, "set"
        CASE "W"
            print #location.W, "set"
        CASE ELSE
            notice "error in reading W or E longitude"
            wait
    END SELECT

    print #location.lat, "  "+LATdec$
    print #location.long, " "+LONGdec$ 

    wait

    [setE]
        LONGew$ = "E"
    wait

    [setW]
        LONGew$ = "W"
    wait

    [setN]
        LATns$ = "N"
    wait

    [setS]
        LATns$ = "S"
    wait

    [resetE]
    [resetW]
    [resetN]
    [resetS]
    wait

    [Save_location]
        print #location.lat, "!contents? LATdec$";
        print #location.long, "!contents? LONGdec$";

        LATdec = val(LATdec$)
        LONGdec = val(LONGdec$)

        if LATdec < 0 or LATdec > 90 or LONGdec < 0 or LONGdec > 180 then
            notice "longitude or latitude out of range"
            wait
        end if
                                            'convert textbox values to correct format
        LATdec$  = right$("0"+str$(int(LATdec)),2)+mid$(str$((LATdec MOD 1)+0.05),2,2)
        LONGdec$ = right$("00"+str$(int(LONGdec)),3)+mid$(str$((LONGdec MOD 1)+0.05),2,2)

        Location$ = LATns$+LATdec$+"_"+LONGew$+LONGdec$

        Gosub [Write_PPparms]

        open "IREX.txt" for append as #IREX
            print #IREX, "output from [Location]"
            print #IREX, " "
            print #IREX, "Location$ = ";Location$
            print #IREX, " "
        close #IREX
    wait

    [Quit_location]
    close #location
    LocationFlag = 0
wait
'
[About]
    notice "K' Extinction - Johnso\Cousins\Sloan Differential Photometry"+chr$(13)+_
           "version "+VersionNumber$+chr$(13)+_
           "copyright 2015, Gerald Persha"+chr$(13)+_
           "www.sspdataq.com"
Wait
'
[Help]
    run "hh photometry2.chm"
Wait
'
[MouseChange1]
    'MouseX and MouseY contain mouse coordinates
wait
'
[Quit_Extinction]                   'exit program

    confirm "do you wish to exit program?"; Answer$

    if Answer$ = "yes" then
        if LocationFlag = 1 then
            close #location
        end if
        close #extinction
    else
        wait
    end if
END
'
'=====control buttons and control boxes
'
[Show_U.click]
    print #extinction.Print, "!Enable"
    KUtemporary = 0
    if FilterSystem$ = "1" then
        Yaxis$ = "\u"
    else
        Yaxis$ = "\u'"
    end if
    print #extinction.graphicbox1, "color black"
    gosub [Draw_Graph_Outline]
    gosub [Create_Regression_Array]
    gosub [Solve_Regression_Matrix]
    print #extinction.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                                using("####.###", Intercept) + chr$(13) + chr$(10) +_
                                using("####.###", std.error)
    PointColor$ = "darkblue"
    gosub [Draw_Best_Line]
    gosub [Draw_Description]
    print #extinction.graphicbox1, "flush"
    KUtemporary = Slope
wait

[Show_B.click]
    print #extinction.Print, "!Enable"
    KBtemporary = 0
    if FilterSystem$ = "1" then
        Yaxis$ = "\b"
        PointColor$ = "blue"
    else
        Yaxis$ = "\g'"
        PointColor$ = "green"
    end if
    print #extinction.graphicbox1, "color black"
    gosub [Draw_Graph_Outline]
    gosub [Create_Regression_Array]
    gosub [Solve_Regression_Matrix]
    print #extinction.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                                using("####.###", Intercept) + chr$(13) + chr$(10) +_
                                using("####.###", std.error)

    gosub [Draw_Best_Line]
    gosub [Draw_Description]
    print #extinction.graphicbox1, "flush"
    KBtemporary = Slope
wait

[Show_V.click]
    print #extinction.Print, "!Enable"
    KVtemporary = 0
    if FilterSystem$ = "1" then
        Yaxis$ = "\v"
        PointColor$ = "darkgreen"
    else
        Yaxis$ = "\r'"
        PointColor$ = "red"
    end if
    print #extinction.graphicbox1, "color black"
    gosub [Draw_Graph_Outline]
    gosub [Create_Regression_Array]
    gosub [Solve_Regression_Matrix]
    print #extinction.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                                using("####.###", Intercept) + chr$(13) + chr$(10) +_
                                using("####.###", std.error)

    gosub [Draw_Best_Line]
    gosub [Draw_Description]
    print #extinction.graphicbox1, "flush"
    KVtemporary = Slope
wait

[Show_R.click]
    print #extinction.Print, "!Enable"
    KRtemporary = 0
    if FilterSystem$ = "1" then
        Yaxis$ = "\r"
        PointColor$ = "red"
    else
        Yaxis$ = "\i'"
        PointColor$ = "darkred"
    end if
    print #extinction.graphicbox1, "color black"
    gosub [Draw_Graph_Outline]
    gosub [Create_Regression_Array]
    gosub [Solve_Regression_Matrix]
    print #extinction.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                                using("####.###", Intercept) + chr$(13) + chr$(10) +_
                                using("####.###", std.error)

    gosub [Draw_Best_Line]
    gosub [Draw_Description]
    print #extinction.graphicbox1, "flush"
    KRtemporary = Slope
wait

[Show_I.click]
    print #extinction.Print, "!Enable"
    KItemporary = 0
    if FilterSystem$ = "1" then
        Yaxis$ = "\i"
        PointColor$ = "darkred"
    else
        Yaxis$ = "\z'"
        PointColor$ = "black"
    end if
    print #extinction.graphicbox1, "color black"
    gosub [Draw_Graph_Outline]
    gosub [Create_Regression_Array]
    gosub [Solve_Regression_Matrix]
    print #extinction.Analysis, using("####.###", Slope) + chr$(13) + chr$(10) +_
                                using("####.###", Intercept) + chr$(13) + chr$(10) +_
                                using("####.###", std.error)

    gosub [Draw_Best_Line]
    gosub [Draw_Description]
    print #extinction.graphicbox1, "flush"
    KItemporary = Slope
wait

[Extinction_Table.click]
    #extinction.Table "selection? selected$"
wait
'
[Select_Comp.click]

    print #extinction.graphicbox1, "cls"            'clear the graphics box

    print #extinction.Comp, "selection? selectedComp$"

    print #extinction.ShowU, "!Disable"             'disable the graph buttons until there is data
    print #extinction.ShowB, "!Disable"
    print #extinction.ShowV, "!Disable"
    print #extinction.ShowR, "!Disable"
    print #extinction.ShowI, "!Disable"
    print #extinction.Print, "!Disable"

    RA = 0
    DEC = 0
                                    'get RA and DEC info of comp star from Star Data file
    for DataIndex = 1 to DataIndexMax
        if selectedComp$ = left$(SDitem$(DataIndex,1)+"           ",12) then
                                    'convert RA and DEC to decimal
            RA =  val(SDitem$(DataIndex,3)) + val(SDitem$(DataIndex,4))/60 + val(SDitem$(DataIndex,5))/3600
            RA = (RA/24) * 360       'convert RA to degreeS

            DEC = abs(val(right$(SDitem$(DataIndex,6),2))) +_
                  val(SDitem$(DataIndex,7))/60 + val(SDitem$(DataIndex,8))/3600
                                    'see if  minus sign is in the degree string and make DEC negative if so
                                    'this is need in case of DECd = - 0
            if left$(SDitem$(DataIndex,6),1) = "-" then
                DEC = DEC * -1
            end if
           exit for
        end if
    next
    if (RA = 0) AND (DEC = 0) then
        notice "could not find selected Comp Star in Star Data file"
        wait
    end if
    gosub [Create_Extinction_Table]

    for RawIndex = 5 to RawIndexMax                 'turn on graph buttons for those with data
        if RDitem$(RawIndex,9) = "U" OR RDitem$(RawIndex,9) = "u" then
            print #extinction.ShowU, "!Enable"
        end if
        if RDitem$(RawIndex,9) = "B" OR RDitem$(RawIndex,9) = "g" then
            print #extinction.ShowB, "!Enable"
        end if
        if RDitem$(RawIndex,9) = "V" OR RDitem$(RawIndex,9) = "r" then
            print #extinction.ShowV, "!Enable"
        end if
        if RDitem$(RawIndex,9) = "R" OR RDitem$(RawIndex,9) = "i" then
            print #extinction.ShowR, "!Enable"
        end if
        if RDitem$(RawIndex,9) = "I" OR RDitem$(RawIndex,9) = "z" then
            print #extinction.ShowI, "!Enable"
        end if
    next
wait
'
[DataPrint.click]
    printerdialog
    if PrinterName$ <> "" then
        print #extinction.graphicbox1, "Print VGA"
        dump
    end if
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
            RawIndexMax = RawIndex - 1
            exit for
        end if
        RDitem$(RawIndex,1)  = mid$(RawData$(RawIndex),1,2)        'UT month
        RDitem$(RawIndex,2)  = mid$(RawData$(RawIndex),4,2)        'UT day
        RDitem$(RawIndex,3)  = mid$(RawData$(RawIndex),7,4)        'UT year
        RDitem$(RawIndex,4)  = mid$(RawData$(RawIndex),12,2)       'UT hour
        RDitem$(RawIndex,5)  = mid$(RawData$(RawIndex),15,2)       'UT minute
        RDitem$(RawIndex,6)  = mid$(RawData$(RawIndex),18,2)       'UT second
        RDitem$(RawIndex,7)  = mid$(RawData$(RawIndex),21,1)       'catalog: C, V
        RDitem$(RawIndex,8)  = mid$(RawData$(RawIndex),26,12)      'star name, SKY, SKYNEXT or SKYLAST
        RDitem$(RawIndex,9)  = mid$(RawData$(RawIndex),41,1)       'filter: U,B,V,R or I
        RDitem$(RawIndex,10) = mid$(RawData$(RawIndex),44,5)       'Count 1
        RDitem$(RawIndex,11) = mid$(RawData$(RawIndex),51,5)       'Count 2
        RDitem$(RawIndex,12) = mid$(RawData$(RawIndex),58,5)       'Count 3
        RDitem$(RawIndex,13) = mid$(RawData$(RawIndex),65,5)       'Count 4
        RDitem$(RawIndex,14) = mid$(RawData$(RawIndex),72,2)       'integration time in seconds: 1 or 10
        RDitem$(RawIndex,15) = mid$(RawData$(RawIndex),75,3)       'scale: 1, 10 or 100

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
        print #extinction.statictext4, "u"
        print #extinction.statictext5, "b "
        print #extinction.statictext6, "v "
        print #extinction.statictext7, "r "
        print #extinction.statictext8, "i "
        print #extinction.statictext11, "u"
        print #extinction.statictext12, "b"
        print #extinction.statictext13, "v"
        print #extinction.statictext14, "r"
        print #extinction.statictext15, "i"
        print #extinction.statictext36, "b"
        print #extinction.statictext38, "v"
        print #extinction.statictext40, "r"
        print #extinction.statictext42, "i"
        print #extinction.ShowU, "u "
        print #extinction.ShowB, "b "
        print #extinction.ShowV, "v "
        print #extinction.ShowR, "r "
        print #extinction.ShowI, "i "
    else
        print #extinction.statictext4, "u"
        print #extinction.statictext5, "g "
        print #extinction.statictext6, "r "
        print #extinction.statictext7, "i "
        print #extinction.statictext8, "z "
        print #extinction.statictext11, "u"
        print #extinction.statictext12, "g"
        print #extinction.statictext13, "r"
        print #extinction.statictext14, "i"
        print #extinction.statictext15, "z"
        print #extinction.statictext36, "g"
        print #extinction.statictext38, "r"
        print #extinction.statictext40, "i"
        print #extinction.statictext42, "z"
        print #extinction.ShowU, "u'"
        print #extinction.ShowB, "g'"
        print #extinction.ShowV, "r'"
        print #extinction.ShowR, "i'"
        print #extinction.ShowI, "z'"
    end if
return
'
[Disable_Buttons]
    print #extinction.ShowU, "!Disable"             'disable the graph buttons until there is data
    print #extinction.ShowB, "!Disable"
    print #extinction.ShowV, "!Disable"
    print #extinction.ShowR, "!Disable"
    print #extinction.ShowI, "!Disable"
    print #extinction.Print, "!Disable"
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
        CountFinal(RawIndex) = int((CountSum/Divider) * (100/(Integration * Scale)))
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
                       (val(RDitem$(RawIndex,4)) + val(RDitem$(RawIndex,5))/60 +_
                        val(RDitem$(RawIndex,6))/3600)/24
                                'Julian century
        JT(RawIndex) = JD(RawIndex)/36525
    next
return
'
[IREX_RawFile]          'subtract skies from comp star data
    for RawIndex = 5 to RawIndexMax
                    'go through raw file and pick out the COMP stars with the selected filter U B V R or I
        if (RDitem$(RawIndex,7) = "C")  AND (RDitem$(RawIndex,9) = Filter$) then

                    'make list of unique comparison stars for COMP combobox
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
                    'subtract sky from COMP count depending on SKY, SKYNEXT or SKYLAST protocol and change
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
'=====subroutines for creating estinction table
'
                                'create ExtData() for display in listbox
[Create_Extinction_Table]
    redim ExtData$(4000)
    redim ExtData(4000,12)
    ExtIndex = 0
    for RawIndex = 5 to RawIndexMax
        if selectedComp$ = RDitem$(RawIndex,8) then
            ExtIndex = ExtIndex + 1
            gosub [Siderial_Time]
            gosub [Find_Air_Mass]
            ExtData(ExtIndex,1) = HA
            ExtData(ExtIndex,2) = AirMass
            FilterID$ =  RDitem$(RawIndex,9)
            select case
                case (FilterID$ = "U") OR (FilterID$ = "u")
                    ExtData(ExtIndex,3) = CountFinal(RawIndex)                                         'u counts
                    ExtData(ExtIndex,4) = 0                                                            'b counts
                    ExtData(ExtIndex,5) = 0                                                            'v counts
                    ExtData(ExtIndex,6) = 0                                                            'r counts
                    ExtData(ExtIndex,7) = 0                                                            'i counts
                    ExtData(ExtIndex,8) = -1.0857*log(CountFinal(RawIndex))  'ln(x) = 2.3026 * log(x)  'u inst. mag.
                    ExtData(ExtIndex,9) = 0                                                            'b inst. mag.
                    ExtData(ExtIndex,10) = 0                                                           'v inst. mag.
                    ExtData(ExtIndex,11) = 0                                                           'r inst. mag.
                    ExtData(ExtIndex,12) = 0                                                           'i inst. mag.
                case (FilterID$ = "B") OR (FilterID$ = "g")
                    ExtData(ExtIndex,3) =  0                                                           'u counts
                    ExtData(ExtIndex,4) = CountFinal(RawIndex)                                         'b counts
                    ExtData(ExtIndex,5) = 0                                                            'v counts
                    ExtData(ExtIndex,6) = 0                                                            'r counts
                    ExtData(ExtIndex,7) = 0                                                            'i counts
                    ExtData(ExtIndex,8) = 0                                                            'u inst. mag.
                    ExtData(ExtIndex,9) = -1.0857*log(CountFinal(RawIndex))  'ln(x) = 2.3026 * log(x)  'b inst. mag.
                    ExtData(ExtIndex,10) = 0                                                           'v inst. mag.
                    ExtData(ExtIndex,11) = 0                                                           'r inst. mag.
                    ExtData(ExtIndex,12) = 0                                                           'i inst. mag.
                case (FilterID$ = "V") OR (FilterID$ = "r")
                    ExtData(ExtIndex,3) = 0                                                            'u counts
                    ExtData(ExtIndex,4) = 0                                                            'b counts
                    ExtData(ExtIndex,5) = CountFinal(RawIndex)                                         'v counts
                    ExtData(ExtIndex,6) = 0                                                            'r counts
                    ExtData(ExtIndex,7) = 0                                                            'i counts
                    ExtData(ExtIndex,8) = 0                                                            'u inst. mag.
                    ExtData(ExtIndex,9) = 0                                                            'b inst. mag.
                    ExtData(ExtIndex,10) = -1.0857*log(CountFinal(RawIndex))  'ln(x) = 2.3026 * log(x) 'v inst. mag.
                    ExtData(ExtIndex,11) = 0                                                           'r inst. mag.
                    ExtData(ExtIndex,12) = 0                                                           'i inst. mag.
                case (FilterID$ = "R") OR (FilterID$ = "i")
                    ExtData(ExtIndex,3) = 0                                                            'u counts
                    ExtData(ExtIndex,4) = 0                                                            'b counts
                    ExtData(ExtIndex,5) = 0                                                            'v counts
                    ExtData(ExtIndex,6) = CountFinal(RawIndex)                                         'r counts
                    ExtData(ExtIndex,7) = 0                                                            'i counts
                    ExtData(ExtIndex,8) = 0                                                            'u inst. mag.
                    ExtData(ExtIndex,9) = 0                                                            'b inst. mag.
                    ExtData(ExtIndex,10) = 0                                                           'v inst. mag.
                    ExtData(ExtIndex,11) = -1.0857*log(CountFinal(RawIndex))  'ln(x) = 2.3026 * log(x) 'r inst. mag.
                    ExtData(ExtIndex,12) = 0                                                           'i inst. mag.
                case (FilterID$ = "I") OR (FilterID$ = "z")
                    ExtData(ExtIndex,3) = 0                                                            'u counts
                    ExtData(ExtIndex,4) = 0                                                            'b counts
                    ExtData(ExtIndex,5) = 0                                                            'v counts
                    ExtData(ExtIndex,6) = 0                                                            'r counts
                    ExtData(ExtIndex,7) = CountFinal(RawIndex)                                         'i counts
                    ExtData(ExtIndex,8) = 0                                                            'u inst. mag.
                    ExtData(ExtIndex,9) = 0                                                            'b inst. mag.
                    ExtData(ExtIndex,10) = 0                                                           'v inst. mag.
                    ExtData(ExtIndex,11) = 0                                                           'r inst. mag.
                    ExtData(ExtIndex,12) = -1.0857*log(CountFinal(RawIndex))  'ln(x) = 2.3026 * log(x) 'i inst. mag.
            end select
            ExtData$(ExtIndex) = using("###.##",ExtData(ExtIndex,1))+"  "+_    'hour angle
                                 using("#.###",ExtData(ExtIndex,2))+" "        'air mass

                                 for I = 3 to 7
                                    if ExtData(ExtIndex,I) = 0 then
                                        Temp$ = " . . . "
                                    else
                                        Temp$ = using("######",ExtData(ExtIndex,I))+" "     'u,b,v,r,i counts
                                    end if
                                    ExtData$(ExtIndex) = ExtData$(ExtIndex) + Temp$
                                 next I

                                 for I = 8 to 11
                                    if ExtData(ExtIndex,I) = 0 then
                                        Temp$ = " . . . "
                                    else
                                        Temp$ = using("###.##",ExtData(ExtIndex,I))+" "     'u,b,v,r magnitude
                                    end if
                                    ExtData$(ExtIndex) = ExtData$(ExtIndex) + Temp$
                                 next I

                                 if ExtData(ExtIndex,12) = 0 then
                                    Temp$ = " . . . "
                                 else
                                    Temp$ = using("###.##",ExtData(ExtIndex,12))            'i magnitude
                                 end if
                                 ExtData$(ExtIndex) = ExtData$(ExtIndex) + Temp$ 

        end if
    next
    ExtIndexMax = ExtIndex
    print #extinction.Table, "font courier_new 8 12"
    print #extinction.Table, "reload"
return
'
[Create_Regression_Array]
    RegIndex = 0
    select case Yaxis$           'select the appropriate data for desired color
        case "\u"
            color = 8
        case "\u'"
            color = 8
        case "\b"
            color = 9
        case "\g'"
            color = 9
        case "\v"
            color = 10
        case "\r'"
            color = 10
        case "\r"
            color = 11
        case "\i'"
            color = 11
        case "\i"
            color = 12
        case "\z'"
            color = 12
    end select

    for ExtIndex = 1 to ExtIndexMax
        if ExtData(ExtIndex,color) <> 0 then
            RegIndex = RegIndex + 1
            X(RegIndex) = ExtData(ExtIndex,2)
            m(RegIndex) = ExtData(ExtIndex,color)
        end if
    next
    RegIndexMax = RegIndex

    open "IREX.txt" for append as #IREX
         print #IREX, "output from [Create_Regression_Array]"
         print #IREX, "color: "+right$(Yaxis$,1)
         print #IREX, "RegIndex     X         m"
         for RegIndex = 1 to RegIndexMax
            print #IREX, using("####",RegIndex)+"   "+_
                         using("###.####",X(RegIndex))+"   "+_
                         using("###.####",m(RegIndex))
         next
         print #IREX, " "
    close #IREX
return
'
'====subroutines for file operations
'
[Write_PPparms]
    open "PPparms3.txt" for output as #PPparms
        print #PPparms, Location$                   'latitude and longitude
        print #PPparms, using("##.###",KU)          'first order extinction for U
        print #PPparms, using("##.###",KB)          'first order extinction for B
        print #PPparms, using("##.###",KV)          'first order extinction for V
        print #PPparms, using("##.###",KR)          'first order extinction for R
        print #PPparms, using("##.###",KI)          'first order extinction for I
        print #PPparms, using("##.###",KKbv)        'second order extinction for b-v, default = 0
        print #PPparms, using("##.###",Eps)         'transformation coeff. epsilon for V using B-V
        print #PPparms, using("##.###",Psi)         'transformation coeff. Psi for U-B
        print #PPparms, using("##.###",Mu)          'transformation coeff. mu for B-V
        print #PPparms, using("##.###",Tau)         'transformation coeff. tau for V-R
        print #PPparms, using("##.###",Eta )        'transformation coeff. eta for V-I
        print #PPparms, using("##.###",EpsR )       'transformation coeff. epsilon for V using V-R
        print #PPparms, EpsilonFlag                 '1 if using epsilon to find V and 0 if using epsilon R
        print #PPparms, JDFlag                      '1 if using JD and 0 if using HJD
        print #PPparms, OBSCODE$                    'AAVSO observatory code
        print #PPparms, MEDUSAOBSCODE$              'MEDUSA observatory code
        print #PPparms, using("#.###",Ku)           'first order extinction for Sloan u'
        print #PPparms, using("#.###",Kg)           'first order extinction for Sloan g'
        print #PPparms, using("#.###",Kr)           'first order extinction for Sloan r'
        print #PPparms, using("#.###",Ki)           'first order extinction for Sloan i'
        print #PPparms, using("#.###",Kz)           'first order extinction for Sloan z'
        print #PPparms, using("##.###",KKgr)        'second order extinction for g-r, default = 0
        print #PPparms, using("##.###",SEps)        'transformation coeff. Sloan epsilon for r using g-r
        print #PPparms, using("##.###",SPsi)        'transformation coeff. Sloan psi for u-g
        print #PPparms, using("##.###",SMu)         'transformation coeff. Sloan mu for g-r
        print #PPparms, using("##.###",STau)        'transformation coeff. Sloan tau for r-i
        print #PPparms, using("##.###",SEta)        'transformation coeff. Sloan eta for r-z
        print #PPparms, using("##.###",SEpsR)       'transformation coeff.  Sloan epsilon for r using r-i
        print #PPparms, using("##.###",ZPv)         'zero-point constant for v
        print #PPparms, using("##.###",ZPr)         'zero-point constant for r'
        print #PPparms, using("##.###",ZPbv)        'zero-point constant for b-v
        print #PPparms, using("##.###",ZPgr)        'zero-point constant for g'-r'
        print #PPparms, using("##.###",Ev)          'standard error for v
        print #PPparms, using("##.###",Er)          'standard error for r'
        print #PPparms, using("##.###",Ebv)         'standard error for b-v
        print #PPparms, using("##.###",Egr)         'standard error for g'-r'        
    close #PPparms
return
'
[Find_File_Name]        'seperate out filename and extension from info() path/filename
    FileNameIndex = len(DataFile$)
    FileNameLength = len(DataFile$)
    while mid$(DataFile$, FileNameIndex,1)<>"\"                    'look for the last backlash
        FileNameIndex = FileNameIndex - 1
    wend
    FileNamePath$ = left$(DataFile$, FileNameIndex)
    DataFileName$ = right$(DataFile$, FileNameLength-FileNameIndex)

    print #extinction.FileName, DataFileName$                      'display filename in "File" textbox
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
[Find_Air_Mass]         'compute air mass
    HA = LMST - RA                          'find hour angle in degrees
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
[Solve_Regression_Matrix]
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
    a1 = RegIndexMax
    for I = 1 to RegIndexMax
        a2 = a2 + X(I)
        a3 = a3 + X(I) * X(I)
        c1 = c1 + m(I)
        c2 = c2 + m(I) * X(I)
    next
    det = 1/(a1 * a3 - a2 * a2)
    Intercept = -1 * (a2 * c2 - c1 * a3) * det
    Slope = (a1 * c2 - c1 * a2) * det

            'compute standard error using eq. 3.21
    if RegIndexMax > 2 then
        y.deviation.squared.sum = 0
        for N = 1 to RegIndexMax
            y.fit = Slope * X(N) + Intercept
            y.deviation = m(N) - y.fit
            y.deviation.squared.sum =  y.deviation.squared.sum + y.deviation^2
        next
        std.error = sqr((1/(N-2)) * y.deviation.squared.sum)
    else
        std.error = 0
    end if

    open "IREX.txt" for append as #IREX
        print #IREX, "output from [Solve_Regression_Matrix]"
        print #IREX, "color: "+right$(Yaxis$,1)
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
    print #extinction.graphicbox1, "cls"
    print #extinction.graphicbox1, "font arial 8 16"
    print #extinction.graphicbox1, "down"
    print #extinction.graphicbox1, "place 10 125"
    print #extinction.graphicbox1, Yaxis$
    print #extinction.graphicbox1, "place 143 254"
    print #extinction.graphicbox1, "\X  (air mass)"
    print #extinction.graphicbox1, "font arial 6 12"
    print #extinction.graphicbox1, "place 30 235"
    print #extinction.graphicbox1, "\1.0"
    print #extinction.graphicbox1, "place 133 235"
    print #extinction.graphicbox1, "\1.5"
    print #extinction.graphicbox1, "place 233 235"
    print #extinction.graphicbox1, "\2.0"
    print #extinction.graphicbox1, "place 328 235"
    print #extinction.graphicbox1, "\2.5"
    print #extinction.graphicbox1, "line 40 20 40 220"
    print #extinction.graphicbox1, "line 40 220 340 220"
        print #extinction.graphicbox1, "font arial 6 12"
    for I = 1 to 10                     'print Y-axis divisions every 0.1 mag
        xD =  20 * I
        print #extinction.graphicbox1, "line 40 ";xD;" 45 ";xD
    next
    for I = 1 to 15                     'print X-axis division every 0.1 air mass
        yD = 40 + 20 * I
        print #extinction.graphicbox1, "line ";yD;" 220 ";yD;" 215"
    next
    for I = 0 to 3                      'print X-axis long division every 0.5 air mass
        yD = 40 + I * 100
        print #extinction.graphicbox1, "line ";yD;" 220 ";yD;" 210"
    next
return
'
[Draw_Best_Line]
    print #extinction.graphicbox1, "color ";PointColor$
    print #extinction.graphicbox1, "backcolor ";PointColor$
    StartLine = 1.0 * Slope + Intercept                         'start of best fit line at X = 1.00
    EndLine   = 2.5 * Slope + Intercept                         'end of best fit line at X = 2.50
    YaxisTop = abs(int(StartLine * 10)) * 20 + 60               'value for top of Y axis, about 0.2 mag higher
                                                                'than best fit line
    StartLine = YaxisTop - abs(int(StartLine * 200))
    EndLine = YaxisTop - abs(int(EndLine * 200))
    print #extinction.graphicbox1, "line 40 ";StartLine;" 340 ";EndLine
                                                                'plot data points
    for RegIndex = 1 to RegIndexMax
        Xpoint = int(X(RegIndex) * 200) - 160
        Ypoint = YaxisTop - abs(int(m(RegIndex) * 200))
        print #extinction.graphicbox1, "place ";Xpoint;" ";Ypoint
        print #extinction.graphicbox1, "circlefilled 3"
    next
                                                                'draw y scale values
    print #extinction.graphicbox1, "backcolor white"
    print #extinction.graphicbox1, "color black"
    print #extinction.graphicbox1, "font arial 6 12"
    print #extinction.graphicbox1, "place 7 25"
    Temporary = Slope + Intercept - .15
    ScaleTop$ = "\"+using("###.#", Temporary)
    print #extinction.graphicbox1, ScaleTop$
    print #extinction.graphicbox1, "place 7 220"
    Temporary = Temporary + 1
    ScaleBot$ = "\"+using("###.#", Temporary)
    print #extinction.graphicbox1, ScaleBot$
return
'
[Draw_Description]
                                                    'print file name
    print #extinction.graphicbox1, "place 60 300"
    print #extinction.graphicbox1, "\FILE NAME :"
    print #extinction.graphicbox1, "place 160 300"
    GraphicFileName$ = "\"+ShortDataFile$
    print #extinction.graphicbox1, GraphicFileName$ 
                                                    'print extiction star
    print #extinction.graphicbox1, "place 60 325"
    print #extinction.graphicbox1, "\STAR :"
    print #extinction.graphicbox1, "place 160 325"
    GraphicSelectedComp$ = "\"+selectedComp$
    print #extinction.graphicbox1, GraphicSelectedComp$
                                                    'print start Julian Date
    print #extinction.graphicbox1, "place 60 350"
    print #extinction.graphicbox1, "\START J2000:"
    print #extinction.graphicbox1, "place 160 350"
    GraphicStartJD$ = "\"+Using("####.####", StartJD)
    print #extinction.graphicbox1, GraphicStartJD$ 
                                                    'print end Julian Date
    print #extinction.graphicbox1, "place 60 375"
    print #extinction.graphicbox1, "\END J2000:"
    print #extinction.graphicbox1, "place 160 375"
    GraphicEndJD$ = "\"+Using("####.####", EndJD)
    print #extinction.graphicbox1, GraphicEndJD$ 
                                                    'print slope
    print #extinction.graphicbox1, "place 60 400"
    print #extinction.graphicbox1, "\SLOPE:"
    print #extinction.graphicbox1, "place 160 400"
    GraphicSlope$ = "\"+Using("####.###", Slope)
    print #extinction.graphicbox1, GraphicSlope$ 
                                                    'printer intercept
    print #extinction.graphicbox1, "place 60 425"
    print #extinction.graphicbox1, "\INTERCEPT:"
    print #extinction.graphicbox1, "place 160 425"
    GraphicIntercept$ = "\"+Using("####.###", Intercept)
    print #extinction.graphicbox1, GraphicIntercept$ 
                                                    'print standard error
    print #extinction.graphicbox1, "place 60 450"
    print #extinction.graphicbox1, "\STD. ERROR:"
    print #extinction.graphicbox1, "place 160 450"
    GraphicStd.error$ = "\"+Using("####.###", std.error)
    print #extinction.graphicbox1, GraphicStd.error$ 
return
'
end

