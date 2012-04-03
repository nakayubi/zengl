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
unit zgl_tiles_2d;

{$I zgl_config.cfg}

interface

uses
  zgl_types,
  zgl_fx,
  zgl_textures,
  zgl_math_2d;

type
  zglPTiles2D = ^zglTTiles2D;
  zglTTiles2D = record
    Count : record
      X, Y : Integer;
            end;
    Size  : record
      W, H : Single;
            end;
    Tiles : array of array of Integer;
  end;

procedure tiles2d_Draw( Texture : zglPTexture; X, Y : Single; Tiles : zglPTiles2D; Alpha : Byte = 255; FX : LongWord = FX_BLEND );

implementation
uses
  zgl_application,
  zgl_screen,
  zgl_direct3d,
  zgl_direct3d_all,
  zgl_render_2d,
  zgl_camera_2d;

const
  FLIP_TEXCOORD : array[ 0..3 ] of zglTTexCoordIndex = ( ( 0, 1, 2, 3 ), ( 1, 0, 3, 2 ), ( 3, 2, 1, 0 ), ( 2, 3, 0, 1 ) );

// TODO: rewrite the code with optimizations and fix for using with camera in some cases
procedure tiles2d_Draw( Texture : zglPTexture; X, Y : Single; Tiles : zglPTiles2D; Alpha : Byte = 255; FX : LongWord = FX_BLEND );
  var
    w, h, tX, tY, tU, tV, u, v   : Single;
    i, j, aI, aJ, bI, bJ : Integer;
    s, c, x1, y1, x2, y2, x3, y3, x4, y4 : Single;
    tc  : zglPTextureCoord;
    tci : zglPTexCoordIndex;
begin
  if ( not Assigned( Texture ) ) or ( not Assigned( Tiles ) ) Then exit;

  i := Round( Tiles.Size.W );
  j := Round( Tiles.Size.H );

  if X < 0 Then
    begin
      aI := Round( -X ) div i;
      bI := render2dClipW div i + aI;
    end else
      begin
        aI := 0;
        bI := render2dClipW div i - Round( X ) div i;
      end;

  if Y < 0 Then
    begin
      aJ := Round( -Y ) div j;
      bJ := render2dClipH div j + aJ;
    end else
      begin
        aJ := 0;
        bJ := render2dClipH div j - Round( Y ) div j;
      end;

  if not cam2d.OnlyXY Then
    begin
      tX := -cam2d.CX;
      tY := -cam2d.CY;
      tU := render2dClipW + tX;
      tV := render2dClipH + tY;
      u  := cam2d.CX;
      v  := cam2d.CY;

      m_SinCos( -cam2d.Global.Angle * deg2rad, s, c );

      x1 := tX * c - tY * s + u;
      y1 := tX * s + tY * c + v;
      x2 := tU * c - tY * s + u;
      y2 := tU * s + tY * c + v;
      x3 := tU * c - tV * s + u;
      y3 := tU * s + tV * c + v;
      x4 := tX * c - tV * s + u;
      y4 := tX * s + tV * c + v;

      if x1 > x2 Then tX := x2 else tX := x1;
      if tX > x3 Then tX := x3;
      if tX > x4 Then tX := x4;
      if y1 > y2 Then tY := y2 else tY := y1;
      if tY > y3 Then tY := y3;
      if tY > y4 Then tY := y4;
      if x1 < x2 Then tU := x2 else tU := x1;
      if tU < x3 Then tU := x3;
      if tU < x4 Then tU := x4;
      if y1 < y2 Then tV := y2 else tV := y1;
      if tV < y3 Then tV := y3;
      if tV < y4 Then tV := y4;

      DEC( aI, Round( -tX / i ) );
      INC( bI, Round( ( ( tU - render2dClipW ) ) / i ) );
      DEC( aJ, Round( -tY / j ) );
      INC( bJ, Round( ( tV - render2dClipH ) / j ) );

      x1 := cam2d.Global.X * c - cam2d.Global.Y * s;
      y1 := cam2d.Global.X * s + cam2d.Global.Y * c;
      INC( aI, Round( x1 / i ) - 1 );
      INC( bI, Round( x1 / i ) + 1 );
      INC( aJ, Round( y1 / j ) - 1 );
      INC( bJ, Round( y1 / j ) + 1 );
    end else
      begin
        if X >= 0 Then
          INC( aI, Round( ( cam2d.Global.X - X ) / i ) - 1 )
        else
          INC( aI, Round( cam2d.Global.X / i ) - 1 );
        INC( bI, Round( ( cam2d.Global.X ) / i ) + 1 );
        if Y >= 0 Then
          INC( aJ, Round( ( cam2d.Global.Y - Y ) / j ) - 1 )
        else
          INC( aJ, Round( cam2d.Global.Y / j ) - 1 );
        INC( bJ, Round( cam2d.Global.Y / j ) + 1 );
      end;

  if aI < 0 Then aI := 0;
  if aJ < 0 Then aJ := 0;
  if bI >= Tiles.Count.X Then bI := Tiles.Count.X - 1;
  if bJ >= Tiles.Count.Y Then bJ := Tiles.Count.Y - 1;

  if ( not b2dStarted ) or batch2d_Check( GL_QUADS, FX, Texture ) Then
    begin
      if FX and FX_BLEND > 0 Then
        glEnable( GL_BLEND )
      else
        glEnable( GL_ALPHA_TEST );
      glEnable( GL_TEXTURE_2D );
      glBindTexture( GL_TEXTURE_2D, Texture^.ID );

      glBegin( GL_QUADS );
    end;

  if FX and FX_COLOR > 0 Then
    begin
      fx2dAlpha^ := Alpha;
      glColor4ubv( @fx2dColor[ 0 ] );
    end else
      begin
        fx2dAlphaDef^ := Alpha;
        glColor4ubv( @fx2dColorDef[ 0 ] );
      end;

  tci := @FLIP_TEXCOORD[ FX and FX2D_FLIPX + FX and FX2D_FLIPY ];

  w := Tiles.Size.W;
  h := Tiles.Size.H;
  for i := aI to bI do
    for j := aJ to bJ do
      begin
        if ( Tiles.Tiles[ i, j ] < 1 ) or ( Tiles.Tiles[ i, j ] >= length( Texture.FramesCoord ) ) Then continue;
        tc := @Texture.FramesCoord[ Tiles.Tiles[ i, j ] ];

        glTexCoord2fv( @tc[ tci[ 0 ] ] );
        glVertex2f( x + i * w, y + j * h );

        glTexCoord2fv( @tc[ tci[ 1 ] ] );
        glVertex2f( x + i * w + w, y + j * h );

        glTexCoord2fv( @tc[ tci[ 2 ] ] );
        glVertex2f( x + i * w + w, y + j * h + h );

        glTexCoord2fv( @tc[ tci[ 3 ] ] );
        glVertex2f( x + i * w, y + j * h + h );
      end;

  if not b2dStarted Then
    begin
      glEnd();

      glDisable( GL_TEXTURE_2D );
      glDisable( GL_BLEND );
      glDisable( GL_ALPHA_TEST );
    end;
end;

end.
