Option Compare Database
Option Explicit

' =================================
' MODULE:       mod_Db
' Level:        Framework module
' Version:      1.00
' Description:  Database related functions & subroutines
'
' Source/date:  Bonnie Campbell, April 2015
' Revisions:    BLC, 4/30/2015 - initial version
' =================================

' =================================
' FUNCTION:     fxnBEUpdates
' Description:  Runs SQL statement updates from the systems table tsys_BE_Updates. Such
'               updates are sometimes necessary when there is a remote copy of the back-end
'               file that the developer cannot access, but which needs to be updated to
'               include the current release information. tsys_BE_Updates has the following
'               structure:  Update_ID (txt serial number autoincrementing), Is_done (yes/no),
'               Run_date (datetime), SQL_statement (memo), Update_desc (txt 100)
' Parameters:   bRunAll - True (default), or False if only running lines where [Is_done]=False
' Returns:      none
' Throws:       none
' References:   none
' Source/date:  John R. Boetsch, 6/10/2008
' Revisions:    JRB, 11/21/2008 - added optional parameter to either run all update lines
'                   (default), or just one where [Is_done]=False
'               BLC, 4/30/2015  - moved to mod_Db framework module from mod_Custom_Functions
' =================================
Public Function fxnBEUpdates(Optional ByVal bRunAll As Boolean = True)
    On Error GoTo Err_Handler

    Dim db As DAO.Database
    Dim rst As DAO.Recordset
    Dim intNumUpdates As Integer
    Dim varReturn As Variant
    Dim intI As Integer
    Dim strSQL As String
    
    Set db = CurrentDb
    Set rst = db.OpenRecordset("SELECT tsys_BE_Updates.* FROM tsys_BE_Updates " & _
        "ORDER BY tsys_BE_Updates.Update_ID;", dbOpenDynaset)

    ' Counts the number of db update records in the system table
    rst.MoveLast    ' Need to do this to make the record count accurate
    intNumUpdates = rst.RecordCount
    If intNumUpdates = 0 Then    ' No records in the recordset
        GoTo Exit_Procedure
    End If

    ' First pass to verify the tables in the specified database
    '   Initialize the system meter to indicate progress
    varReturn = SysCmd(acSysCmdInitMeter, "Performing database updates", intNumUpdates)
    intI = 0
    rst.MoveFirst
    On Error Resume Next
    Do Until rst.EOF
        intI = intI + 1
        varReturn = SysCmd(acSysCmdUpdateMeter, intI)
        If bRunAll = True Or rst![Is_done] = False Then
            DoCmd.SetWarnings False
            strSQL = rst![SQL_statement]
            DoCmd.RunSQL strSQL
            With rst
                .Edit
                ![Run_date] = Now()
                ![Is_done] = True
                .Update
            End With
        End If
        rst.MoveNext
    Loop

Exit_Procedure:
    On Error Resume Next
    DoCmd.SetWarnings True
    varReturn = SysCmd(acSysCmdRemoveMeter)
    rst.Close
    Set rst = Nothing
    Set db = Nothing
    Exit Function

Err_Handler:
    Select Case Err.Number
      Case 3061   ' Bad parameters for the SQL string
        MsgBox "Error #" & Err.Number & ":  SQL syntax error. Please notify the " & _
            "database administrator before using this application.", vbCritical, _
            "Error encountered (#" & Err.Number & " - fxnBEUpdates[mod_Db])"
      Case Else
        MsgBox "Error #" & Err.Number & ": " & Err.Description, vbCritical, _
            "Error encountered (#" & Err.Number & " - fxnBEUpdates[mod_Db])"
    End Select
    Resume Exit_Procedure

End Function

' ---------------------------------
' FUNCTION:     getAccessObjectType
' Description:  looks up object type in Access sys tables
' Parameters:   strName  - name of object w/in Access
' Returns:      long (type) or NULL if object doesn't exist
'                   ----------------
'                   1 = Access Table
'                   4 = OBDB-Linked Table / View
'                   5 = Access Query
'                   6 = Attached (Linked) File  (such as Excel, another Access Table or query, text file, etc.)
'                   -32768 = Access Form
'                   -32764 = Access Report
'                   -32761 = Access Module
'                   ----------------
' Throws:       none
' References:   Tom Davidson, April 8, 2011
'   http://stackoverflow.com/questions/2090578/ms-access-determine-object-type

' Source/date:  Bonnie Campbell August 20, 2014 - NCPN tools
' Adapted:      -
' Revisions:    BLC, 8/20/2014 - initial vesrion
'               BLC, 4/30/2015 - moved from mod_Common_UI
' ---------------------------------
Public Function getAccessObjectType(strObject As String)
On Error GoTo Err_Handler:

    getAccessObjectType = DLookup("Type", "MSysObjects", "NAME = '" & strObject & "'")
   
Exit_Function:
    Exit Function

Err_Handler:
    Select Case Err.Number
      Case Else
        MsgBox "Error #" & Err.Number & ": " & Err.Description, vbCritical, _
            "Error encountered (#" & Err.Number & " - getAccessObjectType[mod_Db])"
    End Select
    Resume Exit_Function
End Function

' =================================
' FUNCTION:     fxnTableExists
' Description:  Returns whether the specified table exists in the current database collection
' Parameters:   strTableName - string for the name of the table to check
' Returns:      True if the specified table exists in the master systems table, or False
' Throws:       none
' References:   none
' Source/date:  John R. Boetsch, 6/29/2009
' Revisions:    JRB, 6/29/2009 - initial version
'               BLC, 4/30/2015 - moved from mod_Utilities
' =================================
Public Function fxnTableExists(ByVal strTableName As String) As Boolean
    On Error GoTo Err_Handler

    fxnTableExists = DCount("*", "MSysObjects", "(([Type] In (1,4,6)) AND ([Name]=""" & _
        strTableName & """))")

Exit_Function:
    Exit Function

Err_Handler:
    Select Case Err.Number
      Case Else
        MsgBox "Error #" & Err.Number & ": " & Err.Description, vbCritical, _
            "Error encountered (#" & Err.Number & " - fxnTableExists[mod_Db])"
    End Select
    Resume Exit_Function

End Function


' ---------------------------------
' FUNCTION:     GetTempVarIndex
' Description:  Retrieves the index of a TempVar item
' Parameters:   strItem - item name(string)
' Returns:      index of item, if found (integer); not found returns -1
' Throws:       -
' References:   -
' Source/date:  Dal Jeanis, 7/11/2013
'               http://www.accessforums.net/modules/demo-module-vba-code-syntax-using-tempvars-36353.html
' Adapted:      Bonnie Campbell, Sep 1, 2014
' Revisions:    BLC, 9/1/2014 - initial version
'               BLC, 4/30/2015 - moved from mod_Utilities to mod_Db
' ---------------------------------
Public Function GetTempVarIndex(strItem) As String
On Error GoTo Err_Handler

Dim i As Integer

    For i = 0 To [TempVars].count - 1
        If [TempVars].item(i).name = strItem Then
            'fetch the index and exit
            GetTempVarIndex = i
            Exit Function
        End If
    Next i
    
    'none found -> return -1
    GetTempVarIndex = -1
    
Exit_Function:
    Exit Function

Err_Handler:
    Select Case Err.Number
      Case Else
        MsgBox "Error #" & Err.Number & ": " & Err.Description, vbCritical, _
            "Error encountered (#" & Err.Number & " - GetTempVarIndex[mod_Db])"
    End Select
    Resume Exit_Function
End Function