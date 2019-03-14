; Raspberry Pi 'Bare Metal' V3D Texture NV Vertex Array Triangle Control List Demo by krom (Peter Lemon):
; 1. Run Tags & Set V3D Frequency To 250MHz, & Enable Quad Processing Unit
; 2. Setup Frame Buffer
; 3. Setup & Run V3D Control List Rendered Tile Buffer

format binary as 'img'
include 'LIB\FASMARM.INC'
include 'LIB\R_PI.INC'
include 'LIB\V3D.INC'
include 'LIB\CONTROL_LIST.INC'

; Setup Frame Buffer
SCREEN_X       = 640
SCREEN_Y       = 480
BITS_PER_PIXEL = 32

; Setup V3D Binning
BIN_ADDRESS = $00400000
BIN_BASE    = $00500000

org $0000

; Run Tags To Initialize V3D
imm32 r0,PERIPHERAL_BASE + MAIL_BASE
imm32 r1,TAGS_STRUCT
orr r1,MAIL_TAGS
str r1,[r0,MAIL_WRITE] ; Mail Box Write

FB_Init:
  imm32 r0,FB_STRUCT + MAIL_TAGS
  imm32 r1,PERIPHERAL_BASE + MAIL_BASE + MAIL_WRITE + MAIL_TAGS
  str r0,[r1] ; Mail Box Write

  ldr r0,[FB_POINTER] ; R0 = Frame Buffer Pointer
  cmp r0,0 ; Compare Frame Buffer Pointer To Zero
  beq FB_Init ; IF Zero Re-Initialize Frame Buffer

  and r0,$3FFFFFFF ; Convert Mail Box Frame Buffer Pointer From BUS Address To Physical Address ($CXXXXXXX -> $3XXXXXXX)
  str r0,[FB_POINTER] ; Store Frame Buffer Pointer Physical Address

imm32 r1,TILE_MODE_ADDRESS + 1 ; Store Frame Buffer Pointer To Control List Tile Rendering Mode Configuration Memory Address
strb r0,[r1],1
lsr r0,8
strb r0,[r1],1
lsr r0,8
strb r0,[r1],1
lsr r0,8
strb r0,[r1],1

; Run Binning Control List (Thread 0)
imm32 r0,PERIPHERAL_BASE + V3D_BASE ; Load V3D Base Address
imm32 r1,CONTROL_LIST_BIN_STRUCT ; Store Control List Executor Binning Thread 0 Current Address
str r1,[r0,V3D_CT0CA]
imm32 r1,CONTROL_LIST_BIN_END ; Store Control List Executor Binning Thread 0 End Address
str r1,[r0,V3D_CT0EA] ; When End Address Is Stored Control List Thread Executes

WaitBinControlList: ; Wait For Control List To Execute
  ldr r1,[r0,V3D_BFC] ; Load Flush Count
  tst r1,1 ; Test IF PTB Has Flushed All Tile Lists To Memory
  beq WaitBinControlList

; Run Rendering Control List (Thread 1)
imm32 r1,CONTROL_LIST_RENDER_STRUCT ; Store Control List Executor Rendering Thread 1 Current Address
str r1,[r0,V3D_CT1CA]
imm32 r1,CONTROL_LIST_RENDER_END ; Store Control List Executor Rendering Thread 1 End Address
str r1,[r0,V3D_CT1EA] ; When End Address Is Stored Control List Thread Executes

Loop:
  b Loop

align 16
FB_STRUCT: ; Mailbox Property Interface Buffer Structure
  dw FB_STRUCT_END - FB_STRUCT ; Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  dw $00000000 ; Buffer Request/Response Code
	       ; Request Codes: $00000000 Process Request Response Codes: $80000000 Request Successful, $80000001 Partial Response
; Sequence Of Concatenated Tags
  dw Set_Physical_Display ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw SCREEN_X ; Value Buffer
  dw SCREEN_Y ; Value Buffer

  dw Set_Virtual_Buffer ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw SCREEN_X ; Value Buffer
  dw SCREEN_Y ; Value Buffer

  dw Set_Depth ; Tag Identifier
  dw $00000004 ; Value Buffer Size In Bytes
  dw $00000004 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw BITS_PER_PIXEL ; Value Buffer

  dw Set_Virtual_Offset ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_OFFSET_X:
  dw 0 ; Value Buffer
FB_OFFSET_Y:
  dw 0 ; Value Buffer

  dw Allocate_Buffer ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_POINTER:
  dw 0 ; Value Buffer
  dw 0 ; Value Buffer

dw $00000000 ; $0 (End Tag)
FB_STRUCT_END:

align 16
TAGS_STRUCT: ; Mailbox Property Interface Buffer Structure
  dw TAGS_END - TAGS_STRUCT ; Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  dw $00000000 ; Buffer Request/Response Code
	       ; Request Codes: $00000000 Process Request Response Codes: $80000000 Request Successful, $80000001 Partial Response
; Sequence Of Concatenated Tags
  dw Set_Clock_Rate ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw CLK_V3D_ID ; Value Buffer (V3D Clock ID)
  dw 250*1000*1000 ; Value Buffer (250MHz)

  dw Enable_QPU ; Tag Identifier
  dw $00000004 ; Value Buffer Size In Bytes
  dw $00000004 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw 1 ; Value Buffer (1 = Enable)

dw $00000000 ; $0 (End Tag)
TAGS_END:

align 4
CONTROL_LIST_BIN_STRUCT: ; Control List Of Concatenated Control Records & Data Structure (Binning Mode Thread 0)
  Tile_Binning_Mode_Configuration BIN_ADDRESS, $2000, BIN_BASE, 10, 8, Auto_Initialise_Tile_State_Data_Array ; Tile Binning Mode Configuration (B) (Address, Size, Base Address, Tile Width, Tile Height, Data)
  Start_Tile_Binning ; Start Tile Binning (Advances State Counter So That Initial State Items Actually Go Into Tile Lists) (B)

  Clip_Window 0, 0, SCREEN_X, SCREEN_Y ; Clip Window
  Configuration_Bits Enable_Forward_Facing_Primitive + Enable_Reverse_Facing_Primitive, Early_Z_Updates_Enable ; Configuration Bits
  Viewport_Offset 0, 0 ; Viewport Offset
  NV_Shader_State NV_SHADER_STATE_RECORD ; NV Shader State (No Vertex Shading)
  Vertex_Array_Primitives Mode_Triangles, 3, 0 ; Vertex Array Primitives (OpenGL)
  Flush ; Flush (Add Return-From-Sub-List To Tile Lists & Then Flush Tile Lists To Memory) (B)
CONTROL_LIST_BIN_END:

align 4
CONTROL_LIST_RENDER_STRUCT: ; Control List Of Concatenated Control Records & Data Structures (Rendering Mode Thread 1)
  Clear_Colors $FF00FFFFFF00FFFF, 0, 0, 0 ; Clear Colors (R) (Clear Color (Yellow/Yellow), Clear ZS, Clear VGMask, Clear Stencil)

  TILE_MODE_ADDRESS:
    Tile_Rendering_Mode_Configuration $00000000, SCREEN_X, SCREEN_Y, Frame_Buffer_Color_Format_RGBA8888 ; Tile Rendering Mode Configuration (R) (Address, Width, Height, Data)

  Tile_Coordinates 0, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Store_Tile_Buffer_General 0, 0, 0 ; Store Tile Buffer General (R)

  ; Tile Row 0
  Tile_Coordinates 0, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 0) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 1, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 1) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 2, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 2) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 3, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 3) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 4, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 4) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 5, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 5) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 6, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 6) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 7, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 7) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 8, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 8) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 9, 0 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((0 * 10 + 9) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  ; Tile Row 1
  Tile_Coordinates 0, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 0) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 1, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 1) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 2, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 2) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 3, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 3) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 4, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 4) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 5, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 5) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 6, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 6) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 7, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 7) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 8, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 8) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 9, 1 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((1 * 10 + 9) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  ; Tile Row 2
  Tile_Coordinates 0, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 0) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 1, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 1) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 2, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 2) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 3, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 3) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 4, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 4) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 5, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 5) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 6, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 6) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 7, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 7) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 8, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 8) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 9, 2 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((2 * 10 + 9) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  ; Tile Row 3
  Tile_Coordinates 0, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 0) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 1, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 1) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 2, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 2) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 3, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 3) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 4, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 4) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 5, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 5) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 6, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 6) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 7, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 7) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 8, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 8) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 9, 3 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((3 * 10 + 9) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  ; Tile Row 4
  Tile_Coordinates 0, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 0) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 1, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 1) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 2, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 2) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 3, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 3) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 4, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 4) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 5, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 5) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 6, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 6) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 7, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 7) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 8, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 8) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 9, 4 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((4 * 10 + 9) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  ; Tile Row 5
  Tile_Coordinates 0, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 0) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 1, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 1) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 2, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 2) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 3, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 3) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 4, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 4) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 5, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 5) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 6, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 6) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 7, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 7) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 8, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 8) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 9, 5 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((5 * 10 + 9) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  ; Tile Row 6
  Tile_Coordinates 0, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 0) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 1, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 1) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 2, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 2) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 3, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 3) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 4, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 4) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 5, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 5) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 6, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 6) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 7, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 7) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 8, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 8) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 9, 6 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((6 * 10 + 9) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  ; Tile Row 7
  Tile_Coordinates 0, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 0) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 1, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 1) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 2, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 2) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 3, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 3) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 4, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 4) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 5, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 5) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 6, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 6) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 7, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 7) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 8, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 8) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample ; Store Multi-Sample (Resolved Tile Color Buffer) (R)

  Tile_Coordinates 9, 7 ; Tile Coordinates (R) (Tile Column, Tile Row)
  Branch_To_Sub_List BIN_ADDRESS + ((7 * 10 + 9) * 32); Branch To Sub List (32-Bit Absolute Branch Address, Maximum Of 2 Levels Of Nesting)
  Store_Multi_Sample_End ; Store Multi-Sample (Resolved Tile Color Buffer & Signal End Of Frame) (R)
CONTROL_LIST_RENDER_END:

align 16 ; 128-Bit Align
NV_SHADER_STATE_RECORD:
  db 0 ; Flag Bits: 0 = Fragment Shader Is Single Threaded, 1 = Point Size Included In Shaded Vertex Data, 2 = Enable Clipping, 3 = Clip Coordinates Header Included In Shaded Vertex Data
  db 5 * 4 ; Shaded Vertex Data Stride
  db 0 ; Fragment Shader Number Of Uniforms (Not Used Currently)
  db 2 ; Fragment Shader Number Of Varyings
  dw FRAGMENT_SHADER_CODE ; Fragment Shader Code Address
  dw FRAGMENT_SHADER_UNIFORMS ; Fragment Shader Uniforms Address
  dw VERTEX_DATA ; Shaded Vertex Data Address (128-Bit Aligned If Including Clip Coordinate Header)

align 16 ; 128-Bit Align
VERTEX_DATA:
  ; Vertex: Top
  dh 320 * 16 ; X In 12.4 Fixed Point
  dh  32 * 16 ; Y In 12.4 Fixed Point
  dw 1.0 ; Z
  dw 1.0 ; 1 / W
  dw 2.0 ; Varying 0 (S)
  dw 0.0 ; Varying 1 (T)

  ; Vertex: Bottom Left
  dh  32 * 16 ; X In 12.4 Fixed Point
  dh 448 * 16 ; Y In 12.4 Fixed Point
  dw 1.0 ; Z
  dw 1.0 ; 1 / W
  dw 0.0 ; Varying 0 (S)
  dw 3.0 ; Varying 1 (T)

  ; Vertex: Bottom Right
  dh 608 * 16 ; X In 12.4 Fixed Point
  dh 448 * 16 ; Y In 12.4 Fixed Point
  dw 1.0 ; Z
  dw 1.0 ; 1 / W
  dw 4.0 ; Varying 0 (S)
  dw 3.0 ; Varying 1 (T)

align 16 ; 128-Bit Align
FRAGMENT_SHADER_UNIFORMS:
  dw Texture32x32 ; Uniform 0: Texture Base Pointer Bits 12..31 (Texture Config Parameter 0)
  dw 0x80000000 + (32 * 1048576) + (32 * 256) ; Uniform 1: RGBA32R Raster Format Bit 31, Height Bits 20..30, Width Bits 8..18 (Texture Config Parameter 1)
  dw 0 ; Uniform 2 (Texture Config Parameter 2)
  dw 0 ; Uniform 3 (Texture Config Parameter 3)

align 16 ; 128-Bit Align
FRAGMENT_SHADER_CODE:
  ; Texture Shader

  ; Tex S: ACC0 = S * W (R15A)
  ; Add Op: No Operation, Add Cond: Never
  ; Mul Pipe: Floating Point Multiply, ACC0, R15, VARYING_READ, Cond: Always
  dw $203E3037
  dw $100049E0 ; nop; fmul r0, ra15, vary; nop

  ; Tex S Coord: ACC0 = S * W + C, Tex T: ACC1 = T * W (R15A)
  ; Add Pipe: Floating Point Add, ACC0, ACC R0, ACC R5, Cond: Always
  ; Mul Pipe: Floating Point Multiply, ACC1, R15, VARYING_READ, Cond: Always
  ; Signal: Wait For Scoreboard
  dw $213E3177
  dw $40024821 ; fadd r0, r0, r5; fmul r1, ra15, vary; sbwait

  ; Tex T Write Reg = T * W + C, Trigger First Sampler Param Uniform Read
  ; Add Pipe: Floating Point Add, TMU0_T, ACC R1, ACC R5, Cond: Always
  ; Mul Op: No Operation, Mul Cond: Never
  dw $019E7340
  dw $10020E67 ; fadd t0t, r1, r5; nop; nop

  ; Moving S coord (In ACC0) To S Register, Trigger Second Sampler Param Uniform Read, & Kick It All Off
  ; Add Pipe: Bitwise OR, TMU0_S_RETIRING, ACC R0, ACC R0, Cond: Always
  ; Mul Op: No Operation, Mul Cond: Never
  dw $159E7000
  dw $10020E27 ; mov t0s, r0; nop; nop

  ; Signal TMU Texture Read
  ; Add Op: No Operation, Add cond: Never
  ; Mul Op: No Operation, Mul cond: Never
  ; Signal: Load Data From TMU0 To R4
  dw $009E7000
  dw $A00009E7 ; nop; nop; ldtmu0

  ; Exporting Read Texture Data To MRT0
  ; Add Pipe: Bitwise OR, TLB_COLOUR_ALL, ACC R4, ACC R4, Cond: Always
  ; Mul Op: No operation, Mul Cond: Never
  ; Signal: Program End
  dw $159E7900
  dw $30020BA7 ; mov tlbc, r4; nop; thrend

  ; Thread End Delay Slot 1
  ; Add Op: No Operation, Add cond: Never
  ; Mul Op: No Operation, Mul cond: Never
  dw $009E7000 ;
  dw $100009E7 ; nop; nop; nop

  ; Thread End Delay Slot 2
  ; Add Op: No Operation, Add cond: Never
  ; Mul Op: No Operation, Mul cond: Never
  ; Signal: Scoreboard Unlock
  dw $009E7000 ;
  dw $500009E7 ; nop; nop; sbdone

align 4096 ; 4096 Byte Align
Texture32x32: ; RGBA:8888 (32x32x32B = 4096 Bytes)
  dw $FF0000FF,$FF0000FF,$FF0000FF,$FF0000FF,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF00FF00,$FF00FF00,$FF00FF00,$FF00FF00
  dw $FF0000FF,$FF0000FF,$FF0000FF,$FF0000FF,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF00FF00,$FF00FF00,$FF00FF00,$FF00FF00
  dw $FF0000FF,$FF0000FF,$FF0000FF,$FF0000FF,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF00FF00,$FF00FF00,$FF00FF00,$FF00FF00
  dw $FF0000FF,$FF0000FF,$FF0000FF,$FF0000FF,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF00FF00,$FF00FF00,$FF00FF00,$FF00FF00
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000
  dw $00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000
  dw $FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000
  dw $FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000
  dw $FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
  dw $FFFF0000,$FFFF0000,$FFFF0000,$FFFF0000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FFFF00FF,$FFFF00FF,$FFFF00FF,$FFFF00FF
  dw $FFFF0000,$FFFF0000,$FFFF0000,$FFFF0000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FFFF00FF,$FFFF00FF,$FFFF00FF,$FFFF00FF
  dw $FFFF0000,$FFFF0000,$FFFF0000,$FFFF0000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FFFF00FF,$FFFF00FF,$FFFF00FF,$FFFF00FF
  dw $FFFF0000,$FFFF0000,$FFFF0000,$FFFF0000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$FF000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$FFFF00FF,$FFFF00FF,$FFFF00FF,$FFFF00FF