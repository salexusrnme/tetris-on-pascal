program Tetris;
uses crt;

type
    tBlock = record //  keeps coordinates of a single tetromino block
        m, n: integer;
    end;
    tCord = array [1..4] of tBlock;  //  keeps coordinates of tetromino's blocks
    tTypes = (
        shapeL, shapeJ, shapeS, shapeZ, //  writes every type of tetromino
        shapeT, shapeI, shapeO
    );
    
    tPiece = record
    {   data structure that keeps information about current tetromino piece  }
        cords: tCord;   //  raw coordinates (how far away blocks are from the pivot point)
        shape: tTypes;
        x, y: integer;  //  pivot point on the gameboard
        rotation: byte; //  current state of rotation
    end;

    tHold = record
    {   data structure that keeps info about hold (refer to holdPiece procedure   }
        isEmpty: boolean;
        heldPiece: tPiece;
    end;

const 
    tetromino: array [tTypes] of tCord = (

{   saves coordinates of each block in tetromino    }

        ((m: -1; n: 0), (m: 0; n: 0), (m: 1; n: 0), (m: 1; n: 1)),  // L
        ((m: -1; n: 0), (m: 0; n: 0), (m: 1; n: 0), (m: -1; n: 1)), // J
        ((m: -1; n: 0), (m: 0; n: 0), (m: 0; n: 1), (m: 1; n: 1)),  // S
        ((m: 0; n: 0), (m: 1; n: 0), (m: -1; n: 1), (m: 0; n: 1)),  // Z
        ((m: -1; n: 0), (m: 0; n: 0), (m: 1; n: 0), (m: 0; n: 1)),  // T
        ((m: -1; n: 0), (m: 0; n: 0), (m: 1; n: 0), (m: 2; n: 0)),  // I
        ((m: 0; n: 0), (m: 1; n: 0), (m: 0; n: 1), (m: 1; n: 1))    // O
);

    errScreenHeight = 'Your terminal must be at least 24 symbols ' +
                      'in height to run this program.';
    errScreenWidth  = 'Your terminal must be at least 64 symbols ' +
                      'in width to run this program.';
                      
var
    gameboard: array [-1..20, 1..10] of char;    //  gameboard[y, x]
    x0, y0, ScreenHeight, ScreenWidth: integer;
    hold: tHold;
    
procedure GetKey(var code: integer);

{   gets rid of side effect of 'ReadKey' function and
    allows to type extended keys (specifically, arrow keys) }

var
    c: char;

begin
    c := ReadKey;
    if c = #0 then begin
        c := ReadKey;
        code := -ord(c)
    end
    else
        code := ord(c)
end;

procedure outputLine(y: integer);

{   writes a single line on a gameboard  }

var
    i: integer;

begin
    GotoXY(x0, y0+y-1);
    write(' ');
    for i := 1 to 10 do
        write(gameboard[y, i], ' ')
end;

{$IFDEF GAMEBOARD_DEBUG}
procedure gameboard_debug();

{   this procedure is used to show full gameboard if 
    specific debug mode is on   }

var
    i, j: integer;

begin   
    GotoXY(Screenwidth-22, 1);
    write('GAMEBOARD IN REAL TIME');
    GotoXY(Screenwidth-10, 2);
    for i := -1 to 20 do begin
        for j := 1 to 10 do
            if gameboard[i, j] = '#' then
                write(1)
            else
                write(0);
        GotoXY(Screenwidth-10, 4+i)
    end
end;
{$ENDIF}

procedure outputTetr(piece: tPiece; dy: integer);

{   outputs tetromino to the gameboard  }

begin
    case piece.rotation of
        0: begin
            if piece.shape <> shapeI then
                outputLine(piece.y-1);
            outputLine(piece.y);
            if dy = 1 then
                outputLine(piece.y+1)
        end;
        1: begin
            if piece.shape = shapeI then
                outputLine(piece.y-2);
            outputLine(piece.y-1);
            outputLine(piece.y);
            outputLine(piece.y+1);
            if dy = 1 then
                outputLine(piece.y+2)
        end;
        2: begin
            outputLine(piece.y-1);
            outputLine(piece.y);
            if ((piece.shape = shapeI) and (dy = 1)) or
              (piece.shape <> shapeI) then 
                outputLine(piece.y+1);
            if (dy = 1) and (piece.shape <> shapeI) then
                outputLine(piece.y+2)
        end;
        3: begin
            outputLine(piece.y-1);
            outputLine(piece.y);
            outputLine(piece.y+1);
            if (dy = 1) or (piece.shape = shapeI) then
                outputLine(piece.y+2);
            if (dy = 1) and (piece.shape = shapeI) then
                outputLine(piece.y+3)
        end
    end
end;

function canPlace(piece: tPiece; dx, dy: integer): boolean;

{   determines if it is possible to shift tetromino placement 
    by (dx, dy) without going out of bounds or overlapping 
    another tetromino   }

var
    i, curX, curY: integer;

begin
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        if (curX+dx > 10) or (curX+dx < 1) or (curY+dy > 20) or
            (curY+dy < -1) or (gameboard[curY+dy, curX+dx] = '#')
        then begin
            canPlace := false;
            exit;
        end
    end;
    canPlace := true
end;

procedure ghostPiece(piece: tPiece; block: char);

{   procedure works with ghost piece: removes it from the 
    gameboard and places it back, both happen when piece 
    moves horizontally or rotates  }

var
    i, curX, curY: integer;

begin
    for i := piece.y to 20 do begin
        if canPlace(piece, 0, 1) then
            piece.y := piece.y + 1
        else
            break
    end;
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        if (curY < 1) and (block = '.') then
            gameboard[curY, curX] := ' '
        else
            gameboard[curY, curX] := block
    end;
    outputTetr(piece, 0)
end;

procedure moveTetr(var piece: tPiece; dx, dy: integer; 
                                           var cannotProgress: boolean);

{   shifts tetromino by (dx, dy) on the gameboard if possible	} 

var
    i, curX, curY: integer;
    tmp: tPiece;

begin
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        if curY < 1 then
            gameboard[curY, curX] := ' '
        else
            gameboard[curY, curX] := '.'
    end;
    if canPlace(piece, dx, dy) then begin
        if dx <> 0 then begin
            tmp := piece;
            ghostPiece(tmp, '.');
            tmp.x := tmp.x + dx;
            ghostPiece(tmp, '0')
        end;
        for i := 1 to 4 do begin
            curX := piece.x + piece.cords[i].m;
            curY := piece.y - piece.cords[i].n;
            gameboard[curY+dy, curX+dx] := '#'
        end
    end
    else begin
        for i := 1 to 4 do begin
            curX := piece.x + piece.cords[i].m;
            curY := piece.y - piece.cords[i].n;
            gameboard[curY, curX] := '#'
        end;
        cannotProgress := true;
        exit;
    end;
    outputTetr(piece, dy);
    piece.x := piece.x + dx;
    piece.y := piece.y + dy
end;

procedure rotateTetr(var piece: tPiece);

{   rotates tetromino counterclockwise and outputs it    }

var
    tmp: tPiece;
    i, curX, curY: integer;

begin
    if piece.shape = shapeO then
        exit;
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        if curY < 1 then
            gameboard[curY, curX] := ' '
        else
            gameboard[curY, curX] := '.'
    end;
    tmp := piece;
    for i := 1 to 4 do begin
        tmp.cords[i].m := -(piece.cords[i].n);
        tmp.cords[i].n := piece.cords[i].m
    end;
    if canPlace(tmp, 0, 0) then begin
        tmp.rotation := (tmp.rotation + 1) mod 4;
        ghostPiece(piece, '.');
        ghostPiece(tmp, '0');
        for i := 1 to 4 do begin
            curX := tmp.x + tmp.cords[i].m;
            curY := tmp.y - tmp.cords[i].n;
            gameboard[curY, curX] := '#'
        end;
        piece := tmp;
        if (piece.shape = shapeI) and (piece.rotation = 2) then
            outputLine(piece.y-2);
        if (piece.shape = shapeI) and (piece.rotation = 0) then begin
            outputLine(piece.y-1);
            outputLine(piece.y+2);
        end;
        outputLine(piece.y+1);
        outputTetr(piece, 0)
    end
    else begin
        for i := 1 to 4 do begin
            curX := piece.x + piece.cords[i].m;
            curY := piece.y - piece.cords[i].n;
            gameboard[curY, curX] := '#';
        end
    end
end;

procedure outputHoldTetr(piece: tPiece);

{   places tetromino piece in hold section  }

begin
    GotoXY(x0-9, y0+1);
    case piece.shape of
        shapeL: begin
            writeln(' . . . #');
            GotoXY(x0-9, y0+2);
            writeln(' . # # #')
        end;
        shapeJ: begin
            writeln(' . # . .');
            GotoXY(x0-9, y0+2);
            writeln(' . # # #')
        end;
        shapeS: begin
            writeln(' . . # #');
            GotoXY(x0-9, y0+2);
            writeln(' . # # .')
        end;
        shapeZ: begin
            writeln(' . # # .');
            GotoXY(x0-9, y0+2);
            writeln(' . . # #')
        end;
        shapeT: begin
            writeln(' . . # .');
            GotoXY(x0-9, y0+2);
            writeln(' . # # #')
        end;
        shapeI: begin
            writeln(' . . . .');
            GotoXY(x0-9, y0+2);
            writeln(' # # # #')
        end;
        shapeO: begin
            writeln(' . . # #');
            GotoXY(x0-9, y0+2);
            writeln(' . . # #')
        end
    end
end;

procedure spawnNewTetromino(var piece: tPiece; var cannotSpawn: boolean);

{   places new tetromino on top of the board   }

var
    curX, curY, i: integer;

begin
    if not canPlace(piece, 0, 0) then begin
        cannotSpawn := true;
        exit
    end;
    ghostPiece(piece, '0');
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        gameboard[curY, curX] := '#'
    end;
    outputLine(-1);
    outputLine(0);
end;

function generateTetr: tPiece;

{   generates new tetromino piece when called   }

begin
    generateTetr.shape := tTypes(random(7));
    generateTetr.cords := tetromino[generateTetr.shape];
    generateTetr.x := 5;
    if generateTetr.shape = shapeI then
        generateTetr.y := -1
    else
        generateTetr.y := 0;
    generateTetr.rotation := 0;
end;

procedure holdPiece(var piece: tPiece; var hold: tHold);

{   tetris has a hold function, which stores current piece
    to use it later
    
    does exactly that	}

var
    tmp: tPiece;
    curX, curY, i: integer;
    uselessbool: boolean;

begin
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        if curY < 1 then
            gameboard[curY, curX] := ' '
        else
            gameboard[curY, curX] := '.'
    end;
    ghostPiece(piece, '.');
    outputTetr(piece, 0);
    uselessbool := false;
    if not hold.isEmpty then
        tmp := hold.heldPiece;
    hold.heldPiece.shape := piece.shape;
    hold.heldPiece.cords := tetromino[piece.shape];
    hold.heldPiece.x := 5;
    if piece.shape = shapeI then
        hold.heldPiece.y := -1
    else
        hold.heldPiece.y := 0;
    hold.heldPiece.rotation := 0;
    outputHoldTetr(hold.heldPiece);
    if hold.isEmpty then begin
        hold.isEmpty := false;
        piece := generateTetr;
        spawnNewTetromino(piece, uselessbool)
    end
    else begin
        piece := tmp;
        spawnNewTetromino(piece, uselessbool)
    end
end;

procedure hardDrop(var piece: tPiece);

{   implementation of hard drop function from tetris as it is - makes
    tetromino instantly fall and hit either floor or another tetromino  }

var
    i, curX, curY: integer;

begin
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        if curY < 1 then
            gameboard[curY, curX] := ' '
        else
            gameboard[curY, curX] := '.'
    end;
    outputTetr(piece, 0);
    for i := piece.y to 20 do begin
        if canPlace(piece, 0, 1) then
            piece.y := piece.y + 1
        else
            break
    end;    
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        gameboard[curY, curX] := '#'
    end;
    outputTetr(piece, 0)
end;

procedure keyboardInput(var piece: tPiece);

{   gets inputs from keyboard and makes changes for tetromino's position    }

var
    ms, key, tick: integer;
    uselessvar: boolean;

const
    exitOnX = 'You pressed ''x'' and ended the program.';
    LeftKey = -75;
    DownKey = -80;
    RightKey = -77;
    EscKey = 27;
    SpaceKey = 32;
    HoldKey = 99;	//  code of 'c'
    RotateKey = 113;    //  code of 'q'
    AltRotateKey = 122; //  code of 'z'
    ExitKey = 120;      //  code of 'x'    

begin
    ms := 0;
    tick := 50;
    uselessvar := true; //  this variable doesn't do anything. it only exists for moveTetr's number of parameters
    while ms < 1000 do
    begin
        if KeyPressed then begin
            GetKey(key);
            case key of
                LeftKey:
                    moveTetr(piece, -1, 0, uselessvar);
                DownKey:
                    moveTetr(piece, 0, 1, uselessvar);
                RightKey:
                    moveTetr(piece, 1, 0, uselessvar);
                RotateKey, AltRotateKey:
                    rotateTetr(piece);
                HoldKey:
                    holdPiece(piece, hold);
                SpaceKey: begin
                    hardDrop(piece);
                    exit
                end;
                EscKey: begin
                    GotoXY(1, ScreenHeight);
                    write('Game paused (press ''x'' to exit)');
                    repeat
                        GetKey(key);
                        if key = ExitKey then begin
                            clrscr;
                            writeln(exitOnX);
                            halt
                        end
                    until key = EscKey;
                    GotoXY(1, ScreenHeight);
                    write('                                 ');
                end
            end
        end;
        {$IFDEF GAMEBOARD_DEBUG}
        gameboard_debug();
        {$ENDIF}
        {$IFDEF DEBUG}
        GotoXY(1, 2);
        writeln('CURSHAPE: ', piece.shape);
        writeln('SHAPECORDS:'); 
        write('X=', piece.x, ', Y=', piece.y);
        writeln('  ');
        writeln('ROTATION: ', piece.rotation);
        {$ENDIF}
        GotoXY(1, ScreenHeight);
        while KeyPressed do     //  clears input buffer
            ReadKey;
        delay(tick);
        ms := ms + tick
    end
end;

function checkLine(y: integer): boolean;

{   checks if line is filled with '#'   }

var
    i: integer;

begin
    for i := 1 to 10 do begin
        if gameboard[y, i] <> '#' then begin
           checkLine := false;
           exit
        end
    end;
    checkLine := true
end;

procedure clearFilledLines;

{  removes all filled lines from the gameboard  }

var
    i, j: integer;

begin
    for i := 1 to 20 do begin
        if checkLine(i) then begin
            for j := i downto 2 do begin
                gameboard[j] := gameboard[j-1];
                outputLine(j);
            end;
            for j := 1 to 10 do
                if gameboard[0, j] = '#' then
                    gameboard[1, j] := '#'
                else
                    gameboard[1, j] := '.';
            gameboard[0] := gameboard[-1];
            for j := 1 to 10 do
                gameboard[-1, j] := ' ';
            outputLine(1);
            outputLine(0);
            outputLine(-1);
        end
    end
end;

procedure writeHold;

{   rewrites hold section   }

begin
    GotoXY(x0-10, y0);
    writeln('+===Hold=');
    GotoXY(x0-10, y0+1);
    writeln('! . . . .');
    GotoXY(x0-10, y0+2);
    writeln('! . . . .');
    GotoXY(x0-10, y0+3);
    writeln('+========')
end;

procedure initGameboard;

{   draws the gameboard, making borders around it   }

var
    i, j: integer;

const
    floor = '<!=====================!>';
    
begin
    GotoXY(x0-2, y0);
    for i := 1 to 20 do begin
        write('<! ');
        for j := 1 to 10 do
            write(gameboard[i, j] + ' ');
        write('!>');
        GotoXY(x0-2, y0+i)
    end;
    write(floor);
    writeHold
end;

procedure startGame;

{   main game cycle    }

var
    piece: tPiece;
    cannotSpawnTetr, cycleBroken: boolean;
    x, y: integer;

begin
    clrscr;
    randomize;
    {$IF Defined(DEBUG) OR Defined(GAMEBOARD_DEBUG)}
    GotoXY(1, 1);
    writeln('DEBUG MODE');
    {$ENDIF}
    {$IF not Defined(DEBUG) AND not Defined(GAMEBOARD_DEBUG)}
    GotoXY(ScreenWidth-16, 10);
    write(' Basic controls: ');
    GotoXY(ScreenWidth-25, 11);
    write(' Down/Left/Right arrows - ');
    GotoXY(ScreenWidth-5, 12);
    write(' move');
    GotoXY(Screenwidth-16, 13);
    write(' Q or Z - rotate');
    GotoXY(Screenwidth-14, 14);
    write('C - hold piece');
    GotoXY(Screenwidth-18, 15);
    write(' Space - hard drop');
    GotoXY(ScreenWidth-15, 16);
    write(' Escape - pause');
    {$ENDIF}
    x0 := (ScreenWidth - 20) div 2;         //  sets start position at which
    y0 := (ScreenHeight - 22) div 2 + 2;    //  gameboard is centered
    for y := -1 to 0 do
        for x := 1 to 10 do
            gameboard[y, x] := ' ';
    for y := 1 to 20 do
        for x := 1 to 10 do
            gameboard[y, x] := '.';
    initGameboard;
    piece := generateTetr;
    hold.isEmpty := true;
    while canPlace(piece, 0, 0) do begin
        cannotSpawnTetr := false;
        spawnNewTetromino(piece, cannotSpawnTetr);
        if cannotSpawnTetr then
            break;
        cycleBroken := false;
        while piece.y < 21 do begin
            keyboardInput(piece);
            moveTetr(piece, 0, 1, cycleBroken);
            if cycleBroken then
                break
        end;
        clearFilledLines;
        piece := generateTetr
    end;
    GotoXY(1, ScreenHeight);
    delay(1000);
    write('Game Over!');
    delay(2000);
    clrscr
end;

procedure mainMenu();

{   shows main menu at the start of the program and displays options    }

var
    c: char;

begin
    while true do begin
        GotoXY(1, 1);
        writeln('######## ######## ######## ########  ####  ######  ');
        writeln('   ##    ##          ##    ##     ##  ##  ##    ## ');
        writeln('   ##    ##          ##    ##     ##  ##  ##       ');
        writeln('   ##    ######      ##    ########   ##   ######  ');
        writeln('   ##    ##          ##    ##   ##    ##        ## ');
        writeln('   ##    ##          ##    ##    ##   ##  ##    ## ');
        writeln('   ##    ########    ##    ##     ## ####  ######  ');
        GotoXY(1, 9);
        write('1. Start game');
        GotoXY(1, 10);
        write('0. Exit');
        GotoXY(1, 12);
        write('Select your choice: ');
        repeat
            c := ReadKey;
        until c in ['1', '0'];
        case c of
            '1':
                startGame;
            '0': begin
                clrscr;
                halt
            end
        end
    end
end;

begin
    ScreenWidth := WindMaxX;
    ScreenHeight := WindMaxY;
    if ScreenHeight < 24 then begin
        writeln(errScreenHeight);
        halt(1);
    end;
    if ScreenWidth < 64 then begin
        writeln(errScreenWidth);
        halt(1);
    end;
    clrscr;
    {$IF Defined(DEBUG) OR Defined(GAMEBOARD_DEBUG)}
    GotoXY(1, 13);
    writeln('DEBUG MODE');
    {$ENDIF}
    mainMenu
end.
