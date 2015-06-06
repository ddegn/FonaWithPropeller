DAT programName         byte "FonaTest", 0
CON
{  
  This program tests an algorithm for generating appropriate delays to stepper motors.
  The resulting motion should produce an eighth of a circle.

}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

CON

  SCALED_MULTIPLIER = 10_000
  SCALED_DECIMAL_PLACES = 4
  
  X_AXIS = 0
  Y_AXIS = 1
  SCALED_TAU = round(2.0 * pi * float(SCALED_MULTIPLIER))
  SCALED_TAU_OVER_8 = round(pi * float(SCALED_MULTIPLIER) / 4.0)
  SCALED_TAU_OVER_4 = round(pi * float(SCALED_MULTIPLIER) / 2.0)
  SCALED_TAU_OVER_2 = round(pi * float(SCALED_MULTIPLIER))
  SCALED_ROOT_2 = round(^^2.0 * float(SCALED_MULTIPLIER))

  PIECES_IN_CIRCLE = 8

  ' activeMode enumeration
  #0, UXOURIOUS_TERMINAL_MODE, TERMINAL_MODE, UXOURIOUS_PORTABLE_MODE, PORTABLE_MODE

  ' subMode enumeration
  #0, WHICH_PHONE, TEXT_OR_VOICE, WHICH_TEXT

  ' activePhone enumeration
  #0, CHRISTINA_CELL, CHRISTINA_HOME, CHRISTINA_WORD

  MAX_PHONE_INDEX = CHRISTINA_WORD
  NUMBER_OF_PHONES = MAX_PHONE_INDEX + 1

  ' phoneType enumeration
  #0, LAND_LINE, CELL_LINE

  TEXT_MESSAGES = 4
  MAX_MESSAGE_INDEX = TEXT_MESSAGES - 1
  
  QUOTE = 34

VAR

  long axisDelay[2], xIndex, yIndex, xSquared, ySquared
  long rSquared, previousY
  long fastAtNextSlow, nextSlow, nextSlowSquared
  long fastStepsPerSlow, lastStep[2]
  long fullSpeedSteps, decelSteps
  long lastAccel, activeAccel[2]
  long stepState[2], lastHalfStep[2], lastAccelCnt
  long previousCnt, newCnt, differenceCnt
  long missedHalfCount[2], pLastHalfStep[2], pLastStep[2]

  byte networkState
  
DAT

{minDelay                long 100 * MS_001, 0-0
maxDelay                long 250 * MS_001, 0-0 
axisDeltaDelay          long 20 * MS_001, 0-0
defaultDeltaDelay       long 20 * MS_001, 0-0
timesToA                long 132
accelerationInterval    long 300 * MS_001   
radius                  long 400
startOctant             long 0
distance                long 8
'centerX                 long 0
'centerY                 long 400
stepsToTakeX            long 0-0
stepsToTakeY            long 0-0
directionX              long 1[2], -1[4], 1[2]
directionY              long 1[4], -1[4]
previousDirectionX      long 0-0
previousDirectionY      long 0-0
fastAxisByOctant        long 0, 1[2], 0[2], 1[2], 0
slowAxisByOctant        long 1, 0[2], 1[2], 0[2], 1
otherAxis               long 1, 0
presentFast             long 0-0
presentSlow             long 0-0
presentDirectionX       long 0-0
presentDirectionY       long 0-0
accelPhase              long ACCEL_PHASE
activeOctant            long 0-0
toTakeFullSpeedTrigger  long 0-0
toTakeDecelTrigger      long 0-0
accelAxis               long 0-0
decelAxis               long 0-0
stepPinX                long Header#STEP_X_PIN
stepPinY                long Header#STEP_Y_PIN
dirPinX                 long Header#DIR_X_PIN     
dirPinY                 long Header#DIR_Y_PIN
octantSizeX             long 0-0[8]
octantSizeY             long 0-0[8]
fullSpeedOctant         long 0-0
decelOctant             long 0-0
endOctant               long 0-0
}
activeMode              byte UXOURIOUS_TERMINAL_MODE
subMode                 byte WHICH_PHONE
activePhone             byte CHRISTINA_CELL

OBJ

  Header : "HeaderFona"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
  'Sd[1]: "SdSmall" 
  Fona : "FonaMethods"
 
PUB Setup

  Pst.Start(115_200)
 
  repeat
    result := Pst.RxCount
    Pst.str(string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  Pst.RxFlush

  Fona.Start

  Fona.SetPower(1)
  waitcnt(clkfreq / 4 + cnt) 
  'Pst.Clear

  networkState := Fona.CheckNetwork

  Pst.str(string(11, 13))
  Pst.str(Header.FindString(@networkStateText, networkState)) 

  Fona.PressToContinue
  'waitcnt(clkfreq * 2 + cnt) 
  
  'Pst.Clear

  MainLoop

PUB MainLoop

  repeat
    'UxouriousTerminalLoop
    Pst.str(string(11, 13))
    Pst.str(Header.FindString(@networkStateText, networkState)) 
    Fona.TerminalBridge
    
    {
    Pst.Home
    Pst.Str(string(11, 13, "radius = "))
    Pst.Dec(radius)
    Pst.str(string(11, 13, "startOctant = "))
    Pst.Dec(startOctant)
    Pst.str(string(", distance = "))
    Pst.Dec(distance)
    Pst.Str(string(11, 13, "acceleration steps = "))
    Pst.Dec(timesToA)
    
    Pst.Str(string(11, 13, "Machine waiting for input."))
    
    Pst.Str(string(11, 13, "Press ", QUOTE, "r", QUOTE, " to change Radius.")) 
    'Pst.Str(string(11, 13, "Press ", QUOTE, "x", QUOTE, " to change center's X coordinate."))
    'Pst.Str(string(11, 13, "Press ", QUOTE, "y", QUOTE, " to change center's Y coordinate."))
    Pst.Str(string(11, 13, "Press ", QUOTE, "s", QUOTE, " to change Start octant. (0 bottom center and ccw from there.)"))
    Pst.Str(string(11, 13, "Press ", QUOTE, "d", QUOTE, " to change Distance to travel (in eighths of circle)."))
    Pst.Str(string(11, 13, "Press ", QUOTE, "e", QUOTE, " Execute circle with current parameters."))
    Pst.Char(11)
    Pst.Char(13)
    Pst.ClearBelow
    result := Pst.RxCount
  
    CheckMenu(result)   }

'activeMode enumeration
'  #0, UXOURIOUS_TERMINAL_MODE, TERMINAL_MODE, UXOURIOUS_PORTABLE_MODE, PORTABLE_MODE
      
PUB CheckMenu(tempValue) 
 {
  if tempValue
    tempValue := Pst.CharIn
  else
    return
      
  case tempValue
    "r", "R": 
      Pst.Str(string(11, 13, "Enter new radius."))
      radius := Pst.DecIn
    "s", "S": 
      Pst.Str(string(11, 13, "Enter new start octant."))
      startOctant := Pst.DecIn
    "d", "D": 
      Pst.Str(string(11, 13, "Enter new distance to travel (in units of octants)."))
      distance := Pst.DecIn
    "e", "E": 
      Pst.Str(string(11, 13, "Executing Circle"))
      ExecuteCircle
    other:
      Pst.Str(string(11, 13, "Not a valid entry.")) 
              }
PUB TerminalInput

{  repeat

  while fonaMode == TERMINAL_MODE

 }

PUB UxouriousTerminalLoop
 {
  repeat
    UxouriousTerminalMenu
    result := Pst.RxCount
    if result
      UxouriousTerminalInput
  while fonaMode == UXOURIOUS_TERMINAL_MODE
                 }
PUB UxouriousTerminalMenu

  'case subMode
  Pst.Home
  Pst.Str(string(11, 13, "Uxourious Terminal Mode"))

  'Pst.Str(string(11, 13, "The present active number is "))
  'Pst.str(Header.FindString(@phoneNameText, activePhone)
    
  Pst.str(string(11, 13, 11, 13, "Please select on of the following options."))

  Pst.Str(string(11, 13, "Press ", QUOTE, "h", QUOTE, " to call wife at Home.")) 
  Pst.Str(string(11, 13, "Press ", QUOTE, "c", QUOTE, " to call wife on Cell phone."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "w", QUOTE, " to call wife at Work."))

  Pst.Str(string(11, 13, "To send a text message to her cell phone enter one of the numbers below."))
  repeat result from 0 to MAX_MESSAGE_INDEX
    Pst.Dec(result)
    Pst.Str(string(") ", QUOTE))
    Pst.str(Header.FindString(@textMessageText, result))
    Pst.Str(string(") ", QUOTE))
      
  Pst.Char(11)
  Pst.Char(13)
  Pst.ClearBelow

PUB UxouriousTerminalInput

  result := Pst.CharIn
  case result
    "h", "H":
      Fona.Dial(Header.FindString(@phoneNameText, CHRISTINA_HOME), {
      } Header.FindString(@phoneNumberText, CHRISTINA_HOME))
  
PUB SendText(textId)

  if phoneType[activePhone] <> CELL_LINE
    Pst.Str(string(11, 13, "The present active number ", QUOTE))
    Pst.str(Header.FindString(@phoneNameText, activePhone))
    Pst.Str(string(QUOTE, " is not a cell phone."))
    Pst.Str(string(11, 13, "Please select of cell phone to test."))
    return 

  Pst.Str(string(11, 13, "Please select which text message you'd like to send."))
  repeat result from 0 to MAX_MESSAGE_INDEX
    Pst.Dec(result)
    Pst.Str(string(") ", QUOTE))
    Pst.str(Header.FindString(@textMessageText, result))
      
{PUB FillOctantSize(radiusOverRoot2)
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \4|3/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  5\|/2  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  6/|\1  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /7|0\  0) Cx<0, Cy>0
  ''

  Pst.Str(string(11, 13, "FillOctantSize"))
       
  repeat result from 0 to 7
    case result
      0, 3, 4, 7:
        octantSizeX[result] := radiusOverRoot2
        octantSizeY[result] := radius - radiusOverRoot2
      1, 2, 5, 6:
        octantSizeX[result] := radius - radiusOverRoot2
        octantSizeY[result] := radiusOverRoot2

PUB CalculateFullSpeedOctant | localStart[2], localEnd[2], toTakeX[2], toTakeY[2], toA[2], {
} toD[2], dAxis[2], midAxis[2]

  longfill(@localStart, startOctant, 2)
  longfill(@localEnd, endOctant, 2)
  longfill(@toTakeX, stepsToTakeX, 2)
  longfill(@toTakeY, stepsToTakeY, 2)
  longfill(@toA, timesToA, 2)
  longfill(@toD, timesToA, 2)
  longfill(@midAxis, startOctant, 2)
  longfill(@dAxis, endOctant, 2)

  Pst.Str(string(11, 13, "CalculateFullSpeedOctant"))

  Pst.Str(string(11, 13, "endOctant = "))
  Pst.Dec(endOctant)
  Pst.Str(string(11, 13, "startOctant = "))
  Pst.Dec(startOctant)
  Pst.Str(string(11, 13, "toD[0] = "))
  Pst.Dec(toD[0])
    
  repeat while toD[0] > 0
    toD[0] -= octantSizeX[dAxis[0]]
    if dAxis[0] == 0 
      dAxis[0] := 7
    else
      dAxis[0]--
    Pst.Str(string(11, 13, "toD[0] = "))
    Pst.Dec(toD[0])
   
  dAxis[0]++
  dAxis[0] &= 7
  Pst.Str(string(11, 13, "dAxis[0] = "))
  Pst.Dec(dAxis[0])

  Pst.Str(string(11, 13, "toD[1] = "))
  Pst.Dec(toD[1])
  
  repeat while toD[1] > 0
    toD[1] -= octantSizeX[dAxis[1]]
    if dAxis[1] == 0 
      dAxis[1] := 7
    else
      dAxis[1]--
    Pst.Str(string(11, 13, "toD[1] = "))
    Pst.Dec(toD[1])
    
  dAxis[1]++
  dAxis[1] &= 7    
  Pst.Str(string(11, 13, "dAxis[1] = "))
  Pst.Dec(dAxis[1])
  
  if dAxis[0] > dAxis[1]
    decelOctant := dAxis[0]
    decelAxis := 0
  elseif dAxis[1] > dAxis[0]
    decelOctant := dAxis[1]
    decelAxis := 1
  elseif toD[0] > toD[1]
    decelOctant := dAxis[0]
    decelAxis := 0
  elseif toD[1] > toD[0]
    decelOctant := dAxis[1]
    decelAxis := 1
  else
    decelOctant := dAxis[0]
    decelAxis := fastAxisByOctant[dAxis[0]]
    {Pst.Str(string(11, 13, "This shouldn't happen. dAxis[0] = "))
    Pst.Dec(dAxis[0])
    Pst.Str(string(", dAxis[1] = "))
    Pst.Dec(dAxis[1])
    Pst.Str(string(11, 13, "toD[0] = "))
    Pst.Dec(toD[0])
    Pst.Str(string(", toD[1] = "))
    Pst.Dec(toD[1])
    Pst.Str(string(7, 11, 13, "Program Over"))
    repeat  }
    
  Pst.Str(string(11, 13, "CalculateFullSpeedOctant, dAxis[0] = "))
  Pst.Dec(dAxis[0])
  Pst.Str(string(", dAxis[1] = "))
  Pst.Dec(dAxis[1])
  Pst.Str(string(11, 13, "toD[0] = "))
  Pst.Dec(toD[0])
  Pst.Str(string(", toD[1] = "))
  Pst.Dec(toD[1])
  Pst.Str(string(", decelOctant = "))
  Pst.Dec(decelOctant)
  Pst.Str(string(", decelAxis = "))
  Pst.Dec(decelAxis)
    
  Pst.Str(string(11, 13, "toA[0] = "))
  Pst.Dec(toA[0])
        
  repeat while toA[0] > 0
    toA[0] -= octantSizeX[localStart[0]++]
    localStart[0] &= 7
    Pst.Str(string(11, 13, "toA[0] = "))
    Pst.Dec(toA[0])

  if localStart[0] == 0 
    localStart[0] := 7
  else
    localStart[0]--
         
  Pst.Str(string(11, 13, "localStart[1] = "))
  Pst.Dec(localStart[1])

  Pst.Str(string(11, 13, "toA[1] = "))
  Pst.Dec(toA[1])
  
  repeat while toA[1] > 0
    toA[1] -= octantSizeX[localStart[1]++]
    localStart[1] &= 7
    Pst.Str(string(11, 13, "toA[1] = "))
    Pst.Dec(toA[1])
    
  if localStart[1] == 0 
    localStart[1] := 7
  else
    localStart[1]--
  
  if localStart[0] > localStart[1]
    fullSpeedOctant := localStart[0]
    accelAxis := 0
  elseif localStart[1] > localStart[0]
    fullSpeedOctant := localStart[1]
    accelAxis := 1
  elseif toA[0] > toA[1]
    fullSpeedOctant := localStart[0]
    accelAxis := 0
  elseif toA[1] > toA[0]
    fullSpeedOctant := localStart[1]
    accelAxis := 1
  else
    fullSpeedOctant := localStart[0]
    accelAxis := fastAxisByOctant[localStart[0]]
    {Pst.Str(string(11, 13, "This shouldn't happen. localStart[0] = "))
    Pst.Dec(localStart[0])
    Pst.Str(string(", localStart[1] = "))
    Pst.Dec(localStart[1])
    Pst.Str(string(11, 13, "toA[0] = "))
    Pst.Dec(toA[0])
    Pst.Str(string(", toA[1] = "))
    Pst.Dec(toA[1])
    Pst.Str(string(7, 11, 13, "Program Over"))
    repeat }
    
  Pst.Str(string(11, 13, "CalculateFullSpeedOctant, localStart[0] = "))
  Pst.Dec(localStart[0])
  Pst.Str(string(", localStart[1] = "))
  Pst.Dec(localStart[1])
  Pst.Str(string(11, 13, "toA[0] = "))
  Pst.Dec(toA[0])
  Pst.Str(string(", toA[1] = "))
  Pst.Dec(toA[1])
  Pst.Str(string(", fullSpeedOctant = "))
  Pst.Dec(fullSpeedOctant)
  Pst.Str(string(", accelAxis = "))
  Pst.Dec(accelAxis)

  toTakeFullSpeedTrigger := stepsToTakeX[accelAxis] - timesToA
  toTakeDecelTrigger := timesToA 

PUB ExecuteCircle | radiusOverRoot2, {
} activeOctants, scaledDistance, now
'' The circle is divided into 8 "pieces" or pieces of eight.
'' For now the start of the circle needs to begin at a piece
'' boundry.
'' y = ^^((r * r) - (x * x))
''
  
  accelPhase := ACCEL_PHASE
  rSquared := radius * radius
  'distanceToCenterSquared := (centerX * centerX) + (centerY * centerY)
  activeOctants := distance
  
  {if distanceToCenterSquared > rSquared
    result := ^^distanceToCenterSquared
    Pst.Str(string(11, 13, "The center is "))
    Pst.Dec(result)
    Pst.Str(string(" units away which is great than the radius which is "))
    Pst.Dec(radius)
    Pst.Str(string(" units. This distance will become the new radius."))
    radius := result    
        
  if ||centerX > radius
    centerX := radius * centerX / ||centerX
    centerY := 0
    Pst.Str(string(11, 13, "centerX too far away."))  
    Pst.Str(string(11, 13, "centerX now equals "))  }

  Pst.Str(string(11, 13, "radius = "))
  Pst.Dec(radius)
  {Pst.str(string(11, 13, "center = "))
  Pst.Dec(centerX)  
  Pst.str(string(", "))
  Pst.Dec(centerY)   }

  radiusOverRoot2 := radius * SCALED_MULTIPLIER / SCALED_ROOT_2
  Pst.Str(string(11, 13, "radiusOverRoot2 = "))
  Pst.Dec(radiusOverRoot2)

  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \4|3/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  5\|/2  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  6/|\1  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /7|0\  0) Cx<0, Cy>0
  ''       
  {if centerX < -radiusOverRoot2 and centerY > 0
    startOctant := 2 '1
    xIndex := -radiusOverRoot2 
    yIndex := 0 
    xCountdown := radius - radiusOverRoot2
    yCountdown := radius + radiusOverRoot2
  elseif centerX < -radiusOverRoot2 
    startOctant := 2
    xCountdown := 2 * radius 
    yCountdown := radius
  elseif centerX < 0 and centerY > 0
    startOctant := 0
    xCountdown := radius 
    yCountdown := 2 * radius
  elseif centerX < 0
    startOctant := 3
    xCountdown := radius + radiusOverRoot2
    yCountdown := radius - radiusOverRoot2
  elseif centerX > radiusOverRoot2 and centerY > 0
    startOctant := 6
    xCountdown := 2 * radius 
    yCountdown := radius
  elseif centerX > radiusOverRoot2 
    startOctant := 5
    xCountdown := radius + radiusOverRoot2
    yCountdown := radius + radiusOverRoot2
  elseif centerX > 0 and centerY > 0
    startOctant := 7
    xCountdown := radius + radiusOverRoot2
    yCountdown := radius - radiusOverRoot2
  else
    startOctant := 4
    xCountdown := radius - radiusOverRoot2
    yCountdown := radius + radiusOverRoot2 }
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \4|3/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  5\|/2  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  6/|\1  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /7|0\  0) Cx<0, Cy>0
  ''     
  case startOctant  ' come up with a better algorithm for fill these values
    0:
      xIndex := 0
      yIndex := -radius
      'xCountdown := radius 
      'yCountdown := 2 * radius
    1:
      xIndex := radiusOverRoot2 
      yIndex := -radiusOverRoot2
      'xCountdown := radius - radiusOverRoot2
      'yCountdown := radius + radiusOverRoot2
    2:
      xIndex := radius
      yIndex := 0
      'xCountdown := 2 * radius 
      'yCountdown := radius
    3:
      xIndex := radiusOverRoot2 
      yIndex := radiusOverRoot2
      'xCountdown := radius + radiusOverRoot2
      'yCountdown := radius - radiusOverRoot2
    4:
      xIndex := 0
      yIndex := radius
      'xCountdown := radius 
      'yCountdown := 2 * radius
    5:
      xIndex := -radiusOverRoot2 
      yIndex := radiusOverRoot2
      'xCountdown := radius - radiusOverRoot2
      'yCountdown := radius + radiusOverRoot2
    6:
      xIndex := -radius
      yIndex := 0
      'xCountdown := 2 * radius 
      'yCountdown := radius
    7:
      xIndex := -radiusOverRoot2 
      yIndex := -radiusOverRoot2
      'xCountdown := radius + radiusOverRoot2
      'yCountdown := radius - radiusOverRoot2
      
  activeOctant := startOctant
  previousDirectionX := directionX[startOctant]
  previousDirectionY := directionY[startOctant]
  
  Pst.Str(string(11, 13, "startOctant = "))
  Pst.Dec(startOctant)
  Pst.Str(string(11, 13, "x direction = "))
  Pst.Str(DisplayDirection(directionX[startOctant]))
  Pst.Str(string(11, 13, "y direction = "))
  Pst.Str(DisplayDirection(directionY[startOctant]))


  endOctant := startOctant + distance
  endOctant &= 7

  result := distance - (startOctant & 1) ' don't count odd pieces at start or end, add these later.
  result -= endOctant & 1 
  stepsToTakeX := radius * result / 2 
  stepsToTakeY := stepsToTakeX  ' doesn't include partial pieces

  case startOctant 
    1, 5:
      stepsToTakeX += radius - radiusOverRoot2
      stepsToTakeY += radiusOverRoot2
    3, 7:
      stepsToTakeX += radiusOverRoot2
      stepsToTakeY += radius - radiusOverRoot2
    
  case endOctant 
    1, 5:
      stepsToTakeX += radiusOverRoot2
      stepsToTakeY += radius - radiusOverRoot2
    3, 7:
      stepsToTakeX += radius - radiusOverRoot2
      stepsToTakeY += radiusOverRoot2
    
      
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \4|3/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  5\|/2  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  6/|\1  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /7|0\  0) Cx<0, Cy>0
  '' 
  'accelSteps := timesToA           
  decelAxis := fastAxisByOctant[endOctant]
  'decelSteps := stepsToTakeX[decelAxis]

  accelAxis := fastAxisByOctant[startOctant]
  'fullSpeedSteps := stepsToTakeX[decelAxis] - timesToA
  ' all but final decel (reached at end of full speed phase)

  axisDelay[fastAxisByOctant[startOctant]] := maxDelay
  axisDeltaDelay[fastAxisByOctant[startOctant]] := -defaultDeltaDelay

  toTakeFullSpeedTrigger := stepsToTakeX[accelAxis] - timesToA
  toTakeDecelTrigger := timesToA 

  FillOctantSize(radiusOverRoot2)
  
  CalculateFullSpeedOctant
  
  presentFast := fastAxisByOctant[startOctant]
  presentSlow := slowAxisByOctant[startOctant] 
  presentDirectionX := -directionX[startOctant] ' start negative so when "ReverseDirection" method
                                                ' is used it corrects the direction as it sets pin
  presentDirectionY := directionY[startOctant] 
  ReverseDirection(0)
  ReverseDirection(1)
  
  
 { timesToA := ComputeAccelIntervals(axisDelay[presentFast], minDelay, {
  } defaultDeltaDelay, accelerationInterval) '(reached at end of accel phase)
  }
  
  'xIndex := 0
  'xSquared := xIndex * xIndex

  '------------------
  ' set values so first call to "ComputeNextSlow" will produce desired results

  nextSlow := xIndex[presentSlow]
  'stepsToTakeX[presentSlow]++
 
  if xIndex[presentSlow] == ||radius
    Pst.str(string(11, 13, "Slow axis equals radius at beginning so start with extra"))
    Pst.str(string(11, 13, "reverse direction to make the direction come out correct."))
    ReverseDirection(presentSlow)
  
  '---------------------
   
  
  
  Pst.str(string(11, 13, "max delay = "))
  Pst.Dec(axisDelay[presentFast] / MS_001)
  Pst.str(string(" ms, min delay = "))
  Pst.Dec(minDelay / MS_001)
  Pst.str(string(" ms, delay change = "))
  Pst.Dec(axisDeltaDelay / MS_001)
  Pst.str(string(" ms, accel interval = "))
  Pst.Dec(accelerationInterval / MS_001)
  Pst.str(string(" ms, timesToA = "))
  Pst.Dec(timesToA)

  Fona.PressToContinue
     
  Pst.str(string(11, 13, "----------------------------"))

  Pst.str(string(11, 13, "Accelerate Phase"))
  
  
  now := cnt
  lastStep := now
  lastHalfStep[0] := now
  lastHalfStep[1] := now
  lastHalfStep[presentFast] -= axisDelay[presentFast] / 2
  lastHalfStep[presentSlow] -= axisDelay[presentSlow] / 2
  lastAccelCnt := now
  ComputeNextSlow
 
  repeat
    
    now := cnt
    if now - lastHalfStep[presentFast] > axisDelay[presentFast]
      'Pst.str(string(11, 13, "n-Hf= "))
      'Pst.Dec((now - lastHalfStep[presentFast]) / MS_001)
      
      ComputeNextHalfStep(presentFast)
    if now - lastHalfStep[presentSlow] > axisDelay[presentSlow]
      {Pst.str(string(11, 13, "n-Hs= "))
      Pst.Dec((now - lastHalfStep[presentSlow]) / MS_001)
      Pst.str(string(11, 13, "aD["))
      Pst.Dec(presentSlow)
      Pst.str(string("]= "))
      Pst.Dec(axisDelay[presentSlow] / MS_001) }
      ComputeNextHalfStep(presentSlow)
    if now - lastStep > axisDelay[presentFast]
      {Pst.str(string(11, 13, "n-f= "))
      Pst.Dec((now - lastStep) / MS_001) }
      ComputeNextFullStep(presentFast)
     
    if now - lastAccelCnt > accelerationInterval
      {Pst.str(string(11, 13, "n-a= "))
      Pst.Dec((now - lastAccelCnt) / MS_001)}
      lastAccelCnt += accelerationInterval  
      AdjustSpeed
  'while xIndex < yIndex
  while stepsToTakeX or stepsToTakeY 'activeOctants
  
  Pst.str(string(11, 13, "x = "))
  Pst.Dec(xIndex)
  Pst.str(string(", y = "))
  Pst.Dec(yIndex)
  Pst.str(string(11, 13, "Done! Execution Over"))
  Fona.PressToContinue

' motion in ccw direction to center
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \4|3/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  5\|/2  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  6/|\1  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /7|0\  0) Cx<0, Cy>0

PUB ComputeNextHalfStep(localAxis) 

  if stepState[localAxis]
    missedHalfCount[localAxis]++
    {'150514b 
    if localAxis
      Pst.Char("Y")
    else
      Pst.Char("X")} '150514b
    {Pst.str(string(11, 13, "ComputeNextHalfStep, stepState[", 7))
    Pst.Dec(localAxis)
    Pst.Str(string("] = "))
    Pst.Dec(stepState[localAxis])
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "lastHalfStep["))
    Pst.Dec(localAxis)
    Pst.Str(string("] = "))
    Pst.Dec(lastHalfStep[localAxis] / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastHalfStep[localAxis]) / MS_001)
    Pst.Str(string(" ms "))  
    Pst.str(string(11, 13, "lastStep = "))
    Pst.Dec(lastStep / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastStep) / MS_001)
    Pst.Str(string(" ms "))  }
    return

  'lastHalfStep[localAxis] += axisDelay[localAxis]
  pLastHalfStep[localAxis] := lastHalfStep[localAxis]
  lastHalfStep[localAxis] := cnt

  '150514b if localAxis == presentSlow
    '150514b Pst.str(string(11, 13, "Slow Half"))
  if 0 'xIndex == 382
    Pst.str(string(11, 13, "Slow Half Step"))
    Pst.str(string(11, 13, "lastHalfStep["))
    Pst.Dec(localAxis)
    Pst.Str(string("] = "))
    Pst.Dec(lastHalfStep[localAxis] / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastHalfStep[localAxis]) / MS_001)
    Pst.Str(string(" ms (this should be a small value)"))
    Pst.str(string(11, 13, "cnt at next half step = "))
    Pst.Dec((lastHalfStep[localAxis] + axisDelay[localAxis]) / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "cnt at next full step = "))
    Pst.Dec((lastStep + axisDelay[localAxis]) / MS_001)
    Pst.Str(string(" ms")) 
    
  'outa[stepPin[localAxis] := 1
  outa[stepPinX[localAxis]] := 1
  stepState[localAxis] := 1
  
PUB ComputeNextFullStep(localAxis)

  {Pst.str(string(11, 13, "ComputeNextFullStep("))
  Pst.Dec(localAxis)
  Pst.Str(string(")"))  }
  ifnot stepState[localAxis]
    Pst.str(string(11, 13, "ComputeNextFullStep, stepState[", 7))
    Pst.Dec(localAxis)
    Pst.Str(string("] = "))
    Pst.Dec(stepState[localAxis])
    return             ' get half step first

  {Pst.str(string(11, 13, "lastStep was = "))
  Pst.Dec(lastStep / MS_001)
  Pst.Str(string(" ms")) }
  
  'lastStep += axisDelay[localAxis]
  pLastStep := lastStep
  lastStep := cnt
  
  {Pst.str(string(11, 13, "lastStep  is = "))
  Pst.Dec(lastStep / MS_001)
  Pst.Str(string(" ms")) }   

  if 0 'xIndex > 62
    Pst.str(string(11, 13, "lastStep = "))
    Pst.Dec(lastStep / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "difference full = "))
    Pst.Dec((cnt - lastStep) / MS_001)
    Pst.Str(string(" ms (this should be a small value)"))
  'xIndex[localAxis] += directionX[(PIECES_IN_CIRCLE * localAxis) + activeOctant]
  xIndex[localAxis] += presentDirectionX[localAxis]
  stepsToTakeX[localAxis]--
  if localAxis == presentSlow  ' This shouldn't happen
    Pst.str(string(11, 13, "Slow Step"))
   { Pst.str(string(11, 13, "lastHalfStep["))
    Pst.Dec(localAxis)
    Pst.Str(string("] = "))
    Pst.Dec(lastHalfStep[localAxis] / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "lastStep = "))
    Pst.Dec(lastStep / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "difference half = "))
    Pst.Dec((cnt - lastHalfStep[localAxis]) / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "difference full = "))
    Pst.Dec((cnt - lastStep) / MS_001)
    Pst.Str(string(" ms (this should be a small value)"))
    Pst.str(string(11, 13, "cnt at next half step = "))
    Pst.Dec((lastHalfStep[localAxis] + axisDelay[localAxis]) / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "cnt at next full step = "))
    Pst.Dec((lastStep + axisDelay[localAxis]) / MS_001)
    Pst.Str(string(" ms")) }
    
  ifnot xIndex[localAxis]  
    AdvanceOctant
    '-presentDirectionX[otherAxis[localAxis]] ' slow direction is reversed
    
    '150514a Pst.str(@astriskLine)
    {'150514c 
    Pst.str(string(11, 13))
    if localAxis
      Pst.Char("Y")
    else
      Pst.Char("X")
    Pst.str(string(" Equals 0")) }'150514c  
    '150514a Pst.str(@astriskLine)
  if ||xIndex[localAxis] == radius  ' this shouldn't happen
    Pst.str(@astriskLine)
    Pst.str(string(11, 13))
    if localAxis
      Pst.Char("Y")
    else
      Pst.Char("X")
    Pst.str(string(" = "))
    Pst.Dec(xIndex[localAxis])  
    CatastrophicError(@fastAtRadiusError)
      
  case accelPhase
    ACCEL_PHASE:
      if stepsToTakeX[localAxis] =< toTakeFullSpeedTrigger and localAxis == accelAxis
        Pst.str(string(11, 13, "Full Speed Phase ********************"))
        {if localAxis <> accelAxis
          Pst.str(string(11, 13, "localAxis = ", 7))
          Pst.Dec(localAxis)
          Pst.Str(string(", accelAxis = "))
          Pst.Dec(accelAxis)
          CatastrophicError(@accelAxisError) }
        Pst.str(string(11, 13, "stepsToTakeX[localAxis] = "))
        Pst.Dec(stepsToTakeX[localAxis])
        Pst.Str(string(", toTakeFullSpeedTrigger = "))
        Pst.Dec(toTakeFullSpeedTrigger)
        repeat
        accelPhase := FULL_SPEED_PHASE
        lastAccel := axisDelay[localAxis]
        axisDelay[localAxis] := minDelay
        lastHalfStep[localAxis] := cnt - (minDelay / 2)
        axisDeltaDelay[localAxis] := 0
        axisDeltaDelay[otherAxis[localAxis]] := 0
    FULL_SPEED_PHASE:
      if stepsToTakeX[localAxis] =< toTakeDecelTrigger and localAxis == decelAxis 
        Pst.str(string(11, 13, "Decelerate Phase"))
        {if localAxis <> decelAxis 
          Pst.str(string(11, 13, "localAxis = ", 7))
          Pst.Dec(localAxis)
          Pst.Str(string(", decelAxis = "))
          Pst.Dec(decelAxis)
          CatastrophicError(@decelAxisError)  }
        Pst.str(string(11, 13, "stepsToTakeX[localAxis] = "))
        Pst.Dec(stepsToTakeX[localAxis])
        Pst.Str(string(", toTakeDecelTrigger = "))
        Pst.Dec(toTakeDecelTrigger)
        repeat
        accelPhase := DECEL_PHASE
        axisDelay[decelAxis] := lastAccel 
        axisDeltaDelay[localAxis] := defaultDeltaDelay
        lastHalfStep[localAxis] := cnt - (axisDelay[localAxis] / 2)
    DECEL_PHASE:

  toTakeFullSpeedTrigger := stepsToTakeX[accelAxis] - timesToA
  

  
  'outa[stepPin[localAxis] := 0
  outa[stepPinX[localAxis]] := 0
  stepState[localAxis] := 0
 
  if xIndex[localAxis] == fastAtNextSlow
    
    result := lastHalfStep[otherAxis[localAxis]]
    lastHalfStep[otherAxis[localAxis]] := cnt   
    ifnot stepState[otherAxis[localAxis]]
      outa[stepPinX[otherAxis[localAxis]]] := 1
      stepState[otherAxis[localAxis]] := 1
      if missedHalfCount[otherAxis[localAxis]] == 0
        Pst.str(string(7, 11, 13, "missedHalfCount equals zero", 7))
      {Pst.str(string(7, 11, 13, "Error! Slow axis in wrong stepState!", 7))
      Pst.str(string(11, 13, "lastHalfStep[otherAxis[localAxis]] was = "))
      Pst.Dec(result / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "lastHalfStep[otherAxis[localAxis]]  is = "))
      Pst.Dec(lastHalfStep[otherAxis[localAxis]] / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "time since lastHalfStep[slow] = "))
      Pst.Dec((cnt - result) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "there should have been a half step = "))
      Pst.Dec((cnt - (result + axisDelay[otherAxis[localAxis]])) / MS_001)
      Pst.Str(string(" ms ago (is this positive?)"))
      Pst.str(string(11, 13, "next half step should be = "))
      Pst.Dec((lastHalfStep[otherAxis[localAxis]] + axisDelay[otherAxis[localAxis]]) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "cnt = "))
      Pst.Dec(cnt / MS_001)
      Pst.Str(string(" ms")) }
      'repeat
    missedHalfCount[otherAxis[localAxis]] := 0
    
    outa[stepPinX[otherAxis[localAxis]]] := 0
    stepState[otherAxis[localAxis]] := 0
    stepsToTakeX[otherAxis[localAxis]]--
    ComputeNextSlow
    '150514d if xIndex == yIndex
    '150514d   Pst.str(string(11, 13, "X Equals Y *************************"))
      

  {'150514d}
  {'150514e
  previousCnt := newCnt
  newCnt := cnt
  differenceCnt := newCnt - previousCnt
  Pst.str(string(11, 13, "x = "))
  Pst.Dec(xIndex)
  Pst.str(string(", y = "))
  Pst.Dec(yIndex) 
  Pst.str(string(11, 13, "missedHalfCount = "))
  Pst.Dec(missedHalfCount[0])
  Pst.str(string(", and "))
  Pst.Dec(missedHalfCount[1]) 
  Pst.str(string(11, 13, "cnt = "))
  DecPoint(newCnt / MS_001, 3)
  Pst.Str(string(" s, difference = "))
  Pst.Dec(differenceCnt / MS_001)
  Pst.Str(string(" ms"))   } '150514e
  if differenceCnt > constant(100 * MS_001)
    Pst.str(string(11, 13, "fastAtNextSlow = "))
    Pst.Dec(fastAtNextSlow)
    Pst.str(string(11, 13, "pLastHalfStep = "))
    Pst.Dec(pLastHalfStep[0] / MS_001)
    Pst.str(string(", and "))
    Pst.Dec(pLastHalfStep[1] / MS_001)
    Pst.str(string(11, 13, "lastHalfStep = "))
    Pst.Dec(lastHalfStep[0] / MS_001)
    Pst.str(string(", and "))
    Pst.Dec(lastHalfStep[1] / MS_001)
    Pst.str(string(11, 13, "pLastStep = "))
    Pst.Dec(pLastStep / MS_001)
   
    Pst.str(string(11, 13, "lastStep = "))
    Pst.Dec(lastStep / MS_001)
   

   {}'150514d 
  {if xIndex > 300
    Pst.str(string(11, 13, "Why? "))
    repeat }
PUB ComputeNextSlow | previousSlow

  '150513a Pst.str(string(11, 13, "ComputeNextSlow"))

  'presentFast := presentFast[startOctant]
  'presentSlow := slowAxisByOctant[startOctant]
  'presentDirectionX
  previousSlow := xIndex[presentSlow]
  xIndex[presentSlow] := nextSlow
  'stepsToTakeX[presentSlow]--
  ifnot xIndex[presentSlow]
    CatastrophicError(string("Slow Axis Equals Zero")) 

  if ||xIndex[presentSlow] == ||radius
    '150513a Pst.str(string(11, 13, "Slow Axis Equals Radius"))
    '-presentDirectionX[presentSlow] ' slow direction is reversed
    'SetDirection(presentSlow, presentDirectionX[presentSlow])
    ReverseDirection(presentSlow)
  

  if ||xIndex[presentSlow] == ||xIndex[presentFast] or ||previousSlow == ||xIndex[presentFast]
    AdvanceOctant
    '150514a Pst.str(@astriskLine)
    {'150514a Pst.str(string(7, 11, 13, "before SwapSpeeds, nextSlow (old) = "))
    Pst.Dec(nextSlow)
    Pst.str(string(11, 13, "transition okay? fastAtNextSlow (old) = "))
    Pst.Dec(fastAtNextSlow)
    Pst.str(string(11, 13, "xIndex[presentSlow] (new) = "))
    Pst.Dec(xIndex[presentSlow])
    Pst.str(string(11, 13, "xIndex[presentFast] = "))
    Pst.Dec(xIndex[presentFast])
    Pst.str(string(11, 13, "previousSlow = "))
    Pst.Dec(previousSlow)  }'150514a 
    result := 1
    SwapSpeeds
    'repeat

  nextSlow := xIndex[presentSlow] + presentDirectionX[presentSlow]
  nextSlowSquared := nextSlow * nextSlow
  fastAtNextSlow := ^^(rSquared - nextSlowSquared)
  if ||fastAtNextSlow > radius 
    Pst.str(@astriskLine)
    Pst.str(string(11, 13, "fastAtNextSlow = "))
    Pst.Dec(fastAtNextSlow)
    Pst.str(string(11, 13, "nextSlowSquared = "))
    Pst.Dec(nextSlowSquared)
    Pst.str(string(11, 13, "nextSlow = "))
    Pst.Dec(nextSlow)
    Pst.str(string(11, 13, "xIndex[presentSlow] = "))
    Pst.Dec(xIndex[presentSlow])
    Pst.str(string(11, 13, "presentDirectionX[presentSlow] = "))
    Pst.Dec(presentDirectionX[presentSlow])
    CatastrophicError(string("fastAtNextSlow too large"))
    
  if 0 '150514a result
    Pst.str(string(7, 11, 13, "after SwapSpeeds, nextSlow (new) = "))
    Pst.Dec(nextSlow)
    Pst.str(string(11, 13, "fastAtNextSlow (new) = "))
    Pst.Dec(fastAtNextSlow)
    
  case activeOctant
    1, 4, 6, 7:
      -fastAtNextSlow
      {'150514a Pst.str(string(11, 13, "negate fastAtNextSlow"))
      if result
        Pst.str(string(11, 13, "fastAtNextSlow (negated) = "))
        Pst.Dec(fastAtNextSlow) } '150514a 
             
  fastStepsPerSlow := ||(fastAtNextSlow - xIndex[presentFast])
  axisDelay[presentSlow] := axisDelay[presentFast] * fastStepsPerSlow
  axisDeltaDelay[presentSlow] := axisDeltaDelay[presentFast] * fastStepsPerSlow
  lastHalfStep[presentSlow] := cnt - (axisDelay[presentSlow] / 2)

  '150514a Pst.str(string(11, 13, "fastStepsPerSlow = "))
  '150514a Pst.Dec(fastStepsPerSlow)
  if ||fastStepsPerSlow > radius / 2
    Pst.str(string(7, 11, 13, "fastAtNextSlow = "))
    Pst.Dec(fastAtNextSlow)
    Pst.str(string(11, 13, "xIndex[presentFast] = "))
    Pst.Dec(xIndex[presentFast])
    CatastrophicError(string("||fastStepsPerSlow > radius / 2"))
     
  {if xIndex[presentSlow] == xIndex[presentFast] or previousSlow == xIndex[presentFast]
    AdvanceOctant
    Pst.str(string(7, 11, 13, "before SwapSpeeds, nextSlow = "))
    Pst.Dec(nextSlow)
    Pst.str(string(11, 13, "transition okay? fastAtNextSlow = "))
    Pst.Dec(fastAtNextSlow)
    SwapSpeeds
  }
  {'150513a   
  Pst.str(string(11, 13, "axisDelay[presentFast] = "))
  Pst.Dec(axisDelay[presentFast] / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "axisDeltaDelay[presentFast] = "))
  Pst.Dec(axisDeltaDelay[presentFast] / MS_001)
  Pst.Str(string(" ms"))

  Pst.str(string(11, 13, "axisDelay[presentSlow] = "))
  Pst.Dec(axisDelay[presentSlow] / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "axisDeltaDelay[presentSlow] = "))
  Pst.Dec(axisDeltaDelay[presentSlow] / MS_001)
  Pst.Str(string(" ms"))

  Pst.str(string(11, 13, "nextSlow = "))
  Pst.Dec(nextSlow)
  Pst.str(string(11, 13, "fastAtNextSlow = "))
  Pst.Dec(fastAtNextSlow)
  Pst.str(string(11, 13, "fastStepsPerSlow = "))
  Pst.Dec(fastStepsPerSlow)
  }'150513a 
  {'150513a case xIndex
    61, 62, 63, 67, 68, 69:
      Pst.str(string(11, 13, "lastHalfStep[presentSlow] = "))
      Pst.Dec(lastHalfStep[presentSlow] / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "time since lastHalfStep[slow] = "))
      Pst.Dec((cnt - lastHalfStep[presentSlow]) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "next half step should be = "))
      Pst.Dec((lastHalfStep[presentSlow] + axisDelay[presentSlow]) / MS_001)
      Pst.Str(string(" ms"))

      Pst.str(string(11, 13, "next fast full step should be = "))
      Pst.Dec((lastStep + axisDelay[presentFast]) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "fastAtNextSlow fast full step should be = "))
      Pst.Dec((lastStep + (axisDelay[presentFast] * fastStepsPerSlow)) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "cnt = "))
      Pst.Dec(cnt / MS_001)
      Pst.Str(string(" ms"))    }'150513a 
    
PUB SwapSpeeds

  presentFast := presentSlow
  presentSlow := otherAxis[presentFast]
  result := axisDeltaDelay[0]
  axisDeltaDelay[0] := axisDeltaDelay[1]
  axisDeltaDelay[1] := result
  result := axisDelay[0]
  axisDelay[0] := axisDelay[1]
  axisDelay[1] := result

  result := lastHalfStep[0]
  lastHalfStep[0] := lastHalfStep[1]
  lastHalfStep[1] := result
  
  {Pst.str(string(7, 11, 13, "SwapSpeeds, new fast = "))
  Pst.Dec(presentFast)
    
  repeat result from 0 to 1
    Pst.str(string(11, 13, "axisDelay["))
    Pst.Dec(result)
    Pst.Str(string("] = "))
    Pst.Dec(axisDelay[result] / MS_001)
    Pst.Str(string(" ms"))

    Pst.str(string(11, 13, "axisDeltaDelay["))
    Pst.Dec(result)
    Pst.Str(string("] = "))
    Pst.Dec(axisDeltaDelay[result] / MS_001)
    Pst.Str(string(" ms"))  }

  
PUB AdvanceOctant

  activeOctant++
  activeOctant &= 7
  '150514c Pst.str(string(11, 13, "activeOctant = "))
  '150514c Pst.Dec(activeOctant)
  '150514a Pst.str(@astriskLine)
  
PUB ReverseDirection(localAxis)

  {Pst.str(string(11, 13, "presentDirectionX["))
  Pst.Dec(localAxis)
  Pst.Str(string("] was = "))
  Pst.Dec(presentDirectionX[localAxis]) }
  
  -presentDirectionX[localAxis]
  
 { Pst.str(string(11, 13, "presentDirectionX["))
  Pst.Dec(localAxis)
  Pst.Str(string("]  is = "))
  Pst.Dec(presentDirectionX[localAxis]) }
  
  if presentDirectionX[localAxis] == 1
    outa[dirPinX[localAxis]] := 1
  else
    outa[dirPinX[localAxis]] := 0
    
PUB AdjustSpeed

  axisDelay[0] += axisDeltaDelay[0]
  axisDelay[1] += axisDeltaDelay[1]
  {Pst.str(string(11, 13, "AdjustSpeed = (fast)axisDelay[ "))
  Pst.Dec(presentFast)
  Pst.Str(string("] = "))
  Pst.Dec(axisDelay[presentFast] / MS_001)
  Pst.Str(string(" ms, axisDelay[ "))
  Pst.Dec(presentSlow)
  Pst.Str(string("] = "))
  Pst.Dec(axisDelay[presentSlow] / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "(fast)axisDeltaDelay[ "))
  Pst.Dec(presentFast)
  Pst.Str(string("] = "))
  Pst.Dec(axisDeltaDelay[presentFast] / MS_001)
  Pst.Str(string(" ms, axisDeltaDelay[ "))
  Pst.Dec(presentSlow)
  Pst.Str(string("] = "))
  Pst.Dec(axisDeltaDelay[presentSlow] / MS_001)
  Pst.Str(string(" ms"))    
  Pst.str(string(11, 13, "cnt at next half step (fast)= "))
  Pst.Dec((lastHalfStep[presentFast] + axisDelay[presentFast]) / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "cnt at next full step = "))
  Pst.Dec((lastStep + axisDelay[presentFast]) / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "cnt at next half step (slow)= "))
  Pst.Dec((lastHalfStep[presentSlow] + axisDelay[presentSlow]) / MS_001)
  Pst.Str(string(" ms"))
 
  Pst.str(string(11, 13, "cnt = "))
  Pst.Dec(cnt / MS_001)
  Pst.Str(string(" ms"))     }
  
PRI ComputeAccelIntervals(localMax, localMin, localChange, localAccelInterval) | nextAccel, {
} nextStep

  {{Pst.Str(string(11, 13, "ComputeAccelIntervals("))
  Pst.Dec(localMax)
  Pst.Str(string(", "))
  Pst.Dec(localMin)
  Pst.Str(string(", "))
  Pst.Dec(localChange)
  Pst.Str(string(", "))
  Pst.Dec(localAccelInterval)
  Pst.Str(string("), accelIntervals = "))
  Pst.Dec(accelIntervals) }}
  
  longfill(@nextAccel, 0, 2)

  repeat while localMax > localMin
    nextAccel += localAccelInterval
    {{Pst.Str(string(11, 13, "localMax = "))
    Pst.Dec(localMax)
    Pst.Str(string(", Min = "))
    Pst.Dec(localMin)}}
    
    repeat while nextStep < nextAccel
      result++
      nextStep += localMax
      {{Pst.Str(string(", intervals = "))
      Pst.Dec(result)
      Pst.Str(string(", nextStep = "))
      Pst.Dec(nextStep)}}
    localMax -= localChange  

PUB TtaMethod(N, X, localD)   ' return X*N/D where all numbers and result are positive =<2^31
  return (N / localD * X) + (binNormal(N//localD, localD, 31) ** (X*2))

PUB BinNormal (y, x, b) : f                  ' calculate f = y/x * 2^b
' b is number of bits
' enter with y,x: {x > y, x < 2^31, y <= 2^31}
' exit with f: f/(2^b) =<  y/x =< (f+1) / (2^b)
' that is, f / 2^b is the closest appoximation to the original fraction for that b.
  repeat b
    y <<= 1
    f <<= 1
    if y => x    '
      y -= x
      f++
  if y << 1 => x    ' Round off. In some cases better without.
      f++
   }
PUB DecPoint(value, decimalPlaces) | localBuffer[4]

  result := Format.FDec(@localBuffer, value, decimalPlaces + 4, decimalPlaces)
  byte[result] := 0
  Pst.str(@localBuffer)

PUB CatastrophicError(errorPtr)

  Pst.str(@astriskLine)
  Pst.str(string(7, 11, 13, "Error! ", 7))
  Pst.str(errorPtr)
  Pst.str(string(7, 11, 13, "Done! Program Over", 7))
  repeat

{PUB DisplayAxis(localIndex)

  Pst.str(Header.FindString(@axisText, localIndex))
  Pst.str(string("-Axis"))
  
PUB DisplayPhase(localIndex)

  Pst.str(Header.FindString(@phaseText, localIndex))
  Pst.str(string(" phase"))
  
PUB DisplaySpeed(localIndex)

  Pst.str(Header.FindString(@speedText, localIndex))
  
PUB DisplayDirection(localIndex)

  Pst.str(Header.FindString(@directionText, localIndex))
      }
DAT

astriskLine   byte 11, 13, "**************************************************"
              byte "*********************", 0

fastAtRadiusError       byte "||xIndex[localAxis] == radius", 0
accelAxisError          byte "localAxis <> accelAxis", 0
decelAxisError          byte "localAxis <> decelAxis", 0

axisText                byte "X", 0, "Y", 0
speedText               byte "fast", 0, "slow", 0
phaseText               byte "accleration", 0, "full speed", 0, "deceleration", 0
directionText           byte "forward", 0, "reverse", 0

networkStateText        byte "The Fona is off, it's not possible to detect network.", 0
                        byte "The Fona is not connected to a network.", 0
                        byte "The network is ready for voice and text.", 0
                        byte "The network is ready for GPRS data.", 0
'  #0, FONA_OFF_NETWORK, NO_CONNECTION_NETWORK, READY_NETWORK, GPRS_DATA_ACTIVE_NETWORK
  
phoneNumberText         byte "2400000", 0
                        byte "2390000", 0
                        byte "6370000", 0
                        
phoneNameText           byte "Christina Cell", 0
                        byte "Christina Home", 0
                        byte "Christina Work", 0

textMessageText         byte "Hi Chrisina, I love you.", 0
                        byte "Christina you are a beautiful person.", 0
                        byte "Christina would you like to go on a date with me tonight?", 0
                        byte "Yes dear.", 0
'' Make sure and change the constant "TEXT_MESSAGES" if messages are added or removed.                        

phoneTypeText           byte "land line", 0
                        byte "cell phone", 0

phoneType               byte CELL_LINE, LAND_LINE, LAND_LINE