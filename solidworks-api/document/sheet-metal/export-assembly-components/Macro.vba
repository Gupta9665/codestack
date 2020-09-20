Enum SheetMetalOptions_e
    ExportFlatPatternGeometry = 1
    IncludeHiddenEdges = 2
    ExportBendLines = 4
    IncludeSketches = 8
    MergeCoplanarFaces = 16
    ExportLibraryFeatures = 32
    ExportFormingTools = 64
    ExportBoundingBox = 2048
End Enum

Const SKIP_EXISTING_FILES As Boolean = False

Const OUT_NAME_TEMPLATE As String = "DXFs\<_FileName_>_<_FeatureName_>_<_ConfName_>_<Description>.dxf"

Const FLAT_PATTERN_OPTIONS As Integer = SheetMetalOptions_e.ExportBendLines + SheetMetalOptions_e.ExportFlatPatternGeometry

Dim swApp As SldWorks.SldWorks

Sub main()
        
    Set swApp = Application.SldWorks
    
try_:
    On Error GoTo catch_
    
    Dim swAssy As SldWorks.AssemblyDoc
    
    Set swAssy = swApp.ActiveDoc
        
    swAssy.ResolveAllLightWeightComponents True
        
    Dim vComps As Variant
    vComps = GetDistinctSheetMetalComponents(swAssy)
    
    Dim i As Integer
    
    For i = 0 To UBound(vComps)
    
        Dim swComp As SldWorks.Component2
        Set swComp = vComps(i)
        
        ProcessSheetMetalComponent swAssy, swComp
    
    Next
    
    swApp.SendMsgToUser2 "Operation completed", swMessageBoxIcon_e.swMbInformation, swMessageBoxBtn_e.swMbOk
    
    GoTo finally_
    
catch_:
    swApp.SendMsgToUser2 Err.Description, swMessageBoxIcon_e.swMbStop, swMessageBoxBtn_e.swMbOk
finally_:

End Sub

Function GetDistinctSheetMetalComponents(assy As SldWorks.AssemblyDoc) As Variant
    
    Dim vComps As Variant
    vComps = assy.GetComponents(False)
        
    Dim i As Integer
    
    Dim swSheetMetalComps() As SldWorks.Component2
    
    For i = 0 To UBound(vComps)
        
        Dim swComp As SldWorks.Component2
        Set swComp = vComps(i)
                
        If False = swComp.IsSuppressed() Then
            
            If Not ContainsComponent(swSheetMetalComps, swComp) Then
                
                If IsSheetMetalComponent(swComp) Then
                    If (Not swSheetMetalComps) = -1 Then
                        ReDim swSheetMetalComps(0)
                    Else
                        ReDim Preserve swSheetMetalComps(UBound(swSheetMetalComps) + 1)
                    End If
                    
                    Set swSheetMetalComps(UBound(swSheetMetalComps)) = swComp
                End If
            
            End If
            
        End If
        
    Next
    
    If (Not swSheetMetalComps) = -1 Then
        GetDistinctSheetMetalComponents = Empty
    Else
        GetDistinctSheetMetalComponents = swSheetMetalComps
    End If
    
End Function

Function IsSheetMetalComponent(comp As SldWorks.Component2) As Boolean
    
    Dim vBodies As Variant
    vBodies = comp.GetBodies3(swBodyType_e.swSolidBody, Empty)
    
    If Not IsEmpty(vBodies) Then
        
        Dim i As Integer
        
        For i = 0 To UBound(vBodies)
            Dim swBody As SldWorks.Body2
            Set swBody = vBodies(i)
            
            If False <> swBody.IsSheetMetal() Then
                IsSheetMetalComponent = True
                Exit Function
            End If
            
        Next
    End If
    
    IsSheetMetalComponent = False
    
End Function

Function ContainsComponent(comps As Variant, swComp As SldWorks.Component2) As Boolean

    Dim i As Integer
    
    For i = 0 To UBound(comps)
        Dim swThisComp As SldWorks.Component2
        Set swThisComp = comps(i)
        
        If swThisComp.GetPathName() = swComp.GetPathName() And swThisComp.ReferencedConfiguration = swComp.ReferencedConfiguration Then
            ContainsComponent = True
            Exit Function
        End If
    Next
    
    ContainsComponent = False

End Function

Function ComposeOutFileName(template As String, assm As SldWorks.AssemblyDoc, comp As SldWorks.Component2, flatPatternFeat As SldWorks.Feature, cutListFeat As SldWorks.Feature) As String

    Dim regEx As Object
    Set regEx = CreateObject("VBScript.RegExp")
    
    regEx.Global = True
    regEx.IgnoreCase = True
    regEx.Pattern = "<[^>]*>"
    
    Dim regExMatches As Object
    Set regExMatches = regEx.Execute(template)
    
    Dim i As Integer
    
    Dim outFileName As String
    outFileName = template
    
    For i = regExMatches.Count - 1 To 0 Step -1
        
        Dim regExMatch As Object
        Set regExMatch = regExMatches.Item(i)
                    
        Dim tokenName As String
        tokenName = Mid(regExMatch.Value, 2, Len(regExMatch.Value) - 2)
        
        outFileName = Left(outFileName, regExMatch.FirstIndex) & ResolveToken(tokenName, comp, flatPatternFeat, cutListFeat) & Right(outFileName, Len(outFileName) - (regExMatch.FirstIndex + regExMatch.Length))
    Next
    
    ComposeOutFileName = GetFullPath(assm, outFileName)
    
End Function

Function ResolveToken(token As String, comp As SldWorks.Component2, flatPatternFeat As SldWorks.Feature, cutListFeat As SldWorks.Feature) As String
    
    Const FILE_NAME_TOKEN As String = "_FileName_"
    Const FEAT_NAME_TOKEN As String = "_FeatureName_"
    Const CONF_NAME_TOKEN As String = "_ConfName_"
    
    Select Case LCase(token)
        Case LCase(FILE_NAME_TOKEN)
            ResolveToken = GetFileNameWithoutExtension(comp.GetPathName)
        Case LCase(FEAT_NAME_TOKEN)
            ResolveToken = flatPatternFeat.Name
        Case LCase(CONF_NAME_TOKEN)
            ResolveToken = comp.ReferencedConfiguration
        Case Else
            Dim swCustPrpMgr As SldWorks.CustomPropertyManager
            Set swCustPrpMgr = cutListFeat.CustomPropertyManager
            Dim resVal As String
            swCustPrpMgr.Get2 token, "", resVal
            ResolveToken = resVal
    End Select
    
End Function

Function GetFileNameWithoutExtension(path As String) As String
    
    GetFileNameWithoutExtension = Mid(path, InStrRev(path, "\") + 1, InStrRev(path, ".") - InStrRev(path, "\") - 1)
    
End Function

Function GetCutListFeatures(model As SldWorks.ModelDoc2) As Variant
    GetCutListFeatures = GetFeaturesByType(model, "CutListFolder")
End Function

Function GetFlatPatternFeatures(model As SldWorks.ModelDoc2) As Variant
    GetFlatPatternFeatures = GetFeaturesByType(model, "FlatPattern")
End Function

Function ProcessSheetMetalComponent(assm As SldWorks.AssemblyDoc, comp As SldWorks.Component2)
    
    Dim swCompModel As SldWorks.ModelDoc2
    Set swCompModel = comp.GetModelDoc2
    
    Dim conf As String
    conf = comp.ReferencedConfiguration
    
    Dim vCutListFeats As Variant
    vCutListFeats = GetCutListFeatures(swCompModel)
    
    If Not IsEmpty(vCutListFeats) Then
        
        Dim vFlatPatternFeats As Variant
        vFlatPatternFeats = GetFlatPatternFeatures(swCompModel)
        
        If Not IsEmpty(vFlatPatternFeats) Then
            
            Dim i As Integer
    
            For i = 0 To UBound(vFlatPatternFeats)
                
                Dim swFlatPatternFeat As SldWorks.Feature
                Dim swFlatPattern As SldWorks.FlatPatternFeatureData
                
                Set swFlatPatternFeat = vFlatPatternFeats(i)
                
                Set swFlatPattern = swFlatPatternFeat.GetDefinition
                
                Dim swFixedFace As SldWorks.Face2
                Set swFixedFace = swFlatPattern.FixedFace2
                
                Dim swBody As SldWorks.Body2
                Set swBody = swFixedFace.GetBody
                
                Dim swCutListFeat As SldWorks.Feature
                Set swCutListFeat = FindCutListFeature(vCutListFeats, swBody)
                
                If Not swCutListFeat Is Nothing Then
                    Dim outFileName As String
                    outFileName = ComposeOutFileName(OUT_NAME_TEMPLATE, assm, comp, swFlatPatternFeat, swCutListFeat)
                    
                    If Not SKIP_EXISTING_FILES Or Not FileExists(outFileName) Then
                        ExportFlatPattern swCompModel, swFlatPatternFeat, outFileName, FLAT_PATTERN_OPTIONS, conf
                    End If
                    
                Else
                    Err.Raise vbError, "", "Failed to find cut-list for flat pattern " & swFlatPatternFeat.Name
                End If
                
            Next
            
        Else
            Err.Raise vbError, "", "No flat pattern features found"
        End If
        
    Else
        Err.Raise vbError, "", "No cut-list items found"
    End If
    
End Function

Function FileExists(filePath As String) As Boolean
    FileExists = Dir(filePath) <> ""
End Function

Function FindCutListFeature(vCutListFeats As Variant, body As SldWorks.Body2) As SldWorks.Feature
    
    Dim i As Integer
    
    For i = 0 To UBound(vCutListFeats)
        
        Dim swCutListFeat As SldWorks.Feature
        Set swCutListFeat = vCutListFeats(i)
        
        Dim swBodyFolder As SldWorks.BodyFolder
        Set swBodyFolder = swCutListFeat.GetSpecificFeature2
        
        Dim vBodies As Variant
        
        vBodies = swBodyFolder.GetBodies
        
        If ContainsBody(vBodies, body) Then
            Set FindCutListFeature = swCutListFeat
        End If
            
    Next
    
End Function

Function ContainsBody(vBodies As Variant, body As SldWorks.Body2) As Boolean
    
    If Not IsEmpty(vBodies) Then
    
        Dim i As Integer
        
        For i = 0 To UBound(vBodies)
            
            Dim swCutListBody As SldWorks.Body2
            Set swCutListBody = vBodies(i)
            
            If swApp.IsSame(swCutListBody, body) = swObjectEquality.swObjectSame Then
                ContainsBody = True
                Exit Function
            End If
        Next
        
    End If
    
    ContainsBody = False
    
End Function

Function GetFeaturesByType(model As SldWorks.ModelDoc2, typeName As String) As Variant
    
    Dim swFeats() As SldWorks.Feature
    
    Dim swFeat As SldWorks.Feature
    
    Set swFeat = model.FirstFeature
    
    Do While Not swFeat Is Nothing
        
        If typeName = "CutListFolder" And swFeat.GetTypeName2() = "SolidBodyFolder" Then
            Dim swBodyFolder As SldWorks.BodyFolder
            Set swBodyFolder = swFeat.GetSpecificFeature2
            swBodyFolder.UpdateCutList
        End If
        
        ProcessFeature swFeat, swFeats, typeName

        Set swFeat = swFeat.GetNextFeature
        
    Loop
    
    If (Not swFeats) = -1 Then
        GetFeaturesByType = Empty
    Else
        GetFeaturesByType = swFeats
    End If
    
End Function

Sub ProcessFeature(thisFeat As SldWorks.Feature, featsArr() As SldWorks.Feature, typeName As String)
    
    If thisFeat.GetTypeName2() = typeName Then
    
        If (Not featsArr) = -1 Then
            ReDim featsArr(0)
            Set featsArr(0) = thisFeat
        Else
            Dim i As Integer
            
            For i = 0 To UBound(featsArr)
                If swApp.IsSame(featsArr(i), thisFeat) = swObjectEquality.swObjectSame Then
                    Exit Sub
                End If
            Next
            
            ReDim Preserve featsArr(UBound(featsArr) + 1)
            Set featsArr(UBound(featsArr)) = thisFeat
        End If
    
    End If
    
    Dim swSubFeat As SldWorks.Feature
    Set swSubFeat = thisFeat.GetFirstSubFeature
        
    While Not swSubFeat Is Nothing
        ProcessFeature swSubFeat, featsArr, typeName
        Set swSubFeat = swSubFeat.GetNextSubFeature
    Wend
        
End Sub

Sub ExportFlatPattern(part As SldWorks.PartDoc, flatPattern As SldWorks.Feature, outFilePath As String, opts As SheetMetalOptions_e, conf As String)
    
    Dim swModel As SldWorks.ModelDoc2
    Set swModel = part
    
    Dim error As ErrObject
    Dim hide As Boolean

try_:
    
    On Error GoTo catch_

    If Not swModel.Visible Then
        hide = True
        swModel.Visible = True
    End If
    
    swModel.FeatureManager.EnableFeatureTree = False
    swModel.FeatureManager.EnableFeatureTreeWindow = False
    swModel.ActiveView.EnableGraphicsUpdate = False
    
    Dim curConf As String
    
    curConf = swModel.ConfigurationManager.ActiveConfiguration.Name
    
    If curConf <> conf Then
        If False = swModel.ShowConfiguration2(conf) Then
            Err.Raise vbError, "", "Failed to activate configuration"
        End If
    End If
    
    Dim outDir As String
    outDir = Left(outFilePath, InStrRev(outFilePath, "\"))
    
    CreateDirectories outDir
    
    Dim modelPath As String
    
    modelPath = part.GetPathName
    
    If modelPath = "" Then
        Err.Raise vbError, "", "Part document must be saved"
    End If
    
    If False <> flatPattern.Select2(False, -1) Then
        If False = part.ExportToDWG2(outFilePath, modelPath, swExportToDWG_e.swExportToDWG_ExportSheetMetal, True, Empty, False, False, opts, Empty) Then
            Err.Raise vbError, "", "Failed to export flat pattern"
        End If
    Else
        Err.Raise vbError, "", "Failed to select flat-pattern"
    End If
    
    swModel.ShowConfiguration2 curConf
    
    GoTo finally_
    
catch_:
    Set error = Err
finally_:

    swModel.FeatureManager.EnableFeatureTree = True
    swModel.FeatureManager.EnableFeatureTreeWindow = True
    swModel.ActiveView.EnableGraphicsUpdate = True
    
    If hide Then
        swApp.CloseDoc swModel.GetTitle
    End If
    
    If Not error Is Nothing Then
        Err.Raise error.Number, error.Source, error.Description, error.HelpFile, error.HelpContext
    End If
    
End Sub

Sub CreateDirectories(fileDir As String)
    
    Dim pathParts As Variant
    pathParts = Split(fileDir, "\")
    
    Dim i As Integer
    Dim curPath As String
    
    For i = 0 To UBound(pathParts)
        curPath = curPath & pathParts(i) & "\"
        If Len(Dir(curPath, vbDirectory)) = 0 Then
            MkDir curPath
        End If
    Next
    
End Sub

Function GetFullPath(model As SldWorks.ModelDoc2, path As String)
    
    GetFullPath = path
    
    Dim isRelative As Boolean
    isRelative = Mid(path, 2, 1) <> ":"
    
    If isRelative Then
        
        If Left(path, 1) <> "\" Then
            path = "\" & path
        End If
        
        Dim modelPath As String
        Dim modelDir As String
        
        modelPath = model.GetPathName
        
        modelDir = Left(modelPath, InStrRev(modelPath, "\") - 1)
        
        GetFullPath = modelDir & path
        
    End If
    
End Function