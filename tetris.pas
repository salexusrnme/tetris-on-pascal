program Tetris;
uses crt;

type
    tBlock = record //  keeps coordinates of a single tetromino block
        m, n: integer;
    end;
    tCord = array [1..4] of tBlock;  //  keeps coordinates of tetromino's blocks
    tTypes = (
        shapeL, shapeJ, shapeZ, shapeS, //  writes every type of tetromino
        shapeT, shapeI, shapeO
    );
    
    tPiece = record
    {   data structure that keeps information about current tetromino piece  }
        cords: tCord;   //  raw coordinates (how far away blocks are from the pivot point)
        shape: tTypes;
        x, y: integer;  //  pivot point on the gameboard
        rotation: byte; //  current state of rotation
    end;

const
    tetromino: array [tTypes] of tCord = (

{   saves coordinates of each block in tetromino    }

        ((m: -1; n: 0), (m: 0; n: 0), (m: 1; n: 0), (m: 1; n: 1)),  // L
        ((m: -1; n: 0), (m: 0; n: 0), (m: 1; n: 0), (m: -1; n: 1)), // J
        ((m: -1; n: 0), (m: 0; n: 0), (m: 0; n: 1), (m: 1; n: 1)),  // Z
        ((m: 0; n: 0), (m: 1; n: 0), (m: -1; n: 1), (m: 0; n: 1)),  // S
        ((m: -1; n: 0), (m: 0; n: 0), (m: 1; n: 0), (m: 0; n: 1)),  // T
        ((m: -1; n: 0), (m: 0; n: 0), (m: 1; n: 0), (m: 2; n: 0)),  // I
        ((m: 0; n: 0), (m: 1; n: 0), (m: 0; n: 1), (m: 1; n: 1))    // O
);

    errScreenHeight = 'Your terminal must be at least 24 symbols ' +
                      'in height to run this program.';
                      
var
    gameboard: array [-1..20, 1..10] of char;    //  gameboard[y, x]
    x0, y0: integer;
    
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

procedure outputTetr(var piece: tPiece; dy: integer);

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

procedure moveTetr(var piece: tPiece; dx, dy: integer; 
                                           var cannotProgress: boolean);

{   shifts tetromino by (dx, dy) on the gameboard if possible	} 

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
    if canPlace(piece, dx, dy) then begin
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
        for i := 1 to 4 do begin
            curX := tmp.x + tmp.cords[i].m;
            curY := tmp.y - tmp.cords[i].n;
            gameboard[curY, curX] := '#'
        end;
        piece := tmp;
        piece.rotation := (piece.rotation + 1) mod 4;
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

procedure hardDrop(var piece: tPiece);
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
    ms, key: integer;
    uselessvar: boolean;

const
    exitOnEsc = 'You pressed Escape and ended the program.';
    LeftKey = -75;
    DownKey = -80;
    RightKey = -77;
    EscKey = 27;
    SpaceKey = 32;
    RotateKey = 113;    //  code of 'q'
    AltRotateKey = 122; //  code of 'z'
    
begin
    ms := 0;
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
                SpaceKey: begin
                    hardDrop(piece);
                    ms := 950;
                end;
                EscKey: begin
                    clrscr;
                    writeln(exitOnEsc);
                    halt
                end
            end
        end;
        {$IFDEF GAMEBOARD_DEBUG}
        gameboard_debug();
        {$ENDIF}
        {$IFDEF DEBUG}
        GotoXY(1, 2);
        writeln('CURSHAPE: ', piece.shape);
        write('SHAPECORDS: X=', piece.x, ', Y=', piece.y);
        writeln(' ');
        writeln('ROTATION: ', piece.rotation);
        {$ENDIF}
        GotoXY(1, ScreenHeight);
        while KeyPressed do     //  clears input buffer
            ReadKey;
        delay(50);
        ms := ms + 50
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


procedure initializeGameboard;

{   draws the gameboard, making borders around it   }

var
    i, j: integer;

const
    floor = ' +=====================+';
    
begin
    GotoXY(x0-2, y0);
    for i := 1 to 20 do begin
        write('<! ');
        for j := 1 to 10 do
            write(gameboard[i, j] + ' ');
        write('!>');
        GotoXY(x0-2, y0+i)
    end;
    write(floor)
end;

function continueGame(condY, condX: integer): boolean;

{   game cannot continue if there is no place for another tetromino to appear

    determines if it is possible to continue the game
    if yes, returns true, if not, returns false }

begin
    continueGame := gameboard[condY, condX] <> '#';
end;

procedure spawnNewTetromino(var piece: tPiece; var cannotSpawn: boolean);

{   makes tetromino appear on top of the board  }

var
    curX, curY, i: integer;

begin
    for i := 1 to 4 do begin
        curX := piece.x + piece.cords[i].m;
        curY := piece.y - piece.cords[i].n;
        if gameboard[curY, curX] = '#' then begin
            cannotSpawn := true;
            exit
        end
        else
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
    GotoXY(Screenwidth-18, 14);
    write(' Space - hard drop');
    GotoXY(ScreenWidth-22, 15);
    write(' Escape - exit program');
    {$ENDIF}
    x0 := (ScreenWidth - 19) div 2;         //  sets start position at which
    y0 := (ScreenHeight - 22) div 2 + 2;    //  gameboard is centered
    for x := 1 to 10 do begin
        for y := -1 to 0 do
            gameboard[y, x] := ' ';
        for y := 1 to 20 do
            gameboard[y, x] := '.'
    end;
    initializeGameboard;
    piece := generateTetr;
    while continueGame(piece.y, piece.x) do begin
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
    if ScreenHeight < 24 then begin
	writeln(errScreenHeight);
	halt(1);
    end;
    clrscr;
    {$IF Defined(DEBUG) OR Defined(GAMEBOARD_DEBUG)}
    GotoXY(1, 13);
    writeln('DEBUG MODE');
    {$ENDIF}
    mainMenu
end.
