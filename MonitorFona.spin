DAT programName         byte "MonitorFona", 0
CON
{{
  By Duane Degn
  June 6, 2015

  This program monitors four serial lines. The four
  serial lines monitored are the data out from the
  FONA module, the data sent to the FONA from the
  Arduino, the data sent from the Arduino's terminal
  window and the Arduino and it also monitors the
  data sent from the Arduino to the terminal window.

  The purpose of the program it to make it easier to
  write a similar program to the one written by
  Limor Fried (aka Lady Ada)of Adafruit Industries.

  I think it will be easier to determine the proper
  syntex of various commands by seeing the data 
  exchanged by the various devices than attempting
  to understand these commands from the datasheet
  or from reading Lady Ada's program.
  
  This program using six of the Propeller's eight cogs.
  Five of the cogs are used to create software UARTs.
  One cog is used to monitor these UARTs for new data.
  
}}
{
  ******* Private Notes *******
  
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MILLISECOND = CLK_FREQ / 1_000

  TIME_TIL_SERIAL_RELEASE = 2 * MILLISECOND ' To prevent fragmented serial data
  
  ' serialId and rx pin
  #0, FONA, ARDUINO, FROM_TERM, TO_TERM

  MAX_SERIAL_ID = TO_TERM
  NUMBER_OF_SERIAL_TO_MONITOR = MAX_SERIAL_ID + 1

OBJ

  Pst : "Parallax Serial Terminal"
  Serial[NUMBER_OF_SERIAL_TO_MONITOR] : "Parallax Serial Terminal"
  
PUB Start

  Pst.Start(57_600)
  InitSerialToMonitor
  
  MonitorFona
  
PRI InitSerialToMonitor : serialId

  repeat serialId from 0 to MAX_SERIAL_ID
    Serial[serialId].StartRxTx(serialId, -1, 0, baud[serialId])
 
PUB MonitorFona : serialId
'' Monitors Comminication between Arduino and Fona.
'' This method only listens to Fona. It does
'' not pass any data to the Fona.

  repeat
    repeat serialId from 0 to MAX_SERIAL_ID
      RxFromSerial(serialId, TIME_TIL_SERIAL_RELEASE)
      
PRI RxFromSerial(serialId, serialHoldInterval) | timer, localCharacter, crFlag

  crFlag := 0
  timer := cnt + serialHoldInterval ' make sure empty rx buffers get skipped
  
  repeat
    result := Serial[serialId].RxCount
    if result
      localCharacter := Serial[serialId].CharIn    
      if localCharacter and previousSource <> serialId
        Pst.ClearEnd
        Pst.NewLine
        Pst.Str(FindString(@serialNameText, serialId))
        Pst.Char(">")
        previousSource := serialId
      if localCharacter == 13 
        if crFlag++ ' skip first cariage return 
          Pst.NewLine
      SafeTx(localCharacter)
      timer := cnt
  while cnt - timer < serialHoldInterval
  
PRI SafeTx(localCharacter)

  if localCharacter => 32 and localCharacter =< "~"
    Pst.Char(localCharacter)
  elseif localCharacter == 0 ' this may need to be changed if monitoring raw data
                             ' "Parallax Serial Terminal" doesn't catch framing errors
                             ' so without this "elseif" line you can end up with a
                             ' bunch of zeros if a line is inactive. 
    return
  else
    Pst.Char("<") 
    Pst.Char("$")
    Pst.Hex(localCharacter, 2)
    Pst.Char(">")

PUB FindString(firstStr, stringIndex)      
'' Finds start address of one string in a list
'' of string. "firstStr" is the address of 
'' string #0 in the list. "stringIndex"
'' indicates which of the strings in the list
'' the method is to find.

  result := firstStr 
  repeat while stringIndex    
    repeat while byte[result++]  
    stringIndex--
    
DAT

baud                    long 4_800[2], 57_600[2]
  
serialNameText          byte "FONA", 0, "Ard", 0, "FromTerm", 0, "ToTerm", 0
previousSource          byte 255
    