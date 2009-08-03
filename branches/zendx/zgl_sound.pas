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
unit zgl_sound;

{$I zgl_config.cfg}

interface

uses
  Windows,
  {$IFDEF USE_OPENAL}
  zgl_sound_openal,
  {$ELSE}
  zgl_sound_dsound,
  {$ENDIF}
  zgl_types,
  zgl_file,
  zgl_memory;

const
  SND_ALL    = -2;
  SND_STREAM = -3;

type
  zglPSound        = ^zglTSound;
  zglPSoundStream  = ^zglTSoundStream;
  zglPSoundDecoder = ^zglTSoundDecoder;
  zglPSoundFormat  = ^zglTSoundFormat;
  zglPSoundManager = ^zglTSoundManager;

{$IFDEF USE_OPENAL}
  zglTSound = record
    Buffer       : DWORD;
    sCount       : DWORD;
    Source       : array of DWORD;

    Data         : Pointer;
    Size         : Integer;
    Frequency    : Integer;

    Prev, Next   : zglPSound;
end;
{$ELSE}
  zglTSound = record
    Buffer       : DWORD; // unused
    sCount       : DWORD;
    Source       : array of IDirectSoundBuffer;

    Data         : Pointer;
    Size         : Integer;
    Frequency    : Integer;

    Prev, Next   : zglPSound;
end;
{$ENDIF}

  zglTSoundStream = record
    _Data      : Pointer;
    _File      : zglTFile;
    _Decoder   : zglPSoundDecoder;
    Rate       : DWORD;
    Channels   : DWORD;
    Buffer     : Pointer;
    BufferSize : DWORD;
    Loop       : Boolean;
    Played     : Boolean;
end;

  zglTSoundDecoder = record
    Ext   : AnsiString;
    Open  : function( var Stream : zglPSoundStream; const FileName : AnsiString ) : Boolean;
    Read  : function( var Stream : zglPSoundStream; const Buffer : Pointer; const Count : DWORD; var _End : Boolean ) : DWORD;
    Loop  : procedure( var Stream : zglPSoundStream );
    Close : procedure( var Stream : zglPSoundStream );
end;

  zglTSoundFormat = record
    Extension  : AnsiString;
    Decoder    : zglPSoundDecoder;
    FileLoader : procedure( const FileName : AnsiString; var Data : Pointer; var Size, Format, Frequency : Integer );
    MemLoader  : procedure( const Memory : zglTMemory; var Data : Pointer; var Size, Format, Frequency : Integer );
end;

  zglTSoundManager = record
    Count   : record
      Items   : DWORD;
      Formats : DWORD;
              end;
    First   : zglTSound;
    Formats : array of zglTSoundFormat;
end;

function  snd_Init : Boolean;
procedure snd_Free;
function  snd_Add( const SourceCount : Integer ) : zglPSound;
procedure snd_Del( var Sound : zglPSound );
function  snd_LoadFromFile( const FileName : AnsiString; const SourceCount : Integer = 8 ) : zglPSound;
function  snd_LoadFromMemory( const Memory : zglTMemory; const Extension : AnsiString; const SourceCount : Integer = 8 ) : zglPSound;

function  snd_Play( const Sound : zglPSound; const Loop : Boolean = FALSE; const X : Single = 0; const Y : Single = 0; const Z : Single = 0) : Integer;
procedure snd_Stop( const Sound : zglPSound; const Source : Integer );
procedure snd_SetVolume( const Sound : zglPSound; const Volume : Single; const ID : Integer );
procedure snd_SetFrequency( const Sound : zglPSound; const Frequency, ID : Integer );
procedure snd_SetFrequencyCoeff( const Sound : zglPSound; const Coefficient : Single; const ID : Integer );

procedure snd_PlayFile( const FileName : AnsiString; const Loop : Boolean = FALSE );
procedure snd_StopFile;
function  snd_ProcFile( data : Pointer ) : PInteger; stdcall;
procedure snd_ResumeFile;

var
  managerSound : zglTSoundManager;

  sndActive      : Boolean;
  sndInitialized : Boolean = FALSE;
  sndVolume      : Single  = 1;
  sndCanPlay     : Boolean = TRUE;
  sndCanPlayFile : Boolean = TRUE;
  sndStopFile    : Boolean = FALSE;
  sndAutoPaused  : Boolean;

  sfStream : zglPSoundStream;
  sfVolume : Single = 1;
  {$IFDEF USE_OPENAL}
  sfFormat   : array[ 1..2 ] of LongInt = ( AL_FORMAT_MONO16, AL_FORMAT_STEREO16 );
  sfBufCount : Integer = 4;
  sfSource   : LongWord;
  sfBuffers  : array[ 0..3 ] of LongWord;
  {$ELSE}
  sfBuffer  : IDirectSoundBuffer;
  sfLastPos : DWORD;
  {$ENDIF}

  Thread   : DWORD;
  ThreadID : DWORD;

implementation
uses
  zgl_main,
  zgl_window,
  zgl_timers,
  zgl_log,
  zgl_utils;

function snd_Init;
begin
  Result := FALSE;
{$IFDEF USE_OPENAL}
  log_Add( 'OpenAL: load ' + libopenal  );
  if not InitOpenAL Then
    begin
      log_Add( 'Error while loading ' + libopenal );
      exit;
    end;

  log_Add( 'OpenAL: open device' );
  log_Add( 'OpenAL: Default device is "' + alcGetString( nil, ALC_DEFAULT_DEVICE_SPECIFIER ) + '"' );

  oal_Device := alcOpenDevice( 'Generic Software' );
  if not Assigned( oal_Device ) Then
    oal_Device := alcOpenDevice( nil );
  if not Assigned( oal_Device ) Then
    begin
      log_Add( 'Cannot open sound device' );
      exit;
    end;

  log_Add( 'OpenAL: create context' );
  oal_Context := alcCreateContext( oal_Device, nil );
  if not Assigned( oal_Context ) Then
    begin
      log_Add( 'Cannot create sound context' );
      exit;
    end;

  if alcMakeContextCurrent( oal_Context ) Then
    log_Add( 'OpenAL: sound system initialized successful' )
  else
    begin
      log_Add( 'OpenAL: cannot set current context' );
      exit;
    end;

  alListenerfv( AL_POSITION,    @oal_Position );
  alListenerfv( AL_VELOCITY,    @oal_Velocity );
  alListenerfv( AL_ORIENTATION, @oal_Orientation );

  alGenSources( 1, @sfSource );
  alGenBuffers( sfBufCount, @sfBuffers );

  while TRUE do
    begin
      if length( oal_Sources ) > 63 Then break; // 64 хватит с головой :)
      SetLength( oal_Sources, length( oal_Sources ) + 1 );
      SetLength( oal_SrcPtrs, length( oal_SrcPtrs ) + 1 );
      SetLength( oal_SrcState, length( oal_SrcState ) + 1 );
      alGenSources( 1, @oal_Sources[ length( oal_Sources ) - 1 ] );
      if oal_Sources[ length( oal_Sources ) - 1 ] = 0 Then
        begin
          SetLength( oal_Sources, length( oal_Sources ) - 1 );
          SetLength( oal_SrcPtrs, length( oal_SrcPtrs ) - 1 );
          SetLength( oal_SrcState, length( oal_SrcState ) - 1 );
          break;
        end;
    end;
  log_Add( 'OpenAL: generate ' + u_IntToStr( length( oal_Sources ) ) + ' source' );
{$ELSE}
  log_Add( 'DirectSound: load DSound.dll' );
  if not InitDSound Then
    log_Add( 'DirectSound: Error while loading libraries' );

  if DirectSoundCreate( nil, ds_Device, nil ) <> DS_OK Then
    begin
      FreeDSound;
      log_Add( 'DirectSound: Error while calling DirectSoundCreate' );
      exit;
    end;

  if ds_Device.SetCooperativeLevel( wnd_Handle, DSSCL_PRIORITY ) <> DS_OK Then
    log_Add( 'DirectSound: Can''t SetCooperativeLevel' );

  log_Add( 'DirectSound: sound system initialized successful' );
{$ENDIF}

  zgl_GetMem( Pointer( sfStream ), SizeOf( zglTSoundStream  ) );

  sndInitialized := TRUE;
  Result         := TRUE;
end;

procedure snd_Free;
begin
  if not sndInitialized Then exit;

  if Assigned( sfStream ) Then
    begin
      if Assigned( sfStream._Decoder ) Then
        sfStream._Decoder.Close( sfStream );
      if Assigned( sfStream.Buffer ) Then
        FreeMemory( sfStream.Buffer );
      FreeMemory( sfStream );
    end;

{$IFDEF USE_OPENAL}
  alDeleteSources( 1, @sfSource );
  alDeleteBuffers( sfBufCount, @sfBuffers[ 0 ] );
  alDeleteSources( length( oal_Sources ), @oal_Sources[ 0 ] );
  SetLength( oal_Sources, 0 );
  SetLength( oal_SrcPtrs, 0 );

  log_Add( 'OpenAL: destroy current sound context' );
  alcDestroyContext( oal_Context );
  log_Add( 'OpenAL: close sound device' );
  alcCloseDevice( oal_Device );
  log_Add( 'OpenAL: sound system finalized successful' );
  FreeOpenAL;
{$ELSE}
  sfBuffer  := nil;
  ds_Device := nil;

  FreeDSound;
  log_Add( 'DirectSound: sound system finalized successful' );
{$ENDIF}
end;

function snd_Add;
  {$IFDEF USE_OPENAL}
  var
    i : Integer;
  {$ENDIF}
begin
  Result := nil;

  if not sndInitialized Then exit;

  Result := @managerSound.First;
  while Assigned( Result.Next ) do
    Result := Result.Next;

  zgl_GetMem( Pointer( Result.Next ), SizeOf( zglTSound ) );
  Result.Next.Prev := Result;
  Result.Next.Next := nil;
  Result           := Result.Next;

{$IFDEF USE_OPENAL}
  alGenBuffers( 1, @Result.Buffer );
  Result.sCount := SourceCount;
  SetLength( Result.Source, SourceCount );
  for i := 0 to SourceCount - 1 do
    Result.Source[ i ] := 0;
{$ELSE}
  Result.sCount := SourceCount;
  SetLength( Result.Source, SourceCount );
{$ENDIF}

  INC( managerSound.Count.Items );
end;

procedure snd_Del;
  var
    i : Integer;
begin
  if not Assigned( Sound ) Then exit;

{$IFDEF USE_OPENAL}
  alDeleteBuffers( 1, @Sound.Buffer );
{$ELSE}
  FreeMemory( Sound.Data );
  for i := 0 to Sound.sCount - 1 do
    Sound.Source[ i ] := nil;
{$ENDIF}
  SetLength( Sound.Source, 0 );

  if Assigned( Sound.Prev ) Then
    Sound.Prev.Next := Sound.Next;
  if Assigned( Sound.Next ) Then
    Sound.Next.Prev := Sound.Prev;

  FreeMemory( Sound );
  DEC( managerSound.Count.Items );

  Sound := nil;
end;

function snd_LoadFromFile;
  var
    i   : Integer;
    f   : Integer;
    ext : AnsiString;
begin
  Result := nil;

  if not sndInitialized Then exit;

  if not file_Exists( FileName ) Then
    begin
      log_Add( 'Cannot read ' + FileName );
      exit;
    end;
  Result := snd_Add( SourceCount );

  for i := managerSound.Count.Formats - 1 downto 0 do
    begin
      file_GetExtension( FileName, ext );
      if u_StrUp( ext ) = managerSound.Formats[ i ].Extension Then
        managerSound.Formats[ i ].FileLoader( FileName, Result.Data, Result.Size, f, Result.Frequency );
    end;

  if not Assigned( Result.Data ) Then
    begin
      log_Add( 'Cannot load sound: ' + FileName );
      snd_Del( Result );
      exit;
    end;

{$IFDEF USE_OPENAL}
  alBufferData( Result.Buffer, f, Result.Data, Result.Size, Result.Frequency );
  FreeMemory( Result.Data );
{$ELSE}
  Result.Source[ 0 ] := dsu_CreateBuffer( Result.Size, Pointer( f ) );
  dsu_FillData( Result.Source[ 0 ], Result.Data, Result.Size );
  for i := 1 to Result.sCount - 1 do
    ds_Device.DuplicateSoundBuffer( Result.Source[ 0 ], Result.Source[ i ] );
{$ENDIF}

  log_Add( 'Successful loading of sound: ' + FileName );
end;

function snd_LoadFromMemory;
  var
    i : Integer;
    f : Integer;
begin
  Result := nil;

  if not sndInitialized Then exit;

  Result := snd_Add( SourceCount );

  for i := managerSound.Count.Formats - 1 downto 0 do
    if u_StrUp( Extension ) = managerSound.Formats[ i ].Extension Then
      managerSound.Formats[ i ].MemLoader( Memory, Result.Data, Result.Size, f, Result.Frequency );

  if not Assigned( Result.Data ) Then
    begin
      log_Add( 'Cannot load sound: From Memory' );
      exit;
    end;

{$IFDEF USE_OPENAL}
  alBufferData( Result.Buffer, f, Result.Data, Result.Size, Result.Frequency );
{$ELSE}
  Result.Source[ 0 ] := dsu_CreateBuffer( Result.Size, Pointer( f ) );
  dsu_FillData( Result.Source[ 0 ], Result.Data, Result.Size );
  for i := 1 to Result.sCount - 1 do
    ds_Device.DuplicateSoundBuffer( Result.Source[ 0 ], Result.Source[ i ] );
{$ENDIF}
end;

function snd_Play;
  var
    i, j      : Integer;
    {$IFDEF USE_OPENAL}
    sourcePos : array[ 0..2 ] of Single;
    {$ELSE}
    DSERROR : HRESULT;
    Status  : DWORD;
    Vol     : Single;
    {$ENDIF}
begin
  Result := -1;

  if ( not Assigned( Sound ) ) or
     ( not sndInitialized ) or
     ( not sndCanPlay ) Then exit;

{$IFDEF USE_OPENAL}
  for i := 0 to Sound.sCount - 1 do
    begin
      if Sound.Source[ i ] = 0 Then
        Sound.Source[ i ] := oal_Getsource( @Sound.Source[ i ] );

      alGetSourcei( Sound.Source[ i ], AL_SOURCE_STATE, j );
      if j <> AL_PLAYING Then
         begin
           Result := i;
           break;
         end;
    end;
  if Result = -1 Then exit;

  sourcePos[ 0 ] := X;
  sourcePos[ 1 ] := Y;
  sourcePos[ 2 ] := Z;

  alSourcei ( Sound.Source[ Result ], AL_BUFFER,    Sound.Buffer );
  alSourcefv( Sound.Source[ Result ], AL_POSITION,  @sourcePos );
  alSourcefv( Sound.Source[ Result ], AL_VELOCITY,  @oal_Velocity );
  alSourcef ( Sound.Source[ Result ], AL_GAIN,      sndVolume );
  alSourcei ( Sound.Source[ Result ], AL_FREQUENCY, Sound.Frequency );

  if Loop Then
    alSourcei( Sound.Source[ Result ], AL_LOOPING, AL_TRUE )
  else
    alSourcei( Sound.Source[ Result ], AL_LOOPING, AL_FALSE );

  alSourcePlay( Sound.Source[ Result ] );
{$ELSE}
  for i := 0 to Sound.sCount - 1 do
    begin
      DSERROR := Sound.Source[ i ].GetStatus( Status );
      if DSERROR <> DS_OK Then Status := 0;
      if ( Status and DSBSTATUS_PLAYING ) = 0 Then
        begin
          if ( Status and DSBSTATUS_BUFFERLOST ) <> 0 Then
            begin
              Sound.Source[ i ].Restore;
              if i = 0 Then
                dsu_FillData( Sound.Source[ i ], Sound.Data, Sound.Size )
              else
                ds_Device.DuplicateSoundBuffer( Sound.Source[ 0 ], Sound.Source[ i ] );
            end;
          Result := i;
          break;
        end;
    end;
  if Result = -1 Then exit;

  Sound.Source[ Result ].SetPan      ( dsu_CalcPos( X, Y, Z, Vol )                 );
  Sound.Source[ Result ].SetVolume   ( dsu_CalcVolume( Vol )                       );
  Sound.Source[ Result ].SetFrequency( Sound.Frequency                             );
  Sound.Source[ Result ].Play        ( 0, 0, DSBPLAY_LOOPING * Byte( Loop = TRUE ) );
{$ENDIF}
end;

procedure snd_Stop;
  var
    i, j : Integer;
    snd : zglPSound;
    state : {$IFDEF USE_OPENAL} Integer {$ELSE} DWORD {$ENDIF};
  procedure Stop( const Sound : zglPSound; const ID : Integer );
  begin
    {$IFDEF USE_OPENAL}
    if Sound.Source[ ID ] <> 0 Then
      begin
        alSourceStop( Sound.Source[ ID ] );
        alSourcei( Sound.Source[ ID ], AL_BUFFER, AL_NONE );
      end;
    {$ELSE}
    if Assigned( Sound.Source[ ID ] ) Then
      Sound.Source[ ID ].Stop;
    {$ENDIF}
  end;
begin
  if not sndInitialized Then exit;

  if Assigned( Sound ) Then
    begin
      if Source = SND_ALL Then
        begin
          for i := 0 to Sound.sCount - 1 do
            Stop( Sound, i );
        end else
          if Source >= 0 Then
            Stop( Sound, Source );
    end else
      if Source = SND_ALL Then
        begin
          snd := managerSound.First.Next;
          for i := 0 to managerSound.Count.Items - 1 do
            begin
              for j := 0 to snd.sCount - 1 do
                Stop( snd, j );
              snd := snd.Next;
            end;
        end;
end;

procedure snd_SetVolume;
  var
    i, j : Integer;
    snd  : zglPSound;
  procedure SetVolume( const Sound : zglPSound; const ID : Integer; const Volume : Single );
  begin
    {$IFDEF USE_OPENAL}
    if Sound.Source[ ID ] <> 0 Then
      alSourcef( Sound.Source[ ID ], AL_GAIN, Volume );
    {$ELSE}
    if Assigned( Sound.Source[ ID ] ) Then
      Sound.Source[ ID ].SetVolume( dsu_CalcVolume( Volume ) );
    {$ENDIF}
  end;
begin
  if not sndInitialized Then exit;

  if ID = SND_STREAM Then
    sfVolume := Volume
  else
    if ( not Assigned( Sound ) ) and ( ID = SND_ALL ) Then
      sndVolume := Volume;

  if ( ID = SND_STREAM ) and ( Assigned( sfStream._Decoder ) ) Then
    begin
      {$IFDEF USE_OPENAL}
      alSourcef( sfSource, AL_GAIN, Volume );
      {$ELSE}
      sfBuffer.SetVolume( dsu_CalcVolume( Volume ) );
      {$ENDIF}
      exit;
    end;

  if Assigned( Sound ) Then
    begin
      if ID = SND_ALL Then
        begin
          for i := 0 to Sound.sCount - 1 do
            SetVolume( Sound, i, Volume );
        end else
          if ID >= 0 Then
            SetVolume( Sound, ID, Volume );
    end else
      if ID = SND_ALL Then
        begin
          snd := managerSound.First.Next;
          for i := 0 to managerSound.Count.Items - 1 do
            begin
              for j := 0 to snd.sCount - 1 do
                SetVolume( snd, j, Volume );
              snd := snd.Next;
            end;
        end;
end;

procedure snd_SetFrequency;
  var
    i, j : Integer;
    snd  : zglPSound;
  procedure SetFrequency( const Sound : zglPSound; const ID, Frequency : Integer );
  begin
    {$IFDEF USE_OPENAL}
    if Sound.Source[ ID ] <> 0 Then
      alSourcei( Sound.Source[ ID ], AL_FREQUENCY, Frequency );
    {$ELSE}
    if Assigned( Sound.Source[ ID ] ) Then
      Sound.Source[ ID ].SetFrequency( Frequency );
    {$ENDIF}
  end;
begin
  if not sndInitialized Then exit;

  if ( ID = SND_STREAM ) and ( Assigned( sfStream._Decoder ) ) Then
    begin
      {$IFDEF USE_OPENAL}
      alSourcef( sfSource, AL_FREQUENCY, Frequency );
      {$ELSE}
      sfBuffer.SetFrequency( Frequency );
      {$ENDIF}
      exit;
    end;

  if Assigned( Sound ) Then
    begin
      if ID = SND_ALL Then
        begin
          for i := 0 to Sound.sCount - 1 do
            SetFrequency( Sound, i, Frequency );
        end else
          if ID >= 0 Then
            SetFrequency( Sound, ID, Frequency );
    end else
      if ID = SND_ALL Then
        begin
          snd := managerSound.First.Next;
          for i := 0 to managerSound.Count.Items - 1 do
            begin
              for j := 0 to snd.sCount - 1 do
                SetFrequency( snd, j, Frequency );
              snd := snd.Next;
            end;
        end;
end;

procedure snd_SetFrequencyCoeff;
  var
    i, j : Integer;
    snd  : zglPSound;
  procedure SetFrequency( const Sound : zglPSound; const ID, Frequency : Integer );
  begin
    {$IFDEF USE_OPENAL}
    if Sound.Source[ ID ] <> 0 Then
      alSourcei( Sound.Source[ ID ], AL_FREQUENCY, Frequency );
    {$ELSE}
    if Assigned( Sound.Source[ ID ] ) Then
      Sound.Source[ ID ].SetFrequency( Frequency );
    {$ENDIF}
  end;
begin
  if not sndInitialized Then exit;

  if ( ID = SND_STREAM ) and ( Assigned( sfStream._Decoder ) ) Then
    begin
      {$IFDEF USE_OPENAL}
      alSourcef( sfSource, AL_FREQUENCY, Round( snd.Frequency * Coefficient ) );
      {$ELSE}
      sfBuffer.SetFrequency( Round( snd.Frequency * Coefficient ) );
      {$ENDIF}
      exit;
    end;

  if Assigned( Sound ) Then
    begin
      if ID = SND_ALL Then
        begin
          for i := 0 to Sound.sCount - 1 do
            SetFrequency( Sound, i, Round( Sound.Frequency * Coefficient ) );
        end else
          if ID >= 0 Then
            SetFrequency( Sound, ID, Round( Sound.Frequency * Coefficient ) );
    end else
      if ID = SND_ALL Then
        begin
          snd := managerSound.First.Next;
          for i := 0 to managerSound.Count.Items - 1 do
            begin
              for j := 0 to snd.sCount - 1 do
                SetFrequency( snd, j, Round( snd.Frequency * Coefficient ) );
              snd := snd.Next;
            end;
        end;
end;

procedure snd_PlayFile;
  var
    i         : Integer;
    ext       : AnsiString;
    {$IFDEF USE_OPENAL}
    _End      : Boolean;
    BytesRead : Integer;
    {$ELSE}
    buffDesc : zglTBufferDesc;
    {$ENDIF}
begin
  if ( not sndInitialized ) or
     ( not sndCanPlayFile ) Then exit;

  if Assigned( sfStream._Decoder ) Then
    begin
      snd_StopFile;
      FreeMemory( sfStream.Buffer );
      sfStream._Decoder.Close( sfStream );
    end;

  if not file_Exists( FileName ) Then
    begin
      log_Add( 'Cannot read ' + FileName );
      exit;
    end;

  for i := managerSound.Count.Formats - 1 downto 0 do
    begin
      file_GetExtension( FileName, ext );
      if u_StrUp( ext ) = managerSound.Formats[ i ].Extension Then
        sfStream._Decoder := managerSound.Formats[ i ].Decoder;
    end;

  if Assigned( sfStream._Decoder ) Then
    sfStream.Loop := Loop;

  if ( not Assigned( sfStream._Decoder ) ) or
     ( not sfStream._Decoder.Open( sfStream, FileName ) ) Then
    begin
      sfStream._Decoder := nil;
      log_Add( 'Cannot play: ' + FileName );
      exit;
    end;

{$IFDEF USE_OPENAL}
  alSourceStop( sfSource );
  alSourceRewind( sfSource );
  alSourcei( sfSource, AL_BUFFER, AL_NONE );

  for i := 0 to sfBufCount - 1 do
    begin
      BytesRead := sfStream._Decoder.Read( sfStream, sfStream.Buffer, sfStream.BufferSize, _End );
      if BytesRead <= 0 Then break;

      alBufferData( sfBuffers[ i ], sfFormat[ sfStream.Channels ], sfStream.Buffer, BytesRead, sfStream.Rate );
      alSourceQueueBuffers( sfSource, 1, @sfBuffers[ i ] );
    end;

  alSourcei( sfSource, AL_LOOPING, AL_FALSE );
  alSourcePlay( sfSource );
  alSourcef( sfSource, AL_GAIN, sfVolume );
  alSourcef( sfSource, AL_FREQUENCY, sfStream.Rate );
{$ELSE}
  with buffDesc do
    begin
      FormatCode     := 1;
      ChannelNumber  := sfStream.Channels;
      SampleRate     := sfStream.Rate;
      BitsPerSample  := 16;
      BytesPerSample := ( BitsPerSample div 8 ) * ChannelNumber;
      BytesPerSecond := SampleRate * BytesPerSample;
      cbSize         := SizeOf( buffDesc );
    end;
  if Assigned( sfBuffer ) Then sfBuffer := nil;
  sfBuffer := dsu_CreateBuffer( sfStream.BufferSize, @buffDesc.FormatCode );

  sfBuffer.SetCurrentPosition( 0 );
  sfLastPos := 0;
  sfBuffer.Play( 0, 0, DSBPLAY_LOOPING );
  sfBuffer.SetVolume( dsu_CalcVolume( sfVolume ) );
  sfBuffer.SetFrequency( sfStream.Rate );
{$ENDIF}

  sfStream.Played := TRUE;
  Thread := CreateThread( nil, 0, @snd_ProcFile, nil, 0, ThreadID );
end;

procedure snd_StopFile;
begin
  if ( not Assigned( sfStream ) ) or
     ( not Assigned( sfStream._Decoder ) ) or
     ( not sfStream.Played ) or
     ( not sndInitialized ) Then exit;

  sfStream.Played := FALSE;

{$IFDEF USE_OPENAL}
  sndStopFile := TRUE;
  while sndStopFile do;

  alSourceStop( sfSource );
  alSourceRewind( sfSource );
  alSourcei( sfSource, AL_BUFFER, 0 );
{$ELSE}
  sndStopFile := TRUE;
  while sndStopFile do;

  CloseHandle( Thread );
  sfBuffer.Stop;
{$ENDIF}
end;

function snd_ProcFile;
  var
    _End : Boolean;
  {$IFDEF USE_OPENAL}
    processed : LongInt;
    buffer    : LongWord;
    BytesRead : Integer;
  {$ELSE}
    Block1, Block2 : Pointer;
    b1Size, b2Size : DWORD;
    Position       : DWORD;
    FillSize       : DWORD;
  {$ENDIF}
begin
  {$IFDEF USE_OPENAL}
  processed := 0;
  while processed < 1 do
    alGetSourcei( sfSource, AL_BUFFERS_PROCESSED, processed );
  {$ENDIF}
  while not sndStopFile do
    begin
      if ( not Assigned( sfStream ) ) or
         ( not sndInitialized ) Then break;

      u_Sleep( 100 );
      {$IFDEF USE_OPENAL}
      alGetSourcei( sfSource, AL_BUFFERS_PROCESSED, processed );
      while ( processed > 0 ) and ( not sndStopFile ) do
        begin
          alSourceUnQueueBuffers( sfSource, 1, @buffer );

          BytesRead := sfStream._Decoder.Read( sfStream, sfStream.Buffer, sfStream.BufferSize, _End );
          alBufferData( buffer, sfFormat[ sfStream.Channels ], sfStream.Buffer, BytesRead, sfStream.Rate );
          alSourceQueueBuffers( sfSource, 1, @buffer );

          if _End Then break;

          DEC( processed );
        end;
      {$ELSE}
      while DWORD( sfBuffer.GetCurrentPosition( @Position, @b1Size ) ) = DSERR_BUFFERLOST do
        sfBuffer.Restore;

      FillSize := ( sfStream.BufferSize + Position - sfLastPos ) mod sfStream.BufferSize;

      Block1 := nil;
      Block2 := nil;
      b1Size := 0;
      b2Size := 0;

      sfBuffer.Lock( sfLastPos, FillSize, Block1, b1Size, Block2, b2Size, 0 );
      sfLastPos := Position;

      sfStream._Decoder.Read( sfStream, Block1, b1Size, _End );
      if ( b2Size <> 0 ) and ( not _End ) Then
        sfStream._Decoder.Read( sfStream, Block2, b2Size, _End );

      sfBuffer.Unlock( Block1, b1Size, Block2, b2Size );
      {$ENDIF}
      if _End then
        begin
          if sfStream.Loop Then
            sfStream._Decoder.Loop( sfStream )
          else
            begin
              sfStream^.Played := FALSE;
              break;
            end;
        end;
    end;
{$IFDEF USE_OPENAL}
  alSourceQueueBuffers( sfSource, 1, @buffer );
{$ELSE}
  sfBuffer.Stop;
{$ENDIF}
  sndStopFile := FALSE;
end;

procedure snd_ResumeFile;
{$IFDEF USE_OPENAL}
  var
    i    : Integer;
    _End : Boolean;
    BytesRead : Integer;
{$ENDIF}
begin
  if ( not Assigned( sfStream ) ) or
     ( not Assigned( sfStream._Decoder ) ) or
     ( sfStream.Played ) or
     ( not sndInitialized ) Then exit;

{$IFDEF USE_OPENAL}
  alSourceStop( sfSource );
  alSourceRewind( sfSource );
  alSourcei( sfSource, AL_BUFFER, 0 );

  for i := 0 to sfBufCount - 1 do
    begin
      BytesRead := sfStream._Decoder.Read( sfStream, sfStream.Buffer, sfStream.BufferSize, _End );
      if BytesRead <= 0 Then break;

      alBufferData( sfBuffers[ i ], sfFormat[ sfStream.Channels ], sfStream.Buffer, BytesRead, sfStream.Rate );
      alSourceQueueBuffers( sfSource, 1, @sfBuffers[ i ] );
    end;

  alSourcei( sfSource, AL_LOOPING, AL_FALSE );
  alSourcePlay( sfSource );
  alSourcef( sfSource, AL_GAIN, sfVolume );
  alSourcef( sfSource, AL_FREQUENCY, sfStream.Rate );
{$ELSE}
  sfBuffer.Play( 0, 0, DSBPLAY_LOOPING );
  sfBuffer.SetVolume( dsu_CalcVolume( sfVolume ) );
  sfBuffer.SetFrequency( sfStream.Rate );
{$ENDIF}

  sfStream.Played := TRUE;
  Thread := CreateThread( nil, 0, @snd_ProcFile, nil, 0, ThreadID );
end;

end.
