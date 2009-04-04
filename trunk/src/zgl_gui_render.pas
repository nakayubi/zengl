{
 * Copyright © Kemka Andrey aka Andru
 * mail: dr.andru@gmail.com
 * site: http://andru-kun.ru
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
unit zgl_gui_render;

{$I zgl_config.cfg}

interface
uses
  zgl_gui_types;

const
  COLOR_WINDOW = $646866;
  COLOR_WIDGET = $424644;
  COLOR_LIGHT  = $BBBBBB;
  COLOR_DARK   = $202422;
  COLOR_EDIT   = $36342E;
  COLOR_SELECT = $DBB095;

  SCROLL_SIZE  = 16;

procedure gui_DrawWidget( const Widget : zglPWidget );

procedure gui_DrawButton     ( const Widget : zglPWidget );
procedure gui_DrawCheckBox   ( const Widget : zglPWidget );
procedure gui_DrawRadioButton( const Widget : zglPWidget );
procedure gui_DrawLabel      ( const Widget : zglPWidget );
procedure gui_DrawEditBox    ( const Widget : zglPWidget );
procedure gui_DrawListBox    ( const Widget : zglPWidget );
procedure gui_DrawGroupBox   ( const Widget : zglPWidget );
procedure gui_DrawSpin       ( const Widget : zglPWidget );

implementation
uses
  zgl_types,
  zgl_opengl_all,
  zgl_opengl_simple,
  zgl_mouse,
  zgl_primitives_2d,
  zgl_text,
  zgl_gui_main,
  zgl_math_2d,
  zgl_collision_2d;

procedure _button_draw( const x, y, w, h : Single; const pressed : Boolean );
  var
    color : DWORD;
begin
  color := COLOR_WIDGET;
  pr2d_Rect( x, y, w, h, color, 255, PR2D_FILL );
  pr2d_Rect( x, y, w, h, $000000, 255, 0 );

  color := COLOR_LIGHT;
  if pressed Then color := COLOR_DARK;
  pr2d_Line( x + 1, y + 1, x + w - 2, y + 1, color, 255, 0 );
  pr2d_Line( x + 1, y + 1, x + 1, y + h - 2, color, 255, 0 );
  color := COLOR_DARK;
  if pressed Then color := COLOR_LIGHT;
  pr2d_Line( x + 1, y + h - 2, x + w - 2, y + h - 2, color, 255, 0 );
  pr2d_Line( x + w - 2, y + 1, x + w - 2, y + h - 2, color, 255, 0 );
  if pressed Then
    pr2d_Rect( X, Y, W, H, COLOR_SELECT, 25, PR2D_FILL );
end;

procedure _scroll_draw( const x, y, h : Single; const UPressed, DPressed : Boolean );
  var
    sy : Single;
begin
  _button_draw( X, Y + SCROLL_SIZE, SCROLL_SIZE, h - SCROLL_SIZE * 2, false );
  _button_draw( X, Y, SCROLL_SIZE, SCROLL_SIZE, UPressed );
  glColor4f( 0, 0, 0, 1 );
  glBegin( GL_TRIANGLES );
    gl_Vertex2f( X + SCROLL_SIZE / 2 + Byte( UPressed ), Y + 2 + Byte( UPressed ) );
    gl_Vertex2f( X + SCROLL_SIZE - 2 + Byte( UPressed ), Y + SCROLL_SIZE - 2 + Byte( UPressed ) );
    gl_Vertex2f( X + 2 + Byte( UPressed ),               Y + SCROLL_SIZE - 2 + Byte( UPressed ) );
  glEnd;
  _button_draw( X, Y + H - SCROLL_SIZE, SCROLL_SIZE, SCROLL_SIZE, DPressed );
  sy := Y + H - SCROLL_SIZE;
  glColor4f( 0, 0, 0, 1 );
  glBegin( GL_TRIANGLES );
    gl_Vertex2f( X + 2 + Byte( DPressed ),               sy + 2 + Byte( DPressed ) );
    gl_Vertex2f( X + SCROLL_SIZE - 2 + Byte( DPressed ), sy + 2 + Byte( DPressed ) );
    gl_Vertex2f( X + SCROLL_SIZE / 2 + Byte( DPressed ), sy + SCROLL_SIZE - 2 + Byte( DPressed ) );
  glEnd;
end;

procedure _clip( const widget : zglPWidget ); overload;
  var
    clip : zglTRect;
begin
  clip := col2d_ClipRect( widget.rect, widget.parent.rect );
  scissor_Begin( Round( clip.X + 2 ), Round( clip.Y + 2 ), Round( clip.W - 4 ), Round( clip.H - 4 ) );
end;

procedure _clip( const widget : zglPWidget; const X, Y, W, H : Single ); overload;
  var
    clip : zglTRect;
begin
  clip.X := X;
  clip.Y := Y;
  clip.W := W;
  clip.H := H;
  clip := col2d_ClipRect( clip, widget.parent.rect );
  scissor_Begin( Round( clip.X + 2 ), Round( clip.Y + 2 ), Round( clip.W - 4 ), Round( clip.H - 4 ) );
end;

procedure gui_DrawWidget;
  var
    w : zglPWidget;
begin
  if not Assigned( Widget ) Then exit;

  if Assigned( Widget.OnDraw ) Then Widget.OnDraw( Widget );
  if Assigned( Widget.child ) Then
    begin
      w := Widget.child;
      repeat
        _clip( w.parent );
        w := w.Next;
        gui_DrawWidget( w );
        scissor_End;
      until not Assigned( w.Next );
    end;
end;

procedure gui_DrawButton;
begin
  with zglTButtonDesc( Widget.desc^ ), Widget.rect do
    begin
      _button_draw( X, Y, W, H, Pressed );

      if Widget.focus Then
        pr2d_Rect( X - 1, Y - 1, W + 2, H + 2, COLOR_SELECT, 155 );

      _clip( Widget );
      text_Draw( Font, Round( X + ( W - text_GetWidth( Font, Caption ) ) / 2 ) + Byte( Pressed ),
                       Round( Y + ( H - Font.MaxHeight ) / 2 ) + Byte( Pressed ), Caption );
      scissor_End;
    end;
end;

procedure gui_DrawCheckBox;
begin
  with zglTCheckBoxDesc( Widget.desc^ ), Widget.rect do
    begin
      pr2d_Rect( X, Y, W, H, COLOR_WIDGET, 255, PR2D_FILL );
      pr2d_Rect( X, Y, W, H, $000000, 255, 0 );
      if Widget.mousein Then
        pr2d_Rect( X + 1, Y + 1, W - 2, H - 2, COLOR_SELECT, 55, PR2D_FILL );
      if Checked Then
        pr2d_Rect( X + 3, Y + 3, W - 6, H - 6, $000000, 255, PR2D_FILL );
      if Widget.focus Then
        pr2d_Rect( X - 1, Y - 1, W + 2, H + 2, COLOR_SELECT, 155 );

      text_Draw( Font, X + W + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Round( Y + ( H - Font.MaxHeight ) / 2 ), Caption );
    end;
end;

procedure gui_DrawRadioButton;
begin
  with zglTRadioButtonDesc( Widget.desc^ ), Widget.rect do
    begin
      pr2d_Circle( X + W / 2, Y + H / 2, W / 2, COLOR_WIDGET, 255, 8, PR2D_FILL );
      pr2d_Circle( X + W / 2, Y + H / 2, W / 2, $000000, 255, 8 );
      if Widget.mousein Then
        pr2d_Circle( X + W / 2, Y + H / 2, W / 2 - 1, COLOR_SELECT, 55, 8, PR2D_FILL );
      if Checked Then
        pr2d_Circle( X + W / 2, Y + H / 2, W / 3, $000000, 255, 8, PR2D_FILL );
      if Widget.focus Then
        pr2d_Circle( X + W / 2, Y + H / 2, W / 2 + 1, COLOR_SELECT, 155, 8 );

      text_Draw( Font, X + W + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Round( Y + ( H - Font.MaxHeight ) / 2 ), Caption );
    end;
end;

procedure gui_DrawLabel;
begin
  with zglTCheckBoxDesc( Widget.desc^ ), Widget.rect do
    text_Draw( Font, X, Y, Caption );
end;

procedure gui_DrawEditBox;
  var
    tw, th : Single;
begin
  with zglTEditBoxDesc( Widget.desc^ ), Widget.rect do
    begin
      pr2d_Rect( X, Y, W, H, COLOR_EDIT, 255, PR2D_FILL );
      pr2d_Rect( X, Y, W, H, COLOR_WIDGET, 255, 0 );
      pr2d_Rect( X + 1, Y + 1, W - 2, H - 2, $000000, 255, 0 );
      if Widget.mousein Then
        pr2d_Rect( X + 1, Y + 1, W - 2, H - 2, COLOR_SELECT, 55, PR2D_FILL );
      if Widget.focus Then
        pr2d_Rect( X, Y, W, H, COLOR_SELECT, 155 );

      _clip( Widget );
      th := Y + Round( ( H - Font.MaxHeight ) / 2 ) + 1;
      text_Draw( Font, X + Font.CharDesc[ Byte( ' ' ) ].ShiftP, th, Text );

      if Widget.focus Then
        begin
          tw := X + Font.CharDesc[ Byte( ' ' ) ].ShiftP + text_GetWidth( Font, Text );
          pr2d_Line( tw, th, tw, th + Font.MaxHeight - Font.MaxShiftY, $FFFFFF, 255 * Byte( cursorAlpha < 25 ) );
        end;
      scissor_End;
    end;
end;

procedure gui_DrawListBox;
  var
    i      : Integer;
    sx, sy : Single;
    tb, bb : zglTRect;
begin
  with zglTListBoxDesc( Widget.desc^ ), Widget.rect do
    begin
      pr2d_Rect( X, Y, W - SCROLL_SIZE - 1, H, COLOR_EDIT, 255, PR2D_FILL );
      pr2d_Rect( X, Y, W - SCROLL_SIZE - 1, H, COLOR_WIDGET, 255, 0 );
      pr2d_Rect( X + 1, Y + 1, W - 2 - SCROLL_SIZE - 1, H - 2, $000000, 255, 0 );
      if Widget.focus Then
        pr2d_Rect( X, Y, W - SCROLL_SIZE - 1, H, COLOR_SELECT, 155 );

      tb.X := X + W - SCROLL_SIZE;
      tb.Y := Y;
      tb.W := SCROLL_SIZE;
      tb.H := SCROLL_SIZE;
      bb.X := X + W - SCROLL_SIZE;
      bb.Y := Y + H - SCROLL_SIZE;
      bb.W := SCROLL_SIZE;
      bb.H := SCROLL_SIZE;
      _scroll_draw( X + W - SCROLL_SIZE, Y, H,
                    col2d_PointInRect( mouse_X, mouse_Y, tb ) and mouse_Down( M_BLEFT ),
                    col2d_PointInRect( mouse_X, mouse_Y, bb ) and mouse_Down( M_BLEFT ) );

      _clip( Widget, X, Y, W - SCROLL_SIZE - 1, H );
      for i := 0 to List.Count - 1 do
        text_Draw( Font, X + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Y + i * Font.MaxHeight + i * 3 + 3, List.Items[ i ] );

      if ItemIndex > -1 Then
        begin
          pr2d_Rect( X + 2, Y + 3 + ItemIndex * Font.MaxHeight + ItemIndex * 3,
                     W - 4 - SCROLL_SIZE - 1, Font.MaxHeight, COLOR_SELECT, 55, PR2D_FILL );
          pr2d_Rect( X + 2, Y + 3 + ItemIndex * Font.MaxHeight + ItemIndex * 3,
                     W - 4 - SCROLL_SIZE - 1, Font.MaxHeight, COLOR_SELECT, 155 );
        end;
      scissor_End;
    end;
end;

procedure gui_DrawGroupBox;
  var
    th : Integer;
begin
  with zglTGroupBoxDesc( Widget.desc^ ), Widget.rect do
    begin
      th := Trunc( Font.MaxHeight / 2 );
      pr2d_Rect( X, Y, W, H, COLOR_WINDOW, 255, PR2D_FILL );

      pr2d_Rect( X, Y, W - 1, H - 1, COLOR_WIDGET, 255, 0 );
      pr2d_Rect( X + 1, Y + 1, W - 1, H - 1, COLOR_LIGHT, 255, 0 );
      pr2d_Rect( X + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Y, text_GetWidth( Font, Caption ), th, COLOR_WINDOW, 255, PR2D_FILL );

      text_Draw( Font, X + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Y - th, Caption );
    end;
end;

procedure gui_DrawSpin;
begin
  with zglTSpinDesc( Widget.desc^ ), Widget.rect do
    begin
      _button_draw( X, Y, W, H / 2, UPressed );
      glColor4f( 0, 0, 0, 1 );
      glBegin( GL_TRIANGLES );
        gl_Vertex2f( X + W / 2 + Byte( UPressed ), Y + 2 + Byte( UPressed ) );
        gl_Vertex2f( X + W - 2 + Byte( UPressed ), Y + H / 2 - 2 + Byte( UPressed ) );
        gl_Vertex2f( X + 2 + Byte( UPressed ),     Y + H / 2 - 2 + Byte( UPressed ) );
      glEnd;

      _button_draw( X, Y + H / 2, W, H / 2, DPressed );
      glColor4f( 0, 0, 0, 1 );
      glBegin( GL_TRIANGLES );
        gl_Vertex2f( X + 2 + Byte( DPressed ),     Y + H / 2 + 2 + Byte( DPressed ) );
        gl_Vertex2f( X + W - 2 + Byte( DPressed ), Y + H / 2 + 2 + Byte( DPressed ) );
        gl_Vertex2f( X + W / 2 + Byte( DPressed ), Y + H - 2 + Byte( DPressed ) );
      glEnd;
    end;
end;

end.
