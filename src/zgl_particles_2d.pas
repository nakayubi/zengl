{
 *  Copyright © Kemka Andrey aka Andru
 *  mail: dr.andru@gmail.com
 *  site: http://andru-kun.inf.ua
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
unit zgl_particles_2d;

{$I zgl_config.cfg}

interface
uses
  zgl_textures,
  zgl_math_2d,
  zgl_file,
  zgl_memory;

const
  ZGL_EMITTER_2D : array[ 0..14 ] of AnsiChar = ( 'Z', 'G', 'L', '_', 'E', 'M', 'I', 'T', 'T', 'E', 'R', '_', '2', 'D', #0 );

  ZEF_CHUNK_TYPE      = $01;
  ZEF_CHUNK_PARAMS    = $02;
  ZEF_CHUNK_TEXTURE   = $03;
  ZEF_CHUNK_BLENDMODE = $04;
  ZEF_CHUNK_COLORMODE = $05;
  ZEF_CHUNK_LIFETIME  = $06;
  ZEF_CHUNK_FRAME     = $07;
  ZEF_CHUNK_COLOR     = $08;
  ZEF_CHUNK_SIZEXY    = $09;
  ZEF_CHUNK_ANGLE     = $0A;
  ZEF_CHUNK_VELOCITY  = $0B;
  ZEF_CHUNK_AVELOCITY = $0C;
  ZEF_CHUNK_SPIN      = $0D;

  EMITTER_MAX_PARTICLES = 1024;

  EMITTER_NONE      = 0;
  EMITTER_POINT     = 1;
  EMITTER_LINE      = 2;
  EMITTER_RECTANGLE = 3;
  EMITTER_CIRCLE    = 4;

type
  PDiagramByte         = ^TDiagramByte;
  PDiagramLW           = ^TDiagramLW;
  PDiagramSingle       = ^TDiagramSingle;
  zglPParticle2D       = ^zglTParticle2D;
  zglPEmitterPoint     = ^zglTEmitterPoint;
  zglPEmitterLine      = ^zglTEmitterLine;
  zglPEmitterRect      = ^zglTEmitterRect;
  zglPParticleParams   = ^zglTParticleParams;
  zglPEmitter2D        = ^zglTEmitter2D;
  zglPPEngine2D        = ^zglTPEngine2D;
  zglPEmitter2DManager = ^zglTEmitter2DManager;

  TDiagramByte = record
    Life  : Single;
    Value : Byte;
  end;

  TDiagramLW = record
    Life  : Single;
    Value : LongWord;
  end;

  TDiagramSingle = record
    Life  : Single;
    Value : Single;
  end;

  zglTParticle2D = record
    _lColorID     : Integer;
    _lAlphaID     : Integer;
    _lSizeXID     : Integer;
    _lSizeYID     : Integer;
    _lVelocityID  : Integer;
    _laVelocityID : Integer;
    _lSpinID      : Integer;
    ID            : Integer;

    Life          : Single;
    LifeTime      : LongWord;
    Time          : Double;

    Frame         : Word;
    Color         : LongWord;
    Alpha         : Byte;

    Position      : zglTPoint2D;
    Size          : zglTPoint2D;
    SizeS         : zglTPoint2D;
    Angle         : Single;
    Direction     : Single;

    Velocity      : Single;
    VelocityS     : Single;
    aVelocity     : Single;
    aVelocityS    : Single;
    Spin          : Single;
  end;

  zglTEmitterPoint = record
    Direction : Single;
    Spread    : Single;
  end;

  zglTEmitterLine = record
    Direction : Single;
    Spread    : Single;
    Size      : Single;
    TwoSide   : Boolean;
  end;

  zglTEmitterRect = record
    Rect : zglTRect;
  end;

  zglPEmitterCircle = ^zglTEmitterCircle;
  zglTEmitterCircle = record
    cX, cY : Single;
    Radius : Single;
  end;

  zglTParticleParams = record
    Texture    : zglPTexture;
    BlendMode  : Byte;
    ColorMode  : Byte;

    LifeTimeS  : LongWord;
    LifeTimeV  : LongWord;
    Frame      : array[ 0..1 ] of LongWord;
    Color      : array of TDiagramLW;
    Alpha      : array of TDiagramByte;
    SizeXS     : Single;
    SizeYS     : Single;
    SizeXV     : Single;
    SizeYV     : Single;
    SizeXD     : array of TDiagramSingle;
    SizeYD     : array of TDiagramSingle;
    AngleS     : Single;
    AngleV     : Single;
    VelocityS  : Single;
    VelocityV  : Single;
    VelocityD  : array of TDiagramSingle;
    aVelocityS : Single;
    aVelocityV : Single;
    aVelocityD : array of TDiagramSingle;
    SpinS      : Single;
    SpinV      : Single;
    SpinD      : array of TDiagramSingle;
  end;

  zglTEmitter2D = record
    _type       : Byte;
    _pengine    : zglPPEngine2D;
    _particle   : array[ 0..EMITTER_MAX_PARTICLES - 1 ] of zglTParticle2D;
    _list       : array[ 0..EMITTER_MAX_PARTICLES - 1 ] of zglPParticle2D;
    _parCreated : LongWord;
    _texFile    : AnsiString;
    _texHash    : LongWord;

    ID          : Integer;
    Params      : record
      Layer    : LongWord;
      LifeTime : LongWord;
      Loop     : Boolean;
      Emission : LongWord;
      Position : zglTPoint2D;
                  end;
    ParParams   : zglTParticleParams;

    Life        : Single;
    Time        : Double;
    LastSecond  : Double;
    Particles   : LongWord;
    BBox        : record
      MinX, MaxX : Single;
      MinY, MaxY : Single;
                  end;

    case Byte of
      EMITTER_POINT: ( AsPoint : zglTEmitterPoint );
      EMITTER_LINE: ( AsLine : zglTEmitterLine );
      EMITTER_RECTANGLE: ( AsRect : zglTEmitterRect );
      EMITTER_CIRCLE: ( AsCircle : zglTEmitterCircle );
  end;

  zglTPEngine2D = record
    Count : record
      Emitters  : LongWord;
      Particles : LongWord;
            end;
    List  : array of zglPEmitter2D;
  end;

  zglTEmitter2DManager = record
    Count : LongWord;
    List  : array of zglPEmitter2D;
  end;

procedure pengine2d_Set( PEngine : zglPPEngine2D );
function  pengine2d_Get : zglPPEngine2D;
procedure pengine2d_Draw;
procedure pengine2d_Proc( dt : Double );
function  pengine2d_AddEmitter( Emitter : zglPEmitter2D; X : Single = 0; Y : Single = 0 ) : zglPEmitter2D;
procedure pengine2d_DelEmitter( ID : Integer );
procedure pengine2d_ClearAll;
function  pengine2d_LoadTexture( const FileName : AnsiString ) : zglPTexture;

procedure pengine2d_Sort( iLo, iHi : Integer );
procedure pengine2d_SortID( iLo, iHi : Integer );

function  emitter2d_Add : zglPEmitter2D;
procedure emitter2d_Del( var Emitter : zglPEmitter2D );

function emitter2d_Load : zglPEmitter2D;
function emitter2d_LoadFromFile( const FileName : String ) : zglPEmitter2D;
function emitter2d_LoadFromMemory( const Memory : zglTMemory ) : zglPEmitter2D;

procedure emitter2d_SaveToFile( Emitter : zglPEmitter2D; const FileName : String );

procedure emitter2d_Init( Emitter : zglPEmitter2D );
procedure emitter2d_Free( var Emitter : zglPEmitter2D );
procedure emitter2d_Draw( Emitter : zglPEmitter2D );
procedure emitter2d_Proc( Emitter : zglPEmitter2D; dt : Double );
procedure emitter2d_Sort( Emitter : zglPEmitter2D; iLo, iHi : Integer );

procedure particle2d_Proc( Particle : zglPParticle2D; Params : zglPParticleParams; dt : Double );

var
  managerEmitter2D : zglTEmitter2DManager;

implementation
uses
  zgl_main,
  zgl_log,
  zgl_opengl,
  zgl_opengl_all,
  zgl_fx,
  zgl_render_2d,
  zgl_utils;

var
  _pengine     : zglTPEngine2D;
  pengine2d    : zglPPEngine2D;
  emitter2dMem : zglTMemory;
  emitter2dID  : array[ 0..14 ] of AnsiChar;

procedure pengine2d_Set( PEngine : zglPPEngine2D );
begin
  if Assigned( PEngine ) Then
    pengine2d := PEngine
  else
    pengine2d := @_pengine;
end;

function pengine2d_Get : zglPPEngine2D;
begin
  Result := pengine2d;
end;

procedure pengine2d_Draw;
  var
    i : Integer;
begin
  for i := 0 to pengine2d.Count.Emitters - 1 do
    emitter2d_Draw( pengine2d.List[ i ] );
end;

procedure pengine2d_Proc( dt : Double );
  var
    i, a, b, l : Integer;
    e          : zglPEmitter2D;
begin
  i := 0;
  pengine2d.Count.Particles := 0;
  while i < pengine2d.Count.Emitters do
    begin
      e := pengine2d.List[ i ];
      emitter2d_Proc( e, dt );
      if ( e.Life <= 0 ) and ( not e.Params.Loop ) and ( e.Particles = 0 ) Then
        pengine2d_DelEmitter( i )
      else
        begin
          INC( i );
          INC( pengine2d.Count.Particles, e.Particles );
        end;
    end;

  if pengine2d.Count.Emitters > 1 Then
    begin
      l := 0;
      for i := 0 to pengine2d.Count.Emitters - 1 do
        begin
          e := pengine2d.List[ i ];
          if e.Params.Layer > l Then l := e.Params.Layer;
          if e.Params.Layer < l Then
            begin
              pengine2d_Sort( 0, pengine2d.Count.Emitters - 1 );
              // TODO: наверное сделать выбор вкл./выкл. устойчивой сортировки
              l := pengine2d.List[ 0 ].Params.Layer;
              a := 0;
              for b := 0 to pengine2d.Count.Emitters - 1 do
                begin
                  e := pengine2d.List[ b ];
                  if ( l <> e.Params.Layer ) Then
                    begin
                      pengine2d_SortID( a, b - 1 );
                      a := b;
                      l := e.Params.Layer;
                    end;
                  if b = pengine2d.Count.Emitters - 1 Then
                    pengine2d_SortID( a, b );
                end;
              for a := 0 to pengine2d.Count.Emitters - 1 do
                pengine2d.List[ a ].ID := a;
              break;
            end;
        end;
    end;
end;

function pengine2d_AddEmitter( Emitter : zglPEmitter2D; X : Single = 0; Y : Single = 0 ) : zglPEmitter2D;
  var
    new : zglPEmitter2D;
    len : Integer;
begin
  if pengine2d.Count.Emitters + 1 > length( pengine2d.List ) Then
    SetLength( pengine2d.List, length( pengine2d.List ) + 16384 );

  zgl_GetMem( Pointer( new ), SizeOf( zglTEmitter2D ) );
  pengine2d.List[ pengine2d.Count.Emitters ] := new;
  INC( pengine2d.Count.Emitters );

  Result := new;
  with Result^ do
    begin
      _type       := Emitter._type;
      _pengine    := pengine2d;
      _parCreated := Emitter._parCreated;
      _texFile    := Emitter._texFile;
      _texHash    := Emitter._texHash;
      ID          := pengine2d.Count.Emitters - 1;
      Params      := Emitter.Params;
      Life        := Emitter.Life;
      Time        := Emitter.Time;
      LastSecond  := Emitter.LastSecond;
      Particles   := Emitter.Particles;
      BBox        := Emitter.BBox;
      case Emitter._type of
        EMITTER_POINT:     AsPoint  := Emitter.AsPoint;
        EMITTER_LINE:      AsLine   := Emitter.AsLine;
        EMITTER_RECTANGLE: AsRect   := Emitter.AsRect;
        EMITTER_CIRCLE:    AsCircle := Emitter.AsCircle;
      end;
      with ParParams do
        begin
          Texture   := Emitter.ParParams.Texture;
          BlendMode := Emitter.ParParams.BlendMode;
          ColorMode := Emitter.ParParams.ColorMode;

          LifeTimeS := Emitter.ParParams.LifeTimeS;
          LifeTimeV := Emitter.ParParams.LifeTimeV;
          Frame     := Emitter.ParParams.Frame;

          len := length( Emitter.ParParams.Color );
          SetLength( Color, len );
          Move( Emitter.ParParams.Color[ 0 ], Color[ 0 ], len * SizeOf( Color[ 0 ] ) );

          len := length( Emitter.ParParams.Alpha );
          SetLength( Alpha, len );
          Move( Emitter.ParParams.Alpha[ 0 ], Alpha[ 0 ], len * SizeOf( Alpha[ 0 ] ) );

          SizeXS := Emitter.ParParams.SizeXS;
          SizeYS := Emitter.ParParams.SizeYS;
          SizeXV := Emitter.ParParams.SizeXV;
          SizeYV := Emitter.ParParams.SizeYV;

          len := length( Emitter.ParParams.SizeXD );
          SetLength( SizeXD, len );
          Move( Emitter.ParParams.SizeXD[ 0 ], SizeXD[ 0 ], len * SizeOf( SizeXD[ 0 ] ) );

          len := length( Emitter.ParParams.SizeYD );
          SetLength( SizeYD, len );
          Move( Emitter.ParParams.SizeYD[ 0 ], SizeYD[ 0 ], len * SizeOf( SizeYD[ 0 ] ) );

          AngleS    := Emitter.ParParams.AngleS;
          AngleV    := Emitter.ParParams.AngleV;
          VelocityS := Emitter.ParParams.VelocityS;
          VelocityV := Emitter.ParParams.VelocityV;

          len := length( Emitter.ParParams.VelocityD );
          SetLength( VelocityD, len );
          Move( Emitter.ParParams.VelocityD[ 0 ], VelocityD[ 0 ], len * SizeOf( VelocityD[ 0 ] ) );

          aVelocityS := Emitter.ParParams.aVelocityS;
          aVelocityV := Emitter.ParParams.aVelocityV;

          len := length( Emitter.ParParams.aVelocityD );
          SetLength( aVelocityD, len );
          Move( Emitter.ParParams.aVelocityD[ 0 ], aVelocityD[ 0 ], len * SizeOf( aVelocityD[ 0 ] ) );

          SpinS := Emitter.ParParams.SpinS;
          SpinV := Emitter.ParParams.SpinV;

          len := length( Emitter.ParParams.SpinD );
          SetLength( SpinD, len );
          Move( Emitter.ParParams.SpinD[ 0 ], SpinD[ 0 ], len * SizeOf( SpinD[ 0 ] ) );
        end;

      Params.Position.X := Params.Position.X + X;
      Params.Position.Y := Params.Position.Y + Y;
      Move( Emitter._particle[ 0 ], _particle[ 0 ], Emitter.Particles * SizeOf( zglTParticle2D ) );
    end;

  emitter2d_Init( Result );
end;

procedure pengine2d_DelEmitter( ID : Integer );
  var
    i : Integer;
begin
  if ( ID < 0 ) or ( ID > pengine2d.Count.Emitters - 1 ) or ( pengine2d.Count.Emitters = 0 ) Then exit;

  emitter2d_Free( pengine2d.List[ ID ] );
  pengine2d.List[ ID ] := nil;
  for i := ID to pengine2d.Count.Emitters - 2 do
    begin
      pengine2d.List[ i ]    := pengine2d.List[ i + 1 ];
      pengine2d.List[ i ].ID := i;
    end;

  DEC( pengine2d.Count.Emitters );
end;

procedure pengine2d_ClearAll;
  var
    i : Integer;
begin
  for i := 0 to pengine2d.Count.Emitters - 1 do
    emitter2d_Free( pengine2d.List[ i ] );
  SetLength( pengine2d.List, 0 );
  pengine2d.Count.Emitters := 0;
end;

function pengine2d_LoadTexture( const FileName : AnsiString ) : zglPTexture;
  var
    i    : Integer;
    hash : LongWord;
begin
  Result := nil;
  hash   := u_Hash( FileName );
  for i := 0 to pengine2d.Count.Emitters - 1 do
    if pengine2d.List[ i ]._texHash = hash Then
      begin
        Result := pengine2d.List[ i ].ParParams.Texture;
        break;
      end;

  if not Assigned( Result ) Then
    Result := tex_LoadFromFile( FileName );
end;

procedure pengine2d_Sort( iLo, iHi : Integer );
  var
    lo, hi, mid : Integer;
    t : zglPEmitter2D;
begin
  lo   := iLo;
  hi   := iHi;
  mid  := pengine2d.List[ ( lo + hi ) shr 1 ].Params.Layer;

  with pengine2d^ do
  repeat
    while List[ lo ].Params.Layer < mid do INC( lo );
    while List[ hi ].Params.Layer > mid do DEC( hi );
    if lo <= hi then
      begin
        t          := List[ lo ];
        List[ lo ] := List[ hi ];
        List[ hi ] := t;
        INC( lo );
        DEC( hi );
      end;
  until lo > hi;

  if hi > iLo Then pengine2d_Sort( iLo, hi );
  if lo < iHi Then pengine2d_Sort( lo, iHi );
end;

procedure pengine2d_SortID( iLo, iHi : Integer );
  var
    lo, hi, mid : Integer;
    t : zglPEmitter2D;
begin
  lo   := iLo;
  hi   := iHi;
  mid  := pengine2d.List[ ( lo + hi ) shr 1 ].ID;

  with pengine2d^ do
  repeat
    while List[ lo ].ID < mid do INC( lo );
    while List[ hi ].ID > mid do DEC( hi );
    if lo <= hi then
      begin
        t          := List[ lo ];
        List[ lo ] := List[ hi ];
        List[ hi ] := t;
        INC( lo );
        DEC( hi );
      end;
  until lo > hi;

  if hi > iLo Then pengine2d_SortID( iLo, hi );
  if lo < iHi Then pengine2d_SortID( lo, iHi );
end;

function emitter2d_Add : zglPEmitter2D;
begin
  if managerEmitter2D.Count + 1 > length( managerEmitter2D.List ) Then
    SetLength( managerEmitter2D.List, length( managerEmitter2D.List ) + 128 );

  zgl_GetMem( Pointer( Result ), SizeOf( zglTEmitter2D ) );
  managerEmitter2D.List[ managerEmitter2D.Count ] := Result;
  INC( managerEmitter2D.Count );

  emitter2d_Init( Result );
end;

procedure emitter2d_Del( var Emitter : zglPEmitter2D );
  var
    i, j : Integer;
begin
  for i := 0 to managerEmitter2D.Count - 1 do
    if managerEmitter2D.List[ i ] = Emitter Then
      begin
        emitter2d_Free( Emitter );
        managerEmitter2D.List[ i ] := nil;
        for j := i to managerEmitter2D.Count - 2 do
          managerEmitter2D.List[ i ] := managerEmitter2D.List[ i + 1 ];
      end;
end;

function emitter2d_Load : zglPEmitter2D;
  var
    c     : LongWord;
    chunk : Word;
    size  : LongWord;
begin
  Result := emitter2d_Add();
  with Result^ do
    while mem_Read( emitter2dMem, chunk, 2 ) > 0 do
      begin
        mem_Read( emitter2dMem, size, 4 );
        case chunk of
          ZEF_CHUNK_TYPE:
            begin
              mem_Read( emitter2dMem, _type, 1 );
              case _type of
                EMITTER_POINT: mem_Read( emitter2dMem, AsPoint, SizeOf( zglTEmitterPoint ) );
                EMITTER_LINE: mem_Read( emitter2dMem, AsLine, SizeOf( zglTEmitterLine ) );
                EMITTER_RECTANGLE: mem_Read( emitter2dMem, AsRect, SizeOf( zglTEmitterRect ) );
                EMITTER_CIRCLE: mem_Read( emitter2dMem, AsCircle, SizeOf( zglTEmitterCircle ) );
              else
                emitter2dMem.Position := emitter2dMem.Position + size - 1;
              end;
            end;
          ZEF_CHUNK_PARAMS:
            begin
              mem_Read( emitter2dMem, Params, size );
            end;
          ZEF_CHUNK_TEXTURE:
            begin
              mem_Read( emitter2dMem, Params, size );
              SetLength( _texFile, size );
              mem_Read( emitter2dMem, _texFile[ 1 ], size );
              _texHash := u_Hash( _texFile );
              ParParams.Texture := pengine2d_LoadTexture( _texFile );
            end;
          ZEF_CHUNK_BLENDMODE:
            begin
              mem_Read( emitter2dMem, ParParams.BlendMode, 1 );
            end;
          ZEF_CHUNK_COLORMODE:
            begin
              mem_Read( emitter2dMem, ParParams.ColorMode, 1 );
            end;
          ZEF_CHUNK_LIFETIME:
            begin
              mem_Read( emitter2dMem, ParParams.LifeTimeS, 4 );
              mem_Read( emitter2dMem, ParParams.LifeTimeV, 4 );
            end;
          ZEF_CHUNK_FRAME:
            begin
              mem_Read( emitter2dMem, ParParams.Frame[ 0 ], 8 );
            end;
          ZEF_CHUNK_COLOR:
            begin
              mem_Read( emitter2dMem, c, 4 );
              SetLength( ParParams.Color, c );
              mem_Read( emitter2dMem, ParParams.Color[ 0 ], SizeOf( TDiagramLW ) * c );

              mem_Read( emitter2dMem, c, 4 );
              SetLength( ParParams.Alpha, c );
              mem_Read( emitter2dMem, ParParams.Alpha[ 0 ], SizeOf( TDiagramByte ) * c );
            end;
          ZEF_CHUNK_SIZEXY:
            begin
              mem_Read( emitter2dMem, ParParams.SizeXS, 4 );
              mem_Read( emitter2dMem, ParParams.SizeYS, 4 );
              mem_Read( emitter2dMem, ParParams.SizeXV, 4 );
              mem_Read( emitter2dMem, ParParams.SizeYV, 4 );

              mem_Read( emitter2dMem, c, 4 );
              SetLength( ParParams.SizeXD, c );
              mem_Read( emitter2dMem, ParParams.SizeXD[ 0 ], SizeOf( TDiagramSingle ) * c );

              mem_Read( emitter2dMem, c, 4 );
              SetLength( ParParams.SizeYD, c );
              mem_Read( emitter2dMem, ParParams.SizeYD[ 0 ], SizeOf( TDiagramSingle ) * c );
            end;
          ZEF_CHUNK_ANGLE:
            begin
              mem_Read( emitter2dMem, ParParams.AngleS, 4 );
              mem_Read( emitter2dMem, ParParams.AngleV, 4 );
            end;
          ZEF_CHUNK_VELOCITY:
            begin
              mem_Read( emitter2dMem, ParParams.VelocityS, 4 );
              mem_Read( emitter2dMem, ParParams.VelocityV, 4 );

              mem_Read( emitter2dMem, c, 4 );
              SetLength( ParParams.VelocityD, c );
              mem_Read( emitter2dMem, ParParams.VelocityD[ 0 ], SizeOf( TDiagramSingle ) * c );
            end;
          ZEF_CHUNK_AVELOCITY:
            begin
              mem_Read( emitter2dMem, ParParams.aVelocityS, 4 );
              mem_Read( emitter2dMem, ParParams.aVelocityV, 4 );

              mem_Read( emitter2dMem, c, 4 );
              SetLength( ParParams.aVelocityD, c );
              mem_Read( emitter2dMem, ParParams.aVelocityD[ 0 ], SizeOf( TDiagramSingle ) * c );
            end;
          ZEF_CHUNK_SPIN:
            begin
              mem_Read( emitter2dMem, ParParams.SpinS, 4 );
              mem_Read( emitter2dMem, ParParams.SpinV, 4 );

              mem_Read( emitter2dMem, c, 4 );
              SetLength( ParParams.SpinD, c );
              mem_Read( emitter2dMem, ParParams.SpinD[ 0 ], SizeOf( TDiagramSingle ) * c );
            end;
        else
          emitter2dMem.Position := emitter2dMem.Position + size;
        end;
      end;
end;

function emitter2d_LoadFromFile( const FileName : String ) : zglPEmitter2D;
begin
  Result := nil;
  if not file_Exists( FileName ) Then
    begin
      log_Add( 'Cannot read "' + FileName + '"' );
      exit;
    end;

  mem_LoadFromFile( emitter2dMem, FileName );
  mem_Read( emitter2dMem, emitter2dID, 14 );
  if emitter2dID <> ZGL_EMITTER_2D Then
    log_Add( FileName + ' - it''s not a ZenGL Emitter 2D file' )
  else
    Result := emitter2d_Load();
  mem_Free( emitter2dMem );
end;

function emitter2d_LoadFromMemory( const Memory : zglTMemory ) : zglPEmitter2D;
begin
  emitter2dMem.Size     := Memory.Size;
  emitter2dMem.Memory   := Memory.Memory;
  emitter2dMem.Position := Memory.Position;

  mem_Read( emitter2dMem, emitter2dID, 14 );
  if emitter2dID <> ZGL_EMITTER_2D Then
    begin
      Result := nil;
      log_Add( 'Unable to determinate ZenGL Emitter 2D: From Memory' );
    end else
      Result := emitter2d_Load();
end;

procedure emitter2d_SaveToFile( Emitter : zglPEmitter2D; const FileName : String );
  var
    c : LongWord;
    f : zglTFile;
    chunk : Word;
    size  : LongWord;
begin
  if not Assigned( Emitter ) Then exit;

  file_Open( f, FileName, FOM_CREATE );
  file_Write( f, ZGL_EMITTER_2D, 14 );
  with Emitter^ do
    begin
      // ZEF_CHUNK_TYPE
      chunk := ZEF_CHUNK_TYPE;
      case _type of
        EMITTER_POINT: size := SizeOf( zglTEmitterPoint ) + 1;
        EMITTER_LINE: size := SizeOf( zglTEmitterLine ) + 1;
        EMITTER_RECTANGLE: size := SizeOf( zglTEmitterRect ) + 1;
        EMITTER_CIRCLE: size := SizeOf( zglTEmitterCircle ) + 1;
      end;
      file_Write( f, chunk, 2 );
      file_Write( f, size, 4 );

      file_Write( f, _type, 1 );
      file_Write( f, PByte( @AsPoint )^, size - 1 );

      // ZEF_CHUNK_PARAMS
      chunk := ZEF_CHUNK_PARAMS;
      size  := SizeOf( Params );
      file_Write( f, chunk, 2 );
      file_Write( f, size, 4 );

      file_Write( f, Params, SizeOf( Params ) );

      with ParParams do
        begin
          // ZEF_CHUNK_TEXTURE
          chunk := ZEF_CHUNK_TEXTURE;
          size  := length( Emitter._texFile );
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, Emitter._texFile[ 1 ], size );

          // ZEF_CHUNK_BLENDMODE
          chunk := ZEF_CHUNK_BLENDMODE;
          size  := 1;
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, BlendMode, 1 );

          // ZEF_CHUNK_COLORMODE
          chunk := ZEF_CHUNK_COLORMODE;
          size  := 1;
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, ColorMode, 1 );

          // ZEF_CHUNK_LIFETIME
          chunk := ZEF_CHUNK_LIFETIME;
          size  := 4 + 4;
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, LifeTimeS, 4 );
          file_Write( f, LifeTimeV, 4 );

          // ZEF_CHUNK_FRAME
          chunk := ZEF_CHUNK_FRAME;
          size  := 8;
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, Frame, 8 );

          // ZEF_CHUNK_COLOR
          chunk := ZEF_CHUNK_COLOR;
          size  := 4 + length( Color ) * SizeOf( TDiagramLW ) + 4 + length( Alpha ) * SizeOf( TDiagramByte );
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          c := length( Color );
          file_Write( f, c, 4 );
          file_Write( f, Color[ 0 ], SizeOf( TDiagramLW ) * c );

          c := length( Alpha );
          file_Write( f, c, 4 );
          file_Write( f, Alpha[ 0 ], SizeOf( TDiagramByte ) * c );

          // ZEF_CHUNK_SIZEXY
          chunk := ZEF_CHUNK_SIZEXY;
          size  := 4 + 4 + 4 + 4 + ( 4 + length( SizeXD ) * SizeOf( TDiagramSingle ) + 4 + length( SizeYD ) * SizeOf( TDiagramSingle ) );
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, SizeXS, 4 );
          file_Write( f, SizeYS, 4 );
          file_Write( f, SizeXV, 4 );
          file_Write( f, SizeYV, 4 );

          c := length( SizeXD );
          file_Write( f, c, 4 );
          file_Write( f, SizeXD[ 0 ], SizeOf( TDiagramSingle ) * c );

          c := length( SizeYD );
          file_Write( f, c, 4 );
          file_Write( f, SizeYD[ 0 ], SizeOf( TDiagramSingle ) * c );

          // ZEF_CHUNK_ANGLE
          chunk := ZEF_CHUNK_ANGLE;
          size  := 4 + 4;
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, AngleS, 4 );
          file_Write( f, AngleV, 4 );

          // ZEF_CHUNK_VELOCITY
          chunk := ZEF_CHUNK_VELOCITY;
          size  := 4 + 4 + ( 4 + length( VelocityD ) * SizeOf( TDiagramSingle ) );
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, VelocityS, 4 );
          file_Write( f, VelocityV, 4 );

          c := length( VelocityD );
          file_Write( f, c, 4 );
          file_Write( f, VelocityD[ 0 ], SizeOf( TDiagramSingle ) * c );

          // ZEF_CHUNK_AVELOCITY
          chunk := ZEF_CHUNK_AVELOCITY;
          size  := 4 + 4 + ( 4 + length( aVelocityD ) * SizeOf( TDiagramSingle ) );
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, aVelocityS, 4 );
          file_Write( f, aVelocityV, 4 );

          c := length( aVelocityD );
          file_Write( f, c, 4 );
          file_Write( f, aVelocityD[ 0 ], SizeOf( TDiagramSingle ) * c );

          // ZEF_CHUNK_SPIN
          chunk := ZEF_CHUNK_SPIN;
          size  := 4 + 4 + ( 4 + length( SpinD ) * SizeOf( TDiagramSingle ) );
          file_Write( f, chunk, 2 );
          file_Write( f, size, 4 );

          file_Write( f, SpinS, 4 );
          file_Write( f, SpinV, 4 );

          c := length( SpinD );
          file_Write( f, c, 4 );
          file_Write( f, SpinD[ 0 ], SizeOf( TDiagramSingle ) * c );
        end;
    end;

    file_Close( f );
end;

procedure emitter2d_Init( Emitter : zglPEmitter2D );
  var
    i : Integer;
begin
  for i := 0 to EMITTER_MAX_PARTICLES - 1 do
    with Emitter^ do
      begin
        _list[ i ]    := @_particle[ i ];
        _list[ i ].ID := i;
      end;
end;

procedure emitter2d_Free( var Emitter : zglPEmitter2D );
begin
  Emitter._texFile := '';
  with Emitter.ParParams do
    begin
      SetLength( Color, 0 );
      SetLength( Alpha, 0 );
      SetLength( SizeXD, 0 );
      SetLength( SizeYD, 0 );
      SetLength( VelocityD, 0 );
      SetLength( aVelocityD, 0 );
      SetLength( SpinD, 0 );
    end;
  FreeMem( Emitter );
  Emitter := nil;
end;

procedure emitter2d_Draw( Emitter : zglPEmitter2D );
  var
    i      : Integer;
    p      : zglPParticle2D;
    quad   : array[ 0..3 ] of zglTPoint2D;
    q      : zglPPoint2D;
    tc     : zglPTextureCoord;
    x1, x2 : Single;
    y1, y2 : Single;
    cX, cY : Single;
    c, s   : Single;
begin
  with Emitter.BBox do
    if not sprite2d_InScreen( MinX, MinY, MaxX - MinX, MaxY - MinY, 0 ) Then exit;

  with Emitter^ do
    begin
      fx_SetBlendMode( ParParams.BlendMode );
      fx_SetColorMode( ParParams.ColorMode );

      if ( not b2d_Started ) or batch2d_Check( GL_QUADS, FX_BLEND or FX_COLOR, ParParams.Texture ) Then
        begin
          glEnable( GL_BLEND );
          glEnable( GL_TEXTURE_2D );
          glBindTexture( GL_TEXTURE_2D, ParParams.Texture^.ID );

          glBegin( GL_QUADS );
        end;

      if length( ParParams.Color ) = 0 Then
        begin
          fx2d_SetColor( $FFFFFF );
          for i := 0 to Particles - 1 do
            begin
              p  := _list[ i ];
              tc := @ParParams.Texture.FramesCoord[ p.Frame ];

              if p.Angle <> 0 Then
                begin
                  x1 := -p.Size.X / 2;
                  y1 := -p.Size.Y / 2;
                  x2 := -x1;
                  y2 := -y1;
                  cX :=  p.Position.X;
                  cY :=  p.Position.Y;

                  m_SinCos( p.Angle * deg2rad, s, c );

                  q := @quad[ 0 ];
                  q.X := x1 * c - y1 * s + cX;
                  q.Y := x1 * s + y1 * c + cY;
                  INC( q );
                  q.X := x2 * c - y1 * s + cX;
                  q.Y := x2 * s + y1 * c + cY;
                  INC( q );
                  q.X := x2 * c - y2 * s + cX;
                  q.Y := x2 * s + y2 * c + cY;
                  INC( q );
                  q.X := x1 * c - y2 * s + cX;
                  q.Y := x1 * s + y2 * c + cY;
                end else
                  begin
                    x1 := p.Position.X - p.Size.X / 2;
                    y1 := p.Position.Y - p.Size.Y / 2;

                    q := @quad[ 0 ];
                    q.X := x1;
                    q.Y := y1;
                    INC( q );
                    q.X := x1 + p.Size.X;
                    q.Y := y1;
                    INC( q );
                    q.X := x1 + p.Size.X;
                    q.Y := y1 + p.Size.Y;
                    INC( q );
                    q.X := x1;
                    q.Y := y1 + p.Size.Y;
                  end;

              fx2dAlpha^ := p.Alpha;
              glColor4ubv( @fx2dColor[ 0 ] );

              glTexCoord2fv( @tc[ 0 ] );
              gl_Vertex2fv( @quad[ 0 ] );

              glTexCoord2fv( @tc[ 1 ] );
              gl_Vertex2fv( @quad[ 1 ] );

              glTexCoord2fv( @tc[ 2 ] );
              gl_Vertex2fv( @quad[ 2 ] );

              glTexCoord2fv( @tc[ 3 ] );
              gl_Vertex2fv( @quad[ 3 ] );
            end;
        end else
          for i := 0 to Particles - 1 do
            begin
              p  := _list[ i ];
              tc := @ParParams.Texture.FramesCoord[ p.Frame ];
              fx2d_SetColor( p.Color );

              if p.Angle <> 0 Then
                begin
                  x1 := -p.Size.X / 2;
                  y1 := -p.Size.Y / 2;
                  x2 := -x1;
                  y2 := -y1;
                  cX :=  p.Position.X;
                  cY :=  p.Position.Y;

                  m_SinCos( p.Angle * deg2rad, s, c );

                  q := @quad[ 0 ];
                  q.X := x1 * c - y1 * s + cX;
                  q.Y := x1 * s + y1 * c + cY;
                  INC( q );
                  q.X := x2 * c - y1 * s + cX;
                  q.Y := x2 * s + y1 * c + cY;
                  INC( q );
                  q.X := x2 * c - y2 * s + cX;
                  q.Y := x2 * s + y2 * c + cY;
                  INC( q );
                  q.X := x1 * c - y2 * s + cX;
                  q.Y := x1 * s + y2 * c + cY;
                end else
                  begin
                    x1 := p.Position.X - p.Size.X / 2;
                    y1 := p.Position.Y - p.Size.Y / 2;

                    q := @quad[ 0 ];
                    q.X := x1;
                    q.Y := y1;
                    INC( q );
                    q.X := x1 + p.Size.X;
                    q.Y := y1;
                    INC( q );
                    q.X := x1 + p.Size.X;
                    q.Y := y1 + p.Size.Y;
                    INC( q );
                    q.X := x1;
                    q.Y := y1 + p.Size.Y;
                  end;

              fx2dAlpha^ := p.Alpha;
              glColor4ubv( @fx2dColor[ 0 ] );

              glTexCoord2fv( @tc[ 0 ] );
              gl_Vertex2fv( @quad[ 0 ] );

              glTexCoord2fv( @tc[ 1 ] );
              gl_Vertex2fv( @quad[ 1 ] );

              glTexCoord2fv( @tc[ 2 ] );
              gl_Vertex2fv( @quad[ 2 ] );

              glTexCoord2fv( @tc[ 3 ] );
              gl_Vertex2fv( @quad[ 3 ] );
            end;

      if not b2d_Started Then
        begin
          glEnd();

          glDisable( GL_TEXTURE_2D );
          glDisable( GL_BLEND );
          glDisable( GL_ALPHA_TEST );
        end;
    end;
end;

procedure emitter2d_Proc( Emitter : zglPEmitter2D; dt : Double );
  var
    i        : Integer;
    p        : zglPParticle2D;
    parCount : LongWord;
    size     : Single;
begin
  with Emitter^ do
    begin
      BBox.MinX := Params.Position.X;
      BBox.MaxX := Params.Position.X;
      BBox.MinY := Params.Position.Y;
      BBox.MaxY := Params.Position.Y;

      i := 0;
      while i < Particles do
        begin
          particle2d_Proc( _list[ i ], @Emitter.ParParams, dt );
          if _list[ i ].Life = 0 Then
            begin
              p                      := _list[ i ];
              _list[ i ]             := _list[ Particles - 1 ];
              _list[ Particles - 1 ] := p;
              DEC( Particles );
            end else
              INC( i );
        end;
      if Particles > 2 Then
        emitter2d_Sort( Emitter, 0, Particles - 1 );

      Time := Time + dt;
      Life := Params.LifeTime - Time;
      if Life > 0 Then
        Life := 1 / Life;
      if ( Time >= Params.LifeTime ) and ( not Params.Loop ) Then
        exit;

      parCount    := Round( ( Time - LastSecond ) * ( Params.Emission / 1000 ) - _parCreated );
      _parCreated := _parCreated + parCount;

      for i := 0 to parCount - 1 do
        begin
          p := _list[ Particles ];
          p._lColorID := 1;
          p._lAlphaID := 1;
          p._lSizeXID := 1;
          p._lSizeYID := 1;

          p.Life       := 1;
          p.LifeTime   := ParParams.LifeTimeS + Random( ParParams.LifeTimeV ) - Round( ParParams.LifeTimeV / 2 );
          p.Time       := 0;
          p.Frame      := ParParams.Frame[ 0 ];
          if length( ParParams.Color ) > 0 Then
            p.Color    := ParParams.Color[ 0 ].Value
          else
            p.Color    := $FFFFFF;
          p.Alpha      := ParParams.Alpha[ 0 ].Value;
          p.SizeS.X    := ParParams.SizeXS + Random( Round( ParParams.SizeXV * 1000 ) ) / 1000 - ParParams.SizeXV / 2;
          p.SizeS.Y    := ParParams.SizeYS + Random( Round( ParParams.SizeYV * 1000 ) ) / 1000 - ParParams.SizeYV / 2;
          p.Size.X     := p.SizeS.X;
          p.Size.Y     := p.SizeS.Y;
          p.Angle      := ParParams.AngleS + Random( Round( ParParams.AngleV * 1000 ) ) / 1000 - ParParams.AngleV / 2;
          p.VelocityS  := ParParams.VelocityS + Random( Round( ParParams.VelocityV * 1000 ) ) / 1000 - ParParams.VelocityV / 2;
          p.Velocity   := p.VelocityS;
          p.aVelocityS := ParParams.aVelocityS + Random( Round( ParParams.aVelocityV * 1000 ) ) / 1000 - ParParams.aVelocityV / 2;
          p.aVelocity  := p.aVelocityS;
          p.Spin       := ParParams.SpinS + Random( Round( ParParams.SpinV * 1000 ) ) / 1000 - ParParams.SpinV / 2;

          case _type of
            EMITTER_POINT:
              begin
                p.Direction := AsPoint.Direction + AsPoint.Spread / 2 - Random( Round( AsPoint.Spread * 1000 ) ) / 1000;
                p.Position  := Params.Position;
              end;
            EMITTER_LINE:
              begin
                p.Direction  := AsLine.Direction + AsLine.Spread / 2 - Random( Round( AsLine.Spread * 1000 ) ) / 1000;
                p.Position.X := Params.Position.X + cos( AsLine.Direction + 90 * deg2rad ) * ( AsLine.Size / 2 - Random( Round( AsLine.Size * 1000 ) ) / 1000 );
                p.Position.Y := Params.Position.Y + sin( AsLine.Direction + 90 * deg2rad ) * ( AsLine.Size / 2 - Random( Round( AsLine.Size * 1000 ) ) / 1000 );
                if AsLine.TwoSide Then
                  p.Direction := p.Direction + 180 * ( Random( 2 ) - 1 ) * deg2rad;
              end;
            EMITTER_RECTANGLE:
              begin
                p.Position.X := Params.Position.X + AsRect.Rect.X + Random( Round( AsRect.Rect.W ) );
                p.Position.Y := Params.Position.Y + AsRect.Rect.Y + Random( Round( AsRect.Rect.H ) );
              end;
            EMITTER_CIRCLE:
              begin
                p.Position.X := Params.Position.X + AsCircle.cX + cos( Random( 360 ) * deg2rad ) * AsCircle.Radius;
                p.Position.Y := Params.Position.Y + AsCircle.cY + sin( Random( 360 ) * deg2rad ) * AsCircle.Radius;
              end;
          end;

          particle2d_Proc( p, @Emitter.ParParams, ( parCount - i ) * dt / parCount );
          INC( Particles );
        end;

        for i := 0 to Particles - 1 do
          begin
            p    := _list[ i ];
            size := ( p.Size.X + p.Size.Y ) / 2;
            if p.Position.X - size < Emitter.BBox.MinX Then
              Emitter.BBox.MinX := p.Position.X - size;
            if p.Position.X + size > Emitter.BBox.MaxX Then
              Emitter.BBox.MaxX := p.Position.X + size;
            if p.Position.Y - size < Emitter.BBox.MinY Then
              Emitter.BBox.MinY := p.Position.Y - size;
            if p.Position.Y + size > Emitter.BBox.MaxY Then
              Emitter.BBox.MaxY := p.Position.Y + size;
          end;

      if Time >= Params.LifeTime Then
        begin
          Time        := 0;
          LastSecond  := 0;
          _parCreated := 0;
        end;

      if Time - LastSecond >= 1000 Then
        begin
          _parCreated := 0;
          LastSecond  := Time;
        end;
    end;
end;

procedure emitter2d_Sort( Emitter : zglPEmitter2D; iLo, iHi : Integer );
  var
    lo, hi, mid : Integer;
    t           : zglPParticle2D;
begin
  lo   := iLo;
  hi   := iHi;
  mid  := Emitter._list[ ( lo + hi ) shr 1 ].ID;

  with Emitter^ do
    repeat
      while _list[ lo ].ID < mid do INC( lo );
      while _list[ hi ].ID > mid do DEC( hi );
      if lo <= hi then
        begin
          t           := _list[ lo ];
          _list[ lo ] := _list[ hi ];
          _list[ hi ] := t;
          INC( lo );
          DEC( hi );
        end;
    until lo > hi;

  if hi > iLo Then emitter2d_Sort( Emitter, iLo, hi );
  if lo < iHi Then emitter2d_Sort( Emitter, lo, iHi );
end;

procedure particle2d_Proc( Particle : zglPParticle2D; Params : zglPParticleParams; dt : Double );
  var
    coeff        : Single;
    speed        : Single;
    iLife        : Single;
    r, g, b      : Byte;
    rn, gn, bn   : Byte;
    rp, gp, bp   : Byte;
    prevB, nextB : PDiagramByte;
    prevL, nextL : PDiagramLW;
    prevS, nextS : PDiagramSingle;
begin
  with Particle^ do
    begin
      Time  := Time + dt;
      iLife := Time / LifeTime;
      Life  := 1 - iLife;
      if Life > 0 Then
        begin
          // Frame
          Frame := Params.Frame[ 0 ] + Round( ( Params.Frame[ 1 ] - Params.Frame[ 0 ] ) * iLife );

          // Color
          if length( Params.Color ) > 0 Then
            begin
              while iLife > Params.Color[ _lColorID ].Life do INC( _lColorID );
              prevL := @Params.Color[ _lColorID - 1 ];
              nextL := @Params.Color[ _lColorID ];
              coeff := ( iLife - prevL.Life ) / ( nextL.Life - prevL.Life );
              rn    :=   nextL.Value             shr 16;
              gn    := ( nextL.Value and $FF00 ) shr 8;
              bn    :=   nextL.Value and $FF;
              rp    :=   prevL.Value             shr 16;
              gp    := ( prevL.Value and $FF00 ) shr 8;
              bp    :=   prevL.Value and $FF;
              r     := rp + Round( ( rn - rp ) * coeff );
              g     := gp + Round( ( gn - gp ) * coeff );
              b     := bp + Round( ( bn - bp ) * coeff );
              Color := r shl 16 + g shl 8 + b;
            end else
              Color := $FFFFFF;

          // Alpha
          while iLife > Params.Alpha[ _lAlphaID ].Life do INC( _lAlphaID );
          prevB := @Params.Alpha[ _lAlphaID - 1 ];
          nextB := @Params.Alpha[ _lAlphaID ];
          Alpha := prevB.Value + Round( ( nextB.Value - prevB.Value ) * ( iLife - prevB.Life ) / ( nextB.Life - prevB.Life ) );

          // Size
          while iLife > Params.SizeXD[ _lSizeXID ].Life do INC( _lSizeXID );
          while iLife > Params.SizeYD[ _lSizeYID ].Life do INC( _lSizeYID );
          prevS  := @Params.SizeXD[ _lSizeXID - 1 ];
          nextS  := @Params.SizeXD[ _lSizeXID ];
          Size.X := SizeS.X * ( prevS.Value + ( nextS.Value - prevS.Value ) * ( iLife - prevS.Life ) / ( nextS.Life - prevS.Life ) );
          prevS  := @Params.SizeYD[ _lSizeYID - 1 ];
          nextS  := @Params.SizeYD[ _lSizeYID ];
          Size.Y := SizeS.Y * ( prevS.Value + ( nextS.Value - prevS.Value ) * ( iLife - prevS.Life ) / ( nextS.Life - prevS.Life ) );

          // Velocity
          while iLife > Params.VelocityD[ _lVelocityID ].Life do INC( _lVelocityID );
          prevS      := @Params.VelocityD[ _lVelocityID - 1 ];
          nextS      := @Params.VelocityD[ _lVelocityID ];
          Velocity   := VelocityS * ( prevS.Value + ( nextS.Value - prevS.Value ) * ( iLife - prevS.Life ) / ( nextS.Life - prevS.Life ) );
          coeff      := dt / 1000;
          speed      := Velocity * coeff;
          Direction  := Direction + aVelocity * coeff;
          Position.X := Position.X + cos( Direction ) * speed;
          Position.Y := Position.Y + sin( Direction ) * speed;

          // Angular Velocity
          while iLife > Params.aVelocityD[ _laVelocityID ].Life do INC( _laVelocityID );
          prevS     := @Params.aVelocityD[ _laVelocityID - 1 ];
          nextS     := @Params.aVelocityD[ _laVelocityID ];
          aVelocity := aVelocityS * ( prevS.Value + ( nextS.Value - prevS.Value ) * ( iLife - prevS.Life ) / ( nextS.Life - prevS.Life ) );

          // Spin
          while iLife > Params.SpinD[ _lSpinID ].Life do INC( _lSpinID );
          prevS := @Params.SpinD[ _lSpinID - 1 ];
          nextS := @Params.SpinD[ _lSpinID ];
          Angle := Angle + Spin * ( prevS.Value + ( nextS.Value - prevS.Value ) * ( iLife - prevS.Life ) / ( nextS.Life - prevS.Life ) ) * coeff * rad2deg;
        end else
          Life := 0;
    end;
end;

initialization
  pengine2d := @_pengine;

end.
