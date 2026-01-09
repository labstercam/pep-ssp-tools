'                      Star Data Editor
'                         Optec, Inc.
'
'======version history
'
'V2.56, November, 2015
'   added FOE Catalogs
'   added Select Filter System
'
'V2.53, September, 2015
'   added print catalog
'
'V2.52, September, 2015
'   compiled with LB 4.50
'   increased DIM
'
'V2.50, September 12, 2014
'   added Sloan stars
'
'V2.36, April 18, 2014
'    fixed error in - dec
'
'V2.35, January 19,2014
'    added sort by U-B, V-R and V-I
'    minor format changes
'
'V2.34, October 31, 2013
'    corrected errors in sorting
'    added sort by B-V
'    changed NEW STAR entry
'
'V2.33, October 2013
'    added Q type for check star entry
'
'V2.32, August 2013
'    corrected file name length from 8 to 12 characters
'
'V2.31, May 2013
'    corrected help file call to chm
'
'V2.30, March, 2013
'    added SOE Star Data
'    modified sort commands
'
'V2.00, Sepember, 2007
'   expanded data to include U-B, V-R and V-I indices
'   increased star name size to 12 characters
'
'V1.01, November 1, 2005
'   compiled with Liberty Basic 4.02
'
'V1.00
'
'======initialize star data array
'
DIM info$(10,10)
files "c:\",info$()         'get file infomation about C drive
DIM StarData$(4000)
DIM SDitem$(4000,19)
'
'=======initialize any variables
'
VersionNumber$ = "2.56"
StarDataFile$ = ""
'
'======set up main window
'
[WindowSetup]
    NOMAINWIN
    WindowWidth = 770 : WindowHeight = 377
    UpperLeftX = INT((DisplayWidth-WindowWidth)/2)
    UpperLeftY = INT((DisplayHeight-WindowHeight)/2)

[ControlSetup]
Menu        #DataEdit, "File",          "Open Comp/Var/Check Star Data", [Open_Star_Data],_
                                        "Open Transformation Star Data", [Open_Trans_Data],_
                                        "Open SOE Star Data", [Open_SOE_Data],_
                                        "Open FOE Star Data", [Open_FOE_Data],_
                                        "Save Data File", [Save_Data_File],_
                                        "Print Catalog", [Print_Cat],_
                                        "Quit", [Quit_Data_Editor]

Menu        #DataEdit, "Filter System", "Johnson/Cousins", [Select_Johnson_Cousins],_
                                        "Sloan", [Select_Sloan]

Menu        #DataEdit, "Sort",          "Sort by Name", [Sort_Name],_
                                        "Sort by RA", [Sort_RA],_
                                        "Sort by Type", [Sort_Type],_
                                        "Sort by V/r'", [Sort_V],_
                                        "Sort by B-V/g'-r'", [Sort_BV],_
                                        "Sort by U-B/u'-g'", [Sort_UB],_
                                        "Sort by V-R/r'-i'", [Sort_VR],_
                                        "Sort by V-I/r'-z'", [Sort_VI]

Menu        #DataEdit, "Help", "About", [About], "Help", [Help]

statictext  #DataEdit.statictext1, "Name", 40, 20, 60, 14
statictext  #DataEdit.statictext2, "RA(2000)", 192, 20, 80, 14
statictext  #DataEdit.statictext3, "DEC(2000)", 285, 20, 90, 14
statictext  #DataEdit.statictext4, "V", 410, 20, 20, 14
statictext  #DataEdit.statictext5, "B-V", 470, 20, 45, 14
statictext  #DataEdit.statictext13, "U-B", 542, 20, 45, 14
statictext  #DataEdit.statictext14, "V-R", 614, 20, 45, 14
statictext  #DataEdit.statictext15, "V-I", 687, 20, 45, 14
statictext  #DataEdit.statictext6, "Type", 134, 20, 40, 14
statictext  #DataEdit.statictext7, "h", 178, 239, 10, 14
statictext  #DataEdit.statictext8, "m", 210, 239, 10, 14
statictext  #DataEdit.statictext9, "s", 242, 239, 10, 14
statictext  #DataEdit.statictext10, "d", 285, 239, 10, 14
statictext  #DataEdit.statictext11, "m", 318, 239, 10, 14
statictext  #DataEdit.statictext12, "s", 350, 239, 10, 14

button      #DataEdit.select, "Select Star",[List_Data],UL, 15, 290, 175, 25
button      #DataEdit.new, "Enter New Star",[New_Star.click],UL, 200, 290, 175, 25
button      #DataEdit.delete, "Delete Star ",[Delete_Star.click],UL, 385, 290, 175, 25
button      #DataEdit.save, "Save Changes",[Save_Star.click],UL, 570, 290, 175, 25

textbox     #DataEdit.name, 15, 255, 120, 25
textbox     #DataEdit.type, 140, 255, 21, 25
textbox     #DataEdit.rah, 168, 255, 32, 25
textbox     #DataEdit.ram, 200, 255, 32, 25
textbox     #DataEdit.ras, 232, 255, 32, 25
textbox     #DataEdit.decd, 272, 255, 36, 25
textbox     #DataEdit.decm, 308, 255, 32, 25
textbox     #DataEdit.decs, 340, 255, 32, 25
textbox     #DataEdit.v, 380, 255, 70, 25
textbox     #DataEdit.bv, 458, 255, 60, 25
textbox     #DataEdit.ub, 527, 255, 60, 25
textbox     #DataEdit.vr, 596, 255, 60, 25
textbox     #DataEdit.vi, 665, 255, 60, 25

listbox     #DataEdit.StarData, StarData$(),[List_Data], 15, 40, 732, 195

Open "Star Data Editor  - Johnson/Cousins/Sloan Photometry" for Window as #DataEdit
    #DataEdit "trapclose [Quit_Data_Editor]"
    #DataEdit "font courier_new 10 14"
    FilterSystem$ = "1"
Wait
'
[Quit_Data_Editor]
    if StarDataFile$ <> "" then
        confirm "Have you saved the data file?"+chr$(13)+_
                "Press YES to exit program"; Answer$
        if Answer$ = "no" then
            Wait
        end if
    end if
    close #DataEdit
END
'

[Select_Johnson_Cousins]
    FilterSystem$ = "1"
   ' gosub [Write_Johnson_Filters]
Wait
'
[Select_Sloan]
    FilterSystem$ = "0"
   ' gosub [Write_Sloan_Filters]
Wait
'
[Open_Star_Data]
    if FilterSystem$ = "1" then
        redim StarData$(4000)
        redim SDitem$(4000,19)
        StarDataFile$ = "Star Data Version 2.txt"
        gosub [Open_Data_File]
        print #DataEdit.StarData, "reload"
        gosub [Write_Johnson_Filters]
    else
        redim StarData$(4000)
        redim SDitem$(4000,19)
        StarDataFile$ = "Star Data Version 2 Sloan.txt"
        gosub [Open_Data_File]
        print #DataEdit.StarData, "reload"
        gosub [Write_Sloan_Filters]
    end if
Wait
'
[Open_Trans_Data]
    if FilterSystem$ = "1" then
        redim StarData$(4000)
        redim SDitem$(4000,19)
        StarDataFile$ = "Transformation Data Version 2.txt"
        gosub [Open_Data_File]
        print #DataEdit.StarData, "reload"
        gosub [Write_Johnson_Filters]
    else
        redim StarData$(4000)
        redim SDitem$(4000,19)
        StarDataFile$ = "Transformation Data Version 2 Sloan.txt"
        gosub [Open_Data_File]
        print #DataEdit.StarData, "reload"
        gosub [Write_Sloan_Filters]
    end if
Wait
'
[Open_SOE_Data]
    if FilterSystem$ = "1" then
        redim StarData$(4000)
        redim SDitem$(4000,19)
        StarDataFile$ = "SOE Data Version 2.txt"
        gosub [Open_Data_File]
        print #DataEdit.StarData, "reload"
        gosub [Write_Johnson_Filters]
    else
        redim StarData$(4000)
        redim SDitem$(4000,19)
        StarDataFile$ = "SOE Data Version 2 Sloan.txt"
        gosub [Open_Data_File]
        print #DataEdit.StarData, "reload"
        gosub [Write_Sloan_Filters]
    end if
Wait
'
[Open_FOE_Data]
    if FilterSystem$ = "1" then
        redim StarData$(4000)
        redim SDitem$(4000,19)
        StarDataFile$ = "FOE Data Version 2.txt"
        gosub [Open_Data_File]
        print #DataEdit.StarData, "reload"
        gosub [Write_Johnson_Filters]
    else
        redim StarData$(4000)
        redim SDitem$(4000,19)
        StarDataFile$ = "FOE Data Version 2 Sloan.txt"
        gosub [Open_Data_File]
        print #DataEdit.StarData, "reload"
        gosub [Write_Sloan_Filters]
    end if
Wait
'
[Save_Data_File]
    if StarDataFile$ = "" then
        notice "no opened file to save"
    else
        gosub [Save_File]
        if StarDataFile$ = "Star Data Version 2.txt" then
            notice "Star Data Version 2.txt saved"+chr$(13)+"backup saved as Star Data Version 2.old"
        end if
        if StarDataFile$ = "Star Data Version 2 Sloan.txt" then
            notice "Star Data Version 2 Sloan.txt saved"+chr$(13)+"backup saved as Star Data Version 2 Sloan.old"
        end if
        if StarDataFile$ = "Transformation Data Version 2.txt" then
            notice "Transformation Data Version 2.txt saved"+chr$(13)+"backup saved as Transformation Data Version 2.old"
        end if
        if StarDataFile$ = "Transformation Data Version 2 Sloan.txt" then
            notice "Transformation Data Version 2 Sloan.txt saved"+chr$(13)+"backup saved as Transformation Data Version 2 Sloan.old"
        end if
        if StarDataFile$ = "SOE Data Version 2.txt" then
            notice "SOE Data Version 2.txt saved"+chr$(13)+"backup saved as SOE Data Version 2.old"
        end if
        if StarDataFile$ = "SOE Data Version 2 Sloan.txt" then
            notice "SOE Data Version 2 Sloan.txt saved"+chr$(13)+"backup saved as SOE Data Version 2 Sloan.old"
        end if
        if StarDataFile$ = "FOE Data Version 2.txt" then
            notice "FOE Data Version 2.txt saved"+chr$(13)+"backup saved as FOE Data Version 2.old"
        end if
        if StarDataFile$ = "FOE Data Version 2 Sloan.txt" then
            notice "FOE Data Version 2 Sloan.txt saved"+chr$(13)+"backup saved as FOE Data Version 2 Sloan.old"
        end if
    end if
Wait
'
[Print_Cat]

    If StarDataFile$ = "" then
        notice "Open Database"
    else
        printerdialog
        if PrinterName$ <> "" then
            lprint "    ";left$(StarDataFile$+"                  ",39)
            lprint " "
            if FilterSystem$ = "1" then
                lprint "Name           Type  RA(2000)    DEC(2000)     V       B-V     U-B     V-R     V-I"
            else
                lprint "Name           Type  RA(2000)    DEC(2000      r'      g'-r'   u'-g'   r'-i'   r'-z'"
            end if
            lprint " "

            for DataIndex = 1 to DataIndexMax
                lprint    left$(SDitem$(DataIndex,1)+"            ",12);"   ";_
                          right$("   "+SDitem$(DataIndex,2),1);"     ";_
                          right$("   "+SDitem$(DataIndex,3),2);"h";_
                          right$("   "+SDitem$(DataIndex,4),2);"m";_
                          right$("   "+SDitem$(DataIndex,5),2);"s  ";_
                          right$("   "+SDitem$(DataIndex,6),3);"d";_
                          right$("   "+SDitem$(DataIndex,7),2);"m";_
                          right$("   "+SDitem$(DataIndex,8),2);"s   ";_
                          right$("   "+SDitem$(DataIndex,9),6);"   ";_
                          right$("   "+SDitem$(DataIndex,10),5);"   ";_
                          right$("   "+SDitem$(DataIndex,11),5);"   ";_
                          right$("   "+SDitem$(DataIndex,12),5);"   ";_
                          right$("   "+SDitem$(DataIndex,13),5)
            next
            Dump
        end if
    end if
Wait
'
[About]
    notice "Star Data Editor - Johnson/Cousins/Sloan Photometry"+chr$(13)+_
           "version "+VersionNumber$+chr$(13)+_
           "copyright 2015, Gerald Persha"+chr$(13)+_
           "www.sspdataq.com"
Wait
'
[Help]
    run "hh photometry2.chm"
Wait
'
[Save_Star.click]
    print #DataEdit.name, "!contents? Temporary$";
    if Temporary$ = "" then
        notice "nothing to save"
        wait
    end if

    Temporary$ = upper$(Temporary$)
    FoundItem$ = "N"
    for DataIndex = 1 to DataIndexMax
        if Temporary$ = SDitem$(DataIndex,1) then
            Index = DataIndex
            FoundItem$ = "Y"
            exit for
        end if
    next

    if FoundItem$ = "Y" then
        confirm "save changes to "+Temporary$+" ?";Answer$
        if Answer$ = "yes" then
            Index = DataIndex
        else
            wait
        end if
    else
        confirm "Enter new star "+Temporary$+" ?"; Answer$
        if Answer$ = "yes" then
            Index = DataIndexMax + 1
            DataIndexMax = Index
        else
            wait
        end if
    end if

    print #DataEdit.name, "!contents?"                      'capture star name, 12 characters maximum
    input #DataEdit.name, SDitem$(Index,1)
    SDitem$(Index,1) = left$(upper$(SDitem$(Index,1)),12)

    print #DataEdit.type, "!contents?"
    input #DataEdit.type, SDitem$(Index,2)
    SDitem$(Index,2) = left$(upper$(SDitem$(Index,2)),1)
    if StarDataFile$ = "Star Data Version 2.txt" OR StarDataFile$ = "Star Data Version 2 Sloan.txt" then
        if SDitem$(Index,2) <> "C" AND SDitem$(Index,2) <> "V" AND SDitem$(Index,2) <> "Q" then
            notice "type must be a C, V or Q"
            wait
        end if
    end if

    print #DataEdit.rah, "!contents?"
    input #DataEdit.rah, SDitem$(Index,3)
    Temporary = int(val(SDitem$(Index,3)))
    if Temporary > 24 OR Temporary < 0 then
        notice "RA hour is not a valid entry"
        wait
    end if
    SDitem$(Index,3) = right$("00"+str$(Temporary),2)

    print #DataEdit.ram, "!contents?"
    input #DataEdit.ram, SDitem$(Index,4)
    Temporary = int(val(SDitem$(Index,4)))
    if Temporary > 60 OR Temporary < 0 then
        notice "RA minute is not a valid entry"
        wait
    end if
    SDitem$(Index,4) = right$("00"+str$(Temporary),2)

    print #DataEdit.ras, "!contents?"
    input #DataEdit.ras, SDitem$(Index,5)
    Temporary = int(val(SDitem$(Index,5)))
    if Temporary > 60 OR Temporary < 0 then
        notice "RA second is not a valid entry"
        wait
    end if
    SDitem$(Index,5) = right$("00"+str$(Temporary),2)

    print #DataEdit.decd, "!contents?"
    input #DataEdit.decd, SDitem$(Index,6)
    Temporary = int(val(SDitem$(Index,6)))
    if Temporary >= 90 or Temporary <= -90  then
        notice "DEC degree is not a valid entry"
        wait
    end if
    if left$(SDitem$(Index,6),1) <> "-" then
        SDitem$(Index,6) = right$("00"+str$(Temporary),2)
    else
        Temporary = abs(Temporary)
        SDitem$(Index,6) = "-"+right$("00"+str$(Temporary),2)
    end if

    print #DataEdit.decm, "!contents?"
    input #DataEdit.decm, SDitem$(Index,7)
    Temporary = int(val(SDitem$(Index,7)))
    if Temporary > 60 OR Temporary < 0 then
        notice "DEC minute is not a valid entry"
        wait
    end if
    SDitem$(Index,7) = right$("00"+str$(Temporary),2)

    print #DataEdit.decs, "!contents?"
    input #DataEdit.decs, SDitem$(Index,8)
    Temporary = int(val(SDitem$(Index,8)))
    if Temporary > 60 OR Temporary < 0 then
        notice "DEC second is not a valid entry"
        wait
    end if
    SDitem$(Index,8) = right$("00"+str$(Temporary),2)

    print #DataEdit.v, "!contents?"
    input #DataEdit.v, SDitem$(Index,9)
    Temporary = val(SDitem$(Index,9))
    if Temporary > 20 OR Temporary < -5 then
        if FilterSystem$ = "1" then
            notice "V magnitude is not a valid entry"
        else
            notice "r' magnitude is not a valid entry"
        end if
        wait
    end if
    SDitem$(Index,9) = using("###.##", Temporary)

    print #DataEdit.bv, "!contents?"
    input #DataEdit.bv, SDitem$(Index,10)
    Temporary = val(SDitem$(Index,10))
    if Temporary > 4 OR Temporary < -4 then
        if FilterSystem$ = "1" then
            notice "B-V index is not a valid entry"
        else
            notice "g'-r' index is not a valid entry"
        end if
        wait
    end if
    SDitem$(Index,10) = using("##.##", Temporary)

    print #DataEdit.ub, "!contents?"
    input #DataEdit.ub, SDitem$(Index,11)
    Temporary = val(SDitem$(Index,11))
    if Temporary > 4 OR Temporary < -4 then
        if FilterSystem$ = "1" then
            notice "U-B index is not a valid entry"
        else
            notice "u'-g' index is not a valid entry"
        end if
        wait
    end if
    SDitem$(Index,11) = using("##.##", Temporary)

    print #DataEdit.vr, "!contents?"
    input #DataEdit.vr, SDitem$(Index,12)
    Temporary = val(SDitem$(Index,12))
    if Temporary > 4 OR Temporary < -4 then
        if FilterSystem$ = "1" then
            notice "V-R index is not a valid entry"
        else
            notice "r'-i' index is not a valid entry"
        end if
        wait
    end if
    SDitem$(Index,12) = using("##.##", Temporary)

    print #DataEdit.vi, "!contents?"
    input #DataEdit.vi, SDitem$(Index,13)
    Temporary = val(SDitem$(Index,13))
    if Temporary > 4 OR Temporary < -4 then
        if FilterSystem$ = "1" then
            notice "V-I index is not a valid entry"
        else
            notice "r'-z' index is nota valid entry"
        end if
        wait
    end if
    SDitem$(Index,13) = using("##.##", Temporary)

    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
[New_Star.click]

    if (StarDataFile$ <> "Star Data Version 2.txt") AND_
       (StarDataFile$ <> "Star Data Version 2 Sloan.txt") AND_
       (StarDataFile$ <> "Transformation Data Version 2.txt") AND_
       (StarDataFile$ <> "Transformation Data Version 2 Sloan.txt") AND_
       (StarDataFile$ <> "SOE Data Version 2.txt") AND_
       (StarDataFile$ <> "SOE Data Version 2 Sloan.txt") AND_
       (StarDataFile$ <> "FOE Data Version 2.txt") AND_
       (StarDataFile$ <> "FOE Data Version 2 Sloan.txt") then
        notice "Open a data file first"
        wait
    end if

    print #DataEdit.name, ""
    print #DataEdit.type, ""
    print #DataEdit.rah,  ""
    print #DataEdit.ram,  ""
    print #DataEdit.ras,  ""
    print #DataEdit.decd, ""
    print #DataEdit.decm, ""
    print #DataEdit.decs, ""
    print #DataEdit.v,    ""
    print #DataEdit.bv,   ""
    print #DataEdit.ub,   ""
    print #DataEdit.vr,   ""
    print #DataEdit.vi,   ""

    print #DataEdit.name, "!setfocus";
wait
'
[Delete_Star.click]
    print #DataEdit.name, "!contents? Temporary$";
    if Temporary$ = "" then
        notice "nothing to delete"
        wait
    end if
    Temporary$ = upper$(Temporary$)
    FoundItem$ = "N"
    for DataIndex = 1 to DataIndexMax
        if Temporary$ = SDitem$(DataIndex,1) then
            Index = DataIndex
            FoundItem$ = "Y"
            exit for
        end if
    next

    If FoundItem$ = "Y" then
        confirm "Do you wish to delete "+SDitem$(Index,1)+"?";Answer$
        if Answer$ = "yes" then
            SDitem$(Index,1) = "ZZZZZZZZ"
            sort SDitem$(),1,DataIndexMax,1
            if SDitem$(DataIndexMax,1) = "ZZZZZZZZ" then
                DataIndexMax = DataIndexMax - 1
                gosub [Create_Star_List]
                StarData$(DataIndexMax + 1) = ""
                print #DataEdit.StarData, "reload"
            end if
        end if
    else
        notice "nothing to delete"
    end if

    print #DataEdit.name, ""
    print #DataEdit.type, ""
    print #DataEdit.rah,  ""
    print #DataEdit.ram,  ""
    print #DataEdit.ras,  ""
    print #DataEdit.decd, ""
    print #DataEdit.decm, ""
    print #DataEdit.decs, ""
    print #DataEdit.v,    ""
    print #DataEdit.bv,   ""
    print #DataEdit.ub,   ""
    print #DataEdit.vr,   ""
    print #DataEdit.vi,   ""
wait
'
[List_Data]
    print #DataEdit.StarData, "selectionindex? Index"
    print #DataEdit.name, SDitem$(Index,1)
    print #DataEdit.type, SDitem$(Index,2)
    print #DataEdit.rah, SDitem$(Index,3)
    print #DataEdit.ram, SDitem$(Index,4)
    print #DataEdit.ras, SDitem$(Index,5)
    print #DataEdit.decd, SDitem$(Index,6)
    print #DataEdit.decm, SDitem$(Index,7)
    print #DataEdit.decs, SDitem$(Index,8)
    print #DataEdit.v, SDitem$(Index,9)
    print #DataEdit.bv, SDitem$(Index,10)
    print #DataEdit.ub, SDitem$(Index,11)
    print #DataEdit.vr, SDitem$(Index,12)
    print #DataEdit.vi, SDitem$(Index,13)
wait
'
[Sort_Name]
    sort SDitem$(),1,DataIndexMax,1
    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
[Sort_RA]
    for DataIndex = 1 to DataIndexMax
        SDitem$(DataIndex,14) =  using("##.###",(val(SDitem$(DataIndex,3))+_
                                 val(SDitem$(DataIndex,4))/60+_
                                 val(SDitem$(DataIndex,5))/3600))
    next
    sort SDitem$(),1,DataIndexMax,14
    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
[Sort_Type]
    sort SDitem$(),1,DataIndexMax,2
    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
[Sort_V]
    for DataIndex = 1 to DataIndexMax
        SDitem$(DataIndex,15) =  using("##.###",(val(SDitem$(DataIndex,9))+5))
    next
    sort SDitem$(),1,DataIndexMax,15
    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
[Sort_BV]
    for DataIndex = 1 to DataIndexMax
        SDitem$(DataIndex,16) =  using("##.###",(val(SDitem$(DataIndex,10))+5))
    next
    sort SDitem$(),1,DataIndexMax,16
    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
[Sort_UB]
    for DataIndex = 1 to DataIndexMax
        SDitem$(DataIndex,17) =  using("##.###",(val(SDitem$(DataIndex,11))+5))
    next
    sort SDitem$(),1,DataIndexMax,17
    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
[Sort_VR]
    for DataIndex = 1 to DataIndexMax
        SDitem$(DataIndex,18) =  using("##.###",(val(SDitem$(DataIndex,12))+5))
    next
    sort SDitem$(),1,DataIndexMax,18
    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
[Sort_VI]
    for DataIndex = 1 to DataIndexMax
        SDitem$(DataIndex,19) =  using("##.###",(val(SDitem$(DataIndex,13))+5))
    next
    sort SDitem$(),1,DataIndexMax,19
    gosub [Create_Star_List]
    print #DataEdit.StarData, "reload"
wait
'
'=====gosub routines
'
[Open_Data_File]
    open StarDataFile$ for input as #StarData
    DataIndex = 0
    while eof(#StarData) = 0
        DataIndex = DataIndex + 1
        input #StarData,SDitem$(DataIndex,1)        'star name

        if SDitem$(DataIndex,1) = "" then           'check to see if there are extra LF CR at end of file
            DataIndex = DataIndex - 1
            exit while
        end if

        input #StarData,SDitem$(DataIndex,2),_      'type: C or V
                        SDitem$(DataIndex,3),_      'RA hour
                        SDitem$(DataIndex,4),_      'RA minute
                        SDitem$(DataIndex,5),_      'RA second
                        SDitem$(DataIndex,6),_      'DEC degree
                        SDitem$(DataIndex,7),_      'DEC minute
                        SDitem$(DataIndex,8),_      'DEC second
                        SDitem$(DataIndex,9),_      'V/r' magnitude
                        SDitem$(DataIndex,10),_     'B-V/g'-r' index
                        SDitem$(DataIndex,11),_     'U-B/u'-g' index
                        SDitem$(DataIndex,12),_     'V-R/r'-i' index
                        SDitem$(DataIndex,13)       'V-I/r'-z' index
    wend
    close #StarData
    DataIndexMax = DataIndex

    gosub [Create_Star_List]

return
'
[Write_Sloan_Filters]
    print #DataEdit.statictext4, "r'"
    print #DataEdit.statictext5, "g'-r'"
    print #DataEdit.statictext13, "u'-g'"
    print #DataEdit.statictext14, "r'-i'"
    print #DataEdit.statictext15, "r'-z'"
return
'
[Write_Johnson_Filters]
    print #DataEdit.statictext4, "V"
    print #DataEdit.statictext5, "B-V"
    print #DataEdit.statictext13, "U-B"
    print #DataEdit.statictext14, "V-R"
    print #DataEdit.statictext15, "V-I"
return
'
[Create_Star_List]
    for DataIndex = 1 to DataIndexMax
        StarData$(DataIndex) = left$(SDitem$(DataIndex,1)+"            ",12)+"  "+_
                               right$("   "+SDitem$(DataIndex,2),1)+"   "+_
                               right$("000"+SDitem$(DataIndex,3),2)+"h"+_
                               right$("000"+SDitem$(DataIndex,4),2)+"m"+_
                               right$("000"+SDitem$(DataIndex,5),2)+"s "+_
                               right$("   "+SDitem$(DataIndex,6),3)+"d"+_
                               right$("000"+SDitem$(DataIndex,7),2)+"m"+_
                               right$("000"+SDitem$(DataIndex,8),2)+"s  "+_
                               right$("   "+SDitem$(DataIndex,9),6)+"   "+_
                               right$("   "+SDitem$(DataIndex,10),5)+"   "+_
                               right$("   "+SDitem$(DataIndex,11),5)+"   "+_
                               right$("   "+SDitem$(DataIndex,12),5)+"   "+_
                               right$("   "+SDitem$(DataIndex,13),5)
    next
return
'
[Save_File]
    if StarDataFile$ = "Star Data Version 2.txt" then
        files DefaultDir$, "Star Data Version 2.old", info$()
        if val(info$(0,0)) > 0 then
            kill "Star Data Version 2.old"
        end if
        name "Star Data Version 2.txt" as "Star Data Version 2.old"
    end if
    if StarDataFile$ = "Star Data Version 2 Sloan.txt" then
        files DefaultDir$, "Star Data Version 2 Sloan.old", info$()
        if val(info$(0,0)) > 0 then
            kill "Star Data Version 2 Sloan.old"
        end if
        name "Star Data Version 2 Sloan.txt" as "Star Data Version 2 Sloan.old"
    end if
    if StarDataFile$ = "Transformation Data Version 2.txt" then
        files DefaultDir$, "Transformation Data Version 2.old", info$()
        if val(info$(0,0)) > 0 then
            kill "Transformation Data Version 2.old"
        end if
        name "Transformation Data Version 2.txt" as "Transformation Data Version 2.old"
    end if
    if StarDataFile$ = "Transformation Data Version 2 Sloan.txt" then
        files DefaultDir$, "Transformation Data Version 2 Sloan.old", info$()
        if val(info$(0,0)) > 0 then
            kill "Transformation Data Version 2 Sloan.old"
        end if
        name "Transformation Data Version 2 Sloan.txt" as "Transformation Data Version 2 Sloan.old"
    end if
    if StarDataFile$ = "SOE Data Version 2.txt" then
        files DefaultDir$, "SOE Data Version 2.old", info$()
        if val(info$(0,0)) > 0 then
            kill "SOE Data Version 2.old"
        end if
        name "SOE Data Version 2.txt" as "SOE Data Version 2.old"
    end if
    if StarDataFile$ = "SOE Data Version 2 Sloan.txt" then
        files DefaultDir$, "SOE Data Version 2 Sloan.old", info$()
        if val(info$(0,0)) > 0 then
            kill "SOE Data Version 2 Sloan.old"
        end if
        name "SOE Data Version 2 Sloan.txt" as "SOE Data Version 2 Sloan.old"
    end if
    if StarDataFile$ = "FOE Data Version 2.txt" then
        files DefaultDir$, "FOE Data Version 2.old", info$()
        if val(info$(0,0)) > 0 then
            kill "FOE Data Version 2.old"
        end if
        name "FOE Data Version 2.txt" as "FOE Data Version 2.old"
    end if
    if StarDataFile$ = "FOE Data Version 2 Sloan.txt" then
        files DefaultDir$, "FOE Data Version 2 Sloan.old", info$()
        if val(info$(0,0)) > 0 then
            kill "FOE Data Version 2 Sloan.old"
        end if
        name "FOE Data Version 2 Sloan.txt" as "FOE Data Version 2 Sloan.old"
    end if

    open StarDataFile$ for output as #StarData
    for DataIndex = 1 to DataIndexMax
        print #StarData, SDitem$(DataIndex,1);","; SDitem$(DataIndex,2);","; SDitem$(DataIndex,3);",";_
                         SDitem$(DataIndex,4);","; SDitem$(DataIndex,5);","; SDitem$(DataIndex,6);",";_
                         SDitem$(DataIndex,7);","; SDitem$(DataIndex,8);","; SDitem$(DataIndex,9);",";_
                         SDitem$(DataIndex,10);","; SDitem$(DataIndex,11);","; SDitem$(DataIndex,12);",";_
                         SDitem$(DataIndex,13)
    next
    close #StarData
return
'
END
