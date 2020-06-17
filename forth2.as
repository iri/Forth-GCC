format PE console 

include 'win32ax.inc'
include 'macros.s'

section '.code' code readable executable
entry $
        ; To clean up the stack after calls
        mov [InitialESP], esp
        mov ebp, esp

        ; -10 = SDTIN, -11 = STDOUT, -12 = STDERR
        push STD_INPUT_HANDLE
        call [GetStdHandle]
        mov [STDIN], eax
        mov esp, ebp

        push STD_OUTPUT_HANDLE
        call [GetStdHandle]
        mov [STDOUT], eax
        mov esp, ebp

        invoke __getmainargs, argc, argv, env, 0, stup
        mov esp, ebp
        cmp [argc], 2
        jne argError
        mov esi, [argv]
        mov eax, [esi + 4]
        mov [fileName], eax

        ; Ensure that the file is there        
        push [fileName]
        call [GetFileAttributes]
        cmp eax, -1
        je fileError

        ; Open the file
        push openModeRB
        push [fileName]
        call [fopen]
        mov esp, ebp
        mov [stream], eax

        ; Read in the file ...
        ; Get the file size, allocate memory, read file into memory ...

        ; Get the file size ...
        ; fseek() to the end and then use ftell() to get the size
        ; fseek(fp, offset, from): - from: 0 => SEEK_SET, 1 => SEEK_CUR, 2 => SEEK_END
        push 2
        push 0
        push [stream]
        call [fseek]
        mov esp, ebp

        ; Get the file size
        push [stream]
        call [ftell]
        mov [fileSize], eax
        mov esp, ebp

        ; Reset the file position pointer to beginning of the file
        push 0
        push 0
        push [stream]
        call [fseek]
        mov esp, ebp

        ; Allocate memory for the file
        push [fileSize]
        call [malloc]
        mov [theMemory], eax
        mov esp, ebp

        ; Read the file into memory
        push [stream]
        push [fileSize]
        push 1
        push [theMemory]
        call [fread]
        mov esp, ebp

        ; Close the file
        push [stream]
        call f_FCLOSE
        mov esp, ebp

        ; Initialize the VM
        call f_SYS_INIT

        ; A little test
        ;m_push 1234
        ;m_push 100
        ;call f_SLASHMOD
        ;call f_DOT
        ;call f_DOT
        

        ; **************************************************
        ;                 Register usage
        ; **************************************************
        ; eax: Free to use
        ; ebx is the VM's TOS (top-of-stack)
        ; ecx: Free to use
        ; edx is the start of the VM's address space
        ; esi is the VM's IP (instruction-pointer)
        ; edi is the start of the opcode jump table
        ; ebp is the VM's stack pointer
        ; **************************************************

cpuLoop:
        xor ecx, ecx
        mov cl, [esi]
                ;call dbgEsi ; debug
        mov eax, [edi+ecx*4]
                ;mov ecx, esi ; debug
                ;sub ecx, edx ; debug
        inc esi
        call eax
        jmp cpuLoop

; -------------------------------------------------------------------------------------
; RESET
f_RESET:
        call f_SYS_INIT
        mov esp, [InitialESP]
        jmp cpuLoop
; -------------------------------------------------------------------------------------
; f_SYS_INIT: Initialize the VM
f_SYS_INIT:
            ; Return stack
            mov eax, rStack
            add eax, CELL_SIZE
            mov [rStack], eax
            mov [rDepth], 0

            ; Data stack
            mov ebp, dStack
            mov [dDepth], 0

            ; opcode jump table
            mov edi, jmpTable

            ; edx = theMemory
            mov edx, [theMemory]

            ; esi = IP/PC
            mov esi, edx
            ret

; -------------------------------------------------------------------------------------
dbgEsi:
        ret ; replace with nop (0x90) ... AKA xchg eax, eax

        push ecx
        push esi
        push edi
        push edx
                sub esi, edx
                push ebx
                push ecx
                push esi
                push dbgEsiEcx
                call [printf]
                pop eax
                pop eax
                pop eax
                pop eax
        pop edx
        pop edi
        pop esi
        pop ecx
        ret
; -------------------------------------------------------------------------------------
f_DOT:
        push edx
        m_pop eax
                push eax
                push printOneCharD
                call [printf]
                pop eax
                pop eax
        pop edx
        ret

; -------------------------------------------------------------------------------------
f_TYPE: ; ( addr count -- )
        push edi
        m_pop ecx
        m_pop edi
        add edi, edx

ty1:    test ecx, ecx
        jz tyX
        xor eax, eax
        mov al, [edi]
        m_push eax

        push edi
        push ecx
        call f_EMIT
        pop ecx
        pop edi

        inc edi
        dec ecx
        jmp ty1

tyX:    pop edi
        ret

; -------------------------------------------------------------------------------------
argError:
        invoke printf, printArgError
        jmp f_BYE
; -------------------------------------------------------------------------------------
fileError:
        invoke printf, printFileError, [fileName]
        jmp f_BYE

; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------
; The VM primitives
; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------
; LITERAL
f_LITERAL:
            mov eax, [esi]
            add esi, CELL_SIZE
            m_push eax
            ret

; -------------------------------------------------------------------------------------
; FETCH
f_FETCH:
            add ebx, edx
            mov ebx, [ebx]
            ret

; -------------------------------------------------------------------------------------
; STORE
f_STORE:
            m_pop ecx
            m_pop eax
            add ecx, edx
            mov [ecx], eax
            ret

; -------------------------------------------------------------------------------------
; SWAP
f_SWAP:
            m_get2ND eax
            m_set2ND ebx
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; DROP
f_DROP:
            m_drop
            ret

; -------------------------------------------------------------------------------------
; DUP
f_DUP:
            m_push ebx
            ret

; -------------------------------------------------------------------------------------
; SLITERAL
f_SLITERAL:
            mov eax, esi
            sub eax, edx
            m_push eax
            xor eax, eax
            mov al, [esi]
            add esi, eax
            inc esi
            inc esi
            ret

; -------------------------------------------------------------------------------------
; JMP
f_JMP:
            mov esi, [esi]
            add esi, edx
            ret

; -------------------------------------------------------------------------------------
; JMPZ
f_JMPZ:
            m_pop eax
            cmp eax, 0
            je f_JMP
            ; jmp noJMP
noJMP:      add esi, CELL_SIZE
            ret

; -------------------------------------------------------------------------------------
; JMPNZ
f_JMPNZ:
            m_pop eax
            cmp eax, 0
            jne f_JMP
            jmp noJMP

; -------------------------------------------------------------------------------------
; CALL
f_CALL:
            push dword [esi]
            add esi, CELL_SIZE
            sub esi, edx
            push esi
            call u_rPush
            pop esi
            pop esi
            add esi, edx
            ret

u_rPush:
        cmp [rDepth], 63
        jg rpO
        inc [rDepth]

        mov eax, [esp + 4]              ; the val to rpush
        push ebp
        mov ebp, [rStack]
        add ebp, CELL_SIZE
        mov [ebp], eax
        mov [rStack], ebp
        pop ebp
        ret

rpO:    ret ; RStack overflow

u_rPop:                                 ; returns the val in eax
       cmp [rDepth], 1
       jl rpU
       dec [rDepth]

       push ebp
       mov ebp, [rStack]
       mov eax, [ebp]
       sub ebp, CELL_SIZE
       mov [rStack], ebp
       pop ebp
       ret

rpU:   ret ; RStack underflow

; -------------------------------------------------------------------------------------
; RET
f_RET:
            cmp [rDepth], 1
            jl f_BYE

            call u_rPop
            mov esi, eax
            add esi, edx
            ret

; -------------------------------------------------------------------------------------
; OR
f_OR:
            m_pop eax
            or ebx, eax
            ret

; -------------------------------------------------------------------------------------
; CLITERAL
f_CLITERAL:
            xor eax, eax
            mov al, [esi]
            m_push eax
            inc esi
            ret

; -------------------------------------------------------------------------------------
; CFETCH
f_CFETCH:
            add ebx, edx
            xor eax, eax
            mov al, [ebx]
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; CSTORE
f_CSTORE:
            m_pop ecx
            m_pop eax
            add ecx, edx
            mov [ecx], al
            ret

; -------------------------------------------------------------------------------------
; ADD
f_ADD:
            m_pop eax
            add ebx, eax
            ret

; -------------------------------------------------------------------------------------
; SUB
f_SUB:
            m_pop eax
            sub ebx, eax
            ret

; -------------------------------------------------------------------------------------
; MUL
f_MUL:
            push edx
            m_pop eax
            xor edx, edx
            mul ebx
            m_setTOS eax
            pop edx
            ret

; -------------------------------------------------------------------------------------
f_SLASHMOD:
        ;push edx
        ;  push 1
        ;  push prtHere
        ;  call [printf]
        ;  pop eax
        ;  pop eax
        ;pop edx
           push edx
           m_pop ecx
           m_pop eax
           cmp ecx, 0
           je smDivBy0
           xor edx, edx
           div ecx
           m_push edx          ; Remainder
           m_push eax          ; Quotient
           pop edx
           ret

smDivBy0:
           push divByZero
           call [printf]
           pop eax
           jmp f_RESET
; -------------------------------------------------------------------------------------
; DIV
f_DIV:
            call f_SLASHMOD
            call f_SWAP
            jmp f_DROP

; -------------------------------------------------------------------------------------
; MOD
f_MOD:
            call f_SLASHMOD
            jmp f_DROP

; -------------------------------------------------------------------------------------
; LT
f_LT:
            m_pop eax
            cmp ebx, eax
            jl eq_T
            jmp eq_F

; -------------------------------------------------------------------------------------
; EQ
f_EQ:
            m_pop eax
            cmp ebx, eax
            je eq_T
eq_F:       m_setTOS 0
            ret
eq_T:       m_setTOS -1
            ret

; -------------------------------------------------------------------------------------
; GT
f_GT:
            m_pop eax
            cmp ebx, eax
            jg eq_T
            jmp eq_F

; -------------------------------------------------------------------------------------
; DICTP
f_DICTP:
            add esi, CELL_SIZE
            ret

; -------------------------------------------------------------------------------------
; EMIT
f_EMIT:
            m_pop eax
            push edx
            push eax
            call [putchar]
            pop eax
            pop edx
            ret

; -------------------------------------------------------------------------------------
; OVER
f_OVER:
            m_get2ND eax
            m_push eax
            ret

; -------------------------------------------------------------------------------------
; Makes al lowerCase if upperCase
u_ToLower:
                cmp al, 'A'
                jl u2lR
                cmp al, 'Z'
                jg u2lR
                add al, 32
u2lR:           ret

; -------------------------------------------------------------------------------------
; do_STRCMP
; Compare strings pointed to by esi and edi
; case sensitive: dl = 0
; case insensitive: dl != 0
; return in eax: -1 => eax<ecx, 0 => same, 1 eax>ecx
do_STRCMP:
                mov al, [esi]
                mov ah, [edi]

                test edx, edx
                jz cmp2
                call u_ToLower
                xchg al, ah
                call u_ToLower
                ;xchg al, ah
cmp2:           cmp ah, al
                jl cmpLT
                jg cmpGT
                test ax, ax
                jz cmpEQ
                inc esi
                inc edi
                jmp do_STRCMP

cmpLT:          mov eax, -1
                ret
cmpGT:          mov eax, 1
                ret
cmpEQ:          mov eax, 0
                ret

; -------------------------------------------------------------------------------------
; do_COMPARE
; Compare strings pointed to by esi and edi
; case sensitive: dl = 0
; case insensitive: dl != 0
; return in eax: -1 => strings are equal, 0 => strings are NOT equal
do_COMPARE:
                call do_STRCMP
                test eax, eax
                jz cmpF
                mov eax, 0
                ret
                        push edx
                        push 2
                        push prtHere
                        call [printf]
                        pop eax
                        pop eax
                        pop edx
cmpF:           mov eax, -1
                ret

; -------------------------------------------------------------------------------------
; COMPARE
f_COMPARE:
                push esi
                push edi
                push edx

                m_pop edi
                add edi, edx
                m_pop esi
                add esi, edx
                xor edx, edx
                call do_COMPARE
                m_push eax

                pop edx
                pop edi
                pop esi

                ret

; -------------------------------------------------------------------------------------
; FOPEN
f_FOPEN: ; ( name mode -- fp )
            m_pop eax
            m_pop ecx
            add eax, edx
            add ecx, edx
            push edx
            push eax
            push ecx
            call [fopen]
            m_push eax
            pop eax
            pop eax
            pop edx
            ret

; -------------------------------------------------------------------------------------
; FREAD
f_FREAD:
            ; TODO: fill this in
            m_pop eax
            m_push eax
            m_getTOS eax
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; FREADLINE
f_FREADLINE:
            ; TODO: fill this in
            m_pop eax
            m_push eax
            m_getTOS eax
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; FWRITE
f_FWRITE:
            ; TODO: fill this in
            m_pop eax
            m_push eax
            m_getTOS eax
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; FCLOSE
f_FCLOSE:   ; ( fp -- )
            m_pop eax
            push edx
            push eax
            call [fclose]
            pop eax
            pop edx
            ret

; -------------------------------------------------------------------------------------
; DTOR
f_DTOR:
            m_pop eax
            push eax
            call u_rPush
            pop eax
            ret

; -------------------------------------------------------------------------------------
; RTOD
f_RTOD:
            call u_rPop
            m_push eax
            ret

; -------------------------------------------------------------------------------------
; LOGLEVEL
f_LOGLEVEL:
            ; TODO: fill this in
            m_pop eax
            m_push eax
            m_getTOS eax
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; AND
f_AND:
            m_pop eax
            and ebx, eax
            ret

; -------------------------------------------------------------------------------------
; PICK
f_PICK:
            m_getTOS eax
            shl eax, CELL_SHIFT
            mov ecx, ebp
            sub ecx, eax
            mov eax, [ecx]
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; DEPTH
f_DEPTH:
            mov eax, [dDepth]
            m_push eax
            ret

; -------------------------------------------------------------------------------------
; GETCH
f_GETCH:
            push edx
            call [getch]
            pop edx
            cmp eax, 3
            je f_BYE
            m_push eax
            ret

; -------------------------------------------------------------------------------------
; COMPAREI
f_COMPAREI:
        ;push edx
        ;       push 2
        ;       push prtHere
        ;       call [printf]
        ;       pop eax
        ;       pop eax
        ;pop edx
                push esi
                push edi
                push edx

                m_pop edi
                m_pop esi
                add edi, edx
                add esi, edx
                mov edx, 1
                call do_COMPARE
                m_push eax

                pop edx
                pop edi
                pop esi
                ret

; -------------------------------------------------------------------------------------
; UNUSED1
f_UNUSED1:
            ; TODO: fill this in
            m_pop eax
            m_push eax
            m_getTOS eax
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; USPUSH
f_USPUSH:
            ; TODO: fill this in
            m_pop eax
            m_push eax
            m_getTOS eax
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; USPOP
f_USPOP:
            ; TODO: fill this in
            m_pop eax
            m_push eax
            m_getTOS eax
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; INC
f_INC:
            inc ebx
            ret

; -------------------------------------------------------------------------------------
; RDEPTH
f_RDEPTH:
            m_push [rDepth]
            ret

; -------------------------------------------------------------------------------------
; DEC
f_DEC:
            dec ebx
            ret

; -------------------------------------------------------------------------------------
; GETTICK
f_GETTICK:
            ; TODO: fill this in
            m_pop eax
            m_push eax
            m_getTOS eax
            m_setTOS eax
            ret

; -------------------------------------------------------------------------------------
; BREAK
f_BREAK:
            ; TODO: fill this in
            mov ecx, edi
            sub ecx, edx
            int3
            ret

; -------------------------------------------------------------------------------------
; BYE
f_BYE:
            invoke printf, printBye
            pop eax

            push 0
            call [ExitProcess]
            ret

f_UnknownOpcode:
            push ecx
            push unknownOpcode
            call [printf]
            pop eax
            pop eax

            jmp f_BYE
            jmp f_RESET

; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------

section '.bss' data readable writable

CELL_SIZE = 4
CELL_SHIFT = 2
STD_INPUT_HANDLE = -10
STD_OUTPUT_HANDLE = -11
STD_ERROR_HANDLE = -12

argc dd ?
argv dd ?
env dd ?
stup dd ?

STDIN dd ?
STDOUT dd ?
stream dd ?
InitialESP dd 0

fileName dd ?
fileSize dd ?
theMemory dd ?
dDepth dd 0
dStack dd 64 dup (0)
rDepth dd 0
rStack dd 64 dup (0)

; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------
jmpTable dd f_UnknownOpcode ; 0
dd f_LITERAL            ; Hex: 01
dd f_FETCH              ; Hex: 02
dd f_STORE              ; Hex: 03
dd f_SWAP               ; Hex: 04
dd f_DROP               ; Hex: 05
dd f_DUP                ; Hex: 06
dd f_SLITERAL           ; Hex: 07
dd f_JMP                ; Hex: 08
dd f_JMPZ               ; Hex: 09
dd f_JMPNZ              ; Hex: 0A
dd f_CALL               ; Hex: 0B
dd f_RET                ; Hex: 0C
dd f_OR                 ; Hex: 0D
dd f_CLITERAL           ; Hex: 0E
dd f_CFETCH             ; Hex: 0F
dd f_CSTORE             ; Hex: 10
dd f_ADD                ; Hex: 11
dd f_SUB                ; Hex: 12
dd f_MUL                ; Hex: 13
dd f_DIV                ; Hex: 14
dd f_LT                 ; Hex: 15
dd f_EQ                 ; Hex: 16
dd f_GT                 ; Hex: 17
dd f_DICTP              ; Hex: 18
dd f_EMIT               ; Hex: 19
dd f_OVER               ; Hex: 1A
dd f_COMPARE            ; Hex: 1B
dd f_FOPEN              ; Hex: 1C
dd f_FREAD              ; Hex: 1D
dd f_FREADLINE          ; Hex: 1E
dd f_FWRITE             ; Hex: 1F
dd f_FCLOSE             ; Hex: 20
dd f_DTOR               ; Hex: 21
dd f_RTOD               ; Hex: 22
dd f_LOGLEVEL           ; Hex: 23
dd f_AND                ; Hex: 24
dd f_PICK               ; Hex: 25
dd f_DEPTH              ; Hex: 26
dd f_GETCH              ; Hex: 27
dd f_COMPAREI           ; Hex: 28
dd f_UNUSED1            ; Hex: 29
dd f_USPUSH             ; Hex: 2A
dd f_USPOP              ; Hex: 2B
dd f_INC                ; Hex: 2C
dd f_RDEPTH             ; Hex: 2D
dd f_DEC                ; Hex: 2E
dd f_GETTICK            ; Hex: 2F
dd f_UnknownOpcode ; 48
dd f_UnknownOpcode ; 49
dd f_UnknownOpcode ; 50
dd f_UnknownOpcode ; 51
dd f_UnknownOpcode ; 52
dd f_UnknownOpcode ; 53
dd f_UnknownOpcode ; 54
dd f_UnknownOpcode ; 55
dd f_UnknownOpcode ; 56
dd f_UnknownOpcode ; 57
dd f_UnknownOpcode ; 58
dd f_UnknownOpcode ; 59
dd f_UnknownOpcode ; 60
dd f_UnknownOpcode ; 61
dd f_UnknownOpcode ; 62
dd f_UnknownOpcode ; 63
dd f_UnknownOpcode ; 64
dd f_UnknownOpcode ; 65
dd f_UnknownOpcode ; 66
dd f_UnknownOpcode ; 67
dd f_UnknownOpcode ; 68
dd f_UnknownOpcode ; 69
dd f_UnknownOpcode ; 70
dd f_UnknownOpcode ; 71
dd f_UnknownOpcode ; 72
dd f_UnknownOpcode ; 73
dd f_UnknownOpcode ; 74
dd f_UnknownOpcode ; 75
dd f_UnknownOpcode ; 76
dd f_UnknownOpcode ; 77
dd f_UnknownOpcode ; 78
dd f_UnknownOpcode ; 79
dd f_UnknownOpcode ; 80
dd f_UnknownOpcode ; 81
dd f_UnknownOpcode ; 82
dd f_UnknownOpcode ; 83
dd f_UnknownOpcode ; 84
dd f_UnknownOpcode ; 85
dd f_UnknownOpcode ; 86
dd f_UnknownOpcode ; 87
dd f_UnknownOpcode ; 88
dd f_UnknownOpcode ; 89
dd f_UnknownOpcode ; 90
dd f_UnknownOpcode ; 91
dd f_UnknownOpcode ; 92
dd f_UnknownOpcode ; 93
dd f_UnknownOpcode ; 94
dd f_UnknownOpcode ; 95
dd f_UnknownOpcode ; 96
dd f_UnknownOpcode ; 97
dd f_UnknownOpcode ; 98
dd f_UnknownOpcode ; 99
dd f_UnknownOpcode ; 100
dd f_UnknownOpcode ; 101
dd f_UnknownOpcode ; 102
dd f_UnknownOpcode ; 103
dd f_UnknownOpcode ; 104
dd f_UnknownOpcode ; 105
dd f_UnknownOpcode ; 106
dd f_UnknownOpcode ; 107
dd f_UnknownOpcode ; 108
dd f_UnknownOpcode ; 109
dd f_UnknownOpcode ; 110
dd f_UnknownOpcode ; 111
dd f_UnknownOpcode ; 112
dd f_UnknownOpcode ; 113
dd f_UnknownOpcode ; 114
dd f_UnknownOpcode ; 115
dd f_UnknownOpcode ; 116
dd f_UnknownOpcode ; 117
dd f_UnknownOpcode ; 118
dd f_UnknownOpcode ; 119
dd f_UnknownOpcode ; 120
dd f_UnknownOpcode ; 121
dd f_UnknownOpcode ; 122
dd f_UnknownOpcode ; 123
dd f_UnknownOpcode ; 124
dd f_UnknownOpcode ; 125
dd f_UnknownOpcode ; 126
dd f_UnknownOpcode ; 127
dd f_UnknownOpcode ; 128
dd f_UnknownOpcode ; 129
dd f_UnknownOpcode ; 130
dd f_UnknownOpcode ; 131
dd f_UnknownOpcode ; 132
dd f_UnknownOpcode ; 133
dd f_UnknownOpcode ; 134
dd f_UnknownOpcode ; 135
dd f_UnknownOpcode ; 136
dd f_UnknownOpcode ; 137
dd f_UnknownOpcode ; 138
dd f_UnknownOpcode ; 139
dd f_UnknownOpcode ; 140
dd f_UnknownOpcode ; 141
dd f_UnknownOpcode ; 142
dd f_UnknownOpcode ; 143
dd f_UnknownOpcode ; 144
dd f_UnknownOpcode ; 145
dd f_UnknownOpcode ; 146
dd f_UnknownOpcode ; 147
dd f_UnknownOpcode ; 148
dd f_UnknownOpcode ; 149
dd f_UnknownOpcode ; 150
dd f_UnknownOpcode ; 151
dd f_UnknownOpcode ; 152
dd f_UnknownOpcode ; 153
dd f_UnknownOpcode ; 154
dd f_UnknownOpcode ; 155
dd f_UnknownOpcode ; 156
dd f_UnknownOpcode ; 157
dd f_UnknownOpcode ; 158
dd f_UnknownOpcode ; 159
dd f_UnknownOpcode ; 160
dd f_UnknownOpcode ; 161
dd f_UnknownOpcode ; 162
dd f_UnknownOpcode ; 163
dd f_UnknownOpcode ; 164
dd f_UnknownOpcode ; 165
dd f_UnknownOpcode ; 166
dd f_UnknownOpcode ; 167
dd f_UnknownOpcode ; 168
dd f_UnknownOpcode ; 169
dd f_UnknownOpcode ; 170
dd f_UnknownOpcode ; 171
dd f_UnknownOpcode ; 172
dd f_UnknownOpcode ; 173
dd f_UnknownOpcode ; 174
dd f_UnknownOpcode ; 175
dd f_UnknownOpcode ; 176
dd f_UnknownOpcode ; 177
dd f_UnknownOpcode ; 178
dd f_UnknownOpcode ; 179
dd f_UnknownOpcode ; 180
dd f_UnknownOpcode ; 181
dd f_UnknownOpcode ; 182
dd f_UnknownOpcode ; 183
dd f_UnknownOpcode ; 184
dd f_UnknownOpcode ; 185
dd f_UnknownOpcode ; 186
dd f_UnknownOpcode ; 187
dd f_UnknownOpcode ; 188
dd f_UnknownOpcode ; 189
dd f_UnknownOpcode ; 190
dd f_UnknownOpcode ; 191
dd f_UnknownOpcode ; 192
dd f_UnknownOpcode ; 193
dd f_UnknownOpcode ; 194
dd f_UnknownOpcode ; 195
dd f_UnknownOpcode ; 196
dd f_UnknownOpcode ; 197
dd f_UnknownOpcode ; 198
dd f_UnknownOpcode ; 199
dd f_UnknownOpcode ; 200
dd f_UnknownOpcode ; 201
dd f_UnknownOpcode ; 202
dd f_UnknownOpcode ; 203
dd f_UnknownOpcode ; 204
dd f_UnknownOpcode ; 205
dd f_UnknownOpcode ; 206
dd f_UnknownOpcode ; 207
dd f_UnknownOpcode ; 208
dd f_UnknownOpcode ; 209
dd f_UnknownOpcode ; 210
dd f_UnknownOpcode ; 211
dd f_UnknownOpcode ; 212
dd f_UnknownOpcode ; 213
dd f_UnknownOpcode ; 214
dd f_UnknownOpcode ; 215
dd f_UnknownOpcode ; 216
dd f_UnknownOpcode ; 217
dd f_UnknownOpcode ; 218
dd f_UnknownOpcode ; 219
dd f_UnknownOpcode ; 220
dd f_UnknownOpcode ; 221
dd f_UnknownOpcode ; 222
dd f_UnknownOpcode ; 223
dd f_UnknownOpcode ; 224
dd f_UnknownOpcode ; 225
dd f_UnknownOpcode ; 226
dd f_UnknownOpcode ; 227
dd f_UnknownOpcode ; 228
dd f_UnknownOpcode ; 229
dd f_UnknownOpcode ; 230
dd f_UnknownOpcode ; 231
dd f_UnknownOpcode ; 232
dd f_UnknownOpcode ; 233
dd f_UnknownOpcode ; 234
dd f_UnknownOpcode ; 235
dd f_UnknownOpcode ; 236
dd f_UnknownOpcode ; 237
dd f_UnknownOpcode ; 238
dd f_UnknownOpcode ; 239
dd f_UnknownOpcode ; 240
dd f_UnknownOpcode ; 241
dd f_UnknownOpcode ; 242
dd f_UnknownOpcode ; 243
dd f_UnknownOpcode ; 244
dd f_UnknownOpcode ; 245
dd f_UnknownOpcode ; 246
dd f_UnknownOpcode ; 247
dd f_UnknownOpcode ; 248
dd f_UnknownOpcode ; 249
dd f_UnknownOpcode ; 250
dd f_UnknownOpcode ; 251
dd f_UnknownOpcode ; 252
dd f_BREAK              ; Hex: FD
dd f_RESET              ; Hex: FE
dd f_BYE                ; Hex: FF

; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------

section '.rdata' data readable
printArgError db 'Error: Wrong number of arguments. Run file with "program.exe <file>"', 0
printFileError db 'Error: File [%s] does not exist. Check spelling and try again.', 0
printFileSize db 'File [%s], size: %ld', 13, 10, 0
dbgEsiEcx db ' (ESI: 0x%04lx, ECX: %02x, TOS: %d) ', 0
printTheMemory db 'Memory: %08lX', 13, 10, 0
unknownOpcode db 'unknown opcode! 0x%02X', 13, 10, 0
divByZero db 'cannot divide by 0.', 0
printOneCharH db '%02x ', 0
printOneCharD db '%d ', 0
jmpCalled db ' JMP called!', 0
printOneChar db '%c', 0
printBye db 'Bye', 0
prtHere db '(here %d)', 0
openModeRB db 'rb', 0

; -------------------------------------------------------------------------------------
section '.idata' data readable import

library kernel32, 'kernel32.dll', msvcrt, 'msvcrt.dll', conio, 'conio.dll'

import kernel32, ExitProcess,'ExitProcess', GetFileAttributes, 'GetFileAttributesA' \
    , GetConsoleMode, 'GetConsoleMode', SetConsoleMode, 'SetConsoleMode', GetStdHandle, 'GetStdHandle'

import msvcrt, printf, 'printf', __getmainargs, '__getmainargs' \
    , fopen,'fopen', fclose, 'fclose', fseek, 'fseek', ftell, 'ftell' \
    , fread, 'fread', fgetc, 'fgetc', malloc, 'malloc', putchar, 'putchar', getch, '_getch'

    ; the end