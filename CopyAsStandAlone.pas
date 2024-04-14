unit userscript;

uses 'lib\mteFunctions';
const
	sPatchAuthor = 'WhiskyTangoFox';
	sPatchDescr = 'Standalone Script';
    oldName = 'Pipe';
    newName = '10mm Pipe';
    folder = 'nina';
    modcolLevelOffset = 10;
var
	patch, oldKeyword, newKeyword, newWeapon: IInterface;
    
  
//============================================================================  
  function Initialize: integer;
var
  i: integer;
  f: IInterface;
  temp : string;
  
begin
	addMessage('Starting script');

patch := CreatePatchPlugin();
	
end;
  
  //============================================================================
function Finalize: integer;


begin
	addMessage('FinishedProcessing');
    CleanMasters(patch);
    SortMasters(patch);
end;

  
//============================================================================  

function Process(e: IInterface): integer;
var
    newFull: string;
    i, j: integer;
    newOmod, oldOmod, newMisc, newCobj: IInterface;

begin
	
    
    if (Signature(e) <> 'KYWD') then raise Exception.Create('Script must be run on the target weapons unique ma_Keyword');
    oldKeyword := e;
    //copy and replace keyword
    newKeyword := CopyToPatch(oldKeyword);
    setElementEditValues(newKeyword, 'EDID', EditorID(oldKeyword) + '_' + newName);

    //copy & replace weapon
    for i := 0 to ReferencedByCount(oldKeyword) do if isWinningOverride(ReferencedByIndex(oldKeyword, i)) then begin
        if (signature(ReferencedByIndex(oldKeyword, i)) = 'WEAP') then begin
            
            if getElementEditValues(ReferencedByIndex(oldKeyword, i), 'Record Header\record flags\Non-Playable') = '1' then continue;
            
            newWeapon := CopyToPatch(ReferencedByIndex(oldKeyword, i));
            replaceKeyword(elementByPath(newWeapon, 'KWDA'));
            break;
        end
    end;
    
    for i := 0 to ReferencedByCount(oldKeyword) do if isWinningOverride(ReferencedByIndex(oldKeyword, i)) then begin
        oldOmod := ReferencedByIndex(oldKeyword, i);
        if signature(oldOmod) = 'OMOD' then begin
            //copy omod
            newOmod := CopyToPatch(oldOmod);
            replaceKeyword(elementByPath(newOmod, 'MNAM'));
            //Rename model for moved folder
            setElementEditValues(newOmod, 'MODEL\MODL', folder + '\' + getElementEditValues(newOmod, 'MODEL\MODL'));           
            
            //copy misc for omod
            newMisc := CopyToPatch(LinksTo(elementByPath(newOmod, 'LNAM')));
            setElementEditValues(newOmod, 'LNAM', IntToHex(GetLoadOrderFormID(newMisc), 8));
            
            //copy COBJ for omod
            for j := 0 to ReferencedByCount(oldOmod)-1 do if isWinningOverride(ReferencedByIndex(oldOmod, j)) then begin 
              
              if (signature(ReferencedByIndex(oldOmod, j)) = 'COBJ') then begin
                    newCobj := copyToPatch(ReferencedByIndex(oldOmod, j));
                    setElementEditValues(newCobj, 'CNAM', IntToHex(GetLoadOrderFormID(newOmod), 8));
                end;
            end;

            doOmodReplacement(oldOmod, newOmod);



        end;
        
    end;
		
	
end;

//============================================================================  

// create and initialize new patch plugin
function CreatePatchPlugin: IInterface;
var
  header: IInterface;
begin
  Result := AddNewFile;

  if not Assigned(Result) then
    Exit;
	
  // set plugin's author and description
  header := ElementByIndex(Result, 0);
  Add(header, 'CNAM', True);
  Add(header, 'SNAM', True);
  SetElementEditValues(header, 'CNAM', sPatchAuthor);
  SetElementEditValues(header, 'SNAM', sPatchDescr);
end;  


//============================================================================
// copy record into a patch plugin
function CopyToPatch(r: IInterface): IInterface;
var
  rec: IInterface;
  newFull, newEdid: string;
begin
    
    if not assigned(signature(r)) then exit;

    newEdid := StringReplace(newName, ' ', '', [rfReplaceAll, rfIgnoreCase]);
    newEdid := StringReplace(newEdid, '.', '', [rfReplaceAll, rfIgnoreCase]);
    newEdid := EditorID(r) + '_' + newEdid;

    newFull := StringReplace(getElementEditValues(result, 'FULL'), oldName, newName, [rfReplaceAll, rfIgnoreCase]);

    if GetFileName(GetFile(winningOverride(r))) = GetFileName(patch) then begin
        addMessage('Skipped copying to file - record already present: ' + editorId(r));
        result := winningOverride(r);
        exit;
    end;
    
    result := MainRecordByEditorID(GroupBySignature(patch, signature(r)), newEdid);
    if assigned(result) then begin
        addMessage('Found existing match in file ' + editorId(result));
        exit;
    end;

    AddRequiredElementMasters(r, patch, false);
    result := wbCopyElementToFile(r, patch, true, true);
    setElementEditValues(result, 'EDID', newEdid);
    setElementEditValues(result, 'FULL', newFull);
    addMessage('Copied to file: ' + EditorID(r));
end;

//============================================================================
// copy record into a patch plugin
function replaceKeyword(list: IInterface): IInterface;
var
  temp: string;
  i: integer;
  
begin
  addMessage('replacing keyword in list of ' + intToStr(ElementCount(list)));
  for i := ElementCount(list)-1 downto 0 do begin
    temp := GetEditValue(elementByIndex(list, i));
    addMessage('comparing ' + temp +  ' - ' +editorID(oldKeyword));
    if (containsText(temp, editorID(oldKeyword))) then begin
        addMessage('replacing ' + editorID(oldKeyword) +  ' -> ' + editorId(newKeyword));
        setEditValue(elementByIndex(list, i), IntToHex(GetLoadOrderFormID(newKeyword), 8));
        exit;
    end;
  end;

end;

//============================================================================  

function isModcol(omod: IInterface): Boolean;

begin
   result := false;
   if Signature(omod) = 'OMOD' then if
   assigned(getElementEditValues(omod, 'Record Header\record flags\Mod Collection'))
    then if getElementEditValues(omod, 'Record Header\record flags\Mod Collection') = 1
      then result := true;
end;

//============================================================================
// copy record into a patch plugin
function doOmodReplacement(oldOmod, newOmod :IInterface): IInterface;
var
  ref, newModcol, oldModcol, list, listmods: IInterface;
  temp: string;
  i, j, oldLevel: integer;
  
begin
    addMessage('Replacing ' + editorId(oldOmod) + ' -> ' + editorId(newOmod));
    //replace on newWeapon templates
    list := ElementByPath(newWeapon, 'Object Template\Combinations');
	  for i := 0 to ElementCount(list)-1 do Begin
        listmods := ElementByPath(ElementByIndex(list, i), 'OBTS\Includes');
        for j := 0 to ElementCount(listMods) do begin
            temp := getEditValue(ElementByPath(elementByIndex(listMods, j), 'Mod'));
            if containsText(temp, EditorId(oldOmod)) then begin
                addMessage('Replacing on weapon template ');
                SetEditValue(ElementByPath(elementByIndex(listMods, j), 'Mod'), IntToHex(GetLoadOrderFormID(newOmod), 8));
            end;
        end;
    end;

    for i := 0 to ReferencedByCount(oldOmod)-1 do if isWinningOverride(ReferencedByIndex(oldOmod, i)) AND isModcol(ReferencedByIndex(oldOmod, i)) then begin
        oldModcol := ReferencedByIndex(oldOmod, i);
        newModcol := CopyToPatch(oldModcol);
        listmods := ElementByPath(newModcol, 'DATA\Includes');
        for j := ElementCount(listMods) downto 0 do begin
            if editorId(oldOmod) = editorId(WinningOverride(LinksTo(ElementByPath(ElementByIndex(listMods, j), 'Mod')))) then begin 
                SetEditValue(ElementByPath(elementByIndex(listMods, j), 'Mod'), IntToHex(GetLoadOrderFormID(newOmod), 8));
                oldLevel := getElementEditValues(elementByIndex(listMods, j), 'Minimum Level');
                if (oldLevel > 1) then SetEditValue(ElementByPath(elementByIndex(listMods, j), 'Minimum Level'), oldLevel+modcolLevelOffset);
            end;
        end;
        doOmodReplacement(oldModcol, newModcol);

    end;

end;



end.
