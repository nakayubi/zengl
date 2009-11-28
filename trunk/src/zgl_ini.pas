{
 * Copyright © Kemka Andrey aka Andru
 * mail: dr.andru@gmail.com
 * site: http://andru-kun.inf.ua
 *
 * This file is part of ZenGL
 *
 * ZenGL is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * ZenGL is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
}
unit zgl_ini;

{$I zgl_config.cfg}

interface
uses
  zgl_types,
  zgl_memory;

type
  zglPINIKey = ^zglTINIKey;
  zglTINIKey = record
    Name  : AnsiString;
    Value : AnsiString;
end;

type
  zglPINISection = ^zglTINISection;
  zglTINISection = record
    Name : AnsiString;
    Keys : DWORD;
    Key  : array of zglTINIKey;
end;

type
  zglPINI = ^zglTINI;
  zglTINI = record
    FileName : AnsiString;
    Sections : DWORD;
    Section  : array of zglTINISection;
end;

procedure ini_LoadFromFile( const FileName : AnsiString );
procedure ini_SaveToFile( const FileName : AnsiString );
procedure ini_Add( const Section, Key : AnsiString );
procedure ini_Del( const Section, Key : AnsiString );
procedure ini_Clear( const Section : AnsiString );
function  ini_IsSection( const Section : AnsiString ) : Boolean;
function  ini_IsKey( const Section, Key : AnsiString ) : Boolean;
procedure ini_ReadKeyStr( const Section, Key : AnsiString; var Result : AnsiString );
function  ini_ReadKeyInt( const Section, Key : AnsiString ) : Integer;
function  ini_ReadKeyFloat( const Section, Key : AnsiString ) : Single;
function  ini_ReadKeyBool( const Section, Key : AnsiString ) : Boolean;
function  ini_WriteKeyStr( const Section, Key, Value : AnsiString ) : Boolean;
function  ini_WriteKeyInt( const Section, Key : AnsiString; const Value : Integer ) : Boolean;
function  ini_WriteKeyBool( const Section, Key : AnsiString; const Value : Boolean ) : Boolean;

procedure ini_CopyKey( var k1, k2 : zglTINIKey );
procedure ini_CopySection( var s1, s2 : zglTINISection );
function  ini_GetID( S, K : AnsiString; var idS, idK : Integer ) : Boolean;
procedure ini_Process;
procedure ini_Free;

implementation
uses
  zgl_file,
  zgl_utils;

var
  iniRec : zglTINI;
  iniMem : zglTMemory;

function DelSpaces( str : AnsiString ) : AnsiString;
  var
    i, b, e : Integer;
begin
  b := 1;
  e := length( str );
  for i := 1 to length( str ) do
    if str[ i ] = ' ' Then
      INC( b )
    else
      break;

  for i := length( str ) downto 1 do
    if str[ i ] = ' ' Then
      DEC( e )
    else
      break;

  for i := b to e do
    Result := Result + str[ i ];
end;

procedure AddData( str : AnsiString );
  var
    i, j, s, k, len : Integer;
begin
  if str = '' Then exit;
  if str[ 1 ] = ';' Then exit;
  len := length( str );

  if ( str[ 1 ] = '[' ) and ( str[ len ] = ']' ) Then
    begin
      INC( iniRec.Sections );
      s := iniRec.Sections - 1;

      SetLength( iniRec.Section, iniRec.Sections );
      for i := 2 to len - 1 do
        iniRec.Section[ s ].Name := iniRec.Section[ s ].Name + str[ i ];
      iniRec.Section[ s ].Name := DelSpaces( iniRec.Section[ s ].Name );
    end else
      begin
        s := iniRec.Sections - 1;
        INC( iniRec.Section[ s ].Keys );
        k := iniRec.Section[ s ].Keys - 1;

        SetLength( iniRec.Section[ s ].Key, iniRec.Section[ s ].Keys );
        for i := 1 to len do
          if str[ i ] <> '=' Then
            iniRec.Section[ s ].Key[ k ].Name := iniRec.Section[ s ].Key[ k ].Name + str[ i ]
          else
            begin
              j := i;
              break;
            end;
        iniRec.Section[ s ].Key[ k ].Name := DelSpaces( iniRec.Section[ s ].Key[ k ].Name );

        for i := j + 1 to len do
          iniRec.Section[ s ].Key[ k ].Value := iniRec.Section[ s ].Key[ k ].Value + str[ i ];
        iniRec.Section[ s ].Key[ k ].Value := DelSpaces( iniRec.Section[ s ].Key[ k ].Value );
      end;
end;

procedure ini_Add;
  var
    s, k   : AnsiString;
    ns, nk : Integer;
begin
  s := Section;
  k := Key;

  ini_GetID( s, k, ns, nk );

  if ns = -1 Then
    begin
      INC( iniRec.Sections );
      ns := iniRec.Sections - 1;

      SetLength( iniRec.Section, iniRec.Sections );
      iniRec.Section[ ns ].Name := s;
    end;

  if nk = -1 Then
    begin
      INC( iniRec.Section[ ns ].Keys );
      nk := iniRec.Section[ ns ].Keys - 1;

      SetLength( iniRec.Section[ ns ].Key, iniRec.Section[ ns ].Keys );
      iniRec.Section[ ns ].Key[ nk ].Name := k;
    end;
end;

procedure ini_Del;
  var
    s, k : AnsiString;
    i, ns, nk : Integer;
begin
  s := Section;
  k := Key;

  if ( k <> '' ) and ini_IsKey( s, k ) and ini_GetID( s, k, ns, nk ) Then
    begin
      DEC( iniRec.Section[ ns ].Keys );
      for i := nk to iniRec.Section[ ns ].Keys - 1 do
        ini_CopyKey( iniRec.Section[ ns ].Key[ i ], iniRec.Section[ ns ].Key[ i + 1 ] );
      SetLength( iniRec.Section[ ns ].Key, iniRec.Section[ ns ].Keys + 1 );
    end else
      if ini_IsSection( s ) Then
        begin
          ini_GetID( s, k, ns, nk );

          DEC( iniRec.Sections );
          for i := ns to iniRec.Sections - 1 do
            ini_CopySection( iniRec.Section[ i ], iniRec.Section[ i + 1 ] );
          iniRec.Section[ iniRec.Sections ].Keys := 0;
          SetLength( iniRec.Section, iniRec.Sections + 1 );
        end;
end;

procedure ini_Clear;
  var
    s : AnsiString;
    i, ns, nk : Integer;
begin
  s := Section;

  if s = '' Then
    begin
      iniRec.Sections := 0;
      SetLength( iniRec.Section, 0 );
    end else
      if ini_IsSection( s ) Then
        begin
          ini_GetID( s, '', ns, nk );

          iniRec.Section[ ns ].Keys := 0;
          SetLength( iniRec.Section[ ns ].Key, 0 );
        end;
end;

function ini_IsSection;
  var
    s : AnsiString;
    i, j : Integer;
begin
  s := Section;

  i := -1;
  INI_GetID( s, '', i, j );
  Result := i <> -1;
end;

function ini_IsKey;
  var
    s, k : AnsiString;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  Result := INI_GetID( s, k, i, j );
end;

procedure ini_LoadFromFile;
begin
  ini_Free;
  if not file_Exists( FileName ) Then exit;
  iniRec.FileName := FileName;

  mem_LoadFromFile( iniMem, FileName );
  ini_Process;
  mem_Free( iniMem );
end;

procedure ini_SaveToFile;
  var
    F    : zglTFile;
    i, j : Integer;
    s    : AnsiString;
begin
  file_Open( F, FileName, FOM_CREATE );
  for i := 0 to iniRec.Sections - 1 do
    begin
      s := '[ ' + iniRec.Section[ i ].Name + ' ]' + #13#10;
      file_Write( F, s[ 1 ], length( s ) );
      for j := 0 to iniRec.Section[ i ].Keys - 1 do
        begin
          s := iniRec.Section[ i ].Key[ j ].Name + ' = ';
          file_Write( F, s[ 1 ], length( s ) );
          s := iniRec.Section[ i ].Key[ j ].Value + #13#10;
          file_Write( F, s[ 1 ], length( s ) );
        end;
      if i = iniRec.Sections - 1 Then break;
        begin
          s := #13#10;
          file_Write( F, s[ 1 ], 1 );
        end;
    end;
  file_Close( F );
end;

procedure ini_ReadKeyStr;
  var
    s, k : AnsiString;
    i, j : Integer;
begin
  Result := '';
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    Result := iniRec.Section[ i ].Key[ j ].Value;
end;

function ini_ReadKeyInt;
  var
    s, k : AnsiString;
    i, j : Integer;
begin
  Result := 0;
  s := AnsiString( Section );
  k := AnsiString( Key );

  if ini_GetID( s, k, i, j ) Then
    Result := u_StrToInt( iniRec.Section[ i ].Key[ j ].Value );
end;

function ini_ReadKeyFloat;
  var
    s, k : AnsiString;
    i, j : Integer;
begin
  Result := 0;
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    Result := u_StrToFloat( iniRec.Section[ i ].Key[ j ].Value );
end;

function ini_ReadKeyBool;
  var
    s, k : AnsiString;
    i, j : Integer;
begin
  Result := FALSE;
  s := AnsiString( Section );
  k := AnsiString( Key );

  if ini_GetID( s, k, i, j ) Then
    Result := u_StrToBool( iniRec.Section[ i ].Key[ j ].Value );
end;

function ini_WriteKeyStr;
  var
    s, k : AnsiString;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    begin
      iniRec.Section[ i ].Key[ j ].Value := Value;
      Result := TRUE;
    end else
      begin
        ini_Add( Section, Key );
        ini_WriteKeyStr( Section, Key, Value );
        Result := FALSE;
      end;
end;

function ini_WriteKeyInt;
  var
    s, k : AnsiString;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    begin
      iniRec.Section[ i ].Key[ j ].Value := u_IntToStr( Value );
      Result := TRUE;
    end else
      begin
        ini_Add( Section, Key );
        ini_WriteKeyInt( Section, Key, Value );
        Result := FALSE;
      end;
end;

function ini_WriteKeyBool;
  var
    s, k : AnsiString;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    begin
      iniRec.Section[ i ].Key[ j ].Value := u_BoolToStr( Value );
      Result := TRUE;
    end else
      begin
        ini_Add( Section, Key );
        ini_WriteKeyBool( Section, Key, Value );
        Result := FALSE;
      end;
end;

procedure ini_CopyKey;
begin
  k1.Name  := k2.Name;
  k1.Value := k2.Value;
end;

procedure ini_CopySection;
  var
    i : Integer;
begin
  s1.Name := s2.Name;
  s1.Keys := s2.Keys;
  SetLength( s1.Key, s1.Keys );
  for i := 0 to s1.Keys - 1 do
    ini_CopyKey( s1.Key[ i ], s2.Key[ i ] );
end;

function ini_GetID;
  var
    S1, S2 : AnsiString;
    i, j   : Integer;
begin
  idS := -1;
  idK := -1;
  Result := FALSE;
  for i := 0 to iniRec.Sections - 1 do
    begin
      S1 := u_StrUp( iniRec.Section[ i ].Name );
      S2 := u_StrUp( s );
      if S1 = S2 Then
        begin
          idS := i;
          for j := 0 to iniRec.Section[ i ].Keys - 1 do
            begin
              S1 := u_StrUp( iniRec.Section[ i ].Key[ j ].Name );
              S2 := u_StrUp( k );
              if S1 = S2 Then
                begin
                  idK := j;
                  Result := TRUE;
                  exit;
                end;
            end;
        end;
    end;
end;

procedure ini_Process;
  var
    c : AnsiChar;
    s : AnsiString;
    i : Integer;
begin
  s := '';
  for i := 0 to iniMem.Size - 1 do
    begin
      mem_Read( iniMem, c, 1 );
      if ( c <> #13 ) and ( c <> #10 ) Then
        s := s + c
      else
        begin
          AddData( s );
          s := '';
        end;
    end;
  AddData( s );
end;

procedure ini_Free;
begin
  iniRec.Sections := 0;
  SetLength( iniRec.Section, 0 );
end;

end.
