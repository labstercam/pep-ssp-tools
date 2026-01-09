'
'                         SSP DATA ACQUISITION PROGRAM, VERSION 3 - SSPDATAQ3
'                              for control of SSP-3a and SSP-5a
'                                     copyright 2003-2015
'
'                                       Optec, Inc
'                          written and compiled with Liberty Basic
'
'revision history
'
'V3.21, September,2016
'       fixed bug in Make Script for Continuous Mode
'
'V3.20, December, 2015
'       added All Sky photometry
'
'V3.19, October 2015
'       added skyintervals
'       added interval = 2
'       added Menu Photometry to trial version
'
'V3.18, September 2015
'       compiled with LB 4.50
'       increased DIM space
'
'V3.17, February 2015
'       increased masimum number of objects that can be loaded fromm 100 to 500
'
'V3.16, December 2014
'       fixed error in Make Script with regards to Transformation Cat.
'
'V3.15, November 2014
'       fixed Make Script windows and save command
'
'V3.14, October
'       added multi filter bars
'
'V3.13, September 2014
'        added Sloan Filters
'
'V3.12, May 12, 2014
'       fixed Q'check error
'
'V3.11, November 29, 2013
'       added script control for SKY position
'
'V3.10, October 29, 2013
'       added SSPDataq Program Launcher
'
'V3.04, October 28, 2013
'       corrected error in Celestron telescope control
'
'V3.03, October 13, 2013
'       added check star catalog
'
'V3.02, September 30, 2013
'       added Telescope and Observer name to dparms
'
'V3.01, September 24, 2013
'       corrected UT day error when going past midnight
'
'V3.00, August 1, 2013
'       added telescope control
'       corrected time error in SLOW mode
'       added improved ack for GAIN, INTEG, FILTER, HOME
'
'V2.31, March 22, 2013
'       added countdown timer for FAST mode
'       changed FAST mode Integ to 0.02, 0.05, 0.10, 0.50 & 1.0 sec.
'
'V2.30, March 2013
'       added SOE reduction module
'
'V2.21, March 2010
'       fixed bug in script file so that auto filter works
'       added script writting ability
'
'V2.20, December 2009, improved folder handling
'       enable scroll bars for display window
'       created Temporary Data file to store all data during session
'       prevent program from crashing if END staement is missing in script
'       changed help file format to CHM type
'
'V2.10, January 2009, added motorized flip mirror command
'       improved communication errors with get count command
'
'V2.00, October 2007, SSPDATAQ2,00_8.BAS
'       increased star name size to 12 characters and added version 2 of the photometry package
'       improved serial communication in GET_COUNTS
'       added script functions
'
'V1.13, fixed error in reduction.bas with regards to date-to-Julian calculator for months
'       of Febuary and January
'       added more COM ports
'       compiled with 4.02 of Liberty Basic
'
'V1.12,
'
'V1.11, December 24, 2004
'   added photometry programs to menu list
'   added T selection in catalog listing
'   corrected serial setup to include COM ports 1 to 7
'
'V1.05, November 2, 2004
'   change pause SUB to include Kernel32 call for reducing computer resources
'   added better file control for fast mode and include header
'   changed Fast Mode file handling and saving
'
'v1.04, February 13, 2004
'   changed count display and saving to 5 characters from 4
'   corrected small problem with catalog$ and sky
'
'v1.03, January 14, 2004
'   corrected errors with saved files for compatibility with RPHOT
'
'v1.02, December 11, 2003
'   compiled with Liberty Basic 4.00
'   corrected mispelled variable in Pause routine
'   corrected lost space with 'select' filter
'   added more width to window to allow for all 8 note characters to fit
'   used pixel width & height spec in font command for windows
'
'v1.01, November 24, 2003
'   compiled with Liberty Basic 3.03
'   corrected fault with Pause command when going through midnight
'   corrected error in selecting and saving COM port
'
'v1.00
'   original version completed late October, 2003
'
    DIM CatalogStars$(4000)         'list of stars for object selection from a catalog
    DIM Combo1$(7)                  'filter name array
    DIM Combo2$(10)                 'gain values: 1, 10, 100
    DIM Combo3$(10)                 'integration time values
    DIM Combo4$(10)                 'interval values
    DIM Combo5$(10)                 'count mode values
    DIM Combo6$(4000)                'object values, index is objectindex
    DIM Combo7$(10)                 'catalog name values
    DIM DataArray$(4000)            'intermediate data array, the one seen in display window
    DIM SavedData$(4000)            'final data array with notes ready to be saved to file
    DIM Counts$(4000)               '8 byte readings  from photometer for slow mode, C = X X X X CR LF
    DIM FastTimeArray$(5000)        'time array to be associated with fast time counts
    DIM FastCounts$(5000)           '4 byte readings (2 byte for Vfast mode)from photometer, X X
    DIM Script$(10000)              'script command array - the value of J
    DIM TypeArray$(400)             'object type, index is ObjectIndex
    DIM RAArray(400)                'object RA in degrees, index is ObjectIndex
    DIM DECArray(400)               'object DEC in degrees, index is ObjectIndex
    DIM Filters$(18)                'list of filters in three bars of six each

    DIM SDitem$(4000,13)            'individual data items from Star Data file, index is DataIndex
'
    DIM info$(10, 10)               'get file information from users disk drive
    files "c:\", info$()
'
'====read DPAMS configuration file
'
open "dparms.txt" for input as #dparms
    input #dparms, ComPort          'COM port for SSP, values of 1 to 19 acceptable
    input #dparms, TimeZoneDiff     'values of -12 to +12 acceptable
    input #dparms, AutoManual$      'A = auto 6-position slider, M = manual 2-position slider
    for I = 1 to 18                 'filter names and positions
        input #dparms, Filters$(I)  'positions 1 to 6 for 6-position slider and obsolete 10-position slider
    next
    input #dparms, FilterBar        'filter bar number, 1 to 3, 1 default
    input #dparms, NightFlag        'night/day screen flag, 0 = day, 1 = red night screen
    input #dparms, AutoMirrorFlag   '0 = no, 1 = auto mirror installed
    input #dparms, TelescopeFlag    '0 = no telescope, 1 = telescope control enabled
    input #dparms, TelescopeCOM     'COM, port for telescope, values 1 to 19 acceptable, default 0
    input #dparms, TelescopeType    'Telescope Type, default 0 no telescope, 1 = LX200, 2 = Celestron old GT,
                                    '   3 = Celestron N5 & N8, 4 = Celestron new GT
    input #dparms, Telescope$       'name of telescope for RAW file header
    input #dparms, Observer$        'name of observer for RAW file header
    input #dparms, FilterSystem$    'filter system used in scripting, 1 = Johnson/Cousins, 0 = Sloan
close #dparms
'
'====initialize any start up values
'
VersionNumber$ = "3.21"             'version number

TrialVersion = 0                    '1 if trial version, 0 if full version

CommFlag = 0                        'Com port not opened
ScriptFlag = 0                      'Script window is not opened, 1 if it is
ScriptHold = 0                      'flag indicating that the script is running, 1 if it is, 0 if it is not
CountMode = 1                       'Trial mode set
ObjectIndex = 0                     'make sure ObjectIndex is 0 at start
ObjectIndexMax = 5                  'maximum objects$ at start
DataCounter = 0                     'start Data Array counter at 0
AckCounter = 0                      'counter for number of times to repeat command before failure, 3 = failure
for I = 1 to 4                      'clear counts array
    Counts$(I) = ""
next I
Catalog$ = " "                      'make sure one space is avaialable for display list
NewFileFlag$ = "none"               'no data file opened
DataCounterLast = 0                 'variable for find place in array after append
PathDataFile$ = "*.raw"             'default path for data files
PathFastDataFile$ = "*.raw"         'default path for fast data files
PathScript$ = "*.ssp"               'default path for script files

for I = 1 to 6
    Combo1$(I) = Filters$(I + (FilterBar - 1) * 6)
next
Combo1$(7) = "Home"                 'flag to HOME filter bar

                                    'create and/or clear temporary data to save all data
open "Temporary Data.raw" for input as #Temporary

    if eof(#Temporary) <> -1 then
        close #Temporary
        NAME "Temporary Data.raw" AS "Backup Data.raw"
        notice "IMPORTANT NOTICE"+chr$(13)+_
               "SSPDataq3 did not close normally"+chr$(13)+_
               "Your last data was saved as Backup Data.raw"+chr$(13)+_
               "Please rename or delete the file before proceeding"
       open "Temporary Data.raw" for output as #Temporary
       close #Temporary
    else
       close #Temporary
    end if
'
'
'=====set up main window
'
    NOMAINWIN
    WindowWidth = 860 : WindowHeight = 315
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
'
                          'set Gain values for combobox 2
Combo2$(1) = "1"
Combo2$(2) = "10"
Combo2$(3) = "100"
                          'set Integration values for combobox 3
Combo3$(1) = "0.02"       'SSP-5 only, very fast mode
Combo3$(2) = "0.05"       'fast mode only
Combo3$(3) = "0.10"       'fast mode only
Combo3$(4) = "0.50"       'fast mode only
Combo3$(5) = "1.00"       'fast or slow mode
Combo3$(6) = "5.00"       'fast or slow mode
Combo3$(7) = "10.00"      'fast or slow mode
                          'set Interval values for combobox 4
Combo4$(1) = "1"          'slow mode only
Combo4$(2) = "2"          'slow mode only
Combo4$(3) = "3"          'slow mode only
Combo4$(4) = "4"          'slow mode only
Combo4$(5) = "100"        'fast mode only
Combo4$(6) = "1000"       'fast mode only
Combo4$(7) = "2000"       'fast and very fast modes only
Combo4$(8) = "5000"       'fast and very fast modes only
                          'set Count mode for combobox 5
Combo5$(1) = "trial"
Combo5$(2) = "slow"
Combo5$(3) = "fast"
Combo5$(4) = "Vfast"      'only good for SSP-5
Combo5$(5) = "ABORT"      'flag to abort fast reading and reset instrument
                          'set Object values for combobox 6
Combo6$(1) = "New Object"
Combo6$(2) = "SKY"
Combo6$(3) = "SKYNEXT"
Combo6$(4) = "SKYLAST"
Combo6$(5) = "CATALOG"    'select stars for catalogs - Var/Comp, SOE, Trans
                          'set Catalog values for combobox 7
Combo7$(1) = "Astar"
Combo7$(2) = "Foe"
Combo7$(3) = "Soe"
Combo7$(4) = "Comp"
Combo7$(5) = "Var"
Combo7$(6) = "Moving"
Combo7$(7) = "Trans"
Combo7$(8) = "Q'check"
'
Menu        #main, "File",_
                         "Save Data", [SAVE_FILE],_
                         "Clear Data", [CLEAR_DATA],_
                         "Open Script File", [OPEN_SCRIPT],_
                         "Quit", [quit]
Menu        #main, "Setup",_
                         "Connect to SSP", [CONNECT_SERIAL],_
                         "Disconnect from SSP", [DISCONNECT_SERIAL],_
                         "Select SSP COM Port", [SELECT_COM_PORT],_
                         "Time Zone", [TIME_ZONE],_
                         "Filter Bar Setup", [FILTER_BAR],_
                         "Auto/Manual Filters", [AUTO_MANUAL],_
                         "Auto/Manual Mirror", [AUTO_MIRROR],_
                         "Night/Day Screen", [NIGHT],_
                         "Show Setup Values",[SHOW_SSP_SETUP]
Menu        #main, "Script",_
                         "Open Script File", [OPEN_SCRIPT],_
                         "Make Script", [MAKE_SCRIPT],_
                         "Filter System", [FILTER_SYSTEM]
Menu        #main, "Help",_
                         "SSPDataq3 Help", [GET_HELP],_
                         "Photometry Help", [Photometry_Help],_
                         "About", [GET_ABOUT]
Menu        #main, "Telescope",_
                         "Telescope Control", [TELESCOPE_CONTROL],_
                         "Select Telescope", [SELECT_TELESCOPE],_
                         "Select Telescope COM port", [SELECT_TELESCOPE_COM],_
                         "Show Setup Values",[SHOW_TELESCOPE_SETUP]

if TrialVersion = 1 then
    Menu    #main, "Photometry",_
                         "Star Database Editor", [StarDatabase],_
                         "Extinction", [Extinction],_
                         "Transformation", [Transformation],_
                         "Reduction", [Reduction],_
                         "Photometry Help", [PhotometryHelp]
end if

groupbox    #main.group1, "Control Panel", 5, 180, 837, 75

                        'combobox labels
statictext  #main.statictext18, "Catalog",     25,  205, 65, 20
statictext  #main.statictext8,  "Object",      145, 205, 50, 20
statictext  #main.statictext1,  "Filter",      255, 205, 50, 20
statictext  #main.statictext2,  "Gain",        351, 205, 50, 20
statictext  #main.statictext3,  "Integration", 415, 205, 90, 15
statictext  #main.statictext4,  "Intervals",   519, 205, 65, 20
statictext  #main.statictext5,  "Count",       618, 205, 50, 20
                        'time boxes
statictext  #main.statictext6, "UT Time", 765, 10, 60, 20
statictext  #main.statictext7, "PC Time", 765, 90, 90, 20
                        'data page headers
statictext  #main.statictext9, "Mo-Dy-Year", 10,  10, 80, 20
statictext  #main.statictext10, "UT",        124, 10, 25, 20
statictext  #main.statictext11, "Cat",       170, 10, 30, 20
statictext  #main.statictext12, "Object",    207, 10, 55, 20
statictext  #main.statictext13, "F",         330, 10, 15, 20
statictext  #main.statictext14, "- - - -  Counts   - - - -", 358, 10, 205, 15
statictext  #main.statictext15, "Int",       576, 10, 25, 20
statictext  #main.statictext16, "Gain",      605, 10, 35, 20
statictext  #main.statictext17, "Notes",      655, 10, 40, 20
                        'message box
statictext  #main.statictext19, "Messages:", 5, 159, 70, 20
'
if NightFlag = 1 then
    TextboxColor$ = "darkred"
    ComboboxColor$ = "darkred"
    ListboxColor$ = "darkred"
    BackgroundColor$ = "darkred"
    ForegroundColor$ = "yellow"
end if
'
textbox     #main.textbox1, 752,  30,  90, 20    'UT time box
textbox     #main.textbox2, 752, 110,  90, 20    'PC time box
textbox     #main.textbox4,  80, 155, 762, 25    'message box
textbox     #main.textbox5, 752,  50,  90, 20    'UT date box
textbox     #main.textbox6, 752, 130,  90, 20    'PC date box
'
combobox    #main.combo1,Combo1$(),[SELECT_FILTER.Click],    240, 225,  80, 300
combobox    #main.combo2,Combo2$(),[SELECT_GAIN.Click],      330, 225,  80, 300
combobox    #main.combo3,Combo3$(),[SELECT_INTEG.Click],     420, 225,  80, 300
combobox    #main.combo4,Combo4$(),[SELECT_INTERVALS.Click], 510, 225,  80, 300
combobox    #main.combo5,Combo5$(),[GET_COUNT.Click],        600, 225,  80, 300
combobox    #main.combo6,Combo6$(),[SELECT_OBJECT.Click],    105, 225, 125, 300
combobox    #main.combo7,Combo7$(),[SELECT_CATALOG.Click],    15, 225,  80, 300
'
listbox     #main.listbox1, DataArray$(),[DATA_BOX], 5, 30, 740, 120   'data area box
'
button      #main.button1, "start",[START.Click],UL,  765, 197, 67, 50
button      #main.button3, "?" ,[MIRROR.Click],UL, 690, 197, 67, 50
'
if TrialVersion = 1 then
    Open "SSP Data Acquisition Program Version 3 Trial Version" for Window as #main
else
    Open "SSP Data Acquisition Program Version 3" for Window as #main
end if

    #main, "trapclose [quit]"
'                                  'reset all combobox values

    #main.combo1 "selectindex 0"
    #main.combo2 "selectindex 0"
    #main.combo3 "selectindex 0"
    #main.combo4 "selectindex 0"
    #main.combo5 "selectindex 1"
    #main.combo6 "selectindex 0"
    #main.combo7 "selectindex 0"
    #main "font Courier_New 8 16"

    print #main.combo1, "!select"
    print #main.combo2, "!select"
    print #main.combo3, "!select"
    print #main.combo4, "!select"
    print #main.combo6, "!select"
    print #main.combo7, "!select"

    if AutoMirrorFlag = 0 then
        #main.button3, "!hide"
    else
        #main.button3, "!show"      'flag to indicate that mirror is in VIEW position
    end if

    on error goto [errorHandler]
'
'======main program loop with scan feature
'
[timeloop]
    if time$ <> time$() then
        gosub [FindDateTime]             'find PC and UT time and print to time boxes
    end if

    if ScriptFlag = 0 then           'bypass notes if in script mode
                                     'add any Notes to the Data Array and update the data list box
        if Notes$ <> "" and DataArray$(0) <> "" then
            DataArray$(0) = DataArray$(0)+"  "+Notes$
            SavedData$(DataCounter - 1) = DataArray$(0)
            Notes$ = ""
            print #main.listbox1, "reload"
        end if
    end if
                                     'check to see if the SSP is running and if any error codes are present
    if CommFlag = 1 then
        print #commHandle, "SSSSSS"
        call Pause 20
        numBytes = lof(#commHandle)
        dataRead$ = input$(#commHandle, numBytes)
        SELECT CASE mid$(dataRead$,4,4)
        CASE "ER=1"
            print #main.textbox4, "LOW BATTERY VOLTAGE"
            call Pause 500
            print #main.textbox4, ""
        CASE "ER=2"
            print #main.textbox4, "HIGH VOLTAGE OFF"
            call Pause 500
            print #main.textbox4, ""
        END SELECT
    end if

    if ScriptFlag = 0 then
        scan
    end if
    if ScriptFlag = 1 then
        return
    end if
    call Pause 5                    'short pause to decrease CPU usage

goto [timeloop]
'
[errorHandler]

     print #main.textbox4, Err$

goto [timeloop]
'
[quit]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    if CommFlag = 1 then                    'if COM port is opened then close it
        close #commHandle
        CommFlag = 0
    end if
    if ScriptFlag = 1 then                  'if making script window is opened close it
        close #script
        ScriptFlag = 0
    end if
    if FilterBarFlag = 1 then               'if filter bar window is opened colse it
        close #filt
        FilterFlag = 0
    end if

    open "Temporary Data.raw" for output as #Temporary
    close #Temporary

    close #main                             'shutdown window

    END
'
'======branch labels for menu selections
'
[GET_ABOUT]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if
    if TrialVersion = 1 then
        notice "SSP Data Acquisition v" +  VersionNumber$ + chr$(13)_
             + "Trial Version - copyright 2015 Gerald Persha" + chr$(13)_
             + "www.sspdataq.com,  e-mail to gpersha@sspdataq.com" + chr$(13)_
             + "Full version available for $295.00 from Optec, Inc."
    else
        notice "SSP Data Acquisition v" + VersionNumber$ + chr$(13)_
             + "copyright 2015 Gerald Persha" + chr$(13)_
             + "www.sspdataq.com,  e-mail to gpersha@sspdataq.com"
    end if
goto [timeloop]
'
[SAVE_FILE]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if
                    'open file dialog to select data file either new or old
    filedialog "Save Data File", PathDataFile$, DataFile$
    for I = len(DataFile$) to 1 step -1
        if mid$(DataFile$,I,1) = "\" then
            ShortDataFile$ = mid$(DataFile$,I+1)
            PathDataFile$ = left$(DataFile$,I)+"*.raw"
            exit for
        end if
    next I
    if DataFile$ = "" then [Quit_Open_File]

                    'if file is new go to Make_Header routine to get information
    files "c:\", DataFile$, info$()
    if val(info$(0, 0)) = 0 then
        confirm "Create New Data File?"; Answer$
        if Answer$ <> "yes" then
            goto  [Quit_Open_File]
        else
            gosub [Find_File_Name]
            gosub [Make_Header]

            if (right$(DataFile$,4) = ".raw") OR (right$(DataFile$,4) = ".RAW") then
                open DataFile$ for output as #DataFile
            else
                DataFile$ = DataFile$+".raw"
                open DataFile$ for output as #DataFile
            end if
        end if
        print #DataFile, HeaderLine1$
        print #DataFile, HeaderLine2$
        print #DataFile, HeaderLine3$
        print #DataFile, HeaderLine4$
        for I = 0 to (DataCounter - 1)
            print #DataFile, " "+SavedData$(I)      'add leading space to saved data line for RPHOT
        next I
        close #DataFile
        print #main.textbox4, "data saved to "+ShortDataFile$

                    'if file is old, open it to append data
    else

        if (right$(DataFile$,4) = ".raw") OR (right$(DataFile$,4) = ".RAW") then
             open DataFile$ for append as #DataFile
        else
            DataFile$ = DataFile$+".raw"
            open DataFile$ for append as #DataFile
        end if
        for I = DataCounterLast to (DataCounter - 1)
            print #DataFile, " "+SavedData$(I)
        next I
        close #DataFile
        print #main.textbox4, "data appended to "+ShortDataFile$
    end if

    [Quit_Open_File]

goto [timeloop]
'
[CLEAR_DATA]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    Answer$ = ""
                                            'confirm with user about going on to save data and close file
    confirm "Do you wish to clear the data array?"; Answer$
    if Answer$ = "yes" then
                    'clear all data arrays
        for I = 0 to DataCounter
            SavedData$(I) = ""
        next I
        for I = 0 to DataCounter
            DataArray$(I) = ""
        next I
        print #main.listbox1, "reload"      'clear data display box
        DataCounter = 0                     'reset counting variables for arrays
        DataCounterLast = 0
    end if
goto [timeloop]
'
[OPEN_SCRIPT]
    if TrialVersion = 1 then
        notice "not available in this version"
        goto [timeloop]
    end if

    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    if CommFlag = 0 then
        print #main.textbox4, "port not open - please connect"
        goto [timeloop]
    end if

    filedialog "Open Script File", PathScript$, Script$

    if Script$ = "" then
        goto [timeloop]
    end if
                                            'separate path and file name values
    for I = len(Script$) to 1 step -1
        if mid$(Script$,I,1) = "\" then
            ShortScript$ = mid$(Script$,I+1)
            PathScript$ = left$(Script$,I)+"*ssp"
            exit for
        end if
    next
                                            'make user create new script files with NOTEPAD
    files "c:\", Script$, info$()
    if val(info$(0, 0)) = 0 then
        notice "create or edit script with Notepad"
        goto [OPEN_SCRIPT]
    end if

    open Script$ for input as #ScriptFile

    print #main.combo1, "disable"
    print #main.combo2, "disable"
    print #main.combo3, "disable"
    print #main.combo4, "disable"
    print #main.combo5, "disable"
    print #main.combo6, "disable"
    print #main.combo7, "disable"
    #main, "disable"

    ScriptFlag = 1
    ScriptLine = 0
    ScriptSkyRA = 0
    ScriptSkyDEC = 0

    print #main.textbox4, "Script File: "+ShortScript$

    notice ShortScript$+chr$(13)+_
           "To start the script, press the OK button"+chr$(13)+_
           "To abort script, hold down the ESC key while the script"+chr$(13)+_
           "is running and hold down until the script stops"

    while eof(#ScriptFile) = 0

        ScriptLine = ScriptLine + 1                                     'keep track of number of lines in file
        [StarScriptAgain]
        line input #ScriptFile, FunctionValue$
        for I2 = 1 to len(FunctionValue$)
            if mid$(FunctionValue$,I2,1) = "," then
                exit for
            end if
        next
        Function$ = mid$(FunctionValue$,1,(I2-1))
        Function$ = TRIM$(Function$)                                    'delete any spaces
        Value$ = mid$(FunctionValue$,(I2+1))
        Value$ = TRIM$(Value$)                                          'delete any spaces

        TestFunction = asc(Function$)                                   'test to see of any ASCII 0 are in the data line
        if TestFunction = 0 then
            goto [StarScriptAgain]
        end if

        Function$ = upper$(Function$)
        select case Function$
            case "LOAD"
                LoadDuplicateFlag = 0                                   'reset duplicate flag to 0
                 Value$ = upper$(Value$)
                 for I = 1 to ObjectIndexMax                            'check if any duplciate OBJECT is in array
                    if Value$ = Combo6$(I) then
                        LoadDuplicateFlag = 1                           'set flag to true if duplicate is found
                        exit for
                    end if
                 next I
                 if LoadDuplicateFlag = 0 then                          'enter new OBJECT if no duplicate found
                    ObjectIndexMax=ObjectIndexMax + 1
                    Combo6$(ObjectIndexMax) = Value$
                    print #main.combo6, "reload"
                end if

            case "LOADCATALOG"
                SelectedCatalog$ = Value$
                redim CatalogStars$(4000)
                redim SDitem$(4000,13)

                gosub [Reset_Object_Combobox]

                gosub [Load_Catalog_Stars]

                gosub [Select_All_Objects]

            case "FILTER"
                FilterFlag = 0                                          'assume filter is not in list
                for I = 1 to 10
                    if Value$ = (Combo1$(I)) then
                        Value$ = Combo1$(I)                             'make Value$ exactly equal to filter on list
                        FilterFlag = 1                                  'if filter found set flag to true
                        exit for
                    end if
                next I
                if FilterFlag = 1 then                                  'select filter
                    print #main.combo1, "select ";Value$

                    if AutoManual$ = "M" then                           'check to see of Auto filter is enabled
                        notice "FILTER"+chr$(13)+_                      'prompt for manual filter change
                               "Insert Filter "+Value$
                        print #main.textbox4, "Filter "+Value$+" inserted"
                    else
                        gosub [SELECT_FILTER.Click]                     'auto filter change
                    end if

                else                                                    'if filter not found, show error
                    notice "ERROR"+chr$(13)+_
                           "Filter "+Value$+" at line "+str$(ScriptLine)+" is not in list"
                end if

            case "CATALOG"
                Value$ = upper$(left$(Value$,1))+lower$(mid$(Value$,2)) 'get Catalog name with first letter upper
                                                                        'case and remainder in lower case
                CatalogFlag = 0
                for I = 1 to 8
                    if Value$ = Combo7$(I) then
                        CatalogFlag = 1
                        exit for
                    end if
                next I
                if CatalogFlag = 1 then
                    print #main.combo7, "select ";Value$
                    gosub [SELECT_CATALOG.Click]
                else
                    notice "ERROR"+chr$(13)+_
                           "catalog "+Value$+" at line "+str$(ScriptLine)+" is not in list"
                end if
                Call Pause 1000

            case "NOTICE"
                #main, "Enable"
                print #main.button1, "CONT"
                ScriptHold = 1
                beep
                [WAIT_FOR_CONTINUE]
                wait
                [CONTINUE_SCRIPT]                                      'if #main.button1 is pressed, continue script
                #main, "Disable"

            case "COUNT"
                Value$ = lower$(Value$)
                CountFlag = 0
                for I = 1 to 3
                    if Value$ = Combo5$(I) then
                        CountFlag = 1
                        exit for
                    end if
                next I
                if CountFlag = 1 then
                    print #main.combo5, "select ";Value$
                    gosub [GET_COUNT.Click]
                else
                    notice "ERROR"+chr$(13)+_
                           "count "+Value$+" at line "+str$(ScriptLine)+" is not in list"
                end if

            case "OBJECT"
                Value$ = upper$(Value$)
                ObjectFlag = 0
                for I = 1 to ObjectIndexMax
                    if Value$ = Combo6$(I) then
                        ObjectFlag = 1
                        exit for
                    end if
                next I
                if ObjectFlag = 1 then
                    print #main.combo6, "select ";Value$
                    gosub [SELECT_OBJECT.Click]
                else
                    notice "ERROR"+chr$(13)+_
                           "object "+Value$+" at line "+str$(ScriptLine)+" is not in list"
                end if

            case "GAIN"
                if Value$ = "1" or Value$ = "10" or Value$ = "100" then
                    print #main.combo2, "select ";Value$
                    gosub [SELECT_GAIN.Click]
                else
                    notice "ERROR"+chr$(13)+_
                           "Gain "+Value$+" at line "+str$(ScriptLine)+" needs to be 1, 10 or 100 only"
                end if

            case "INTEGRATION"
                IntegrationFlag = 0
                for I = 1 to 7
                    if Value$ = Combo3$(I) then
                        IntegrationFlag = 1
                        exit for
                    end if
                next I
                if IntegrationFlag = 1 then
                    print #main.combo3, "select ";Value$
                    gosub [SELECT_INTEG.Click]
                else
                    notice "ERROR"+chr$(13)+_
                           "Integration "+Value$+" at line "+str$(ScriptLine)+" is not in list"
                end if

            case "INTERVAL"
                IntervalFlag = 0
                for I = 1 to 8
                    if Value$ = Combo4$(I) then
                        IntervalFlag = 1
                        exit for
                    end if
                next I
                if IntervalFlag = 1 then
                    print #main.combo4, "select ";Value$
                    gosub [SELECT_INTERVALS.Click]
                else
                    notice "ERROR"+chr$(13)+_
                           "Interval "+Value$+" at line "+str$(ScriptLine)+" is not in list"
                end if

            case "VIEW"
                if MirrorFlag = 1 and AutoMirrorFlag = 1 or AutoMirrorFlag = 2 then
                    gosub [MIRROR.Click]
                end if

            case "RECORD"
                if MirrorFlag = 0 and AutoMirrorFlag = 1 or AutoMirrorFlag = 2 then
                    gosub [MIRROR.Click]
                end if

            case "SKYRA"
                ScriptSkyRA = val(Value$)

            case "SKYDEC"
                ScriptSkyDEC = val(Value$)

            case "START"
                gosub [START.Click]

            case "PAUSE"
                Value = val(Value$) * 1000
                call Pause Value

            case "END"
                EXIT WHILE
            case else                                            'give notice if Function$ is in error and
                firstletter = asc(Function$)
                firstletter$ = str$(firstletter)
                notice "do not recognize "+firstletter$+" at line "+str$(ScriptLine)
        end select

                                                                 'press and hold ESC key to abort script file
        CallDLL #user32, "GetAsyncKeyState",_VK_ESCAPE as long, ks as long
        if ks < 0 then
            confirm "Are you sure you wish to exit script?"; Answer$
            if Answer$ = "yes" then
                EXIT WHILE
            end if
        end if
    wend

    close #ScriptFile
    ScriptFlag = 0
    playwave "ding.wav"
    gosub [Enable_Main_Menu]
    print #main.button1, "Start"
    print #main.textbox4, "script file ended"

goto [timeloop]                             'end the program
'
[CONNECT_SERIAL]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    Com = 32768                             'set COM buffer to speified size
    dataRead$ = ""                          'clear string variable used to get COM data
    if CommFlag = 0 then                    'if COM flag is false, then open COM port
        SELECT CASE ComPort
        CASE 0
            notice "select proper COM port in setup menu"
            goto [timeloop]
        CASE ELSE
            oncomerror [COMHandler]
            open "com"+str$(ComPort)+":19200,n,8,1,ds0,cs0" for random as #commHandle
        END SELECT
        print #commHandle, "SSSSSS"         'send goto serial loop command to SSP
        for I = 1 to 100
            call Pause 50                   'wait and then look for something coming back
            numBytes = lof(#commHandle)
            if numBytes > 0  then
                numB = numBytes
                dataRead$ = input$(#commHandle, numBytes)
                I = 100
            end if
        next I
                                            'if SSP returns CR or ! then consider it connected
        if asc(left$(dataRead$,1)) = 10 or asc(left$(dataRead$,1)) = 33 then
            print #main.textbox4, "connected "
                                            'if auto mirror option enabled, put mirror in VIEW position
            if AutoMirrorFlag = 1 then                          'put mirror into view position
                junk$ = input$(#commHandle, lof(#commHandle))   'clear buffer
                print #commHandle, "SVIEW0"                     'start flip mirror operation to VIEW position
                print #main.button3, "WAIT"                     'wait for flip mirror to finish
                call Pause (2000)                               'pause 2 seconds
                print #main.button3, "VIEW"                     'print VIEW on button
                MirrorFlag = 0                                  'indiate that mirror is in VIEW position
            end if
                                            'home filter bar if automatic
            if AutoManual$ = "A" then
                junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
                print #commHandle, "SHNNN"  'home the filter bar
                print #main.textbox4, "filter slider going to position 1"
                gosub [WaitForAck]
                print #main.textbox4, "filter "; Combo1$(1); " is in position"
                FilterIndex = 2
                print #main.combo1, "selectindex 1"
            end if
            CommFlag = 1                    'set COM flag to true
                                            'if failed to connect, then tell user to try it again
        else
            print #main.textbox4, "not connected - try again - is unit on?"
            close #commHandle
            CommFlag = 0                    'keep COM flag at false
        end if
    else
        print #main.textbox4, "port is already opened"
    end if
goto [timeloop]
'
[DISCONNECT_SERIAL]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    if CommFlag = 1 then                    'if COM flag is true, have SSP exit serial loop
        print #commHandle, "SEEEEE"
        print #main.textbox4, "not connected"
        close #commHandle                   'close COM port
        CommFlag = 0                        'set COM flag to false
        #main.combo1 "selectindex 0"
        #main.combo2 "selectindex 0"
        #main.combo3 "selectindex 0"
        #main.combo4 "selectindex 0"
        #main.combo5 "selectindex 1"
        #main.combo6 "selectindex 0"
        #main.combo7 "selectindex 0"

        print #main.combo1, "!select"
        print #main.combo2, "!select"
        print #main.combo3, "!select"
        print #main.combo4, "!select"
        print #main.combo6, "!select"
        print #main.combo7, "!select"
        CountMode = 1                       'Slow mode set
    else
        print #main.textbox4, "already disconnected"
    end if
goto [timeloop]
'
[SELECT_COM_PORT]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    PopupMenu "COM1",  [Select_COM1],  "COM2",  [Select_COM2],  "COM3",  [Select_COM3],_
              "COM4",  [Select_COM4],  "COM5",  [Select_COM5],  "COM6",  [Select_COM6],_
              "COM7",  [Select_COM7],  "COM8",  [Select_COM8],  "COM9",  [Select_COM9],_
              "COM10", [Select_COM10], "COM11", [Select_COM11], "COM12", [Select_COM12],_
              "COM13", [Select_COM13], "COM14", [Select_COM14], "COM15", [Select_COM15],_
              "COM16", [Select_COM16], "COM17", [Select_COM17], "COM18", [Select_COM18],_
              "COM19", [Select_COM19],_
              "E&xit", [timeloop]

    [Select_COM1]
        ComPort = 1
    goto [End_SELECT_COM_PORT]
    [Select_COM2]
        ComPort = 2
    goto [End_SELECT_COM_PORT]
    [Select_COM3]
        ComPort = 3
    goto [End_SELECT_COM_PORT]
    [Select_COM4]
        ComPort = 4
    goto [End_SELECT_COM_PORT]
    [Select_COM5]
        ComPort = 5
    goto [End_SELECT_COM_PORT]
    [Select_COM6]
        ComPort = 6
    goto [End_SELECT_COM_PORT]
    [Select_COM7]
        ComPort = 7
    goto [End_SELECT_COM_PORT]
    [Select_COM8]
        ComPort = 8
    goto [End_SELECT_COM_PORT]
    [Select_COM9]
        ComPort = 9
    goto [End_SELECT_COM_PORT]
    [Select_COM10]
        ComPort = 10
    goto [End_SELECT_COM_PORT]
    [Select_COM11]
        ComPort = 11
    goto [End_SELECT_COM_PORT]
    [Select_COM12]
        ComPort = 12
    goto [End_SELECT_COM_PORT]
    [Select_COM13]
        ComPort = 13
    goto [End_SELECT_COM_PORT]
    [Select_COM14]
        ComPort = 14
    goto [End_SELECT_COM_PORT]
    [Select_COM15]
        ComPort = 15
    goto [End_SELECT_COM_PORT]
    [Select_COM16]
        ComPort = 16
    goto [End_SELECT_COM_PORT]
    [Select_COM17]
        ComPort = 17
    goto [End_SELECT_COM_PORT]
    [Select_COM18]
        ComPort = 18
    goto [End_SELECT_COM_PORT]
    [Select_COM19]
        ComPort = 19

    [End_SELECT_COM_PORT]
    print #main.textbox4, "SSP port set to COM"+str$(ComPort)
    gosub [SaveDparms]
goto [timeloop]
'
[SELECT_TELESCOPE_COM]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    PopupMenu "COM1",  [Select_Tele_COM1],  "COM2",  [Select_Tele_COM2],  "COM3",  [Select_Tele_COM3],_
              "COM4",  [Select_Tele_COM4],  "COM5",  [Select_Tele_COM5],  "COM6",  [Select_Tele_COM6],_
              "COM7",  [Select_Tele_COM7],  "COM8",  [Select_Tele_COM8],  "COM9",  [Select_Tele_COM9],_
              "COM10", [Select_Tele_COM10], "COM11", [Select_Tele_COM11], "COM12", [Select_Tele_COM12],_
              "COM13", [Select_Tele_COM13], "COM14", [Select_Tele_COM14], "COM15", [Select_Tele_COM15],_
              "COM16", [Select_Tele_COM16], "COM17", [Select_Tele_COM17], "COM18", [Select_Tele_COM18],_
              "COM19", [Select_Tele_COM19],_
              "E&xit", [timeloop]

    [Select_Tele_COM1]
        TelescopeCOM = 1
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM2]
        TelescopeCOM = 2
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM3]
        TelescopeCOM = 3
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM4]
        TelescopeCOM = 4
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM5]
        TelescopeCOM = 5
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM6]
        TelescopeCOM = 6
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM7]
        TelescopeCOM = 7
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM8]
        TelescopeCOM = 8
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM9]
        TelescopeCOM = 9
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM10]
        TelescopeCOM = 10
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM11]
        TelescopeCOM = 11
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM12]
        TelescopeCOM = 12
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM13]
        TelescopeCOM = 13
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM14]
        TelescopeCOM = 14
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM15]
        TelescopeCOM = 15
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM16]
        TelescopeCOM = 16
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM17]
        TelescopeCOM = 17
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM18]
        TelescopeCOM = 18
    goto [End_SELECT_TELESCOPE_COM]
    [Select_Tele_COM19]
        TelescopeCOM = 19

    [End_SELECT_TELESCOPE_COM]
    print #main.textbox4, "telescope port set to COM"+str$(TelescopeCOM)
    gosub [SaveDparms]
goto [timeloop]
'
[SELECT_TELESCOPE]
        PopupMenu "LX200", [Select_LX200],_
                  "Celestron old GT", [Select_oldGT],_
                  "Celestron N5/N8", [Select_N5&N8],_
                  "Celestron N8/11GPS & new GT", [Select_newGT],_
                  "&Exit", [End_SELECT_TELESCOPE]

        [Select_LX200]
            TelescopeType = 1
            gosub [SaveDparms]
            goto [End_SELECT_TELESCOPE]
        [Select_oldGT]
            TelescopeType = 2
            gosub [SaveDparms]
            goto [End_SELECT_TELESCOPE]
        [Select_N5&N8]
            TelescopeType = 3
            gosub [SaveDparms]
            goto [End_SELECT_TELESCOPE]
        [Select_newGT]
            TelescopeType = 4
            gosub [SaveDparms]
        [End_SELECT_TELESCOPE]
goto [timeloop]
'
[TIME_ZONE]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if
                                                '+ values for west of meridian and - values for east
                                                'interger values only
    Temporary$ = str$(TimeZoneDiff)
    prompt "Time Zone Edit"+chr$(13)+"Type in your time zone difference:  -12  to  +12"; Temporary$
    If Temporary$ = "" or Temporary$ = str$(TimeZoneDiff) then
        goto [timeloop]
    else
        Temporary = int(val(Temporary$))
        if abs(Temporary) > 12 then
             print #main.textbox4, "time zone difference out of range"
             goto [timeloop]
         else
            TimeZoneDiff = Temporary
            print #main.textbox4, "time zone difference is: "; TimeZoneDiff; " hours"
        end if
    end if
    gosub [SaveDparms]                          'save value to DPAMS file
goto [timeloop]
'
[FILTER_BAR]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    DIM FilterList$(6)
    for I = 1 to 6                             'get filter list for display
        FilterList$(I) = Combo1$(I)
    next I
                                                'open new window to edit filter values
    NOMAINWIN
    WindowWidth = 320 : WindowHeight = 260
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #filt, "&File" , "E&xit", [Quit_filt], "Save", [Complete]
    statictext  #filt.statictext1, "Position  1", 10, 74, 95, 15
    statictext  #filt.statictext2, "          2", 10, 90, 95, 15
    statictext  #filt.statictext3, "          3", 10, 106, 95, 15
    statictext  #filt.statictext4, "          4", 10, 122, 95, 15
    statictext  #filt.statictext5, "          5", 10, 138, 95, 15
    statictext  #filt.statictext6, "          6", 10, 154, 95, 15
    statictext  #filt.statictext11, "Use uppercase for Johnson/Cousins UBVRI and lowercase for Sloan ugriz", 10, 4, 300, 62
    statictext  #filt.statictext12, "Filter Bar", 210,74,90,15

    radiobutton #filt.Bar1, "1", [setBar1], [resetBar1], 240,95,30,20
    radiobutton #filt.Bar2, "2", [setBar2], [resetBar2], 240,120,30,20
    radiobutton #filt.Bar3, "3", [setBar3], [resetBar3], 240,145,30,20

    listbox     #filt.list1, FilterList$(),[Change_Filters.Click], 105, 72, 80, 105

    Open "Edit Filter Bar" for Window as #filt

        #filt "trapclose [Quit_filt]"

        #filt.list1 "selectindex 1"
        #filt "font courier_new 8 16"
        print #filt.list1, "singleclickselect"

        select case FilterBar
            case 1
                print #filt.Bar1, "set"
            case 2
                print #filt.Bar2, "set"
            case 3
                print #filt.Bar3, "set"
        end select
        FilterBarFlag = 1
    Wait
'
    [setBar1]
        FilterBar = 1
        for I = 1 to 6                             'get filter list for display
            FilterList$(I) = Filters$(I + (FilterBar - 1) * 6)
        next I
        print #filt.list1, "reload"
        #main.combo1, "!select"
     wait

    [setBar2]
        FilterBar = 2
        for I = 1 to 6                             'get filter list for display
            FilterList$(I) = Filters$(I + (FilterBar - 1) * 6)
        next I
        print #filt.list1, "reload"
        #main.combo1, "!select"
     wait

    [setBar3]
        FilterBar = 3
        for I = 1 to 6                             'get filter list for display
            FilterList$(I) = Filters$(I + (FilterBar - 1) * 6)
        next I
        print #filt.list1, "reload"
        #main.combo1, "!select"
     wait

    [Change_Filters.Click]
        #filt.list1 "selectionindex? FilterI"
        Temporary$ = ""
         prompt "Filter Edit"+chr$(13)+"enter new filter name"; Temporary$
         If Temporary$ <> "" then
            FilterList$(FilterI) = Temporary$
            print #filt.list1, "reload"
        end if
    wait
'
    [Complete]
        for I = 1 to 6
            Filters$(I + (FilterBar -1) * 6) = FilterList$(I)
        next I

        gosub [SaveDparms]
    wait
'
    [Quit_filt]
        for I = 1 to 6
            Combo1$(I) = FilterList$(I)
        next I
        print #main.combo1, "reload"
        close #filt
        FilterBarFlag = 0
goto [timeloop]
'
[AUTO_MANUAL]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    PopupMenu "&Auto Filters", [Select_Auto], "&Manual Filters", [Select_Manual], "E&xit", [End_AUTO_MANUAL]
    [Select_Auto]
        AutoManual$ = "A"
        print #main.textbox4, "set for auto 6-pos filter slider"
        gosub [SaveDparms]
    goto [End_AUTO_MANUAL]
    [Select_Manual]
        AutoManual$ = "M"
        print #main.textbox4, "set for manual 2-pos slider"
        gosub [SaveDparms]
    goto [End_AUTO_MANUAL]
    [End_AUTO_MANUAL]
goto [timeloop]
'
[AUTO_MIRROR]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    PopupMenu "Auto Mirror", [Select_Auto_Mirror],_
              "Auto Mirror w/confirm", [Select_Auto_Mirror_Confirm],_
              "Manual Mirror", [Select_Manual_Mirror],_
              "E&xit", [End_AUTO_MIRROR]
    [Select_Auto_Mirror]
        AutoMirrorFlag = 2
        print #main.textbox4, "auto mirror option is enabled"
        #main.button3 "!show"
        gosub [SaveDparms]
    goto [End_AUTO_MIRROR]
    [Select_Auto_Mirror_Confirm]
        AutoMirrorFlag = 1
        print #main.textbox4, "auto mirror option is enabled with confirm required"
        #main.button3 "!show"
        gosub [SaveDparms]
    goto [End_AUTO_MIRROR]
    [Select_Manual_Mirror]
        AutoMirrorFlag = 0
        print #main.textbox4, "auto mirror option is disabled"
        #main.button3 "!hide"
        gosub [SaveDparms]
    goto [End_AUTO_MIRROR]
    [End_AUTO_MIRROR]
goto [timeloop]
'
[NIGHT]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    confirm "set screen for night red?"; Answer$
    if Answer$ = "yes" then
        if NightFlag = 0 then
            print #main.textbox4, "you must exit and restart the program to change screen"
            NightFlag = 1
        end if
    else
        if NightFlag = 1 then
            print #main.textbox4, "you must exit and restart the program to change screen"
            NightFlag = 0
        end if
    end if
    gosub [SaveDparms]                          'save value to DPAMS file
goto [timeloop]
'
[TELESCOPE_CONTROL]
    if TrialVersion = 1 then
        notice "not available in this version"
        goto [timeloop]
    end if
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    PopupMenu "&Telescope Control Enabled", [Select_Tel_Enabled],_
              "&Telescope Control Disabled", [Select_Tel_Disabled], "E&xit", [End_TELESCOPE_CONTROL]
    [Select_Tel_Enabled]
        TelescopeFlag = 1
        print #main.textbox4, "telescope control is enabled"
        gosub [SaveDparms]
    goto [End_TELESCOPE_CONTROL]
    [Select_Tel_Disabled]
        TelescopeFlag = 0
        print #main.textbox4, "telescope control is disabled"
        gosub [SaveDparms]
    goto [End_TELESCOPE_CONTROL]

    [End_TELESCOPE_CONTROL]
goto [timeloop]
'
[SHOW_SSP_SETUP]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if
    if FilterSystem$ = "1" then
        FS$ = "J"
    else
        FS$ = "S"
    end if
    print #main.textbox4, "COM port: "+str$(ComPort)+_
                          "   Time Zone Dif: "+str$(TimeZoneDiff)+_
                          "   Auto/Manual Filters: "+AutoManual$+_
                          "   FilterSystem: "+FS$+_
                          "   Red Night Mode: "+str$(NightFlag)

goto [timeloop]
'
[SHOW_TELESCOPE_SETUP]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    if TelescopeFlag = 1 then
        TelescopeFlag$ = "Enabled"
    else
        TelescopeFlag$ = "Disabled"
    end if
    print #main.textbox4, "Telescope Control: "+TelescopeFlag$+_
                          "   Telescope COM port: "+str$(TelescopeCOM)+_
                          "   Telescope Type: "+str$(TelescopeType)
goto [timeloop]
'
[FILTER_SYSTEM]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    PopupMenu "&Johnson/Cousins Filters", [Select_Johnson], "&Sloan Filters", [Select_Sloan], "E&xit", [End_FILTER_SYSTEM]
    [Select_Johnson]
        FilterSystem$ = "1"
        print #main.textbox4, "set scripting to Johnson/Cousins filters"
        gosub [SaveDparms]
        goto  [End_FILTER_SYSTEM]
    [Select_Sloan]
        FilterSystem$ = "0"
        print #main.textbox4, "set scripting to Sloan filters"
        gosub [SaveDparms]
        goto  [End_FILTER_SYSTEM]
    [End_FILTER_SYSTEM]
goto [timeloop]
'
[GET_HELP]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    run "hh sspdataq3.chm"
goto [timeloop]
'
[Photometry_Help]
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    run "hh photometry2.chm"
goto [timeloop]
'
'=====menu selections for trial version
'
    [StarDatabase]
        files DefaultDir$, "Data_Editor2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Star Data Editor not found"
        else
            run "Data_Editor2.tkn"
        end if
    goto [timeloop]

    [Extinction]
        files DefaultDir$, "Extinction2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Extinction coefficients program not found"
        else
            run "Extinction2.tkn"
        end if
    goto [timeloop]

    [Transformation]
        files DefaultDir$, "Transformation2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Transformation coefficients program not found"
        else
            run "Transformation2.tkn"
        end if
    goto [timeloop]

    [Reduction]
        files DefaultDir$, "Reduction2.tkn", info$()
        if val(info$(0, 0)) = 0 then
            notice "Data reduction program not found"
        else
            run "Reduction2.tkn"
        end if
    goto [timeloop]

    [PhotometryHelp]
        run "hh photometry2.chm"
    goto [timeloop]
'
'======branch labels for selections in comboboxes
'
[SELECT_FILTER.Click]
    #main.combo1 "selectionindex? FilterIndex"

    if TrialVersion = 1 then
        if Combo1$(FilterIndex) <> "B" and Combo1$(FilterIndex) <> "V" and FilterIndex <> 7 then
            notice "only B or V filters acceptable in this version"
            goto [timeloop]
        end if
    end if

    if AutoManual$ = "M" and FilterIndex = 7 then
        notice "Home is for auto-filter option"
        goto [timeloop]
    end if

    if AutoManual$ = "A" and FilterIndex = 7 then
        if CommFlag = 0 then            'check to see if COM port is open
            call CommError
            goto [timeloop]
        end if
        junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
        print #commHandle, "SHNNN"      'home the filter bar
        print #main.textbox4, "filter slider going to position 1"

        gosub [WaitForAck]
        if Ack = 0 then             'if Ack not true then repeat command
            AckCounter = AckCounter + 1
            if AckCounter = 3 then  'try three times before giving up
                print #main.textbox4, "problem with SSP communication - no Ack received"
                goto [timeloop]
            else
                goto [SELECT_FILTER.Click]
            end if
            AckCounter = 0
        end if

        FilterIndex = 1
        print #main.textbox4, "filter "; Combo1$(FilterIndex); " is in position"
        print #main.combo1, "selectindex 1"
        goto [timeloop]
    end if
    if AutoManual$ = "A" then
        if CommFlag = 0 then            'check to see if COM port is open
            call CommError
            goto [timeloop]
        end if
        FilterNumber = FilterIndex
        if FilterNumber >= 1 and FilterNumber <= 6 then
            junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
            call Pause 10
            print #commHandle, "SFNNN"; FilterNumber

            gosub [WaitForAck]          'wait for return ! before proceeding
            if Ack = 0 then             'if Ack not true then repeat command
                AckCounter = AckCounter + 1
                if AckCounter = 3 then  'try three times before giving up
                    print #main.textbox4, "problem with SSP communication - no Ack received"
                    goto [timeloop]
                else
                    goto [SELECT_FILTER.Click]
                end if
                AckCounter = 0
            end if

            print #main.textbox4, "filter "; Combo1$(FilterIndex); " is in position"
        end if
    else
        print #main.textbox4, "place filter "; Combo1$(FilterIndex); " in position"
    end if
    #main.combo1 "selectindex 0"
    print #main.combo1, "!";Combo1$(FilterIndex)

    if ScriptFlag = 1 then return       'return to script when finished

goto [timeloop]
'
[SELECT_GAIN.Click]
    #main.combo2 "selectionindex? GainIndex"
    if CommFlag = 0 then                'check to see if COM port is open
        call CommError
        goto [timeloop]
    end if
    SELECT CASE GainIndex
    CASE 1
        print #commHandle, "SGNNN3"
        Gain$ = "1  "
        print #main.textbox4, "gain set to 1"
    CASE 2
        print #commHandle, "SGNNN2"
        Gain$ = "10 "
        print #main.textbox4, "gain set to 10"
    CASE 3
        print #commHandle, "SGNNN1"
        Gain$ = "100"
        print #main.textbox4, "gain set to 100"
    END SELECT

    gosub [WaitForAck]          'wait for return ! before proceeding
    if Ack = 0 then             'if Ack not true then repeat command
        AckCounter = AckCounter + 1
        if AckCounter = 3 then  'try three times before giving up
             print #main.textbox4, "problem with SSP communication - no Ack received"
             goto [timeloop]
        else
             goto [SELECT_GAIN.Click]
        end if
        AckCounter = 0
     end if

    #main.combo2 "selectindex 0"
    print #main.combo2, "!";Combo2$(GainIndex)

    if ScriptFlag = 1 then return                   'return to script when finished

goto [timeloop]
'
[SELECT_INTEG.Click]
    #main.combo3 "selectionindex? IntegIndex"
    SELECT CASE IntegIndex
    if CommFlag = 0 then                            'check to see if COM port is open
        call CommError
        goto [timeloop]
    end if
    CASE 1
        print #commHandle, "SI0002"
        Integ = 20
        Integ$ = "0.02"
        print #main.textbox4, "integration set to 0.02s"
    CASE 2
        print #commHandle, "SI0005"
        Integ = 50
        Integ$ = "0.05"
        print #main.textbox4, "integration set to 0.05s"
    CASE 3
        print #commHandle, "SI0010"
        Integ = 100
        Integ$ = "0.10"
        print #main.textbox4, "integration set to 0.10s"
    CASE 4
        print #commHandle, "SI0050"
        Integ = 500
        Integ$ = "0.50"
        print #main.textbox4, "integration set to 0.50s"
    CASE 5
        print #commHandle, "SI0100"
        Integ = 1000
        Integ$ = "01"
        print #main.textbox4, "integration set to 1.00s"
    CASE 6
        print #commHandle, "SI0500"
        Integ = 5000
        Integ$ = "05"
        print #main.textbox4, "integration set to 5.00s"
    CASE 7
        print #commHandle, "SI1000"
        Integ = 10000
        Integ$ = "10"
        print #main.textbox4, "integration set to 10.00s"
    END SELECT

    gosub [WaitForAck]          'wait for return ! before proceeding
    if Ack = 0 then             'if Ack not true then repeat command
        AckCounter = AckCounter + 1
        if AckCounter = 3 then  'try three times before giving up
             print #main.textbox4, "problem with SSP communication - no Ack received"
             goto [timeloop]
        else
             goto [SELECT_INTEG.Click]
        end if
        AckCounter = 0
     end if

    #main.combo3 "selectindex 0"
    print #main.combo3, "!";Combo3$(IntegIndex)

    if ScriptFlag = 1 then return                   'return to script when finished

goto [timeloop]
'
[SELECT_INTERVALS.Click]
    #main.combo4 "selectionindex? IntervalIndex"
    if CommFlag = 0 then
        call CommError
        goto [timeloop]
    end if
    SELECT CASE IntervalIndex
    CASE 1
        Interval = 1
        print #main.textbox4, "interval set to 1"
    CASE 2
        Interval = 2
        print #main.textbox4, "interval set to 2"
    CASE 3
        Interval = 3
        print #main.textbox4, "interval set to 3"
    CASE 4
        Interval = 4
        print #main.textbox4, "interval set to 4"
    CASE 5
        Interval = 100
        print #main.textbox4, "interval set to 100"
    CASE 6
        Interval = 1000
        print #main.textbox4, "interval set to 1000"
    CASE 7
        Interval = 2000
        print #main.textbox4, "intervals set to 2000"
    CASE 8
        Interval = 5000
        print #main.textbox4, "intervals set to 5000"
'        redim FastTimeArray$(5000)        'time array to be associated with fast time counts
'        redim FastCounts$(5000)           '4 byte readings (2 byte for Vfast mode)from photometer, X X
    END SELECT
    #main.combo4 "selectindex 0"
    print #main.combo4, "!";Combo4$(IntervalIndex)

    if ScriptFlag = 1 then return                   'return to script when finished

goto [timeloop]
'
[GET_COUNT.Click]
    #main.combo5 "selectionindex? CountIndex"
    SELECT CASE CountIndex
    CASE 1
        CountMode = 1
        print #main.textbox4, "set for Trial Count"
    CASE 2
        CountMode = 2
        print #main.textbox4, "set for Slow Count"
    CASE 3
        CountMode = 3
        print #main.textbox4, "set for Fast Count"
    CASE 4
        CountMode = 4
        print #main.textbox4, "set for Very Fast Count, Integration = 2ms"
    CASE 5
        CountMode = 5
        print #main.textbox4, "ABORT - reset instrument values - ABORT"
        #main.combo5 "selectindex 1"
        print #main.button1, "start"
        print #commHandle, "SS"             'exit fast loop in SSP
        CountMode = 1                       'Trial mode set
    END SELECT

    if ScriptFlag = 1 then return           'return to script when finished

goto [timeloop]
'
[SELECT_OBJECT.Click]
    #main.combo6 "selectionindex? ObjectIndex"
    Select Case ObjectIndex
        Case 1                                          'New Object
            Temporary$ = ""
            prompt "enter object name"; Temporary$
            if Temporary$ = "" then
                object$ = "nothing entered"
            else
                object$ = upper$(Temporary$)
                ObjectIndexMax = ObjectIndexMax + 1
                ObjectIndex = ObjectIndexMax
                Combo6$(ObjectIndexMax) = object$ 
            end if
            print #main.textbox4, "object selected is "; object$
        Case 2                                          'SKY
            object$ = Combo6$(2)
            print #main.textbox4, "object selected is "; object$
            #main.combo7 "selectindex 0"
        Case 3                                          'SKYNEXT
            object$ = Combo6$(3)
            print #main.textbox4, "object selected is "; object$
            #main.combo7 "selectindex 0"
        Case 4                                          'SKYLAST
            object$ = Combo6$(4)
            print #main.textbox4, "object selected is "; object$
            #main.combo7 "selectindex 0"
        Case 5                                          'CATALOG
            gosub [Select_Catalog_Stars]  'if catalog is selected
            goto [END_SELECT_OBJECT]
        Case else                                       'star in list
             object$ = Combo6$(ObjectIndex)
             CatalogMatch$ = ""
             Select Case TypeArray$(ObjectIndex)
                Case "A"
                    Catalog$ = "A"
                    CatalogMatch$ = "Astar"
                    print #main.combo7, "select "; CatalogMatch$
                Case "F"
                    Catalog$ = "F"
                    CatalogMatch$ = "Foe"
                    print #main.combo7, "select "; CatalogMatch$
                Case "S"
                    Catalog$ = "S"
                    CatalogMatch$ = "Soe"
                    print #main.combo7, "select "; CatalogMatch$
                Case "C"
                    Catalog$ = "C"
                    CatalogMatch$ = "Comp"
                    print #main.combo7, "select "; CatalogMatch$
                Case "V"
                    Catalog$ = "V"
                    CatalogMatch$ = "Var"
                    print #main.combo7, "select "; CatalogMatch$
                Case "M"
                    Catalog$ = "M"
                    CatalogMatch$ = "Moving"
                    print #main.combo7, "select "; CatalogMatch$
                Case "T"
                    Catalog$ = "T"
                    CatalogMatch$ = "Trans"
                    print #main.combo7, "select "; CatalogMatch$
                Case "Q"
                    Catalog$ = "Q"
                    CatalogMatch$ = "Q'check"
                    print #main.combo7, "select "; CatalogMatch$ 
             End Select
        End Select

        if (TelescopeFlag = 1) and (TrialVersion = 0) then
                                                    'move to SKY coordinates if there are any
            if left$(object$,3) = "SKY" AND ScriptSkyRA <> 0 then
                DEC = ScriptSkyDEC
                RA  = ScriptSkyRA
            else
                DEC = DECArray(ObjectIndex)         'Dec in degrees, -90.0000 to +90.0000
                RA  = RAArray(ObjectIndex)          'RA in degrees, 0 to 359.9999, 0.0007 resolution
            end if
            if DEC = 0 and RA = 0 then          'if object has no RA & DEC, skip the move command
                print #main.textbox4, "object selected is "; object$+_
                                      "  >center object and press Start/CONT<"
            else

                gosub [Find_Meade_Coordinates]

                if ScriptFlag = 0 then          'print "Start" if script not running
                    print #main.textbox4, "object selected is "; object$+_
                                        " moving to RA "+RAhour$+":"+RAminutes$+_
                                        "  DEC "+DECsign$+DECdegrees$+":"+DECminutes$+_
                                        "  >center object and press Start<"
                else                            'print "CONT" if script is running
                    print #main.textbox4, "object selected is "; object$+_
                                        " moving to RA "+RAhour$+":"+RAminutes$+_
                                        "  DEC "+DECsign$+DECdegrees$+":"+DECminutes$+_
                                        "  >center object and press CONT<"
                end if

                select case TelescopeType
                    case 1
                        gosub [Precess_Coordinates]
                        gosub [Find_Meade_Coordinates]
                        gosub [Move_Meade_Telescope]
                    case 2
                        gosub [Move_Celestron]
                    case 3
                        gosub [Move_Celestron]
                    case 4
                        gosub [Move_Celestron_New_GT]
               end select
            end if
        else
            print #main.textbox4, "object selected is "; object$+_
                                  "     >center object and press Start<"
        end if

    [END_SELECT_OBJECT]

    #main.combo6 "selectindex 0"
    print #main.combo6, "reload"

    if object$ <> "nothing entered" then
        print #main.combo6, "!";object$
    end if

    if ScriptFlag = 1 then return            'return to script when finished

goto [timeloop]
'
'
[SELECT_CATALOG.Click]
    #main.combo7 "selectionindex? CatalogIndex"
    SELECT CASE CatalogIndex
    CASE 1
        Catalog$ = "A"
        print #main.textbox4, "Astar catalog selected"
    CASE 2
        Catalog$ = "F"
        print #main.textbox4, "FOE catalog selected"
    CASE 3
        Catalog$ = "S"
        print #main.textbox4, "SOE catalog selected"
    CASE 4
        Catalog$ = "C"
        print #main.textbox4, "Comparison catalog selected"
    CASE 5
        Catalog$ = "V"
        print #main.textbox4, "Variable star catalog selected"
    CASE 6
        Catalog$ = "M"
        print #main.textbox4, "Moving object catalog selected"
    CASE 7
        Catalog$ = "T"
        print #main.textbox4, "Transformation star catalog selected"
    CASE 8
        Catalog$ = "Q"
        print #main.textbox4, "Check star catalog selected"
    CASE else
        Catalog$ = " "
        print #main.textbox4, "No catalog selected"
    END SELECT
    #main.combo7 "selectindex 0"
    print #main.combo7, "!";Combo7$(CatalogIndex)

    if ScriptFlag = 1 then return                   'return to script when finished

goto [timeloop]
'
'======buttons  START and mirror control
'
[START.Click]

    if ScriptHold = 1 then
        ScriptHold = 0
        GOTO [CONTINUE_SCRIPT]
    end if

    Notes$ = ""
    if CommFlag = 0 then                'check to see if COM port is open
        call CommError
        goto [End_START_Click]
    end if
                                        'check to see if settings are right to get a count
    if  (GainIndex = 0) OR (IntegIndex = 0) OR (IntervalIndex = 0) then
        print #main.textbox4, "settings not right"
        goto [End_START_Click]
    end if
                                                         'confirmation not required to flip mirror
    if AutoMirrorFlag = 2 AND MirrorFlag = 0 then           'if Auto Mirror option enabled and mirror in VIEW position
        junk$ = input$(#commHandle, lof(#commHandle))       'clear buffer
        print #commHandle, "SVIEW1"                         'start flip mirror operation to RECORD position
        print #main.button3, "WAIT"                         'wait for flip mirror to finish
        call Pause (2000)                                   'pause 2 seconds
        print #main.button3, "RECORD"
        MirrorFlag = 1
    end if
                                                            'confirmation requred to flip mirror
    if AutoMirrorFlag = 1 AND MirrorFlag = 0 then           'if Auto Mirror option enabled and mirror in VIEW position
        confirm "Mirror is in VIEW position. Do you wish to change it to RECORD?"; answermirror$
        if answermirror$ = "yes" then
            junk$ = input$(#commHandle, lof(#commHandle))   'clear buffer
            print #commHandle, "SVIEW1"                     'start flip mirror operation to RECORD position
            print #main.button3, "WAIT"                     'wait for flip mirror to finish
            call Pause (2000)                               'pause 2 seconds
            print #main.button3, "RECORD"
            MirrorFlag = 1
        end if
    end if

   print #main.textbox4, "Getting count data for - please wait"

    SELECT CASE CountMode
        CASE 1                              'Trial mode, get count and display in Message box
            gosub [Get_Counts]
        CASE 2                              'Slow mode, get 1 to 4 counts and display in data area
            gosub [CheckSlowSettings]

            if filter$ = "select" then      'if "select" is picked at first make it a blank
                filter$ = " "
            end if
                                        'get first letter of filter for proper write to display box
            print #main.combo1, "contents? filter$"
            filter$ = left$(filter$,1)

                                        'if any SKY* object selected, make sure blank is in Cat. column
            if object$ = "SKY" or object$ = "SKYNEXT" or object$ = "SKYLAST" then
                TempCatalog$ = " "
            else
                TempCatalog$ = Catalog$
            end if
            if filter$ = "select" then
                filter$ = " "
            end if

            print #main.textbox4, "Getting count data for "+filter$+" filter - please wait"

            for I = 1 to 4
                Counts$(I) = "    0"
            next I
            gosub [Get_Counts]
            gosub [DisplayData]
            DataCounter = DataCounter + 1
            beep
        CASE 3                              'Fast mode, get counts an display in Fast Count Window
            gosub [CheckFastSettings]

            if ScriptFlag = 1 then
                notice "click OK to start count"
            end if
            gosub [Get_Fast_Counts]

            gosub [Get_Fast_Array]
            for I = 1 to Interval
                FastCounts$(I) = right$("000"+str$(I),4)+"  "+FastTimeArray$(I)+_
                             "   "+FastCounts$(I)
            next I
            beep
            gosub [Open_Fast_Window]
        CASE 4                              'Very Fast Mode, 2ms integration time for SSP-5 only
            gosub [CheckVeryFastSettings]
            gosub [Get_Very_Fast_Counts]
            gosub [Get_Fast_Array]
            for I = 1 to Interval
                FastCounts$(I) = right$("000"+str$(I),4)+"   "+FastTimeArray$(I)+_
                             "   "+FastCounts$(I)
            next I
            beep
            gosub [Open_Fast_Window]
    END SELECT

    print #main.button1, "start"

    [End_START_Click]

    if ScriptFlag = 1 then return                   'return to script when finished

    playwave "ding.wav"                             'play "ding" when finished with counts
goto [timeloop]
'
[MIRROR.Click]
    if CommFlag = 0 then                'check to see if COM port is open
        call CommError
        goto [timeloop]
    end if
    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if
    if MirrorFlag = 0 then
        junk$ = input$(#commHandle, lof(#commHandle))   'clear buffer
        print #commHandle, "SVIEW1"                     'start flip mirror operation to RECORD position
        print #main.button3, "WAIT"                     'wait for flip mirror to finish
        call Pause (2000)                               'pause 2 seconds
        print #main.button3, "RECORD"
        MirrorFlag = 1                                  'flag to indicate that mirror is in RECORD position
    else                                                'if MirrorFlag = 1 then
        junk$ = input$(#commHandle, lof(#commHandle))   'clear buffer
        print #commHandle, "SVIEW0"                     'start flip mirror operation to VIEW position
        print #main.button3, "WAIT"                     'wait for flip mirror to finish
        call Pause (2000)                               'pause 2 seconds
        print #main.button3, "VIEW"
        MirrorFlag = 0                                  'flag to indicate that mirror is in VIEW position
    end if

    if ScriptFlag = 1 then
        return
    end if

goto [timeloop]
'
'====main data area listing box for edit of NOTES
'
[DATA_BOX]
    print #main.listbox1, "selection? selected$"        'double click gets the data line
    print #main.listbox1, "selectionindex? index"       'double click gets the index

    prompt "Note Edit"+chr$(13)+"10 character limit - type 'DEL' to delete note";Notes$

    Notes$ = upper$(Notes$)

    if Notes$ <> "" then
        if Notes$ = "DEL" then
            Notes$ = ""
        end if
        DataLine$ = left$(selected$,77)                 'strip off any notes
        Notes$ = left$(Notes$,10)
                                                        'replace data line with new data line
        SavedData$(DataCounter - index) = DataLine$+"  "+Notes$
    end if
                                                        'put new data line in the saved data array
    for ListingIndex = 0 to DataCounter
         DataArray$(ListingIndex) = SavedData$(DataCounter - ListingIndex)
    next

    Notes$ = ""
    print #main.listbox1, "reload"                      'reload the data listbox

    if ScriptHold = 1 then                              'return to script after entering notes
        goto [WAIT_FOR_CONTINUE]
    end if

goto [timeloop]
'
'=====Communication error handler
'
[COMHandler]                                'routines to handle errors opening port
    oncomerror                              'disable come error handler

    print #main.textbox4, "SSP Port Error "; ComError$;"  Port number: "; ComPort; "  Code: "; ComErrorNumber
goto [timeloop]
'
[TelescopeHandler]
    oncomerror

    print #main.textbox4, "Telescope Port Error "; ComError$;"  Port number: "; TelescopeCOM; "  Code: "; ComErrorNumber
goto [timeloop]
'
'======gosub routines
'
[CheckFastSettings]
    if Interval < 100 then
        notice "Interval must be 100-5000"
        goto [timeloop]
    end if
                                       'calculate the time in seconds for the Interval + dead time
                                       'dead time = 3.7ms
    CountTime =  (Int(((10*Integ+37)*(Interval-1))/10000))
    CountTime$ = str$(CountTime)
    print #main.textbox4, "this will take  ";CountTime$;" seconds, select ABORT under Count to stop"
return
'
[CheckSlowSettings]
    If Integ = 1000 or Integ = 5000 or Integ = 10000 and Interval <= 4 then
        return
    else
        print #main.textbox4, "settings for SLOW mode not right"
        goto [timeloop]
    end if
return
'
[CheckVeryFastSettings]
    if Interval < 2000 then
        notice "Interval must be 2000 or greater"
        goto [timeloop]
    end if
return
'
[disableEverything]                         'disable control in Make Script window
    print #script.cycles, "!disable"
    print #script.cyclelabel, "!disable"
    print #script.comparisontext, ""
    print #script.variabletext,   ""
    print #script.trans3text,     ""
    print #script.trans4text,     ""
    print #script.trans5text,     ""
    print #script.filterU, "disable"
    print #script.filterB, "disable"
    print #script.filterV, "disable"
    print #script.filterR, "disable"
    print #script.filterI, "disable"
    print #script.trans3, ""
    print #script.trans4, ""
    print #script.trans5, ""
    print #script.trans3, "!disable"
    print #script.trans4, "!disable"
    print #script.trans5, "!disable"
return
'
[Disable_Main_Menu]
    print #main.combo1, "Disable"
    print #main.combo2, "Disable"
    print #main.combo3, "Disable"
    print #main.combo4, "Disable"
    print #main.combo5, "Disable"
    print #main.combo6, "Disable"
    print #main.combo7, "Disable"
    print #main, "Disable"
return
'
[DisplayData]
    gosub [UTtimeCorrected]
    SavedData$(DataCounter) = UTdateCorrected$+" "+UTtimeCorrected$+_                      'UT date and time
                              " "+TempCatalog$+"    "+left$(object$+"            ",12)+_   'Catalog and Object
                              "   "+filter$+"  "+_                                         'Filter
                              right$(Counts$(1),5)+"  "+right$(Counts$(2),5)+"  "+_        'count data
                              right$(Counts$(3),5)+"  "+right$(Counts$(4),5)+_             'count data
                              "  "+Integ$+" "+Gain$                                        'Integration and Gain

                                        'save data line to temporary data file
    open "Temporary Data.raw" for append as #Temporary
        print #Temporary, " "+SavedData$(DataCounter)
    close #Temporary
                                        'reload data array into display area
                                        'display data in reverse order
    for ListingIndex = 0 to DataCounter
        DataArray$(ListingIndex) = SavedData$(DataCounter - ListingIndex)
    next

    print #main.listbox1, "reload"
return
'
[Enable_Main_Menu]
    print #main.combo1, "Enable"
    print #main.combo2, "Enable"
    print #main.combo3, "Enable"
    print #main.combo4, "Enable"
    print #main.combo5, "Enable"
    print #main.combo6, "Enable"
    print #main.combo7, "Enable"
    print #main, "Enable"
return
'
[FindDateTime]
    time$ = time$()
    print #main.textbox2, " "; time$
    gosub [UTtimeFind]
    print #main.textbox1, " "; UTtime$

    date$ = date$()
    print #main.textbox6, date$("mm/dd/yyyy")
    gosub [UTdateFind]
    print #main.textbox5, UTdate$
return
'
[Find_File_Name]
    FileNameIndex = len(DataFile$)
    FileNameLength = len(DataFile$)
    while mid$(DataFile$, FileNameIndex,1)<>"\"         'look for the last backlash
        FileNameIndex = FileNameIndex - 1
    wend
    FileNamePath$ = left$(DataFile$, FileNameIndex)
    DataFileName$ = right$(DataFile$, FileNameLength-FileNameIndex)
    print #main.textbox4, "opened new file : "; DataFileName$
return
'
[Find_Meade_Coordinates]                                'converts RA DEC in degrees to Hour Minutes in LX format
                                                        'input RA in degees 0 to 360
                                                        'input DEC in degrees -90 to +90
        RAhour$ = str$(int(RA/15))                      'get RA hours with no leading spaces
        RAhour$ = "00"+RAhour$                          'add 00 to the string
        RAhour$ = right$(RAhour$,2)                     'get RA hours with leading zero
        RAminutes = (RA - val(RAhour$)*15) * 4          'get minutes with fractional part
        RAminutes$ = using("##.#",RAminutes)            'round off tenths of a minute
        RAminutes$ = str$(val(RAminutes$))              'get string variable with no leading spaces
        RAminutes$ = "00"+RAminutes$                    'add 00 to the string
        RAminutes$ = right$(RAminutes$,4)               'get minutes with leading zero and tenths

        if DEC >= 0 then                                'find if it is North or South DEC
            DECsign$ = "+"
        else
            DECsign$ = "-"
        end if
        DECdegrees = abs(int(DEC))                      'get whole degrees
                                                        'get minutes with correct rounding off
        DECminutes = int((abs(DEC) - abs(int(DEC))) * 60 + 0.5)
        if DECminutes  = 60 then                        'see if value is 60 and change to 0 if true and
            DECminutes = 0                               'add 1 degree
            DECdegrees = DECdegrees + 1
        end if
        DECdegrees$ = str$(DECdegrees)
        DECdegrees$ = "00"+DECdegrees$                  'add 00 to the string
        DECdegrees$ = right$(DECdegrees$,2)             'get whole degrees with leading zero if any

        DECminutes$ = str$(DECminutes)
        DECminutes$ = "00"+DECminutes$                  'add 00 to the string
        DECminutes$ = right$(DECminutes$,2)             'get minutes with any leading zero
return
'
[Get_Counts]
    gosub [FindDateTime]
    UTtimeRecord$ = UTtime$                             'get UT time at start of count and store it
    UTdateRecord$ = UTdate$                             'get UT date at start of count and store it
    UTDaysRecord  = Days                                'store Days from UTdateFind sub
    IntervalRecord = Interval                           'corrected interval in case count has to be repeated

    for I = 1 to Interval
        [startover]
        scan
                                      'check to see if an abort was made
        junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
        print #commHandle, "SCnnnn"                    'start the count
        print #main.button1, "WAIT"

        Select Case Integ
            Case 1000
                call Pause 1150
                gosub [FindDateTime]
            Case 5000
                for Temporary = 1 to 5
                    call Pause 1030
                    gosub [FindDateTime]
                next
            Case 10000
                for Temporary = 1 to 10
                    call Pause 1015
                    gosub [FindDateTime]
                next
        End Select

        numBytes = lof(#commHandle)
        TempCounts$ = input$(#commHandle, numBytes)    'get data from buffer
                                                       'find the "=" sign and take the 5 characters to the right
        for I2 = 1 to numBytes
            if mid$(TempCounts$,I2,1) = "=" then
                exit for
            end if
        next I2

        Counts$(I) = mid$(TempCounts$,(I2+1),5)

        firstletter = asc(Counts$(I))

                                                       'error checking for communication problem
        if firstletter = 0 then
            print #main.textbox4, "Communication error - count restarted"
            IntervalRecord = IntervalRecord + 1        'for corrected time change Interval + 1
            goto [startover]
        end if

        print #main.textbox4, "Count ";I;" = ";Right$(Counts$(I),5)
                                                        'press ESC to end count
        CallDLL #user32, "GetAsyncKeyState",_VK_ESCAPE as long, ks as long
        if ks < 0 then
            print #main.textbox4, "Count Ended"
            I = Interval
        end if

    next I

    [End_Get_Counts]
    print #main.button1, "start"
    junk$ = input$(#commHandle, lof(#commHandle))      'clear buffer

    UTtime$ = UTtimeRecord$                            'retrieve stored time and date and make ready to be
    UTdate$ = UTdateRecord$                            'converted to UT corrected time for displayed data
    Days =    UTDaysRecord                             '
return
'
[Get_Fast_Array]                                       'calculate the time for each count event
    TimeIntervalSec = ((TimeEndMs - TimeStartMs)/Interval)/1000
    TimeSec = val(right$(TimeStart$,2))
    TimeMin = val(mid$(TimeStart$,4,2))
    TimeHour = val(left$(TimeStart$,2))
    For I = 1 to Interval
        TimeSec$ = using("##.###", TimeSec)
        TimeMin$ = right$("0"+str$(TimeMin),2)
        TimeHour$ = right$("0"+str$(TimeHour),2)
        FastTimeArray$(I) = TimeHour$+":"+TimeMin$+":"+TimeSec$
        TimeSec = TimeSec + TimeIntervalSec
        if TimeSec >= 60 then
            TimeSec = TimeSec - 60
            TimeMin = TimeMin + 1
        end if
        if TimeMin >= 60 then
            TimeMin = TimeMin - 60
            TimeHour = TimeHour + 1
        end if
        if TimeHour >= 24 then
            TimeHour = TimeHour - 24
        end if
    next I
return
'
[Get_Fast_Counts]
    junk$ = input$(#commHandle, lof(#commHandle))      'clear buffer
    Interval$ = right$("0000"+str$(Interval),4)        'calculate string for Intervals
    print #main.button1, "WAIT"
    TimeStart$ = Time$()                               'get time
    while TimeStart$ =Time$()                          'wait here until time changes
    wend
    print #commHandle, "SM"+Interval$                  'start the fast mode counting
    TimeStart$ = Time$()                               'get the start time
    TimeStartMs = Time$("ms")
    BufferLength = Interval * 6                        'calculate the buffer size for all the data
    while (BufferLength <> lof(#commHandle))           'wait until buffer has all of the data
         Call Pause 2
         if time$ <> time$() then                      'update the time window
             time$ = time$()
             print #main.textbox2, " "; time$
             gosub [UTtimeFind]
             print #main.textbox1, " "; UTtime$
             print #main.textbox4, "this will take  ";CountTime$;" seconds, select ABORT under Count to stop"
             CountTime = CountTime - 1
             CountTime$ = str$(CountTime)
         end if
         scan
    wend
    CountsTotal$ = input$(#commHandle,BufferLength)    'get the count data in on long string
    BufferIndex = 1
    for I = 1 to Interval                              'separate out the individual count data
        FastCounts$(I) = mid$(CountsTotal$,BufferIndex,4)
        BufferIndex = (BufferIndex + 6)
    next I

    TimeEndMs = Time$("ms")                            'get the end time
    if TimeEndMs < TimeStartMs then                    'if run goes past midnight, add 1 day to end time
        TimeEndMs = TimeEndMs + 86400000               '86400000 number of ms in 24 hours
    end if
return
'
[Get_Very_Fast_Counts]
    junk$ = input$(#commHandle, lof(#commHandle))      'clear buffer
    Interval$ = right$("0000"+str$(Interval),4)        'calculate the string for Intervals
    print #main.button1, "WAIT"
    TimeStart$ = Time$()                               'get the time
    while TimeStart$ = Time$()                         'wait here until time changes
    wend
    print #commHandle, "SN"+Interval$                  'start the very fast mode counting
    TimeStart$ = Time$()                               'get the start time
    TimeStartMs = Time$("ms")
    BufferLength = Interval * 2                        'calculate the buffer size for all the data
    while (BufferLength <> lof(#commHandle))           'wait here until buffer has all the data
         Call Pause 2
         scan
    wend
    CountsTotal$ = input$(#commHandle,BufferLength)    'get the counts in one big string
    BufferIndex = 1
    for I = 1 to Interval                              'separate out the individual count
        FastCounts$(I) = mid$(CountsTotal$,BufferIndex,2)
        BufferIndex = (BufferIndex + 2)
    next I
    TimeEndMs = Time$("ms")                            'get the end time
    if TimeEndMs < TimeStartMs then                    'if run goes past midnight, add 1 day to end time
        TimeEndMs = TimeEndMs + 86400000               '86400000 number of ms in 24 hours
    end if
return
'
[Make_Header]                           'open new window to get user and condition info for
                                        'file header
'
    NOMAINWIN
    WindowWidth = 315 : WindowHeight = 230
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

    statictext  #head.statictext1, "Telescope:", 15, 52, 80, 16
    statictext  #head.statictext2, "Observer:",23, 87, 75, 16
    statictext  #head.statictext3, "Conditions:", 10, 122, 90, 16
    button      #head.button2, "Accept",[Accept_Header],UL, 80, 160, 131, 31
    textbox     #head.textbox1, 100, 50, 140, 25
    textbox     #head.textbox2, 100, 85, 140, 25
    textbox     #head.textbox3, 100, 120, 200, 25

    Open "Data File Header Information" for Window as #head

        #head "trapclose [quit_header]"
        #head "font courier_new 8 16"

    print #head.textbox1, Telescope$
    print #head.textbox2, Observer$
    print #head.textbox3, Conditions$ 

    Wait

    [Accept_Header]
        print #head.textbox1, "!contents? TelescopeTemp$"
        print #head.textbox2, "!contents? ObserverTemp$"
        print #head.textbox3, "!contents? Conditions$"

        if TelescopeTemp$ <> Telescope$ or ObserverTemp$ <> Observer$ then
            Telescope$ = TelescopeTemp$
            Observer$ = ObserverTemp$
            gosub [SaveDparms]
        end if

    [quit_header]
        close #head

    Telescope$ = upper$(Telescope$)
    Observer$ = upper$(Observer$)
    Conditions$ = upper$(Conditions$)
    HeaderLine1$ = " FILENAME="+UPPER$(DataFileName$)+"       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM"
    HeaderLine2$ = " UT DATE= "+UTdate$+"   TELESCOPE= "+Telescope$+"      OBSERVER= "+Observer$
    HeaderLine3$ = " CONDITIONS= "+Conditions$
    HeaderLine4$ = " MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS"

                    'save information to Temporary Data file
    open "Temporary Data.raw" for append as #TemporaryData
        print #TemporaryData, HeaderLine1$
        print #TemporaryData, HeaderLine2$
        print #TemporaryData, HeaderLine3$
        print #TemporaryData, HeaderLine4$
    close #TemporaryData
return
'
'
[Move_Celestron]                                                    'code for Celestron old GT (type2) & N5/N8 (type3)
        SELECT CASE TelescopeCOM
        CASE 0
            notice "select proper COM port in setup menu"
            goto [timeloop]
        CASE ELSE
            oncomerror [TelescopeHandler]
            open "com"+str$(TelescopeCOM)+":9600,n,8,1,ds0,cs0,rs" for random as #TelescopeHandle
        END SELECT
        CheckCounter = 0

        RA = RA/360 * 65536
        if DEC >= 0 then
            DEC = DEC/90 * 16384
        else
            DEC = 65536 - abs(DEC)/90 * 16384
        end if

        RAbyte1  = int(RA/256)
        RAbyte2  = int(RA Mod 256)
        DECbyte1 = int(DEC/256)
        DECbyte2 = int(DEC Mod 256)

    [Repeat_Command_Celestron]
        junk$ = input$(#TelescopeHandle, lof(#TelescopeHandle))      'clear buffer
                                                                     '
        print #TelescopeHandle, "?"                                  'initialize
        Call Pause 250                                               'wait and send RA DEC code

        if TelescopeType = 2 then                                    'Celestron old GT type 2
            print #TelescopeHandle, "R"+chr$(RAbyte1)+chr$(RAbyte2)+chr$(0)+_
                                        chr$(DECbyte1)+chr$(DECbyte2)+chr$(0)
        else                                                         'Celestron N5/N8 type 3
            print #TelescopeHandle, "R"+chr$(RAbyte1)+chr$(RAbyte2)+chr$(DECbyte1)+chr$(DECbyte2)
        end if

        Check$ = input$(#TelescopeHandle, lof(#TelescopeHandle))
        if Check$ <> "#" then                                        ' "#" is sent if command received
            CheckCounter = CheckCounter + 1
            if CheckCounter = 5 then
                print #main.textbox4, "ERROR in setting position"
                goto [Exit_Move_Celestron]
            else
                goto [Repeat_Command_Celestron]
            end if
        end if
        CheckCounter = 0

    [Exit_Move_Celestron]
    close #TelescopeHandle
return
'
[Move_Celestron_New_GT]                                             'code for new Celestron GT (type4)
        SELECT CASE TelescopeCOM
        CASE 0
            notice "select proper COM port in setup menu"
            goto [timeloop]
        CASE ELSE
            oncomerror [TelescopeHandler]
            open "com"+str$(TelescopeCOM)+":9600,n,8,1,ds0,cs0,rs" for random as #TelescopeHandle
        END SELECT
        CheckCounter = 0

        RAHEX$ = dechex$(RA/360 * 65536)
        RAHEX$ = right$("0000"+RAHEX$,4)
        if DEC >= 0 then
            DECHEX$ = dechex$(DEC/90 * 16384)
        else
            DECHEX$ = dechex$(65536 - (abs(DEC)/90 * 16384))
        end if
        DECHEX$ = right$("0000"+DECHEX$,4)

    [Repeat_Command_New_GT]
        junk$ = input$(#TelescopeHandle, lof(#TelescopeHandle))      'clear buffer
                                                                     'send DEC set code
        print #TelescopeHandle, "R"+RAHEX$+","+DECHEX$
        Call Pause 150
        Check$ = input$(#TelescopeHandle, lof(#TelescopeHandle))
        if Check$ <> "#" then                                        ' "#" is sent if command received
            CheckCounter = CheckCounter + 1
            if CheckCounter = 5 then
                print #main.textbox4, "ERROR in setting position"
                goto [Exit_Move_Celestron_New_GT]
            else
                goto [Repeat_Command_New_GT]
            end if
        end if
        CheckCounter = 0

    [Exit_Move_Celestron_New_GT]
    close #TelescopeHandle
return
'
[Move_Meade_Telescope]                                               'code for Meade LX200 (type1)
        SELECT CASE TelescopeCOM
        CASE 0
            notice "select proper COM port in setup menu"
            goto [timeloop]
        CASE ELSE
            oncomerror [TelescopeHandler]
            open "com"+str$(TelescopeCOM)+":9600,n,8,1,ds0,cs0,rs" for random as #TelescopeHandle
        END SELECT
        CheckCounter = 0

    [Repeat_RA_Command]
        junk$ = input$(#TelescopeHandle, lof(#TelescopeHandle))      'clear buffer
                                                                     'send RA set code
        print #TelescopeHandle, "#:Sr "+RAhour$+":"+RAminutes$+"#"
        Call Pause 150
        Check$ = input$(#TelescopeHandle, lof(#TelescopeHandle))
        if Check$ <> "1" then                                        'a 1 is sent if DEC is OK
            CheckCounter = CheckCounter + 1
            if CheckCounter = 5 then
                print #main.textbox4, "ERROR in setting RA"
                goto [Exit_Move_Meade_Telescope]
            else
                goto [Repeat_RA_Command]
            end if
        end if
        CheckCounter = 0

    [Repeat_DEC_Command]
        junk$ = input$(#TelescopeHandle, lof(#TelescopeHandle))      'clear buffer
                                                                     'send DEC set code
        print #TelescopeHandle, "#:Sd "+DECsign$+DECdegrees$+chr$(223)+DECminutes$+"#"
        Call Pause 150
        Check$ = input$(#TelescopeHandle, lof(#TelescopeHandle))
        if Check$ <> "1" then                                        'a 1 is sent if DEC is OK
            CheckCounter = CheckCounter + 1
            if CheckCounter = 5 then
                print #main.textbox4, "ERROR in setting DEC"
                goto [Exit_Move_Meade_Telescope]
            else
                goto [Repeat_DEC_Command]
            end if
        end if
        CheckCounter = 0

        Call Pause 10
        junk$ = input$(#TelescopeHandle, lof(#TelescopeHandle))      'clear buffer
                                                                     'send code to move telescope
        print #TelescopeHandle, "#:MS#"
        Call Pause 1000
        Check$ = input$(#TelescopeHandle, lof(#TelescopeHandle))
        if Check$ <> "0" then                                        'a 0 is sent if move command OK
            print #main.textbox4, "LX Error Code: "+left$(Check$,1)+_
                                  "   Description: "+mid$(Check$,2)
            goto [Exit_Move_Meade_Telescope]
        end if

        [Exit_Move_Meade_Telescope]
        close #TelescopeHandle

return
'
[Open_Fast_Window]                                  'display the fast count data in a special window
    NOMAINWIN
    WindowWidth = 351 : WindowHeight = 451
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #fast, "&File" , "E&xit", [quit_fast]
    statictext  #fast.static1, "PC Time", 137, 5, 60, 16
    statictext  #fast.static2, "Count", 228, 5, 45, 16
    statictext  #fast.static3, "Interval", 45, 5, 65, 16
    button      #fast.button1, "Save Data/Exit",[Save_Fast.click],UL, 30, 340, 120, 45
    button      #fast.button2, "Dump Data/Exit",[quit_fast],UL, 200, 340, 120, 45
    listbox     #fast.list1, FastCounts$(),[list_Fast1.click], 55, 30, 240, 285

    Open "Fast Count" for Window as #fast

        #fast "trapclose [quit_fast]"
        #fast "font courier_new 8 16"
        ConfirmHeading$ = "Fast Data File NOT Saved"

    [Save_Fast_Data_Loop]
        Wait

    [Save_Fast.click]                               'if desired, save data
        filedialog "Open Fast Data File", PathFastDataFile$, DataFile$
        for I = len(DataFile$) to 1 step -1
            if mid$(DataFile$,I,1) = "\" then
            PathFastDataFile$ = left$(DataFile$,I)+"*raw"
            exit for
        end if
    next I

        if DataFile$ = "" then [Save_Fast_Data_Loop]

        files "c:\", DataFile$, info$()
        if val(info$(0, 0)) <> 0 then
            confirm "new data will NOT be appended"+chr$(13)+_
                    "do you wish to overwrite file?";Answer$
            if Answer$ <> "yes" then [Save_Fast.click]

            gosub [Find_File_Name]
            if len(DataFileName$) >= 13 then [Save_Fast.click]
        end if
        prompt "Fast Data File Header"+chr$(13)+"enter header infomation for fast data file";FastHeading$
        open DataFile$ for output as #FastCountFile
            print #FastCountFile, "  FILENAME=";DataFile$
            print #FastCountFile, "  ";date$("mm/dd/yyyy");"  ";FastHeading$
            print #FastCountFile, "  Gain: ";
            print #FastCountFile, " "
            print #FastCountFile, "                PC      COUNTS"
            for I = 1 to Interval
                print #FastCountFile, "    ";FastCounts$(I)
            next I
        close #FastCountFile
        ConfirmHeading$ = "Fast Data File Saved"
    [quit_fast]
        confirm ConfirmHeading$+chr$(13)+"do you want to empty fast data array and close?";Answer$
        if Answer$ = "no" then [Save_Fast_Data_Loop]
        redim FastCounts$(5000)
        redim FastTimeArray$(5000)
        close #fast
return
'
[Precess_Coordinates]
                                        'for J2000, equation from
                                        'RAn = RAo + (m + n * sin(RAo) * tan(DECo) * N
                                        'DECn = DECo + (n' * cos(RAo)) * N
                                        'where m  = 3.07420 seconds
                                        '      n  = 1.33589 seconds
                                        '      n' = 20.0382 seconds
                                        '      N  = number of years from 2000
    CurrentDate$ = date$("yyyy/mm/dd")
    CurrentYear = val(left$(CurrentDate$,4))
    CurrentMonth = val(mid$(CurrentDate$,6,2))
    CurrentYearMonth = CurrentYear + CurrentMonth/12

    YearJ2000 = CurrentYearMonth - 2000

    DEC = DEC + (20.0383 * cos(RA/57.29577952)) * YearJ2000 / 3600
    RA = RA + (3.07420 + 1.33589 * sin(RA/57.29577952) * tan(DEC/57.29577952)) * YearJ2000 * .00416666
return
'
[Reset_All_Script_Buttons]
        print #script.filterU, "reset"
        print #script.filterB, "reset"
        print #script.filterV, "reset"
        print #script.filterR, "reset"
        print #script.filterI, "reset"
        print #script.integ1, "reset"
        print #script.integ5, "reset"
        print #script.integ10, "reset"
        print #script.interval1, "reset"
        print #script.interval3, "reset"
        print #script.interval4, "reset"
        print #script.skyinterval1, "reset"
        print #script.skyinterval2, "reset"
        print #script.skyinterval3, "reset"
        print #script.skyinterval4, "reset"
        print #script.gain1, "reset"
        print #script.gain100, "reset"
        print #script.comparison, ""
        print #script.variable, ""
        print #script.trans3, ""
        print #script.trans4, ""
        print #script.trans5, ""
return
'
[Reset_Object_Combobox]
        redim Combo6$(4000)
        Combo6$(1) = "New Object"
        Combo6$(2) = "SKY"
        Combo6$(3) = "SKYNEXT"
        Combo6$(4) = "SKYLAST"
        Combo6$(5) = "CATALOG"
        ObjectIndexMax = 5

return
'
[SaveDparms]
    open "dparms.txt" for output as #dparms
       print #dparms, ComPort          'values of 1 to 19 acceptable
       print #dparms, TimeZoneDiff     'values of -12 to +12 acceptable
       print #dparms, AutoManual$      'A = auto 6-position slider, M = manual 2-position slider
       for I = 1 to 18
          print #dparms, Filters$(I)   'positions 1 to 6 for 6-position slider
       next
       print #dparms, FilterBar        'filter bar 1 to 3, 1 default
       print #dparms, NightFlag        'screen color, 1 for red and 0 for natural
       print #dparms, AutoMirrorFlag   'auto mirror disabled = 0, auto mirror enabled = 1
       print #dparms, TelescopeFlag    'telescope disabled = 0, telescope enabled = 1
       print #dparms, TelescopeCOM
       print #dparms, TelescopeType    '0 = no scope, 1 = LX200, 2 = Celestron old GT, 3 = Celestron N5/N8
                                       '4 = Celestron new GT
       print #dparms, Telescope$       'Telescope for RAW file header
       print #dparms, Observer$        'Observer for RAW file header
       print #dparms, FilterSystem$    'Filter system usded in scripting 1=Johnson/Cousins 0 = Sloan
    close #dparms
return
'
[UTtimeFind]
    time$ = time$()                     'get current PC time
    hours = val(left$(time$,2))         'get hours from PC clock
    hours = hours + TimeZoneDiff        'add time zone difference to get UT hours
    DayUpDown = 0
    if hours >= 24 then                 'if time goes past midnight, add a day
        hours = hours - 24
        DayUpDown = 1
    end if
    if hours < 0 then                   'if time goes back past midnight, subtract a day
        hours = hours + 24
        DayUpDown = -1
    end if
    UThour$ = right$("0"+str$(hours),2)
    UTtime$ = UThour$+right$(time$,6)   'connect revised hour to time string
return
'
[UTdateFind]                            'update the UT day - always run UTtimeFind before running date
    Days = date$("days") + DayUpDown
    UTdate$ = date$(Days)
return
'
[UTtimeCorrected]                       'routine to make sure the day ahead or back is correct
    MidCount =  int((IntervalRecord * (Integ/1000))/2)
    UTsec = val(right$(UTtime$,2))
    UTmin = val(mid$(UTtime$,4,2))
    UThour = val(left$(UTtime$,2))
    UTday = val(mid$(UTdate$,4,2))
    UTmonth = val(left$(UTdate$,2))
    UTyear = val(right$(UTdate$,4))
    UTsec = UTsec + MidCount            'add 1/2 total integration time to find mid-point
    if UTsec >= 60 then
        UTmin = UTmin + 1
        UTsec = UTsec - 60
    end if
    if UTmin >= 60 then
        UThour = UThour + 1
        UTmin = UTmin - 60
    end if
    if UThour >= 24 then                'if going past midnight UT, add a day
        Days = Days + 1
        UTdate$ = date$(Days)
        UTday = val(mid$(UTdate$,4,2))
        UTmonth = val(left$(UTdate$,2))
        UTyear = val(right$(UTdate$,4))
        UThour = UThour - 24
    end if
    UTsec$ = right$("0"+str$(UTsec),2)
    UTmin$ = right$("0"+str$(UTmin),2)
    UThour$ = right$("0"+str$(UThour),2)
    UTday$ = right$("0"+str$(UTday),2)
    UTmonth$ = right$("0"+str$(UTmonth),2)
    UTyear$ = right$(str$(UTyear),4)
    UTtimeCorrected$ = UThour$+":"+UTmin$+":"+UTsec$ 
    UTdateCorrected$ = UTmonth$+"-"+UTday$+"-"+UTyear$
return
'
[WaitForAck]                                'routine to wait for ! to be returned from SSP
    Ack = 0                                 'set ack flag to false

    for I = 1 to 100                        'find the "!" in the serial input and set ack flag to 1 if found
        call Pause 50                       'this may take up to 5 seconds before sending error message
        numBytes = lof(#commHandle)
        dataRead$ = input$(#commHandle, numBytes)

        for I2 = 1 to numBytes
            if mid$(dataRead$, I2, 1) = "!" then
                Ack = 1
                exit for
            end if
        next I2
        if Ack = 1 then
            exit for
        end if
    next I

    if Ack = 0 then                         'if no "!" received then indicate error condition
        print #main.textbox4, "did not receive Ack from SSP - will try again"
        call Pause 2000
    end if
return
'
'=====sub routines
'
SUB Pause mil
    t = time$("milliseconds")
    endtime = t + mil
    if endtime > 86400000 then
        endtime = endtime - 86400000
        while time$("milliseconds") > t
            calldll #kernel32, "Sleep",1 as ulong,r as void
        wend
        while time$("milliseconds") < endtime
            calldll #kernel32, "Sleep",1 as ulong,r as void
        wend
    else
        while time$("milliseconds") < endtime and time$("milliseconds") >= t
            calldll #kernel32, "Sleep",1 as ulong,r as void
        wend
    end if
END SUB
'
SUB CommError                    'routine to print port no opened message
    print #main.textbox4, "port not open - please connect"
    #main.combo1 "selectindex 0"
    print #main.combo1, "!select"
    #main.combo2 "selectindex 0"
    print #main.combo2, "!select"
    #main.combo3 "selectindex 0"
    print #main.combo3, "!select"
    #main.combo4 "selectindex 0"
    print #main.combo4, "!select"
    #main.combo5 "selectindex 1"
END SUB
'
'========Load Catalog Stars Routines
'
[Select_Catalog_Stars]
    NOMAINWIN
    WindowWidth = 351 : WindowHeight = 451
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #catalogStars, "&File" , "E&xit", [quit_catalog_stars]
    statictext  #catalogStars.static1, "Object", 80, 5, 60, 16


    button      #catalogStars.button4, "Select Object", [Select_Object.click],UL, 205, 264, 120, 30
    button      #catalogStars.button5, "Select All", [Select_All_Object.click],UL, 205, 304, 120, 30
    button      #catalogStars.button6, "Clear Object List", [Select_Clear_Object.click], UL, 205, 344, 120, 30

    groupbox    #catalogStars.group1, "Catalogs", 195, 24, 140, 215
    radiobutton #catalogStars.check1, "Johnson/Cousins", [setJohnson], [resetJohnson], 205, 40, 100, 15
    radiobutton #catalogStars.check2, "Sloan", [setSloan], [resetSloan], 205, 60, 100, 15
    button      #catalogStars.button1, "Open Comp/Var/Check",[Open_VarComp.click],UL, 205, 80, 120, 30
    button      #catalogStars.button2, "Open SOE",[Open_SOE.click],UL, 205, 120, 120, 30
    button      #catalogStars.button4, "Open FOE",[Open_FOE.click],UL, 205, 160, 120, 30
    button      #catalogStars.button3, "Open Transformation",[Open_Transformation.click],UL, 205, 200, 120, 30

    listbox     #catalogStars.list1, CatalogStars$(),[Select_Object.click], 25, 30, 160, 345

    Open "Select Catalog Stars" for Window as #catalogStars

    print #catalogStars.list1, "font courier_new 10"

    #catalogStars "trapclose [quit_catalog_stars]"

    [Select_Catalog_Stars_Loop]

    if FilterSystem$ = "1" then
        print #catalogStars.check1, "set"
        FilterSystemTemp$ = "1"
    else
        print #catalogStars.check2, "set"
        FilterSystemTemp$ = "0"
    end if

    Wait

    [setJohnson]
        FilterSystemTemp$ = "1"
    Wait
    [setSloan]
        FilterSystemTemp$ = "0"
    Wait

    [Open_VarComp.click]
        redim CatalogStars$(4000)
        redim SDitem$(4000,13)
        if FilterSystemTemp$ = "1" then
            SelectedCatalog$ = "Star Data Version 2.txt"
        else
            SelectedCatalog$ = "Star Data Version 2 Sloan.txt"
        end if
        gosub [Load_Catalog_Stars]
        print #catalogStars.list1, "reload"
    Wait

    [Open_SOE.click]
        redim CatalogStars$(4000)
        redim SDitem$(4000,13)
        if FilterSystemTemp$ = "1" then
            SelectedCatalog$ = "SOE Data Version 2.txt"
        else
            SelectedCatalog$ = "SOE Data Version 2 Sloan.txt"
        end if
        gosub [Load_Catalog_Stars]
        print #catalogStars.list1, "reload"
    Wait

    [Open_FOE.click]
        redim CatalogStars$(4000)
        redim SDitem$(4000,13)
        if FilterSystemTemp$ = "1" then
            SelectedCatalog$ = "FOE Data Version 2.txt"
        else
            SelectedCatalog$ = "FOE Data Version 2 Sloan.txt"
        end if
        gosub [Load_Catalog_Stars]
        print #catalogStars.list1, "reload"
    Wait

    [Open_Transformation.click]
        redim CatalogStars$(4000)
        redim SDitem$(4000,13)
        if FilterSystemTemp$ = "1" then
            SelectedCatalog$ = "Transformation Data Version 2.txt"
        else
            SelectedCatalog$ = "Transformation Data Version 2 Sloan.txt"
        end if
        gosub [Load_Catalog_Stars]
        print #catalogStars.list1, "reload"
    Wait

    [Select_Object.click]
        print #catalogStars.list1, "selection? selected$"
        print #catalogStars.list1, "selectionindex? DataIndex"
            if selected$ = "" then
                notice "nothing selected"
                goto [Select_Catalog_Stars_Loop]
            end if
        ObjectIndex = ObjectIndexMax + 1
        Combo6$(ObjectIndex) = mid$(selected$,4)                    'put selected object into object combobox list

                                                                    'get RA in HH.DDDD format
        RAArray(ObjectIndex) =  val(SDitem$(DataIndex,3)) +_
                                val(SDitem$(DataIndex,4))/60 + val(SDitem$(DataIndex,5))/3600
        RAArray(ObjectIndex) =  RAArray(ObjectIndex) * 15           'convert RA in hours to RA in degrees, 0 to 359.9999
                                                                    'get DEC in DD.DDDD format, -90.0000 to +90.0000
        DECArray(ObjectIndex) = abs(val(right$(SDitem$(DataIndex,6),2))) +_
                                val(SDitem$(DataIndex,7))/60 + val(SDitem$(DataIndex,8))/3600
                                                                    'see if minus sign is in the degree string and make DEC
                                                                    'negative is so, this is needed in case DECd = -0
        if left$(SDitem$(DataIndex,6),1) = "-" then
                DECArray(ObjectIndex) = DECArray(ObjectIndex) * -1
        end if

        ObjectIndexMax = ObjectIndex

        CatalogStars$(DataIndex) = "X  "+SDitem$(DataIndex,1)       'put an X in front of the picked Catalog object
        print #catalogStars.list1, "reload"
                                                                    'select the Catalog, C,V,S or T
        Select Case
            Case  (SelectedCatalog$ = "SOE Data Version 2.txt") OR (SelectedCatalog$ = "SOE Data Version 2 Sloan.txt")
                TypeArray$(ObjectIndex) = "S"
            Case  (SelectedCatalog$ = "Transformation Data Version 2.txt") OR (SelectedCatalog$ = "Transformation Data Version 2 Sloan.txt")
                TypeArray$(ObjectIndex) = "T"
            Case  (SelectedCatalog$ = "Star Data Version 2.txt") OR (SelectedCatalog$ = "Star Data Version 2 Sloan.txt")
                TypeArray$(ObjectIndex) = SDitem$(DataIndex,2)
            Case Else
                notice "Catalog is missing"
                wait
        End Select
        print #main.textbox4, "catalog star "+mid$(selected$,4)+" entered"
    Wait

    [Select_All_Object.click]

        gosub [Select_All_Objects]

        for DataIndex = 1 to DataIndexMax
            CatalogStars$(DataIndex) = "X  "+SDitem$(DataIndex,1)   'put an X in front of all the Catalog objects
        next
        print #catalogStars.list1, "reload"
        print #main.textbox4, "all catalog stars entered"
    Wait

    [Select_Clear_Object.click]

        gosub [Reset_Object_Combobox]

        redim TypeArray$(400)
        redim RAArray(400)                'object RA in degrees, index is ObjectIndex
        redim DECArray(400)

        for DataIndex = 1 to DataIndexMax
            CatalogStars$(DataIndex) = "   "+SDitem$(DataIndex,1)
        next
        print #catalogStars.list1, "reload"
        print #main.textbox4, "catalog stars cleared"
    Wait

    [quit_catalog_stars]
        close #catalogStars
return
'
'========subroutines for SELECT_CATALOG_STARS
'
[Load_Catalog_Stars]
    open SelectedCatalog$ for input as #StarData
        DataIndex = 0
        while eof(#StarData) = 0
            DataIndex = DataIndex + 1
            input #StarData,SDitem$(DataIndex,1),_      'comp or var star name
                            SDitem$(DataIndex,2),_      'type, either C or V, spectral type
                            SDitem$(DataIndex,3),_      'RA hour
                            SDitem$(DataIndex,4),_      'RA minute
                            SDitem$(DataIndex,5),_      'RA second
                            SDitem$(DataIndex,6),_      'DEC degree
                            SDitem$(DataIndex,7),_      'DEC minute
                            SDitem$(DataIndex,8),_      'DEC second
                            SDitem$(DataIndex,9),_      'V magnitude, ##.##
                            SDitem$(DataIndex,10),_     'B-V index, ##.##
                            SDitem$(DataIndex,11),_     'U-B index, ##.##
                            SDitem$(DataIndex,12),_     'V-R index, ##.##
                            SDitem$(DataIndex,13)       'V-I index, ##.##

        wend
        DataIndexMax = DataIndex
    close #StarData

    for DataIndex = 1 to DataIndexMax
        CatalogStars$(DataIndex) = "   "+SDitem$(DataIndex,1)
    next
return
'
[Select_All_Objects]
        ObjectIndexMax = ObjectIndexMax + DataIndexMax

        For ObjectIndex = 6 to ObjectIndexMax                       'put all the Catalog objects into the object combox list
            Combo6$(ObjectIndex) = mid$(CatalogStars$(ObjectIndex - 5),4)   'get object names

            Select Case                                     'get catalog types
                Case (SelectedCatalog$ = "SOE Data Version 2.txt") OR (SelectedCatalog$ = "SOE Data Version 2 Sloan.txt")
                    TypeArray$(ObjectIndex) = "S"
                Case (SelectedCatalog$ = "Transformation Data Version 2.txt") OR (SelectedCatalog$ = "Transformation Data Version 2 Sloan.txt")
                    TypeArray$(ObjectIndex) = "T"
                Case (SelectedCatalog$ = "Star Data Version 2.txt") OR (SelectedCatalog$ = "Star Data Version 2 Sloan.txt")
                    TypeArray$(ObjectIndex) = SDitem$(ObjectIndex - 5,2)
                 Case Else
                    notice "Catalog is missing"
                    wait
            End Select

            RAArray(ObjectIndex) =  val(SDitem$(ObjectIndex - 5,3)) +_
                                    val(SDitem$(ObjectIndex - 5,4))/60 + val(SDitem$(ObjectIndex - 5,5))/3600
            RAArray(ObjectIndex) =  RAArray(ObjectIndex) * 15       'convert RA in hours to RA in degrees
                                                                    'get DEC in DD.DDDD format
            DECArray(ObjectIndex) = abs(val(right$(SDitem$(ObjectIndex - 5,6),2))) +_
                                    val(SDitem$(ObjectIndex - 5,7))/60 + val(SDitem$(ObjectIndex - 5,8))/3600
                                                                    'see if minus sign is in the degree string and make DEC
                                                                    'negative is so, this is needed in case DECd = -0
            if left$(SDitem$(ObjectIndex - 5,6),1) = "-" then
                DECArray(ObjectIndex) = DECArray(ObjectIndex) * -1
            end if
        next
        print #main.combo6, "reload"
return
'
'
'========Script Routines
'
[MAKE_SCRIPT]

    if TrialVersion = 1 then
        notice "not available in this version"
        goto [timeloop]
    end if

    if ScriptHold = 1 then
        notice "exit script first"
        goto [WAIT_FOR_CONTINUE]
    end if

    NOMAINWIN
    WindowWidth = 321 : WindowHeight = 750
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)
    Menu        #script, "File" , "Exit", [Quit_Script], "Make/Save Script", [MakeScript]

        groupbox #script.type, "Observation Procedure", 10,5,294,100
        radiobutton #script.quickobs, "Quick", [setQuick], [resetObs], 20,22,60,20
        radiobutton #script.standardobs, "Standard", [setStandard], [resetObs], 20,50,100,20
        radiobutton #script.continuousobs, "Continuous", [setCont], [resetObs], 20,77,100,20
        radiobutton #script.extinction, "Extinction", [setExtinction], [resetObs], 85,22,100,20
        radiobutton #script.SOE, "SOE", [setSOE], [resetObs], 190,22,44,20
        radiobutton #script.FOE, "FOE", [setFOE], [resetObs], 190,50,44,20
        radiobutton #script.Trans. "Trans", [setTrans], [resetObs], 239,22,60,20
        statictext #script.cyclelabel, "cycles (5 to 25)", 169,77,130,20
        textbox #script.cycles, 130,76,35,20

        groupbox #script.stars, "Stars", 10,110,294,185
        statictext #script.comparisontext, "Comparison",   135,132,100,20
        textbox #script.comparison,                  15,130,110,22   'comparison star/SOE blue/Trans1

        statictext #script.variabletext, "Variable",     135,158,100,20
        textbox #script.variable,                   15,156,110,22   'variable star/Soe red/Trans1

        statictext #script.trans3text, "Check",     135,186,100,20
        textbox #script.trans3,                     15,184,110,22   'trans3

        statictext #script.trans4text, "",          135,214,100,20
        textbox #script.trans4,                     15,212,110,22   'trans4

        statictext #script.trans5text, "",          135,242,100,20
        textbox #script.trans5,                     15,240,110,22   'trans5

        checkbox #script.Catalog, " Load Catalog", [setCatalog], [resetCatalog], 112,270,140,20

        if FilterSystem$ = "1" then
            groupbox #script.filters, "Johnson/Cousins Filters", 10,300,294,45
            checkbox #script.filterU, "U", [setFilterU], [resetFilterU], 40,320,40,20
            checkbox #script.filterB, "B", [setFilterB], [resetFilterB], 90,320,40,20
            checkbox #script.filterV, "V", [setFilterV], [resetFilterV], 140,320,40,20
            checkbox #script.filterR, "R", [setFilterR], [resetFilterR], 190,320,40,20
            checkbox #script.filterI, "I", [setFilterI], [resetFilterI], 240,320,40,20
        else
            groupbox #script.filters, "Sloan Filters", 10,300,294,45
            checkbox #script.filterU, "u'", [setFilterU], [resetFilterU], 40,320,40,20
            checkbox #script.filterB, "g'", [setFilterB], [resetFilterB], 90,320,40,20
            checkbox #script.filterV, "r'", [setFilterV], [resetFilterV], 140,320,40,20
            checkbox #script.filterR, "i'", [setFilterR], [resetFilterR], 190,320,40,20
            checkbox #script.filterI, "z'", [setFilterI], [resetFilterI], 240,320,40,20
        end if

        groupbox #script.gain, "Gain", 10,350,294,45
        radiobutton #script.gain1, "1", [setGain1], [resetGain], 50,370,40,20
        radiobutton #script.gain10, "10", [setGain10], [resetGain], 130,370,40,20
        radiobutton #script.gain100, "100", [setGain100], [resetGain], 210,370,45,20

        groupbox #script.integ, "Integration", 10,400,294,45
        radiobutton #script.integ1, "1.00", [setInteg1], [resetInteg], 50,420,50,20
        radiobutton #script.integ5, "5.00", [setInteg5], [resetInteg], 130,420,60,20
        radiobutton #script.integ10, "10.00", [setInteg10], [resetInteg], 210,420,60,20

        groupbox #script.interval, "Interval", 10,450,294,45
        radiobutton #script.interval1, "1", [setInterval1], [resetInterval], 50,470,40,20
        radiobutton #script.interval2, "2", [setInterval2], [resetInterval], 110,470,40,20
        radiobutton #script.interval3, "3", [setInterval3], [resetInterval], 170,470,40,20
        radiobutton #script.interval4, "4", [setInterval4], [resetInterval], 230,470,40,20

        groupbox #script.sky, "Sky Position", 10, 500, 294, 90
        textbox #script.RAhour, 15,520,30,22
        textbox #script.RAmin, 50,520,30,22
        textbox #script.RAsec, 85,520,30,22
        statictext #script.RA, "RA hr-min-sec", 125,525,150,20
        textbox #script.DECdeg, 15,550,30,22
        textbox #script.DECmin, 50,550,30,22
        textbox #script.DECsec, 85,550,30,22
        statictext #script.DEC, "DEC deg-min-sec", 125,555,160,20

        groupbox #script.skyinterval, "Sky Interval", 10,595,294,45
        radiobutton #script.skyinterval1, "1", [setSkyInterval1], [resetSkyInterval], 50,615,40,20
        radiobutton #script.skyinterval2, "2", [setSkyInterval2], [resetSkyInterval], 110,615,40,20
        radiobutton #script.skyinterval3, "3", [setSkyInterval3], [resetSkyInterval], 170,615,40,20
        radiobutton #script.skyinterval4, "4", [setSkyInterval4], [resetSkyInterval], 230,615,40,20

        button #script.start, "Make/Save Script", [MakeScript], UL, 90,650,140,30

    Open "Make Script File" for Window as #script
        #script "trapclose [Quit_Script]"
        #script "font courier_new 8 16"

        print #script.filterV, "set"
        print #script.filterB, "set"
        print #script.gain10, "set"
        print #script.integ10, "set"
        print #script.interval3, "set"
        print #script.skyinterval3, "set"
        print #script.standardobs, "set"

        ScriptFlag = 1
                                                'default settings for making script
        if FilterSystem$ = "1" then
            Filter$(3) = "V"
            Filter$(2) = "B"
        else
            Filter$(3) = "r"
            Filter$(2) = "g"
        end if
        Gain$ = "10"
        Integ$ = "10.00"
        Interval$ = "3"
        SkyInterval$ = "3"
        Procedure = 2
        cycleindex = 0
        UseCatalog = 0
        MaximFlag = 0
        print #script.cycles, "!disable"
        print #script.cyclelabel, "!disable"
        print #script.trans4, "!disable"
        print #script.trans5, "!disable"
    wait

    [setQuick]
        Procedure = 1
        Gain$ = "10"
        Integ$ = "10.00"
        Interval$ = "3"
        SkyInterval$ = "2"
        if FilterSystem$ = "1" then
            Filter$(3) = "V"
            Filter$(2) = "B"
        else
            Filter$(3) = "r"
            Filter$(2) = "g"
        end if
        gosub [disableEverything]
        gosub [Reset_All_Script_Buttons]
        print #script.variable, "!enable"
        print #script.comparisontext, "Comparison"
        print #script.variabletext, "Variable"
        print #script.cycles, ""
        print #script.cycles, "!disable"
        print #script.cyclelabel, "!disable"
        print #script.filterU, "enable"
        print #script.filterB, "enable"
        print #script.filterV, "enable"
        print #script.filterR, "enable"
        print #script.filterI, "enable"
        print #script.filterB, "set"
        print #script.filterV, "set"
        print #script.integ10, "set"
        print #script.interval3, "set"
        print #script.skyinterval2, "set"
        print #script.gain10, "set"
    wait

    [setStandard]
        Procedure = 2
        Gain$ = "10"
        Integ$ = "10.00"
        Interval$ = "3"
        SkyInterval$ = "3"
        if FilterSystem$ = "1" then
            Filter$(3) = "V"
            Filter$(2) = "B"
        else
            Filter$(3) = "r"
            Filter$(2) = "g"
        end if
        gosub [disableEverything]
        gosub [Reset_All_Script_Buttons]
        print #script.variable, "!enable"
        print #script.comparison, "!enable"
        print #script.comparisontext, "Comparison"
        print #script.variabletext, "Variable"
        print #script.trans3, "!enable"
        print #script.trans3text, "Check"
        print #script.cycles, ""
        print #script.cycles, "!disable"
        print #script.cyclelabel, "!disable"
        print #script.filterU, "enable"
        print #script.filterB, "enable"
        print #script.filterV, "enable"
        print #script.filterR, "enable"
        print #script.filterI, "enable"
        print #script.filterB, "set"
        print #script.filterV, "set"
        print #script.integ10, "set"
        print #script.interval3, "set"
        print #script.skyinterval3, "set"
        print #script.gain10, "set"
    wait

    [setCont]
        Procedure = 3
        Gain$ = "10"
        Integ$ = "10.00"
        Interval$ = "3"
        SkyInterval$ = "2"
        if FilterSystem$ = "1" then
            Filter$(3) = "V"
            Filter$(2) = "B"
        else
            Filter$(3) = "r"
            Filter$(2) = "g"
        end if
        gosub [disableEverything]
        gosub [Reset_All_Script_Buttons]
        print #script.variable, "!enable"
        print #script.comparison, "!enable"
        print #script.comparisontext, "Comparison"
        print #script.variabletext, "Variable"
        print #script.cycles, "!enable"
        print #script.cyclelabel, "!enable"
        print #script.cycles, "10"
        print #script.filterU, "enable"
        print #script.filterB, "enable"
        print #script.filterV, "enable"
        print #script.filterR, "enable"
        print #script.filterI, "enable"
        print #script.filterB, "set"
        print #script.filterV, "set"
        print #script.integ10, "set"
        print #script.interval3, "set"
        print #script.skyinterval2, "set"
        print #script.gain10, "set"
    wait

    [setSOE]
        Procedure = 4
        Gain$ = "10"
        Integ$ = "10.00"
        Interval$ = "4"
        SkyInterval$ = "3"
        if FilterSystem$ = "1" then
            Filter$(3) = "V"
            Filter$(2) = "B"
        else
            Filter$(3) = "r"
            Filter$(2) = "g"
        end if
        gosub [disableEverything]
        gosub [Reset_All_Script_Buttons]
        print #script.variable, "!enable"
        print #script.comparison, "!enable"
        print #script.filterB, "enable"
        print #script.filterV, "enable"
        print #script.comparisontext, "SOE blue star"
        print #script.variabletext, "SOE red star"
        print #script.filterB, "set"
        print #script.filterV, "set"
        print #script.integ10, "set"
        print #script.interval4, "set"
        print #script.skyinterval3, "set"
        print #script.gain10, "set"
    wait


    [setFOE]
        Procedure = 7
        Gain$ = "10"
        Integ$ = "10.00"
        Interval$ = "3"
        SkyInterval$ = "3"
        if FilterSystem$ = "1" then
            Filter$(3) = "V"
            Filter$(2) = "B"
        else
            Filter$(3) = "r"
            Filter$(2) = "g"
        end if
        gosub [disableEverything]
        gosub [Reset_All_Script_Buttons]
        print #script.variable, "!enable"
        print #script.comparison, "!enable"
        print #script.comparisontext, "FOE 1"
        print #script.variabletext, "FOE 2"
        print #script.trans3text, "FOE 3"
        print #script.trans4text, "FOE 4"
        print #script.trans5text, "FOE 5"
        print #script.filterB, "enable"
        print #script.filterV, "enable"
        print #script.trans3, "!enable"
        print #script.trans4, "!enable"
        print #script.trans5, "!enable"
        print #script.filterB, "set"
        print #script.filterV, "set"
        print #script.integ10, "set"
        print #script.interval3, "set"
        print #script.skyinterval3, "set"
        print #script.gain10, "set"
    wait

    [setTrans]
        Procedure = 5
        Gain$ = "10"
        Integ$ = "10.00"
        Interval$ = "3"
        SkyInterval$ = "3"
        if FilterSystem$ = "1" then
            Filter$(3) = "V"
            Filter$(2) = "B"
        else
            Filter$(3) = "r"
            Filter$(2) = "g"
        end if
        gosub [disableEverything]
        gosub [Reset_All_Script_Buttons]
        print #script.variable, "!enable"
        print #script.comparison, "!enable"
        print #script.comparisontext, "Trans 1"
        print #script.variabletext, "Trans 2"
        print #script.trans3text, "Trans 3"
        print #script.trans4text, "Trans 4"
        print #script.trans5text, "Trans 5"
        print #script.filterU, "enable"
        print #script.filterB, "enable"
        print #script.filterV, "enable"
        print #script.filterR, "enable"
        print #script.filterI, "enable"
        print #script.trans3, "!enable"
        print #script.trans4, "!enable"
        print #script.trans5, "!enable"
        print #script.filterB, "set"
        print #script.filterV, "set"
        print #script.integ10, "set"
        print #script.interval3, "set"
        print #script.skyinterval3, "set"
        print #script.gain10, "set"
    wait

    [setExtinction]
        Procedure = 6
        Gain$ = "10"
        Integ$ = "5.00"
        Interval$ = "3"
        SkyInterval$ = "1"
        if FilterSystem$ = "1" then
            Filter$(3) = "V"
            Filter$(2) = "B"
        else
            Filter$(3) = "r"
            Filter$(2) = "g"
        end if
        gosub [disableEverything]
        gosub [Reset_All_Script_Buttons]
        print #script.comparison, "!enable"
        print #script.comparisontext, "Comparison"
        print #script.variable, "!disable"
        print #script.filterU, "enable"
        print #script.filterB, "enable"
        print #script.filterV, "enable"
        print #script.filterR, "enable"
        print #script.filterI, "enable"
        print #script.filterB, "set"
        print #script.filterV, "set"
        print #script.integ5, "set"
        print #script.interval3, "set"
        print #script.skyinterval1, "set"
        print #script.gain10, "set"
    wait

    [setCatalog]
        UseCatalog = 1
    wait

    [resetCatalog]
        UseCatalog = 0
    wait

    [resetObs]

    wait

    [setFilterU]
        if FilterSystem$ = "1" then
            Filter$(1) = "U"
        else
            Filter$(1) = "u"
        end if
    wait

    [setFilterB]
        if FilterSystem$ = "1" then
            Filter$(1) = "B"
        else
            Filter$(1) = "g"
        end if
    wait

    [setFilterV]
        if FilterSystem$ = "1" then
            Filter$(1) = "V"
        else
            Filter$(1) = "r"
        end if
    wait

    [setFilterR]
        if FilterSystem$ = "1" then
            Filter$(1) = "R"
        else
            Filter$(1) = "i"
        end if
    wait

    [setFilterI]
        if FilterSystem$ = "1" then
            Filter$(1) = "I"
        else
            Filter$(1) = "z"
        end if
    wait

    [resetFilterU]
        Filter$(1) = ""
    wait

    [resetFilterB]
        Filter$(2) = ""
    wait

    [resetFilterV]
        Filter$(3) = ""
    wait

    [resetFilterR]
        Filter$(4) = ""
    wait

    [resetFilterI]
        Filter$(1) = ""
    wait

    [setGain1]
        Gain$ = "1"
    wait

    [setGain10]
        Gain$ = "10"
    wait

    [setGain100]
        Gain$ = "100"
    wait

    [resetGain]

    wait

    [setInteg1]
        Integ$ = "1.00"
    wait

    [setInteg5]
        Integ$ = "5.00"
    wait

    [setInteg10]
        Integ$ = "10.00"
    wait

    [resetInteg]

    wait

    [setInterval1]
        Interval$ = "1"
    wait

    [setInterval2]
        Interval$ = "2"
    wait

    [setInterval3]
        Interval$ = "3"
    wait

    [setInterval4]
        Interval$ = "4"
    wait

    [resetInterval]
    wait

    [setSkyInterval1]
        SkyInterval$ = "1"
    wait

    [setSkyInterval2]
        SkyInterval$ = "2"
    wait

    [setSkyInterval3]
        SkyInterval$ = "3"
    wait

    [setSkyInterval4]
        SkyInterval$ = "4"
    wait

    [resetSkyInterval]
    wait

    [Quit_Script]
        close #script
        ScriptFlag = 0
    goto [timeloop]
'
'==========make the script filename.ssp
'
    [MakeScript]
                                        'get star names
        print #script.comparison, "!contents? Comp$";
        print #script.variable, "!contents? Var$";
        print #script.trans3, "!contents? Trans3$";
        print #script.trans4, "!contents? Trans4$";
        print #script.trans5, "!contents? Trans5$";
        Comp$   = upper$(Comp$)         'Comp|SOE blue|Trans1
        Var$    = upper$(Var$)          'Var|SOE red|Trans2
        Trans3$ = upper$(Trans3$)       'Trans3 or Check star
        Trans4$ = upper$(Trans4$)
        Trans5$ = upper$(Trans5$)

                                        'get the SKY coordinates and convert to degrees
        print #script.RAhour, "!contents? SkyRAhour$";
        print #script.RAmin, "!contents? SkyRAmin$";
        print #script.RAsec,  "!contents? SkyRAsec$";
        print #script.DECdeg, "!contents? SkyDECdeg$";
        print #script.DECmin, "!contents? SkyDECmin$";
        print #script.DECsec, "!contents? SkyDECsec$";
        SkyRA =  (val(SkyRAhour$) + val(SkyRAmin$)/60 + val(SkyRAsec$)/3600) * 15
        SkyRA$ = using("###.######", SkyRA)
        SkyDEC = abs(val(SkyDECdeg$)) + val(SkyDECmin$)/60 + val(SkyDECsec$)/3600
        if left$(SkyDECdeg$,1) = "-" then
            SkyDEC = SkyDEC * -1
        end if
        SkyDEC$ = using("###.######", SkyDEC)

                                         'get cycle number and check range
        if Procedure = 3 then
            print #script.cycles, "!contents? cycles$";
            cycles = val(cycles$)
            if (cycles > 25) OR (cycles < 5) then
                notice "cycles not in range"
                wait
            end if
        end if
'-----------------------------start writing script with inital control values
        Script$(1) = "GAIN,"+Gain$
        Script$(2) = "INTEGRATION,"+Integ$
        Script$(3) = "COUNT,SLOW"
        J = 3
'-------------------------------write SKY coordinates if any
        if SkyRA <> 0 or SkyDEC <> 0 then
            J = J + 1
            Script$(J) = "SKYRA,"+SkyRA$
            J = J + 1
            Script$(J) = "SKYDEC,"+SkyDEC$ 
        end if
'-------------------------------load catalog
        if UseCatalog = 1 then
            SELECT CASE
                CASE (Procedure = 1) OR (Procedure = 2) OR (Procedure = 3) OR (Procedure = 6)
                    if FilterSystem$ = "1" then
                        SelectedCatalog$ = "Star Data Version 2.txt"
                    else
                        SelectedCatalog$ = "Star Data Version 2 Sloan.txt"
                    end if
                CASE Procedure = 4
                    if FilterSystem$ = "1" then
                        SelectedCatalog$ = "SOE Data Version 2.txt"
                    else
                        SelectedCatalog$ = "SOE Data Version 2 Sloan.txt"
                    end if
                CASE Procedure = 5
                    if FilterSystem$ = "1" then
                        SelectedCatalog$ = "Transformation Data Version 2.txt"
                    else
                        SelectedCatalog$ = "Transformation Data Version 2 Sloan.txt"
                    end if
                CASE Procedure = 7
                    if FilterSystem$ = "1" then
                        SelectedCatalog$ = "FOE Data Version 2.txt"
                    else
                        SelectedCatalog$ = "FOE Data Version 2 Sloan.txt"
                    end if
            END SELECT
            J = J + 1
            Script$(J) = "LOADCATALOG,"+SelectedCatalog$
        else
            SELECT CASE
                CASE (Procedure = 1) OR (Procedure = 2) OR (Procedure = 3) OR (Procedure = 4)
                    if Comp$ <> "" then                     'skip if doing AllSky
                        J = J + 1
                        Script$(J) = "LOAD,"+Comp$
                    end if
                    J = J + 1
                    Script$(J) = "LOAD,"+Var$
                CASE (Procedure = 5) OR (Procedure = 7)
                    J = J + 1
                    Script$(J) = "LOAD,"+Comp$
                    J = J + 1
                    Script$(J) = "LOAD,"+Var$ 
                    if Trans3$ <> "" then
                        J = J + 1
                        Script$(J) = "LOAD,"+Trans3$ 
                    end if
                    if Trans4$ <> "" then
                        J = J + 1
                        Script$(J) = "LOAD,"+Trans4$
                    end if
                    if Trans5$ <> "" then
                        J = J + 1
                        Script$(J) = "LOAD,"+Trans5$
                    end if
                CASE (Procedure = 6)
                    J = J + 1
                    Script$(J) = "LOAD,"+Comp$
                END SELECT
        end if
'
'---------------------------------skynext
        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "VIEW"
        end if
        J = J + 1
        Script$(J) = "INTERVAL,"+SkyInterval$
        J = J + 1
        Script$(J) = "OBJECT,SKYNEXT"
        J = J + 1
        Script$(J) = "NOTICE,TARGET SKY"
        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "RECORD"
        end if
        J =  J + 1
        For I = 1 to 5
            if Filter$(I) <>  "" then
                Script$(J) = "FILTER,"+Filter$(I)
                Script$(J+1) = "START"
                J = J + 2
            end if
        next
        Script$(J) = "INTERVAL,"+Interval$
        J = J + 1
'-------------------------------comp
        if Comp$ = "" AND Procedure = 2 then [Skip_Comp_1]  'if no Comp, skip this section - All Sky
            Select Case
                case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3) or (Procedure = 6)
                    Script$(J) = "CATALOG,COMP"
                case (Procedure = 4)
                    Script$(J) = "CATALOG,SOE"
                case (Procedure = 5)
                    Script$(J) = "CATALOG,TRANS"
                case (Procedure = 7)
                    Script$(J) = "CATALOG,FOE"
            end select
            J = J + 1
            Script$(J) = "OBJECT,"+Comp$
            if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
                J = J + 1
                Script$(J) = "VIEW"
            end if
            J = J + 1
            Script$(J) = "NOTICE,TARGET "+Comp$
            if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
                J = J + 1
                Script$(J) = "RECORD"
            end if
            J = J + 1
            For I = 1 to 5
                if Filter$(I) <> "" then
                    Script$(J) = "FILTER,"+Filter$(I)
                    Script$(J+1) = "START"
                    J = J + 2
                end if
            next
        [Skip_Comp_1]
        Call Pause 1
'------------------------------if Procedure = 3 return to this point
        [CycleStart]
        if Procedure = 3 then
            cycleindex = cycleindex + 1
        end if
'------------------------------if Procedure = 6 (extinction) goto SKYLAST
        if Procedure = 6 then
            goto [Script_SKYLAST]
        end if
'------------------------------var
        Select Case
            case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                Script$(J) = "CATALOG,VAR"
            case (Procedure = 4)
                Script$(J) = "CATALOG,SOE"
            case (Procedure = 5)
                Script$(J) = "CATALOG,TRANS"
            case (Procedure = 7)
                Script$(J) = "CATALOG,FOE"
        end select
        J = J + 1
        Script$(J) = "OBJECT,"+Var$
        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "VIEW"
        end if
        J = J + 1
        Script$(J) = "NOTICE,TARGET "+Var$
        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "RECORD"
        end if
        J = J + 1
        For I = 1 to 5
            if Filter$(I) <> "" then
                Script$(J) = "FILTER,"+Filter$(I)
                Script$(J+1) = "START"
                J = J + 2
            end if
        next
'-----------------------------if procedure = 4 or 1 then do SKYLAST and END
        if (Procedure = 4) OR (Procedure = 1) then
            goto [Script_SKYLAST]
        end if
'-----------------------------if procedure = 2 then do VAR again
        if Procedure = 2 then
            For I = 1 to 5
                if Filter$(I) <> "" then
                    Script$(J) = "FILTER,"+Filter$(I)
                    Script$(J+1) = "START"
                    J = J + 2
                end if
            next
        end if
'-----------------------------if procedure = 2 and check star entered
        if Procedure = 2 AND Trans3$ <> "" then
            Script$(J) = "CATALOG,Q'CHECK"
            J = J + 1
            Script$(J) = "OBJECT,"+Trans3$
            J = J + 1
            Script$(J) = "NOTICE,TARGET "+Trans3$
            J = J + 1
            For I = 1 to 5
                if Filter$(I) <> "" then
                    Script$(J) = "FILTER,"+Filter$(I)
                    Script$(J+1) = "START"
                    J = J + 2
                end if
            next
        end if
'-----------------------------comp
        if Comp$ = "" AND Procedure = 2 then  [Skip_Comp_2]       'skip Comp and SKY if doing AllSky
        Select Case
            case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                Script$(J) = "CATALOG,COMP"
            case (Procedure = 4)
                Script$(J) = "CATALOG,SOE"
            case (Procedure = 5)
                Script$(J) = "CATALOG,TRANS"
            case (Procedure = 7)
                    Script$(J) = "CATALOG,FOE"
        end select
        J = J + 1

        Select Case
            case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                Script$(J) = "OBJECT,"+Comp$
            case (Procedure = 5) OR (Procedure = 7)
                Script$(J) = "OBJECT,"+Trans3$ 
        end select

        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "VIEW"
        end if
        J = J + 1

        Select Case
            case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                Script$(J) = "NOTICE,TARGET "+Comp$
            case (Procedure = 5) OR (Procedure = 7)
                Script$(J) = "NOTICE,TARGET "+Trans3$ 
        end select

        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "RECORD"
        end if
        J = J + 1
        For I = 1 to 5
            if Filter$(I) <> "" then
                Script$(J) = "FILTER,"+Filter$(I)
                Script$(J+1) = "START"
                J = J + 2
            end if
        next
'------------------------------sky
        if Procedure <> 7 then
            Script$(J) = "INTERVAL,"+SkyInterval$
            J = J + 1
            Script$(J) = "OBJECT,SKY"
            if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
                J = J + 1
                Script$(J) = "VIEW"
            end if
            J = J + 1
            Script$(J) = "NOTICE, TARGET SKY"
            if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
                J = J + 1
                Script$(J) = "RECORD"
            end if
            J = J + 1
            For I = 1 to 5
                if Filter$(I) <> "" then
                    Script$(J) = "FILTER,"+Filter$(I)
                    Script$(J+1) = "START"
                    J = J + 2
                end if
            next
            Script$(J) = "INTERVAL,"+Interval$
            J = J + 1
        end if
'-----------------------------var
        Select Case
            case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                Script$(J) = "CATALOG,VAR"
            case (Procedure = 4)
                Script$(J) = "CATALOG,SOE"
            case (Procedure = 5)
                Script$(J) = "CATALOG,TRANS"
            case (Procedure = 7)
                Script$(J) = "CATALOG,FOE"
        end select
        J = J + 1

        Select Case
            case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                Script$(J) = "OBJECT,"+Var$
            case (Procedure = 5) OR (Procedure = 7)
                Script$(J) = "OBJECT,"+Trans4$ 
        end select

        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "VIEW"
        end if
        J = J + 1

        Select Case
            case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                Script$(J) = "NOTICE,TARGET "+Var$
            case (Procedure = 5) OR (Procedure = 7)
                Script$(J) = "NOTICE,TARGET "+Trans4$ 
        end select

        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "RECORD"
        end if
        J = J + 1

        [Skip_Comp_2]

        For I = 1 to 5
            if Filter$(I) <> "" then
                Script$(J) = "FILTER,"+Filter$(I)
                Script$(J+1) = "START"
                J = J + 2
            end if
        next
'-----------------------------if Procedure = 2 then do VAR again
        if Procedure = 2 then
            For I = 1 to 5
                if Filter$(I) <> "" then
                    Script$(J) = "FILTER,"+Filter$(I)
                    Script$(J+1) = "START"
                    J = J + 2
                end if
            next
        end if
'-----------------------------if procedure = 2 and check star entered
        if Procedure = 2 AND Trans3$ <> "" then
            Script$(J) = "CATALOG,Q'CHECK"
            J = J + 1
            Script$(J) = "OBJECT,"+Trans3$
            J = J + 1
            Script$(J) = "NOTICE,TARGET "+Trans3$
            J = J + 1
            For I = 1 to 5
                if Filter$(I) <> "" then
                    Script$(J) = "FILTER,"+Filter$(I)
                    Script$(J+1) = "START"
                    J = J + 2
                end if
            next
        end if
'-----------------------------comp
        if Comp$ = "" AND Procedure = 2 then  [Skip_Comp_3]            'skip Comp if doing All Sky
            Select Case
                case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                    Script$(J) = "CATALOG,COMP"
                case (Procedure = 4)
                    Script$(J) = "CATALOG,SOE"
                case (Procedure = 5)
                    Script$(J) = "CATALOG,TRANS"
                case (Procedure = 7)
                    Script$(J) = "CATALOG,FOE"
            end select
            J = J + 1

            Select Case
                case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                    Script$(J) = "OBJECT,"+Comp$
                case (Procedure = 5) or (Procedure = 7)
                    Script$(J) = "OBJECT,"+Trans5$ 
            end select

            if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
                J = J + 1
                Script$(J) = "VIEW"
            end if
            J = J + 1

            Select Case
                case (Procedure = 1) or (Procedure = 2)  or (Procedure = 3)
                    Script$(J) = "NOTICE,TARGET "+Comp$
                case (Procedure = 5) OR (Procedure = 7)
                    Script$(J) = "NOTICE,TARGET "+Trans5$ 
            end select

            if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
                J = J + 1
                Script$(J) = "RECORD"
            end if
            J = J + 1
            For I = 1 to 5
                if Filter$(I) <> "" then
                    Script$(J) = "FILTER,"+Filter$(I)
                    Script$(J+1) = "START"
                    J = J + 2
                end if
            next
        [Skip_Comp_3]
'---------------------------if Procedure = 3, return to [CycleStart]
        if Procedure = 3 then
            if cycleindex = cycles then
                cycleindex = 0
                goto [Script_SKYLAST]
            else
                goto [CycleStart]
            end if
        end if
'---------------------------skylast
        [Script_SKYLAST]
        Script$(J) = "INTERVAL,"+SkyInterval$
        J = J + 1
        Script$(J) = "OBJECT,SKYLAST"
        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "VIEW"
        end if
        J = J + 1
        Script$(J) = "NOTICE, TARGET SKY"
        if AutoMirrorFlag = 1 OR AutoMirrorFlag = 2 then
            J = J + 1
            Script$(J) = "RECORD"
        end if
        J = J + 1
        For I = 1 to 5
            if Filter$(I) <> "" then
                Script$(J) = "FILTER,"+Filter$(I)
                Script$(J+1) = "START"
                J = J + 2
            end if
        next
'----------------------------end
        Script$(J) = "END"
'
'
    [Save_Script]
        filedialog "Save Script File", PathScript$, ScriptFile$
                                            'separate path and file name values
        for I = len(ScriptFile$) to 1 step -1
            if mid$(ScriptFile$,I,1) = "\" then
                ShortScript$ = mid$(ScriptFile$,I+1)
                PathScript$ = left$(ScriptFile$,I)+"*.ssp"
                exit for
            end if
        next

        if ScriptFile$ = "" then [Quit_Save_Script]

        files "c:\", ScriptFile$, info$()
        if val(info$(0, 0)) <> 0 then

            confirm "Write over existing file?"; Answer$
                if Answer$ = "no" then [Save_Script]
        end if

        if right$(ScriptFile$,4) = ".ssp"  OR right$(ScriptFile$,4) = ".SSP" then
            open ScriptFile$ for Output as #ScriptFile
        else
            ScriptFile$ = ScriptFile$+".ssp"
            open ScriptFile$ for Output as #ScriptFile
        end if

        for I = 1 to J
            print #ScriptFile, Script$(I)
        next

        close #ScriptFile

        print #script.start, "SCRIPT SAVED"
        Call Pause 1000
        print #script.start, "Make Script"

    [Quit_Save_Script]

    wait
'
'
END


