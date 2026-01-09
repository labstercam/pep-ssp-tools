    DIM info$(10, 10)               'get file information from users disk drive
    files "c:\", info$()

    VersionNumber$ = "2.56"

    NOMAINWIN
    WindowWidth = 423
    WindowHeight = 366
    UpperLeftX=int((DisplayWidth-WindowWidth)/2)
    UpperLeftY=int((DisplayHeight-WindowHeight)/2)

    menu #Launcher, "File", "Exit", [Quit_Launcher]
    menu #Launcher, "About", "Version", [Version]

    groupbox #Launcher.groupbox12, "License Holder",  10, 122, 190, 178
    groupbox #Launcher.groupbox4,  "Photometry", 215,  17, 190, 283
    groupbox #Launcher.groupbox3,  "Data Acquisition and Control",  10,  17, 190, 90
    button   #Launcher.button1,    "SSPDataq3",[SSPDataq], UL,  28,  42, 155,  25
    button   #Launcher.button2,    "SSPDataq3 Help",[SSPDataqHelp], UL,  28,  74, 155,  25
    button   #Launcher.button5,    "Star Database Editor",[StarDatabase], UL, 233,  42, 155,  25
    button   #Launcher.button6,    "Extinction",[Extinction], UL, 233,  74, 155,  25
    button   #Launcher.button7,    "SOE",[SOE], UL, 233, 106, 155,  25
    button   #Launcher.button12,   "All Sky Calibration",[AllSky], UL, 233, 137, 155,  25
    button   #Launcher.button8,    "Transformation",[Transformation], UL, 233, 170, 155,  25
    button   #Launcher.button9,    "Reduction",[Reduction], UL, 233, 203, 155,  25
    button   #Launcher.button10,   "Plot Data",[PlotData], UL, 233, 236, 155,  25
    button   #Launcher.button11,   "Photometry Help",[PhotometryHelp], UL, 233, 269, 155,  25

'=============change these two line per customer information=================
    statictext #Launcher.statictext13, "free for",  28, 167,  100,  20
    statictext #Launcher.statictext14, "all users",  28, 192,  170,  20
    statictext #Launcher.statictext15, " ",  28, 210,  169,  20
    statictext #Launcher.statictext16, " ",  28, 228,  160,  20
'============================================================================

    open "SSPDataq3 Program Launcher" for window as #Launcher
    print #Launcher, "font ms_sans_serif 10"
    print #Launcher.statictext13, "!font ms_sans_serif 12"

    #Launcher "trapclose [Quit_Launcher]"

    [WaitHere]

    wait
    goto [WaitHere]

    [Version]
        notice "SSPDataq Program Launcher"+chr$(13)+_
               "Version "+VersionNumber$
    goto [WaitHere]

    [SSPDataq]
        files DefaultDir$, "SSPDataq3.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "SPPDataq3 not found"
        else
            run "SSPdataq3.tkn"
        end if
    goto [WaitHere]

    [SSPDataqHelp]
        run "hh sspdataq3.chm"
    goto [WaitHere]

    [StarDatabase]
        files DefaultDir$, "Data_Editor2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Star Data Editor not found"
        else
            run "Data_Editor2.tkn"
        end if
    goto [WaitHere]

    [Extinction]
        files DefaultDir$, "Extinction2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Extinction coefficients program not found"
        else
            run "Extinction2.tkn"
        end if
    goto [WaitHere]

    [SOE]
        files DefaultDir$, "SOE2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "SOE coefficient program not found"
        else
            run "SOE2.tkn"
        end if
    goto [WaitHere]

    [AllSky]
        files DefaultDir$, "AllSky.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "All Sky Calibration program not found"
        else
            run "AllSky.tkn"
        end if
    goto [WaitHere]

    [Transformation]
        files DefaultDir$, "Transformation2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Transformation coefficients program not found"
        else
            run "Transformation2.tkn"
        end if
    goto [WaitHere]

    [Reduction]
        files DefaultDir$, "Reduction2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Data reduction program not found"
        else
            run "Reduction2.tkn"
        end if
    goto [WaitHere]

    [PlotData]
        files DefaultDir$, "ShowData2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Plotting program not found"
        else
            run "ShowData2.tkn"
        end if
    goto [WaitHere]

    [PhotometryHelp]
        run "hh photometry2.chm"
    goto [WaitHere]

    [Quit_Launcher]
    close #Launcher
end
