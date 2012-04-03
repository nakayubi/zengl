{
 *  Copyright © Kemka Andrey aka Andru
 *  mail: dr.andru@gmail.com
 *  site: http://zengl.org
 *
 *  This file is part of ZenGL.
 *
 *  ZenGL is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as
 *  published by the Free Software Foundation, either version 3 of
 *  the License, or (at your option) any later version.
 *
 *  ZenGL is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with ZenGL. If not, see http://www.gnu.org/licenses/
}
unit zgl_sound_openal;

{$I zgl_config.cfg}

interface

const
  libopenal = 'openal32.dll';

  ALC_DEFAULT_DEVICE_SPECIFIER              =$1004;
  ALC_DEVICE_SPECIFIER                      =$1005;

  AL_NONE                                   = 0;
  AL_FALSE                                  = 0;
  AL_TRUE                                   = 1;
  AL_NO_ERROR                               = 0;

  //Sound samples: format specifier.
  AL_FORMAT_MONO8                           =$1100;
  AL_FORMAT_MONO16                          =$1101;
  AL_FORMAT_STEREO8                         =$1102;
  AL_FORMAT_STEREO16                        =$1103;

  //Source state information.
  AL_SOURCE_STATE                           =$1010;
  AL_INITIAL                                =$1011;
  AL_PLAYING                                =$1012;
  AL_PAUSED                                 =$1013;
  AL_STOPPED                                =$1014;

  AL_BUFFER                                 =$1009;
  AL_BUFFERS_PROCESSED                      =$1016;

  AL_POSITION                               =$1004;
  AL_DIRECTION                              =$1005;
  AL_VELOCITY                               =$1006;
  AL_ORIENTATION                            =$100F;

  AL_PITCH                                  =$1003;
  AL_LOOPING                                =$1007;
  AL_GAIN                                   =$100A;
  AL_FREQUENCY                              =$2001;

function  InitOpenAL : Boolean;
procedure FreeOpenAL;

function oal_GetSource( Source : Pointer ) : LongWord;

type
  PALCdevice = ^ALCdevice;
  ALCdevice  = record
end;

type
  PALCcontext = ^ALCcontext;
  ALCcontext  = record
end;

var
  oalLibrary : LongWord;

  alcGetString           : function(device: PALCdevice; param: LongInt): PAnsiChar; cdecl;
  alGetError             : function(device: PALCdevice): LongInt; cdecl;
  // Device
  alcOpenDevice          : function(const devicename: PAnsiChar): PALCdevice; cdecl;
  alcCloseDevice         : function(device: PALCdevice): Boolean; cdecl;
  // Context
  alcCreateContext       : function(device: PALCdevice; const attrlist: PLongInt): PALCcontext; cdecl;
  alcMakeContextCurrent  : function(context: PALCcontext): Boolean; cdecl;
  alcDestroyContext      : procedure(context: PALCcontext); cdecl;
  // Listener
  alListenerfv           : procedure(param: LongInt; const values: PSingle); cdecl;
  // Sources
  alGenSources           : procedure(n: LongInt; sources: PLongWord); cdecl;
  alDeleteSources        : procedure(n: LongInt; const sources: PLongWord); cdecl;
  alSourcei              : procedure(sid: LongWord; param: LongInt; value: LongInt); cdecl;
  alSourcef              : procedure(sid: LongWord; param: LongInt; value: Single); cdecl;
  alSourcefv             : procedure(sid: LongWord; param: LongInt; const values: PSingle); cdecl;
  alGetSourcei           : procedure(sid: LongWord; param: LongInt; out value: LongInt); cdecl;
  alSourcePlay           : procedure(sid: LongWord); cdecl;
  alSourcePause          : procedure(sid: LongWord); cdecl;
  alSourceStop           : procedure(sid: LongWord); cdecl;
  alSourceRewind         : procedure(sid: LongWord); cdecl;
  //
  alSourceQueueBuffers   : procedure(sid: LongWord; numEntries: LongInt; const bids: PLongWord); cdecl;
  alSourceUnqueueBuffers : procedure(sid: LongWord; numEntries: LongInt; bids: PLongWord); cdecl;
  // Buffers
  alGenBuffers           : procedure(n: LongInt; buffers: PLongWord); cdecl;
  alDeleteBuffers        : procedure(n: LongInt; const buffers: PLongWord); cdecl;
  alBufferData           : procedure(bid: LongWord; format: LongInt; data: Pointer; size: LongInt; freq: LongInt); cdecl;

  oalDevice   : PALCdevice  = nil;
  oalContext  : PALCcontext = nil;
  oalSources  : array of LongWord;
  oalSrcPtrs  : array of Pointer;
  oalSrcState : array of LongWord;

  oalPosition    : array[ 0..2 ] of Single = ( 0.0, 0.0, 0.0);
  oalVelocity    : array[ 0..2 ] of Single = ( 0.0, 0.0, 0.0 );
  oalOrientation : array[ 0..5 ] of Single = ( 0.0, 0.0, -1.0, 0.0, 1.0, 0.0 );

  oalFormat  : array[ 1..2 ] of LongInt = ( AL_FORMAT_MONO16, AL_FORMAT_STEREO16 );

implementation
uses
  zgl_utils;

function InitOpenAL : Boolean;
begin
  Result := FALSE;
  oalLibrary := dlopen( libopenal );

  if oalLibrary <> LIB_ERROR Then
    begin
      alcGetString           := dlsym( oalLibrary, 'alcGetString' );
      alcOpenDevice          := dlsym( oalLibrary, 'alcOpenDevice' );
      alcCloseDevice         := dlsym( oalLibrary, 'alcCloseDevice' );
      alcCreateContext       := dlsym( oalLibrary, 'alcCreateContext' );
      alcMakeContextCurrent  := dlsym( oalLibrary, 'alcMakeContextCurrent' );
      alcDestroyContext      := dlsym( oalLibrary, 'alcDestroyContext' );
      alGetError             := dlsym( oalLibrary, 'alGetError' );
      alListenerfv           := dlsym( oalLibrary, 'alListenerfv' );
      alGenSources           := dlsym( oalLibrary, 'alGenSources' );
      alDeleteSources        := dlsym( oalLibrary, 'alDeleteSources' );
      alSourcei              := dlsym( oalLibrary, 'alSourcei' );
      alSourcef              := dlsym( oalLibrary, 'alSourcef' );
      alSourcefv             := dlsym( oalLibrary, 'alSourcefv' );
      alGetSourcei           := dlsym( oalLibrary, 'alGetSourcei' );
      alSourcePlay           := dlsym( oalLibrary, 'alSourcePlay' );
      alSourcePause          := dlsym( oalLibrary, 'alSourcePause' );
      alSourceStop           := dlsym( oalLibrary, 'alSourceStop' );
      alSourceRewind         := dlsym( oalLibrary, 'alSourceRewind' );
      alSourceQueueBuffers   := dlsym( oalLibrary, 'alSourceQueueBuffers' );
      alSourceUnqueueBuffers := dlsym( oalLibrary, 'alSourceUnqueueBuffers' );
      alGenBuffers           := dlsym( oalLibrary, 'alGenBuffers' );
      alDeleteBuffers        := dlsym( oalLibrary, 'alDeleteBuffers' );
      alBufferData           := dlsym( oalLibrary, 'alBufferData' );

      Result := TRUE;
    end else
      Result := FALSE;
end;

procedure FreeOpenAL;
begin
  dlclose( oalLibrary );
end;

function oal_GetSource( Source : Pointer ) : LongWord;
  var
    i, state : Integer;
begin
  Result := 0;
  for i := 0 to length( oalSources ) - 1 do
    begin
      alGetSourcei( oalSources[ i ], AL_SOURCE_STATE, state );
      if state <> AL_PLAYING Then
        begin
          if Assigned( oalSrcPtrs[ i ] ) Then
            LongWord( oalSrcPtrs[ i ]^ ) := 0;
          oalSrcPtrs[ i ] := Source;
          Result := oalSources[ i ];
          break;
        end;
    end;
end;

end.
