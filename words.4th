: ?DUP DUP IF DUP THEN ;
: (const) LITERAL , RET ;
: CONSTANT  CREATE-NAME (const) ;
: VARIABLE  CREATE-NAME HERE 2 + CELL + (const) 0 , ;
: CVARIABLE CREATE-NAME HERE 2 + CELL + (const) 0 C, ;

: ascii. DUP HEX. BL DUP DECIMAL. BL EMIT ;
: ascii 2DUP < IF SWAP THEN BEGIN CRLF DUP ascii. 1+ 2DUP > WHILE 2DROP ;

: dump ( start end -- ) 
    CR 2DUP < 
    IF 
        SWAP 
    THEN 
    BEGIN 
        2DUP <
        IF 2DROP LEAVE 
        THEN 
        DUP BL C@ HEX. 1+ 
    AGAIN ;

: dump-n ( start num -- ) 
    OVER + 1-
    CR 2DUP < 
    IF 
        SWAP 
    THEN 
    BEGIN 
        2DUP < 
        IF 2DROP LEAVE 
        THEN 
        DUP BL C@ HEX. 1+ 
    AGAIN ;

: dump-w ( start end -- ) 
    CR 2DUP < 
    IF 
        SWAP 
    THEN 
    BEGIN 
        2DUP < 
        IF 2DROP LEAVE 
        THEN 
        DUP BL @ HEX. CELL + 
    AGAIN ;

: dump-nw ( start num -- ) 
    CELLS OVER +
    CR 2DUP < 
    IF 
        SWAP 
    THEN 
    BEGIN 
        2DUP < 
        IF 2DROP LEAVE 
        THEN 
        DUP BL @ HEX. CELL + 
    AGAIN ;

: dump.num ( start num -- ) OVER + dump ;

: img-save ( file-name -- )
    1 1 FOPEN IF
       >R
       0 MEM_SZ R@ FWRITE 
	   . "  bytes written." CT
       R> FCLOSE
   ELSE
       " cannot open file!" CT RESET
   THEN ;

\ ------------------------------------------------------------------------------------
\ A stack is comprised of 3 parts, [stack-pointer] [stack-top-pointer] [stack-data]
\ The stack "bottom" is the first CELL after the (stack-top) pointer
\
: (stk-ptr) ;                                   \ ( stk -- stk-ptr-addr )
: (stk-top) CELL + ;		        	        \ ( stk -- last-cell-addr )
: stk-bottom 2 CELLS + ;                        \ ( stk -- bottom )
: stk-top (stk-top) @ ;			                \ ( stk -- last-cell-addr )
: stk-ptr (stk-ptr) @ ;                         \ ( stk -- stk-ptr )
: stk-depth DUP stk-ptr                         \ ( stk -- depth )
    SWAP stk-bottom - CELL / ;
: stk-pick @ swap cells - @ ;                   \ ( n1 stk -- n2 )

: stk-init   USINIT                             \ ( sz stk -- top )
    here over <
    if 
        (here) !
    else 
        drop
    then
 ;

: stk-sz >R R@ cell + @ R> 2 cells + - cell / 1+ ;
: stk-reset >R R@ stk-sz R> stk-init ;   \ ( stk -- )

: >stk USPUSH ; INLINE
: stk> USPOP  ; INLINE
: stk@ dup >R stk> dup R> >stk ;

\ --------------------------------------------------------------------------------
\ -- Parameter stack words
\ --------------------------------------------------------------------------------
variable ps
decimal 64 ps stk-init
: >p ps >stk ; 
: p> ps stk> ; 
: pdepth ps stk-depth ;
: pdrop ps stk> DROP ;
: pclear ps stk-reset ;
: (p) ps @ swap cells - ;
: ppick (p) @ ;
: (p1) 1 (p) ;
: (p2) 2 (p) ;
: (p3) 3 (p) ;
: (p4) 4 (p) ;
: (p5) 5 (p) ;
: (p6) 6 (p) ;
: p1 (p1) @ ;
: p2 (p2) @ ;
: p3 (p3) @ ;
: p4 (p4) @ ;
: p5 (p5) @ ;
: p6 (p6) @ ;
: p1! (p1) ! ;
: p2! (p2) ! ;
: p3! (p3) ! ;
: p4! (p4) ! ;
: p5! (p5) ! ;
: p6! (p6) ! ;
: >>p
    1 begin 
        2dup < if 2drop leave then 
        >R >R 
            >p
        R> R> 1+ 
    again ;
: p>>
    1 begin 
        2dup < if 2drop leave then 
        >R >R 
            pdrop
        R> R> 1+ 
    again ;

\ --------------------------------------------------------------------------------
\ returns 2 raised to the n-th power
: pow-2   \ ( n1 -- n2 )
	1 swap 0 begin
	2dup = if 2drop leave then
	>R >R
	2 *
	R> R> 1+ again ;


\ --------------------------------------------------------------------------------
: start-timer gettick ;
: .ms 1000 /mod . " seconds, " ct . " ms" ct ;
: elapsed gettick swap - .ms ;