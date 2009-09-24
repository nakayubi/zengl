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
unit zgl_render_target;

{$I zgl_config.cfg}

interface
uses
  Windows,
  {$IFDEF USE_DIRECT3D8}
  DirectXGraphics,
  {$ENDIF}
  {$IFDEF USE_DIRECT3D9}
  Direct3D9,
  {$ENDIF}
  zgl_direct3d,
  zgl_direct3d_all,
  zgl_textures;

const
  RT_TYPE_SIMPLE  = 0;
  RT_TYPE_FBO     = 1;
  RT_TYPE_PBUFFER = 2;
  RT_FULL_SCREEN  = $01;
  RT_CLEAR_SCREEN = $02;

  TEX_RESTORE     = $200000;

type
  zglPD3DTarget = ^zglTD3DTarget;
  zglTD3DTarget = record
    Old   : zglPTexture;
    {$IFDEF USE_DIRECT3D8}
    Depth : IDirect3DSurface8;
    {$ENDIF}
    {$IFDEF USE_DIRECT3D9}
    Depth : IDirect3DSurface9;
    {$ENDIF}
  end;

type
  zglPRenderTarget = ^zglTRenderTarget;
  zglTRenderTarget = record
    rtType  : Byte;
    Handle  : zglPD3DTarget;
    Surface : zglPTexture;
    Flags   : Byte;

    Prev, Next : zglPRenderTarget;
  end;

type
  zglPRenderTargetManager = ^zglTRenderTargetManager;
  zglTRenderTargetManager = record
    Count : DWORD;
    First : zglTRenderTarget;
  end;

type
  zglTRenderCallback = procedure( Data : Pointer );

function rtarget_Add( rtType : Byte; const Surface : zglPTexture; const Flags : Byte ) : zglPRenderTarget;
procedure rtarget_Del( var Target : zglPRenderTarget );
procedure rtarget_Set( const Target : zglPRenderTarget );
procedure rtarget_DrawIn( const Target : zglPRenderTarget; const RenderCallback : zglTRenderCallback; const Data : Pointer );

procedure rtarget_Save( const Target : zglPTexture );
procedure rtarget_Restore( const Target : zglPTexture );

var
  managerRTarget : zglTRenderTargetManager;
  lRTarget  : zglPRenderTarget;

implementation
uses
  zgl_main,
  zgl_application,
  zgl_screen,
  zgl_sprite_2d,
  zgl_render_2d,
  zgl_camera_2d;

var
  lCanDraw : Boolean;
  lCam2D   : Boolean;
  lPCam2D  : zglTCamera2D;
  lMode    : Integer;
  {$IFDEF USE_DIRECT3D8}
  lSurface : IDirect3DSurface8;
  {$ENDIF}
  {$IFDEF USE_DIRECT3D9}
  lSurface : IDirect3DSurface9;
  {$ENDIF}
  lTexture : zglPTexture;

procedure rtarget_Save;
  var
    i : Integer;
    s, d : TD3DSurface_Desc;
    {$IFDEF USE_DIRECT3D8}
    src, dst : IDirect3DSurface8;
    {$ENDIF}
    {$IFDEF USE_DIRECT3D9}
    src : IDirect3DSurface9;
    {$ENDIF}
begin
  d3d_resArray[ Target.ID ] := nil;
  {$IFDEF USE_DIRECT3D8}
  d3d_texArray[ Target.ID ].Texture.GetLevelDesc( 0, d );
  if Assigned( d3d_resArray[ Target.ID ] ) Then
    begin
      d3d_resArray[ Target.ID ].GetLevelDesc( 0, s );
      if ( s.Width < d.Width ) or ( s.Height < d.Height ) or ( s.Format <> d.Format ) Then
        d3d_resArray[ Target.ID ] := nil;
    end;
  if not Assigned( d3d_resArray[ Target.ID ] ) Then
    d3d_Device.CreateTexture( d.Width, d.Height, 1, 0, d.Format, D3DPOOL_MANAGED, d3d_resArray[ Target.ID ] );

  d3d_texArray[ Target.ID ].Texture.GetSurfaceLevel( 0, src );
  d3d_resArray[ Target.ID ].GetSurfaceLevel( 0, dst );
  d3d_Device.CopyRects( src, nil, 0, dst, nil );

  src := nil;
  dst := nil;
  {$ENDIF}
  {$IFDEF USE_DIRECT3D9}
  d3d_texArray[ Target.ID ].Texture.GetLevelDesc( 0, d );
  if Assigned( d3d_resArray[ Target.ID ] ) Then
    begin
      d3d_resArray[ Target.ID ].GetDesc( s );
      if ( s.Width < d.Width ) or ( s.Height < d.Height ) or ( s.Format <> d.Format ) Then
        d3d_resArray[ Target.ID ] := nil;
    end;
  if not Assigned( d3d_resArray[ Target.ID ] ) Then
    d3d_Device.CreateOffscreenPlainSurface( d.Width, d.Height, d.Format, D3DPOOL_SYSTEMMEM, d3d_resArray[ Target.ID ], 0 );

  d3d_texArray[ Target.ID ].Texture.GetSurfaceLevel( 0, src );
  d3d_Device.GetRenderTargetData( src, d3d_resArray[ Target.ID ] );

  src := nil;
  {$ENDIF}
end;

procedure rtarget_Restore;
  var
    {$IFDEF USE_DIRECT3D8}
    src, dst : IDirect3DSurface8;
    {$ENDIF}
    {$IFDEF USE_DIRECT3D9}
    dst : IDirect3DSurface9;
    {$ENDIF}
begin
  {$IFDEF USE_DIRECT3D8}
  d3d_texArray[ Target.ID ].Texture.GetSurfaceLevel( 0, dst );
  d3d_resArray[ Target.ID ].GetSurfaceLevel( 0, src );
  d3d_Device.CopyRects( src, nil, 0, dst, nil );

  src := nil;
  dst := nil;
  {$ENDIF}
  {$IFDEF USE_DIRECT3D9}
  d3d_texArray[ Target.ID ].Texture.GetSurfaceLevel( 0, dst );
  d3d_Device.UpdateSurface( d3d_resArray[ Target.ID ], nil, dst, nil );

  dst := nil;
  {$ENDIF}
end;

function rtarget_Add;
var
  fmt    : TD3DFormat;
  Handle : zglPTexture;
begin
  Result := @managerRTarget.First;
  while Assigned( Result.Next ) do
    Result := Result.Next;

  zgl_GetMem( Pointer( Result.Next ), SizeOf( zglTRenderTarget ) );
  zgl_GetMem( Pointer( Result.Next.Handle ), SizeOf( zglTD3DTarget ) );

  case rtType of
    RT_TYPE_SIMPLE, RT_TYPE_FBO, RT_TYPE_PBUFFER:
      begin
        if Surface.Flags and TEX_RGB > 0 Then
          fmt := D3DFMT_X8R8G8B8
        else
          fmt := D3DFMT_A8R8G8B8;

        rtarget_Save( Surface );
        d3d_texArray[ Surface.ID ].Texture := nil;
        {$IFDEF USE_DIRECT3D8}
        d3d_Device.CreateTexture( Round( Surface.Width / Surface.U ), Round( Surface.Height / Surface.V ), 1,
                                  D3DUSAGE_RENDERTARGET, fmt, D3DPOOL_DEFAULT,
                                  d3d_texArray[ Surface.ID ].Texture );
        d3d_Device.CreateDepthStencilSurface( Round( Surface.Width / Surface.U ), Round( Surface.Height / Surface.V ),
                                              d3d_Params.AutoDepthStencilFormat,
                                              D3DMULTISAMPLE_NONE, Result.Next.Handle.Depth );
        {$ENDIF}
        {$IFDEF USE_DIRECT3D9}
        d3d_Device.CreateTexture( Round( Surface.Width / Surface.U ), Round( Surface.Height / Surface.V ), 1,
                                  D3DUSAGE_RENDERTARGET, fmt, D3DPOOL_DEFAULT,
                                  d3d_texArray[ Surface.ID ].Texture, nil );
        d3d_Device.CreateDepthStencilSurface( Round( Surface.Width / Surface.U ), Round( Surface.Height / Surface.V ),
                                              d3d_Params.AutoDepthStencilFormat, D3DMULTISAMPLE_NONE, 0, TRUE,
                                              Result.Next.Handle.Depth, nil );
        {$ENDIF}
        rtarget_Restore( Surface );
      end;
  end;
  Result.Next.rtType     := rtType;
  Result.Next.Handle.Old := Surface;
  Result.Next.Surface    := Surface;
  Result.Next.Flags      := Flags;
  Result.Next.Prev       := Result;
  Result.Next.Next       := nil;
  Result                 := Result.Next;
  INC( managerRTarget.Count );
end;

procedure rtarget_Del;
begin
  if not Assigned( Target ) Then exit;

  tex_Del( Target.Surface );

  if Assigned( Target.Prev ) Then
    Target.Prev.Next := Target.Next;
  if Assigned( Target.Next ) Then
    Target.Next.Prev := Target.Prev;

  FreeMemory( Target.Handle );
  FreeMemory( Target );
  DEC( managerRTarget.Count );

  Target := nil;
end;

procedure rtarget_Set;
  var
    d      : TD3DSurface_Desc;
    addX   : Integer;
    sw, sh : Integer;
    tw, th : Integer;
    {$IFDEF USE_DIRECT3D8}
    src, dst : IDirect3DSurface8;
    {$ENDIF}
    {$IFDEF USE_DIRECT3D9}
    src, dst : IDirect3DSurface9;
    {$ENDIF}
begin
  batch2d_Flush;

  if Assigned( Target ) Then
    begin
      lCanDraw := d3d_CanDraw;
      d3d_BeginScene;
      lRTarget := Target;
      lMode    := ogl_Mode;
      ogl_Mode := 1;

      case Target.rtType of
        RT_TYPE_SIMPLE, RT_TYPE_FBO, RT_TYPE_PBUFFER:
          begin
            if Target.Surface <> Target.Handle.Old Then
              begin
                d3d_texArray[ Target.Surface.ID ].Texture.GetLevelDesc( 0, d );
                if d.Pool <> D3DPOOL_DEFAULT Then
                  begin
                    Target.Handle.Old := Target.Surface;
                    rtarget_Save( Target.Surface );
                    d3d_texArray[ Target.Surface.ID ].Texture := nil;
                    Target.Handle.Depth := nil;
                    {$IFDEF USE_DIRECT3D8}
                    d3d_Device.CreateTexture( d.Width, d.Height, 1,
                                              D3DUSAGE_RENDERTARGET, d.Format, D3DPOOL_DEFAULT,
                                              d3d_texArray[ Target.Surface.ID ].Texture );
                    d3d_Device.CreateDepthStencilSurface( d.Width, d.Height, d3d_Params.AutoDepthStencilFormat,
                                                          D3DMULTISAMPLE_NONE, Target.Handle.Depth );
                    {$ENDIF}
                    {$IFDEF USE_DIRECT3D9}
                    d3d_Device.CreateTexture( d.Width, d.Height, 1,
                                              D3DUSAGE_RENDERTARGET, d.Format, D3DPOOL_DEFAULT,
                                              d3d_texArray[ Target.Surface.ID ].Texture, nil );
                    d3d_Device.CreateDepthStencilSurface( d.Width, d.Height, d3d_Params.AutoDepthStencilFormat,
                                                          D3DMULTISAMPLE_NONE, 0, TRUE, Target.Handle.Depth, nil );
                    {$ENDIF}
                    rtarget_Restore( Target.Surface );
                  end;
              end;
            {$IFDEF USE_DIRECT3D8}
            d3d_Device.GetRenderTarget( d3d_Surface );
            d3d_Device.GetDepthStencilSurface( d3d_Stencil );
            d3d_texArray[ Target.Surface.ID ].Texture.GetSurfaceLevel( 0, lSurface );
            lTexture := Target.Surface;
            d3d_Device.SetRenderTarget( lSurface, Target.Handle.Depth );
            {$ENDIF}
            {$IFDEF USE_DIRECT3D9}
            d3d_Device.GetDepthStencilSurface( d3d_Stencil );
            d3d_Device.GetRenderTarget( 0, d3d_Surface );
            d3d_texArray[ Target.Surface.ID ].Texture.GetSurfaceLevel( 0, lSurface );
            lTexture := Target.Surface;
            d3d_Device.SetRenderTarget( 0, lSurface );
            d3d_Device.SetDepthStencilSurface( Target.Handle.Depth );
            {$ENDIF}
          end;
      end;
      if cam2dApply Then
        glPopMatrix;

      // O_o
      addX := Byte( scr_AddCX > 0 );
      sw := ( ogl_Width - scr_SubCX );
      sh := ( ogl_Height - scr_SubCY );
      tw := Round( Target.Surface.Width / Target.Surface.U );
      th := Round( Target.Surface.Height / Target.Surface.V );
      glScalef( 1, -1, 1 );
      if Target.Flags and RT_FULL_SCREEN > 0 Then
        begin
          glTranslatef( 0, -Target.Surface.Height - ( sh - Target.Surface.Height ), 0 );
          glViewPort( 0, 0, Target.Surface.Width + addX, Target.Surface.Height );
        end else
          begin
            glTranslatef( 0, -Target.Surface.Height, 0 );
            glViewPort( 0, 0, ogl_Width - scr_SubCX + addX, ogl_Height - scr_SubCY );
          end;
      if cam2dApply Then
        begin
          lPCam2D := cam2DGlobal^;
          cam2d_Apply( @lPCam2D );
        end;

      if Target.Flags and RT_CLEAR_SCREEN > 0 then
        d3d_Device.Clear( 0, nil, D3DCLEAR_TARGET, D3DCOLOR_ARGB( 0, 0, 0, 0 ), 1, 0 );
    end else
      begin
        case lRTarget.rtType of
          RT_TYPE_SIMPLE, RT_TYPE_FBO, RT_TYPE_PBUFFER:
            begin
              {$IFDEF USE_DIRECT3D8}
              d3d_Device.SetRenderTarget( d3d_Surface, d3d_Stencil );
              {$ENDIF}
              {$IFDEF USE_DIRECT3D9}
              d3d_Device.SetRenderTarget( 0, d3d_Surface );
              d3d_Device.SetDepthStencilSurface( d3d_Stencil );
              {$ENDIF}
              lSurface    := nil;
              d3d_Surface := nil;
              d3d_Stencil := nil;

              src := nil;
              dst := nil;
            end;
        end;

        lCam2D   := cam2dApply;
        lPCam2D  := cam2DGlobal^;
        ogl_Mode := lMode;
        lRTarget := nil;
        lTexture := nil;
        SetCurrentMode;
        scr_SetViewPort;
        if lCam2D Then
          cam2d_Apply( @lPCam2D );
        if not lCanDraw then
          d3d_EndScene;
      end;
end;

procedure rtarget_DrawIn;
begin
  if ogl_Separate or ( Target.Surface.Flags and TEX_RGB > 0 ) Then
    begin
      rtarget_Set( Target );
      RenderCallback( Data );
      rtarget_Set( nil );
    end else
      begin
        rtarget_Set( Target );

        glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
        glColorMask( GL_TRUE, GL_TRUE, GL_TRUE, GL_FALSE );
        RenderCallback( Data );
        batch2d_Flush;

        glBlendFunc( GL_ONE, GL_ONE_MINUS_SRC_ALPHA );
        glColorMask( GL_FALSE, GL_FALSE, GL_FALSE, GL_TRUE );
        RenderCallback( Data );
        batch2d_Flush;

        rtarget_Set( nil );

        glColorMask( GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE );
        glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
      end;
end;

end.
